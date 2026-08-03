//
//  DNSProvider.swift · Modèle d'un résolveur DNS public
//
//  Un « fournisseur » ici = une variante précise d'un éditeur (AdGuard Familial,
//  Cloudflare 1.1.1.3…), car c'est la variante — pas l'éditeur — qui détermine
//  ce qui est réellement bloqué.
//

import SwiftUI

/// Catégories de domaines qu'un résolveur filtrant peut bloquer.
/// Volontairement limitées à ce que le DNS sait faire : un blocage porte sur un
/// nom de domaine entier, jamais sur une URL ni sur un contenu.
enum BlockCategory: String, CaseIterable, Identifiable, Codable {
    case ads
    case trackers
    case malware
    case adult
    case gambling
    case social
    case newDomains

    var id: String { rawValue }

    var label: LStr {
        switch self {
        case .ads:        return LStr("Publicités", "Advertising")
        case .trackers:   return LStr("Traqueurs", "Trackers")
        case .malware:    return LStr("Malware & phishing", "Malware & phishing")
        case .adult:      return LStr("Contenu adulte", "Adult content")
        case .gambling:   return LStr("Jeux d'argent", "Gambling")
        case .social:     return LStr("Réseaux sociaux", "Social media")
        case .newDomains: return LStr("Domaines récents", "Newly registered domains")
        }
    }

    /// Libellé court pour les en-têtes de colonne du comparatif.
    var shortLabel: LStr {
        switch self {
        case .ads:        return LStr("Pubs", "Ads")
        case .trackers:   return LStr("Traqueurs", "Trackers")
        case .malware:    return LStr("Malware", "Malware")
        case .adult:      return LStr("Adulte", "Adult")
        case .gambling:   return LStr("Jeux", "Gambling")
        case .social:     return LStr("Social", "Social")
        case .newDomains: return LStr("Récents", "New")
        }
    }

    var icon: String {
        switch self {
        case .ads:        return "rectangle.on.rectangle.slash"
        case .trackers:   return "eye.slash"
        case .malware:    return "exclamationmark.shield"
        case .adult:      return "figure.and.child.holdinghands"
        case .gambling:   return "suit.club"
        case .social:     return "bubble.left.and.bubble.right"
        case .newDomains: return "calendar.badge.clock"
        }
    }
}

/// Protocole de transport disponible pour un fournisseur.
enum DNSTransport: String, CaseIterable, Identifiable {
    case plain      // UDP/TCP 53, en clair
    case https      // DNS-over-HTTPS
    case tls        // DNS-over-TLS

    var id: String { rawValue }

    var label: LStr {
        switch self {
        case .plain: return LStr("DNS classique (non chiffré)", "Classic DNS (unencrypted)")
        case .https: return LStr("DNS-over-HTTPS", "DNS-over-HTTPS")
        case .tls:   return LStr("DNS-over-TLS", "DNS-over-TLS")
        }
    }

    var icon: String {
        switch self {
        case .plain: return "lock.open"
        case .https: return "lock.shield"
        case .tls:   return "lock"
        }
    }
}

// MARK: - Pays

/// Juridiction d'un résolveur, identifiée par son code ISO 3166-1 alpha-2.
/// Le pays n'est pas décoratif : il détermine quelle loi s'applique aux requêtes
/// DNS qu'on lui confie. Son dessin de drapeau vit dans `FlagView.swift`.
enum Country {
    /// Nom du pays dans les deux langues de l'app.
    static func name(_ code: String) -> LStr {
        switch code {
        case "FR": return LStr("France", "France")
        case "US": return LStr("États-Unis", "United States")
        case "CH": return LStr("Suisse", "Switzerland")
        case "SE": return LStr("Suède", "Sweden")
        case "CY": return LStr("Chypre", "Cyprus")
        case "EU": return LStr("Union européenne", "European Union")
        case "CZ": return LStr("Tchéquie", "Czechia")
        case "CA": return LStr("Canada", "Canada")
        case "DE": return LStr("Allemagne", "Germany")
        case "GR": return LStr("Grèce", "Greece")
        case "DK": return LStr("Danemark", "Denmark")
        case "AT": return LStr("Autriche", "Austria")
        case "RU": return LStr("Russie", "Russia")
        case "GB": return LStr("Royaume-Uni", "United Kingdom")
        default:   return LStr(code, code)
        }
    }

}

// MARK: - Fournisseur

struct DNSProvider: Identifiable, Hashable {
    /// Identifiant stable, utilisé comme suffixe du PayloadIdentifier des profils.
    let id: String
    let vendor: String
    let variant: LStr
    let summary: LStr
    let ipv4: [String]
    let ipv6: [String]
    /// URL DoH complète (ex. « https://dns.adguard-dns.com/dns-query »).
    let doh: String?
    /// Nom d'hôte DoT, sans le préfixe « tls:// ».
    let dot: String?
    let blocks: Set<BlockCategory>
    let dnssec: Bool
    let noLog: Bool
    /// Code ISO 3166-1 alpha-2 de la juridiction du résolveur.
    let country: String
    let homepage: String
    /// Date de vérification des adresses sur la documentation officielle.
    /// `nil` = valeurs issues de la documentation publiée mais non revérifiées :
    /// l'interface l'affiche explicitement.
    let verifiedOn: String?

    var displayName: String { "\(vendor) — \(variant.current)" }

    var isVerified: Bool { verifiedOn != nil }

    var countryName: String { Country.name(country).current }

    /// Transports réellement proposés par ce fournisseur.
    var transports: [DNSTransport] {
        var t: [DNSTransport] = []
        if !ipv4.isEmpty || !ipv6.isEmpty { t.append(.plain) }
        if doh != nil { t.append(.https) }
        if dot != nil { t.append(.tls) }
        return t
    }

    /// Adresses à écrire via `networksetup` : IPv4 puis IPv6.
    var plainAddresses: [String] { ipv4 + ipv6 }

    /// Adresses de bootstrap d'un profil chiffré : macOS doit pouvoir joindre le
    /// résolveur avant d'avoir résolu son propre nom d'hôte.
    var bootstrapAddresses: [String] { ipv4 + ipv6 }

    var isFiltering: Bool { !blocks.isEmpty }

    static func == (a: DNSProvider, b: DNSProvider) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
