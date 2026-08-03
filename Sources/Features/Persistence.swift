//
//  Persistence.swift · Mémorisation des réglages et de l'état d'origine
//
//  Le point critique est `originalDNS` : avant la toute première application,
//  DNSTuner enregistre les serveurs DNS de chaque service réseau afin de pouvoir
//  restaurer exactement la configuration initiale, et pas seulement « vider ».
//

import Foundation

enum Store {
    private static let d = UserDefaults.standard

    private enum Key {
        static let originalDNS   = "originalDNS"      // [nom de service: [adresses]]
        static let originalSaved = "originalDNSSaved" // sauvegarde déjà effectuée
        static let appliedID     = "appliedProviderID"
        static let lastTab       = "lastTab"
        static let installedProfiles = "installedProfileIDs"
        static let favorites     = "favoriteProviderIDs"
        static let customName    = "customProviderName"
        static let customIPs     = "customProviderIPs"
        static let customDoH     = "customProviderDoH"
    }

    // MARK: - Sauvegarde de l'état d'origine

    /// Enregistre les DNS actuels de chaque service. Ne fait rien si une
    /// sauvegarde existe déjà : sinon, appliquer deux fois de suite écraserait
    /// l'état d'origine par celui posé par DNSTuner.
    static func saveOriginalIfNeeded(_ snapshot: [String: [String]]) {
        guard !d.bool(forKey: Key.originalSaved) else { return }
        d.set(snapshot, forKey: Key.originalDNS)
        d.set(true, forKey: Key.originalSaved)
    }

    static var originalDNS: [String: [String]] {
        (d.dictionary(forKey: Key.originalDNS) as? [String: [String]]) ?? [:]
    }

    static var hasOriginalSnapshot: Bool { d.bool(forKey: Key.originalSaved) }

    /// Après restauration, la sauvegarde n'a plus lieu d'être : la prochaine
    /// application repartira de l'état réel du système.
    static func clearOriginal() {
        d.removeObject(forKey: Key.originalDNS)
        d.set(false, forKey: Key.originalSaved)
    }

    // MARK: - Fournisseur appliqué

    static var appliedProviderID: String? {
        get { d.string(forKey: Key.appliedID) }
        set { d.set(newValue, forKey: Key.appliedID) }
    }

    /// Onglet ouvert au dernier lancement : on retrouve l'app là où on l'a laissée.
    static var lastTab: String? {
        get { d.string(forKey: Key.lastTab) }
        set { d.set(newValue, forKey: Key.lastTab) }
    }

    /// Profils chiffrés posés par l'app et confirmés installés.
    ///
    /// Nécessaire parce qu'un profil de portée système n'apparaît pas dans
    /// `profiles show` sans être root : on retient donc ce qu'on a installé, et
    /// on le confronte à `profiles status`, qui sait dire sans privilège s'il
    /// reste au moins un profil sur la machine.
    static var installedProfileIDs: Set<String> {
        get { Set(d.stringArray(forKey: Key.installedProfiles) ?? []) }
        set { d.set(Array(newValue).sorted(), forKey: Key.installedProfiles) }
    }

    // MARK: - Favoris

    static var favorites: Set<String> {
        get { Set(d.stringArray(forKey: Key.favorites) ?? []) }
        set { d.set(Array(newValue).sorted(), forKey: Key.favorites) }
    }

    static func toggleFavorite(_ id: String) {
        var f = favorites
        if f.contains(id) { f.remove(id) } else { f.insert(id) }
        favorites = f
    }

    // MARK: - Fournisseur personnalisé

    static var customName: String {
        get { d.string(forKey: Key.customName) ?? "" }
        set { d.set(newValue, forKey: Key.customName) }
    }

    static var customIPs: String {
        get { d.string(forKey: Key.customIPs) ?? "" }
        set { d.set(newValue, forKey: Key.customIPs) }
    }

    static var customDoH: String {
        get { d.string(forKey: Key.customDoH) ?? "" }
        set { d.set(newValue, forKey: Key.customDoH) }
    }

    /// Construit un `DNSProvider` à partir des champs personnalisés, ou `nil`
    /// si rien d'exploitable n'a été saisi.
    static func customProvider() -> DNSProvider? {
        let ips = customIPs
            .components(separatedBy: CharacterSet(charactersIn: ", \n\t"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { IPAddress.isValid($0) }
        let doh = customDoH.trimmingCharacters(in: .whitespaces)
        guard !ips.isEmpty || !doh.isEmpty else { return nil }

        let name = customName.trimmingCharacters(in: .whitespaces)
        return DNSProvider(
            id: "custom",
            vendor: name.isEmpty ? T("provider.custom.vendor") : name,
            variant: LStr("Personnalisé", "Custom"),
            summary: LStr("Serveurs saisis manuellement.", "Manually entered servers."),
            ipv4: ips.filter { IPAddress.isIPv4($0) },
            ipv6: ips.filter { !IPAddress.isIPv4($0) },
            doh: doh.hasPrefix("https://") ? doh : nil,
            dot: nil,
            blocks: [],
            dnssec: false, noLog: false, country: "",
            homepage: "", verifiedOn: nil)
    }
}

/// Validation minimale des adresses saisies à la main : une adresse invalide
/// écrite dans `networksetup` couperait la résolution DNS de la machine.
enum IPAddress {
    static func isIPv4(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard !part.isEmpty, part.count <= 3, part.allSatisfy(\.isNumber),
                  let v = Int(part), v >= 0, v <= 255 else { return false }
            return true
        }
    }

    static func isIPv6(_ s: String) -> Bool {
        guard s.contains(":") else { return false }
        var addr = in6_addr()
        return s.withCString { inet_pton(AF_INET6, $0, &addr) == 1 }
    }

    static func isValid(_ s: String) -> Bool { isIPv4(s) || isIPv6(s) }
}
