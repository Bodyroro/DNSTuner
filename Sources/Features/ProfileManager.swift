//
//  ProfileManager.swift · Cycle de vie des profils DoH / DoT
//
//  Installation : `profiles install` est déprécié depuis macOS 11 (« You should
//  add your profiles using the System Settings Profiles preference pane »).
//  L'app écrit donc le profil et l'ouvre : macOS propose l'installation, que
//  l'utilisateur valide dans Réglages Système › Général › Gestion des appareils.
//
//  Suppression : `profiles remove -identifier <id>` reste pleinement scriptable.
//  C'est ce qui permet le bouton « Désactiver » directement dans l'app.
//

import Foundation
import AppKit

@MainActor
final class ProfileManager: ObservableObject {

    /// Identifiants des profils DNSTuner actuellement installés.
    @Published private(set) var installed: Set<String> = []
    /// Profil dont l'installation a été proposée et qui attend l'approbation.
    @Published private(set) var awaitingApproval: String?
    @Published var lastError: String?

    private let profilesTool = "/usr/bin/profiles"
    private var pollTask: Task<Void, Never>?
    private var readGeneration = 0
    /// Fichier du profil proposé, supprimé dès que l'attente se termine.
    private var pendingFile: URL?

    init() { refresh() }

    // MARK: - Détection

    /// Lecture des profils, hors du fil principal : `profiles show` et `profiles status`
    /// sont lents, et l'interrogation se répète toutes les 2 s pendant l'attente.
    private nonisolated static func readState(tool: String) -> (listed: Set<String>, systemHasProfiles: Bool) {
        var listed: Set<String> = []
        for line in Shell.run(tool, ["show"]).split(separator: "\n") {
            guard let range = line.range(of: "profileIdentifier:") else { continue }
            let id = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if id.hasPrefix(ProfileBuilder.identifierPrefix) { listed.insert(id) }
        }
        // `profiles status` répond pour l'ensemble du système, sans root.
        let r = Shell.runResult(tool, ["status", "-type", "configuration"])
        let hasProfiles = r.ok && !r.out.localizedCaseInsensitiveContains("no configuration profiles")
        return (listed, hasProfiles)
    }

    func refresh() {
        Task { await reload() }
    }

    /// Relit les profils installés, sans jamais demander de privilège.
    ///
    /// Nos profils sont de portée système : `profiles show` ne les liste pas
    /// sans être root. On croise donc deux sources : les identifiants confirmés
    /// installés, mémorisés par l'app, et `profiles status`, qui sait dire sans
    /// élévation s'il reste au moins un profil sur la machine. Si la machine
    /// n'en a plus aucun, la mémoire est purgée : l'utilisateur a pu retirer le
    /// profil depuis Réglages Système, et l'app ne doit pas prétendre le contraire.
    func reload() async {
        let tool = profilesTool
        readGeneration += 1
        let generation = readGeneration
        let state = await Task.detached(priority: .userInitiated) { Self.readState(tool: tool) }.value
        // Une lecture plus ancienne qui finit après une plus récente est ignorée (sondage, retrait, rafraîchissement).
        guard generation == readGeneration else { return }
        var found = state.listed

        if state.systemHasProfiles {
            found.formUnion(Store.installedProfileIDs)
            // Un profil apparu pendant l'attente est celui qu'on vient de proposer.
            if let pending = awaitingApproval { found.insert(pending) }
        } else {
            // Plus aucun profil sur la machine : la mémoire est caduque.
            found = []
        }

        installed = found
        Store.installedProfileIDs = found

        if let pending = awaitingApproval, found.contains(pending) {
            awaitingApproval = nil
            removePendingFile()
            stopPolling()
        }
    }

    /// Profil DNSTuner actif, s'il y en a un (un seul peut être pertinent à la fois).
    var activeIdentifier: String? { installed.first }

    // MARK: - Installation

    /// Génère le profil et le présente à l'utilisateur pour approbation.
    /// L'app ne peut pas installer elle-même : macOS impose la validation manuelle.
    @discardableResult
    func install(_ provider: DNSProvider, transport: DNSTransport) -> Bool {
        lastError = nil
        guard let data = ProfileBuilder.makeProfile(for: provider, transport: transport) else {
            lastError = T("error.transportUnavailable")
            return false
        }

        let id = ProfileBuilder.identifier(for: provider, transport: transport)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(id).mobileconfig")
        removePendingFile()
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            lastError = error.localizedDescription
            return false
        }
        pendingFile = url

        NSWorkspace.shared.open(url)
        awaitingApproval = id
        Journal.shared.log(.info, T("journal.profileOffered", provider.displayName))
        startPolling()
        return true
    }

    /// Ouvre directement le volet où l'utilisateur valide le profil téléchargé.
    func openDeviceManagementSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Profiles-Settings.extension")!
        NSWorkspace.shared.open(url)
    }

    /// Sonde l'apparition du profil après approbation, sans bloquer l'interface.
    private func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            for _ in 0..<60 {   // ~2 minutes, largement de quoi valider le profil
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
                await self?.reload()
                if self?.awaitingApproval == nil { return }
            }
            self?.awaitingApproval = nil
            self?.removePendingFile()
        }
    }

    private func removePendingFile() {
        if let url = pendingFile { try? FileManager.default.removeItem(at: url) }
        pendingFile = nil
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Abandonne l'attente d'approbation (l'utilisateur a renoncé).
    func cancelPending() {
        awaitingApproval = nil
        removePendingFile()
        stopPolling()
    }

    // MARK: - Suppression

    /// Supprime un profil DNSTuner. Tente d'abord sans privilèges : un profil
    /// installé au niveau utilisateur se retire sans mot de passe : puis via
    /// l'invite d'administration si nécessaire.
    @discardableResult
    func remove(identifier id: String) async -> Bool {
        lastError = nil
        // Garde-fou : ne jamais retirer un profil qui n'est pas le nôtre.
        guard id.hasPrefix(ProfileBuilder.identifierPrefix) else {
            lastError = T("error.foreignProfile")
            return false
        }

        let tool = profilesTool
        // L'invite de mot de passe attend l'utilisateur : hors du fil principal.
        let (direct, elevated) = await Task.detached(priority: .userInitiated) {
            () -> (Shell.Result, Shell.Result?) in
            let direct = Shell.runResult(tool, ["remove", "-identifier", id])
            if direct.ok { return (direct, nil) }
            return (direct, Shell.admin("\(tool) remove -identifier \(Shell.shellQuoted(id))"))
        }.value
        if direct.ok {
            await finishRemoval(id)
            return true
        }
        guard let elevated else { return false }
        if elevated.ok {
            await finishRemoval(id)
            return true
        }
        if Shell.wasCancelled(elevated) {
            Journal.shared.log(.info, T("journal.cancelled"))
            return false
        }
        lastError = elevated.err.trimmingCharacters(in: .whitespacesAndNewlines)
        Journal.shared.log(.failure, T("journal.profileRemoveFailed", id))
        await reload()
        return false
    }

    private func finishRemoval(_ id: String) async {
        Store.installedProfileIDs.remove(id)
        Journal.shared.log(.success, T("journal.profileRemoved", id))
        await reload()
    }

    /// Supprime tous les profils posés par DNSTuner.
    @discardableResult
    func removeAll() async -> Bool {
        var allOK = true
        for id in installed {
            if await !remove(identifier: id) { allOK = false }
        }
        return allOK
    }
}
