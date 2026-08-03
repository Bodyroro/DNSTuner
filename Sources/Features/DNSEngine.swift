//
//  DNSEngine.swift · Application du DNS système (transport en clair)
//
//  macOS règle le DNS *par service réseau*. Pour un effet réellement système,
//  DNSTuner écrit sur tous les services activés — mais en une seule élévation de
//  privilèges : toutes les commandes `networksetup` sont concaténées en un unique
//  script passé à `Shell.admin`, donc une seule demande de mot de passe.
//

import Foundation

/// Ce qu'on sait du résolveur actif quand il n'appartient pas au catalogue :
/// typiquement la box du fournisseur d'accès, ou un serveur d'entreprise.
struct ResolverIdentity: Equatable {
    /// Adresse du premier résolveur actif.
    let address: String
    /// Nom d'hôte obtenu par résolution inverse, si elle a abouti.
    let hostname: String?
    /// Fabricant déduit de l'adresse matérielle, quand le résolveur est sur le
    /// réseau local. Beaucoup de box ne répondent à aucun PTR : c'est souvent
    /// la seule façon de leur donner un nom.
    let vendor: String?
    /// Vrai si l'adresse est privée — donc une box ou un résolveur local.
    let isLocal: Bool
    /// Vrai si le résolveur est la passerelle par défaut du réseau.
    let isGateway: Bool

    /// Nom lisible, par ordre de fiabilité décroissante : le premier label du
    /// nom d'hôte capitalisé (« freebox.home » → « Freebox »), puis le
    /// fabricant. `nil` quand on n'a rien de mieux que l'adresse : la vue
    /// affiche alors un libellé générique plutôt que de répéter l'adresse.
    var displayName: String? {
        if let hostname {
            // Sur le réseau local, le premier label suffit et se lit mieux
            // (« freebox.home » → « Freebox »). Pour un résolveur public, le nom
            // complet est l'information utile : « ns0.fdn.fr », pas « Ns0 ».
            guard isLocal, let first = hostname.split(separator: ".").first,
                  !first.isEmpty else { return hostname }
            return first.prefix(1).uppercased() + first.dropFirst()
        }
        return vendor
    }

    /// Juridiction présumée. Une box est chez l'utilisateur : la région du
    /// système est le meilleur indicateur disponible sans appel réseau, et il
    /// n'est jamais présenté comme une certitude.
    var country: String {
        isLocal ? (Locale.current.region?.identifier ?? "") : ""
    }
}

@MainActor
final class DNSEngine: ObservableObject {

    /// Services réseau configurables, rafraîchis à chaque `refresh()`.
    @Published private(set) var services: [NetworkService] = []
    /// Résolveurs réellement utilisés par le système (`scutil --dns`).
    @Published private(set) var activeResolvers: [String] = []
    /// DNS déclarés par service, tels que vus par `networksetup`.
    @Published private(set) var declaredDNS: [String: [String]] = [:]
    /// Fournisseur appliqué par DNSTuner, s'il correspond encore à l'état réel.
    @Published private(set) var appliedProvider: DNSProvider?
    /// Identité du résolveur réellement utilisé, quand il n'est pas au catalogue :
    /// nom d'hôte obtenu par résolution inverse, et s'il s'agit d'une box.
    @Published private(set) var resolverIdentity: ResolverIdentity?
    @Published private(set) var busy = false
    @Published var lastError: String?

    private let networksetup = "/usr/sbin/networksetup"

    init() { refresh() }

    // MARK: - Lecture d'état

    func refresh() {
        services = NetworkServices.configurable()
        activeResolvers = NetworkServices.activeResolvers()
        var declared: [String: [String]] = [:]
        for s in services { declared[s.name] = NetworkServices.dnsServers(for: s.name) }
        declaredDNS = declared
        appliedProvider = detectAppliedProvider()
        identifyResolver()
    }

    /// Nomme le résolveur actif quand il n'est pas au catalogue. La résolution
    /// inverse part sur une tâche de fond : elle peut prendre une seconde, et
    /// l'interface ne doit jamais attendre après elle.
    private func identifyResolver() {
        guard appliedProvider == nil, let address = activeResolvers.first else {
            resolverIdentity = nil
            return
        }
        // On garde l'identité déjà connue tant qu'elle porte sur la même adresse,
        // pour ne pas relancer une résolution inverse à chaque rafraîchissement.
        if resolverIdentity?.address == address { return }

        let isLocal = NetworkServices.isPrivate(address)
        resolverIdentity = ResolverIdentity(address: address, hostname: nil, vendor: nil,
                                            isLocal: isLocal, isGateway: false)

        Task.detached(priority: .utility) {
            let name = NetworkServices.reverseName(address)
            let isGateway = NetworkServices.defaultGateway() == address
            // Le fabricant ne se lit que sur le réseau local : hors de là,
            // aucune adresse matérielle n'est visible depuis cette machine.
            let vendor: String? = isLocal
                ? NetworkServices.macAddress(for: address).flatMap(HardwareVendor.name(forMAC:))
                : nil
            await MainActor.run { [weak self] in
                guard let self, self.resolverIdentity?.address == address else { return }
                self.resolverIdentity = ResolverIdentity(address: address,
                                                         hostname: name,
                                                         vendor: vendor,
                                                         isLocal: isLocal,
                                                         isGateway: isGateway)
            }
        }
    }

    /// Un fournisseur n'est considéré « appliqué » que si ses adresses sont
    /// effectivement présentes dans la configuration : mémoriser un identifiant
    /// ne suffit pas, l'utilisateur peut avoir changé le DNS ailleurs.
    private func detectAppliedProvider() -> DNSProvider? {
        let configured = Set(declaredDNS.values.flatMap { $0 })
        guard !configured.isEmpty else { return nil }
        let candidates = ProviderCatalog.all + [Store.customProvider()].compactMap { $0 }
        return candidates.first { provider in
            let addresses = Set(provider.plainAddresses)
            return !addresses.isEmpty && addresses.isSubset(of: configured)
        }
    }

    /// Vrai si au moins un service utilise encore le DNS fourni par le routeur.
    var usesDHCPDNS: Bool {
        services.contains { (declaredDNS[$0.name] ?? []).isEmpty }
    }

    // MARK: - Application

    /// Applique les serveurs d'un fournisseur à tous les services configurables.
    /// Renvoie `false` si l'utilisateur a annulé ou si la commande a échoué.
    @discardableResult
    func apply(_ provider: DNSProvider) -> Bool {
        let addresses = provider.plainAddresses
        guard !addresses.isEmpty else {
            lastError = T("error.noPlainAddress")
            return false
        }
        guard addresses.allSatisfy(IPAddress.isValid) else {
            lastError = T("error.invalidAddress")
            return false
        }
        guard !services.isEmpty else {
            lastError = T("error.noService")
            return false
        }

        // Sauvegarde de l'état d'origine *avant* la première écriture.
        var snapshot: [String: [String]] = [:]
        for s in services { snapshot[s.name] = declaredDNS[s.name] ?? [] }
        Store.saveOriginalIfNeeded(snapshot)

        let quotedAddresses = addresses.map { Shell.shellQuoted($0) }.joined(separator: " ")
        let commands = services.map { service in
            "\(networksetup) -setdnsservers \(Shell.shellQuoted(service.name)) \(quotedAddresses)"
        }
        let ok = runPrivileged(commands + [flushCommands],
                               success: T("journal.applied", provider.displayName),
                               failure: T("journal.applyFailed", provider.displayName))
        if ok { Store.appliedProviderID = provider.id }
        refresh()
        return ok
    }

    /// Restaure la configuration DNS d'origine service par service.
    /// Un service qui n'avait aucun DNS déclaré repasse en `Empty`, c'est-à-dire
    /// au serveur fourni par le routeur via DHCP.
    @discardableResult
    func restore() -> Bool {
        guard !services.isEmpty else {
            lastError = T("error.noService")
            return false
        }
        let original = Store.originalDNS
        let commands = services.map { service -> String in
            let saved = original[service.name] ?? []
            let value = saved.isEmpty ? "Empty"
                                      : saved.map { Shell.shellQuoted($0) }.joined(separator: " ")
            return "\(networksetup) -setdnsservers \(Shell.shellQuoted(service.name)) \(value)"
        }
        let ok = runPrivileged(commands + [flushCommands],
                               success: T("journal.restored"),
                               failure: T("journal.restoreFailed"))
        if ok {
            Store.clearOriginal()
            Store.appliedProviderID = nil
        }
        refresh()
        return ok
    }

    /// Vide le cache de résolution sans rien reconfigurer.
    @discardableResult
    func flushCache() -> Bool {
        runPrivileged([flushCommands],
                      success: T("journal.flushed"),
                      failure: T("journal.flushFailed"))
    }

    /// `dscacheutil -flushcache` vide le cache, mais seul le signal HUP à
    /// mDNSResponder force le démon à relire la nouvelle configuration.
    private var flushCommands: String {
        "/usr/bin/dscacheutil -flushcache ; /usr/bin/killall -HUP mDNSResponder"
    }

    // MARK: - Exécution privilégiée

    /// Exécute toutes les commandes en une seule invite de mot de passe.
    private func runPrivileged(_ commands: [String], success: String, failure: String) -> Bool {
        busy = true
        defer { busy = false }
        lastError = nil

        let result = Shell.admin(commands.joined(separator: " ; "))
        if result.ok {
            Journal.shared.log(.success, success)
            return true
        }
        if Shell.wasCancelled(result) {
            Journal.shared.log(.info, T("journal.cancelled"))
            return false
        }
        lastError = result.err.trimmingCharacters(in: .whitespacesAndNewlines)
        Journal.shared.log(.failure, "\(failure) — \(lastError ?? "")")
        return false
    }
}
