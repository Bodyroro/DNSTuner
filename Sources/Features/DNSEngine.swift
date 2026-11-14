//
//  DNSEngine.swift · Application du DNS système (transport en clair)
//
//  macOS règle le DNS *par service réseau*. Pour un effet réellement système,
//  DNSTuner écrit sur tous les services activés : mais en une seule élévation de
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
    /// Vrai si l'adresse est privée : donc une box ou un résolveur local.
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

    /// Numéro de la dernière lecture lancée : une lecture plus ancienne qui finit
    /// après une plus récente est ignorée.
    private var readGeneration = 0

    init() { refresh() }

    // MARK: - Lecture d'état

    /// Lecture de l'état réseau, hors du fil principal : une dizaine de commandes
    /// (`networksetup`, `ifconfig`, `scutil`) dont aucune ne doit figer l'interface.
    private nonisolated static func readState() -> (services: [NetworkService], resolvers: [String],
                                                    declared: [String: [String]]) {
        let services = NetworkServices.configurable()
        var declared: [String: [String]] = [:]
        for s in services { declared[s.name] = NetworkServices.dnsServers(for: s.name) }
        return (services, NetworkServices.activeResolvers(), declared)
    }

    func refresh() {
        Task { await reload() }
    }

    /// Relit l'état et le publie ; les appelants qui ont besoin du résultat l'attendent.
    func reload() async {
        readGeneration += 1
        let generation = readGeneration
        let state = await Task.detached(priority: .userInitiated) { Self.readState() }.value
        guard generation == readGeneration else { return }
        services = state.services
        activeResolvers = state.resolvers
        declaredDNS = state.declared
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

    // MARK: - Application

    /// Applique les serveurs d'un fournisseur à tous les services configurables.
    /// Renvoie `false` si l'utilisateur a annulé ou si la commande a échoué.
    @discardableResult
    func apply(_ provider: DNSProvider) async -> Bool {
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
        let ok = await runPrivileged(commands + [flushCommands],
                                     success: T("journal.applied", provider.displayName),
                                     failure: T("journal.applyFailed", provider.displayName))
        if ok { Store.appliedProviderID = provider.id }
        await reload()
        return ok
    }

    /// Restaure la configuration DNS d'origine service par service.
    /// Un service qui n'avait aucun DNS déclaré repasse en `Empty`, c'est-à-dire
    /// au serveur fourni par le routeur via DHCP.
    @discardableResult
    func restore() async -> Bool {
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
        let ok = await runPrivileged(commands + [flushCommands],
                                     success: T("journal.restored"),
                                     failure: T("journal.restoreFailed"))
        if ok {
            Store.clearOriginal()
            Store.appliedProviderID = nil
        }
        await reload()
        return ok
    }

    /// Vide le cache de résolution sans rien reconfigurer.
    func flushCache() {
        guard !busy else { return }
        Task {
            await runPrivileged([flushCommands],
                                success: T("journal.flushed"),
                                failure: T("journal.flushFailed"))
        }
    }

    /// `dscacheutil -flushcache` vide le cache, mais seul le signal HUP à
    /// mDNSResponder force le démon à relire la nouvelle configuration.
    private var flushCommands: String {
        "/usr/bin/dscacheutil -flushcache ; /usr/bin/killall -HUP mDNSResponder"
    }

    // MARK: - Exécution privilégiée

    /// Exécute toutes les commandes en une seule invite de mot de passe. L'invite
    /// et les commandes tournent hors du fil principal ; `busy` reste visible.
    @discardableResult
    private func runPrivileged(_ commands: [String], success: String, failure: String) async -> Bool {
        busy = true
        defer { busy = false }
        lastError = nil

        // Le code de sortie est celui de la première commande en échec : un `networksetup` refusé n'est plus masqué par la
        // réussite du rafraîchissement du cache qui le suit.
        let script = "rc=0; " + commands.map { "\($0) || rc=$?" }.joined(separator: "; ") + "; exit $rc"
        let result = await Task.detached(priority: .userInitiated) { Shell.admin(script) }.value
        if result.ok {
            Journal.shared.log(.success, success)
            return true
        }
        if Shell.wasCancelled(result) {
            Journal.shared.log(.info, T("journal.cancelled"))
            return false
        }
        lastError = result.err.trimmingCharacters(in: .whitespacesAndNewlines)
        Journal.shared.log(.failure, "\(failure) : \(lastError ?? "")")
        return false
    }
}
