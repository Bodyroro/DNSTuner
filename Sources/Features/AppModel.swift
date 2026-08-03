//
//  AppModel.swift · État partagé de l'application
//
//  Rassemble les trois moteurs (DNS clair, profils chiffrés, tests) et expose
//  l'état résumé qu'affiche le bandeau permanent.
//

import SwiftUI
import Combine

/// Onglet de la barre du haut. Nommé `AppTab` et non `Tab` : SwiftUI expose déjà
/// un type `Tab`, et la collision rendait les vues incompilables.
/// Les Réglages n'y figurent pas : ils s'ouvrent depuis l'icône ronde de la
/// barre d'outils, comme dans MacTuner.
enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, providers, status, compare, test, diagnostic, journal
    var id: String { rawValue }

    var label: LStr {
        switch self {
        case .dashboard: return LStr("Tableau de bord", "Dashboard")
        case .providers: return LStr("Fournisseurs", "Providers")
        case .status:    return LStr("État", "Status")
        case .compare:   return LStr("Comparatif", "Comparison")
        case .test:      return LStr("Test", "Test")
        case .diagnostic: return LStr("Diagnostic", "Diagnostic")
        case .journal:   return LStr("Journal", "Log")
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .providers: return "list.bullet.rectangle"
        case .status:    return "waveform.path.ecg"
        case .compare:   return "tablecells"
        case .test:      return "speedometer"
        case .diagnostic: return "stethoscope"
        case .journal:   return "text.alignleft"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {

    let engine = DNSEngine()
    let profiles = ProfileManager()
    let tester = DNSTester()
    let diagnostic = DiagnosticEngine()
    let audit = BlockingAudit()

    // L'onglet ouvert est mémorisé d'une session à l'autre. DT_TAB le force,
    // pour le débogage, comme MT_TAB dans MacTuner.
    @Published var tab: AppTab = AppTab(rawValue:
        ProcessInfo.processInfo.environment["DT_TAB"] ?? Store.lastTab ?? "") ?? .dashboard {
        didSet { Store.lastTab = tab.rawValue }
    }
    @Published var selectedProviderID: String?
    @Published var alert: String?
    /// Les Réglages s'ouvrent en feuille modale depuis la barre d'outils.
    @Published var showSettings = false

    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Les moteurs sont des objets observables imbriqués : SwiftUI ne relaie pas
        // leurs changements au travers d'AppModel, on les republie donc à la main.
        for publisher in [engine.objectWillChange, profiles.objectWillChange,
                          tester.objectWillChange, diagnostic.objectWillChange,
                          audit.objectWillChange] {
            publisher.sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
        selectedProviderID = Store.appliedProviderID ?? ProviderCatalog.all.first?.id
    }

    var selectedProvider: DNSProvider? {
        guard let id = selectedProviderID else { return nil }
        if id == "custom" { return Store.customProvider() }
        return ProviderCatalog.provider(id: id)
    }

    // MARK: - Actions

    func apply(_ provider: DNSProvider) {
        if engine.apply(provider) {
            Store.appliedProviderID = provider.id
        } else if let error = engine.lastError {
            alert = error
        }
        refresh()
    }

    func restore() {
        // Retour arrière complet : DNS clair d'origine *et* profil chiffré retiré,
        // sinon le profil continuerait de primer sur la configuration restaurée.
        if !profiles.installed.isEmpty { profiles.removeAll() }
        if !engine.restore(), let error = engine.lastError { alert = error }
        refresh()
    }

    func install(_ provider: DNSProvider, transport: DNSTransport) {
        if !profiles.install(provider, transport: transport), let error = profiles.lastError {
            alert = error
        }
    }

    func removeProfile(_ id: String) {
        if !profiles.remove(identifier: id), let error = profiles.lastError {
            alert = error
        }
    }

    func refresh() {
        engine.refresh()
        profiles.refresh()
    }

    // MARK: - Résumé d'état

    /// Vrai s'il y a quelque chose à défaire : un DNS posé par l'app ou un profil.
    var canRestore: Bool {
        Store.hasOriginalSnapshot || !profiles.installed.isEmpty
            || engine.appliedProvider != nil
    }

    /// Fournisseur associé au profil chiffré installé, s'il en existe un.
    var encryptedProvider: DNSProvider? {
        guard let id = profiles.activeIdentifier else { return nil }
        let core = id.replacingOccurrences(of: "\(ProfileBuilder.identifierPrefix).", with: "")
        // L'identifiant est « <slug>.<transport> » : on retire le transport final.
        let slug = core.split(separator: ".").dropLast().joined(separator: ".")
        return ProviderCatalog.provider(id: slug)
    }

    var isEncrypted: Bool { !profiles.installed.isEmpty }

    var statusIcon: String {
        if isEncrypted { return "lock.shield.fill" }
        if engine.appliedProvider != nil { return "checkmark.shield.fill" }
        return "shield.slash"
    }

    var statusTint: Color {
        if isEncrypted { return .green }
        if engine.appliedProvider != nil { return .accentColor }
        return .secondary
    }

    var statusTitle: String {
        if let p = encryptedProvider { return T("status.encrypted", p.displayName) }
        if isEncrypted { return T("status.encryptedUnknown") }
        if let p = engine.appliedProvider { return T("status.applied", p.displayName) }
        return T("status.default")
    }

    var statusDetail: String {
        let resolvers = engine.activeResolvers
        if resolvers.isEmpty { return T("status.noResolver") }
        return T("status.resolvers", resolvers.joined(separator: ", "))
    }
}
