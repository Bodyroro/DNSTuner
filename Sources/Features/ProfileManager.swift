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

    init() { refresh() }

    // MARK: - Détection

    /// Relit les profils installés, sans jamais demander de privilège.
    ///
    /// Nos profils sont de portée système : `profiles show` ne les liste pas
    /// sans être root. On croise donc deux sources — les identifiants confirmés
    /// installés, mémorisés par l'app, et `profiles status`, qui sait dire sans
    /// élévation s'il reste au moins un profil sur la machine. Si la machine
    /// n'en a plus aucun, la mémoire est purgée : l'utilisateur a pu retirer le
    /// profil depuis Réglages Système, et l'app ne doit pas prétendre le contraire.
    func refresh() {
        var found = profilesListedForUser()

        if systemHasProfiles() {
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
            stopPolling()
        }
    }

    /// Profils DNSTuner visibles au niveau utilisateur. Vide en principe, mais
    /// couvre le cas d'un profil resté d'une version antérieure de l'app.
    private func profilesListedForUser() -> Set<String> {
        let output = Shell.run(profilesTool, ["show"])
        var found: Set<String> = []
        for line in output.split(separator: "\n") {
            guard let range = line.range(of: "profileIdentifier:") else { continue }
            let id = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if id.hasPrefix(ProfileBuilder.identifierPrefix) { found.insert(id) }
        }
        return found
    }

    /// Vrai s'il reste au moins un profil de configuration sur la machine.
    /// `profiles status` répond pour l'ensemble du système, sans root.
    private func systemHasProfiles() -> Bool {
        let r = Shell.runResult(profilesTool, ["status", "-type", "configuration"])
        guard r.ok else { return false }
        return !r.out.localizedCaseInsensitiveContains("no configuration profiles")
    }

    func isInstalled(_ provider: DNSProvider, transport: DNSTransport) -> Bool {
        installed.contains(ProfileBuilder.identifier(for: provider, transport: transport))
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
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            lastError = error.localizedDescription
            return false
        }

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
                self?.refresh()
                if self?.awaitingApproval == nil { return }
            }
            self?.awaitingApproval = nil
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Abandonne l'attente d'approbation (l'utilisateur a renoncé).
    func cancelPending() {
        awaitingApproval = nil
        stopPolling()
    }

    // MARK: - Suppression

    /// Supprime un profil DNSTuner. Tente d'abord sans privilèges — un profil
    /// installé au niveau utilisateur se retire sans mot de passe — puis via
    /// l'invite d'administration si nécessaire.
    @discardableResult
    func remove(identifier id: String) -> Bool {
        lastError = nil
        // Garde-fou : ne jamais retirer un profil qui n'est pas le nôtre.
        guard id.hasPrefix(ProfileBuilder.identifierPrefix) else {
            lastError = T("error.foreignProfile")
            return false
        }

        let direct = Shell.runResult(profilesTool, ["remove", "-identifier", id])
        if direct.ok {
            finishRemoval(id)
            return true
        }

        let elevated = Shell.admin("\(profilesTool) remove -identifier \(Shell.shellQuoted(id))")
        if elevated.ok {
            finishRemoval(id)
            return true
        }
        if Shell.wasCancelled(elevated) {
            Journal.shared.log(.info, T("journal.cancelled"))
            return false
        }
        lastError = elevated.err.trimmingCharacters(in: .whitespacesAndNewlines)
        Journal.shared.log(.failure, T("journal.profileRemoveFailed", id))
        refresh()
        return false
    }

    private func finishRemoval(_ id: String) {
        Store.installedProfileIDs.remove(id)
        Journal.shared.log(.success, T("journal.profileRemoved", id))
        refresh()
    }

    /// Supprime tous les profils posés par DNSTuner.
    @discardableResult
    func removeAll() -> Bool {
        var allOK = true
        for id in installed where !remove(identifier: id) { allOK = false }
        return allOK
    }
}
