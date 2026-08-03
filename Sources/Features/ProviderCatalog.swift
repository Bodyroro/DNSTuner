//
//  ProviderCatalog.swift · Catalogue des résolveurs publics
//
//  Source principale : fiche « Fournisseurs DNS connus » d'AdGuard
//  (https://adguard-dns.io/kb/fr/general/dns-providers/) recoupée avec la
//  documentation de chaque éditeur.
//
//  ⚠️ Règle du catalogue : `verifiedOn` n'est renseigné que pour les entrées dont
//  les adresses ont été relues sur la documentation officielle. Les entrées à
//  `verifiedOn: nil` proviennent de la documentation publiée mais n'ont pas pu
//  être revérifiées ; l'interface les signale à l'utilisateur.
//

import Foundation

enum ProviderCatalog {

    /// Date de la dernière campagne de vérification des adresses.
    static let verificationDate = "2026-07-26"
    private static let V: String? = verificationDate

    static let all: [DNSProvider] = adguard + cloudflare + quad9 + openDNS
        + mullvad + dns4eu + controlD + cleanBrowsing + european + privacy
        + neutral

    static func provider(id: String) -> DNSProvider? {
        all.first { $0.id == id }
    }

    /// Fournisseurs groupés par éditeur, dans l'ordre d'affichage du catalogue.
    static var byVendor: [(vendor: String, providers: [DNSProvider])] {
        var order: [String] = []
        var buckets: [String: [DNSProvider]] = [:]
        for p in all {
            if buckets[p.vendor] == nil { order.append(p.vendor) }
            buckets[p.vendor, default: []].append(p)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    /// Nombre d'éditeurs distincts, affiché sur le tableau de bord.
    static var vendorCount: Int { Set(all.map(\.vendor)).count }
    /// Nombre de pays représentés.
    static var countryCount: Int { Set(all.map(\.country)).count }
    static var filteringCount: Int { all.filter(\.isFiltering).count }
    static var encryptedCount: Int { all.filter { $0.doh != nil || $0.dot != nil }.count }

    // MARK: - AdGuard DNS

    private static let adguard: [DNSProvider] = [
        DNSProvider(
            id: "adguard-default",
            vendor: "AdGuard DNS",
            variant: LStr("Par défaut", "Default"),
            summary: LStr("Bloque publicités et traqueurs, plus les domaines malveillants.",
                          "Blocks ads and trackers, plus malicious domains."),
            ipv4: ["94.140.14.14", "94.140.15.15"],
            ipv6: ["2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff"],
            doh: "https://dns.adguard-dns.com/dns-query",
            dot: "dns.adguard-dns.com",
            blocks: [.ads, .trackers, .malware],
            dnssec: true, noLog: true, country: "CY",
            homepage: "https://adguard-dns.io", verifiedOn: V),

        DNSProvider(
            id: "adguard-family",
            vendor: "AdGuard DNS",
            variant: LStr("Protection familiale", "Family protection"),
            summary: LStr("Filtrage par défaut, plus le contenu adulte et la recherche sécurisée.",
                          "Default filtering, plus adult content and safe search."),
            ipv4: ["94.140.14.15", "94.140.15.16"],
            ipv6: ["2a10:50c0::bad1:ff", "2a10:50c0::bad2:ff"],
            doh: "https://family.adguard-dns.com/dns-query",
            dot: "family.adguard-dns.com",
            blocks: [.ads, .trackers, .malware, .adult],
            dnssec: true, noLog: true, country: "CY",
            homepage: "https://adguard-dns.io", verifiedOn: V),

        DNSProvider(
            id: "adguard-unfiltered",
            vendor: "AdGuard DNS",
            variant: LStr("Sans filtrage", "Unfiltered"),
            summary: LStr("Résolution brute, aucun blocage. Utile pour diagnostiquer un faux positif.",
                          "Plain resolution, no blocking. Useful to diagnose a false positive."),
            ipv4: ["94.140.14.140", "94.140.14.141"],
            ipv6: ["2a10:50c0::1:ff", "2a10:50c0::2:ff"],
            doh: "https://unfiltered.adguard-dns.com/dns-query",
            dot: "unfiltered.adguard-dns.com",
            blocks: [],
            dnssec: true, noLog: true, country: "CY",
            homepage: "https://adguard-dns.io", verifiedOn: V),
    ]

    // MARK: - Cloudflare

    private static let cloudflare: [DNSProvider] = [
        DNSProvider(
            id: "cloudflare-standard",
            vendor: "Cloudflare",
            variant: LStr("1.1.1.1 — standard", "1.1.1.1 — standard"),
            summary: LStr("Résolveur rapide sans filtrage, orienté performance et vie privée.",
                          "Fast resolver with no filtering, focused on speed and privacy."),
            ipv4: ["1.1.1.1", "1.0.0.1"],
            ipv6: ["2606:4700:4700::1111", "2606:4700:4700::1001"],
            doh: "https://cloudflare-dns.com/dns-query",
            dot: "one.one.one.one",
            blocks: [],
            dnssec: true, noLog: true, country: "US",
            homepage: "https://one.one.one.one", verifiedOn: V),

        DNSProvider(
            id: "cloudflare-security",
            vendor: "Cloudflare",
            variant: LStr("1.1.1.2 — sécurité", "1.1.1.2 — security"),
            summary: LStr("Bloque uniquement les domaines malveillants. Aucun blocage publicitaire.",
                          "Blocks malicious domains only. No ad blocking."),
            ipv4: ["1.1.1.2", "1.0.0.2"],
            ipv6: ["2606:4700:4700::1112", "2606:4700:4700::1002"],
            doh: "https://security.cloudflare-dns.com/dns-query",
            dot: "security.cloudflare-dns.com",
            blocks: [.malware],
            dnssec: true, noLog: true, country: "US",
            homepage: "https://one.one.one.one", verifiedOn: V),

        DNSProvider(
            id: "cloudflare-family",
            vendor: "Cloudflare",
            variant: LStr("1.1.1.3 — famille", "1.1.1.3 — family"),
            summary: LStr("Domaines malveillants et contenu adulte. Aucun blocage publicitaire.",
                          "Malicious domains and adult content. No ad blocking."),
            ipv4: ["1.1.1.3", "1.0.0.3"],
            ipv6: ["2606:4700:4700::1113", "2606:4700:4700::1003"],
            doh: "https://family.cloudflare-dns.com/dns-query",
            dot: "family.cloudflare-dns.com",
            blocks: [.malware, .adult],
            dnssec: true, noLog: true, country: "US",
            homepage: "https://one.one.one.one", verifiedOn: V),
    ]

    // MARK: - Quad9

    private static let quad9: [DNSProvider] = [
        DNSProvider(
            id: "quad9-secure",
            vendor: "Quad9",
            variant: LStr("Sécurisé + DNSSEC", "Secured + DNSSEC"),
            summary: LStr("Blocage de menaces alimenté par une vingtaine de sources de renseignement.",
                          "Threat blocking fed by around twenty threat-intelligence feeds."),
            ipv4: ["9.9.9.9", "149.112.112.112"],
            ipv6: ["2620:fe::fe", "2620:fe::9"],
            doh: "https://dns.quad9.net/dns-query",
            dot: "dns.quad9.net",
            blocks: [.malware, .newDomains],
            dnssec: true, noLog: true, country: "CH",
            homepage: "https://quad9.net", verifiedOn: V),

        DNSProvider(
            id: "quad9-unsecured",
            vendor: "Quad9",
            variant: LStr("Non sécurisé", "Unsecured"),
            summary: LStr("Aucun blocage, aucune validation DNSSEC.",
                          "No blocking, no DNSSEC validation."),
            ipv4: ["9.9.9.10", "149.112.112.10"],
            ipv6: ["2620:fe::10", "2620:fe::fe:10"],
            doh: "https://dns10.quad9.net/dns-query",
            dot: "dns10.quad9.net",
            blocks: [],
            dnssec: false, noLog: true, country: "CH",
            homepage: "https://quad9.net", verifiedOn: V),

        DNSProvider(
            id: "quad9-ecs",
            vendor: "Quad9",
            variant: LStr("Sécurisé + ECS", "Secured + ECS"),
            summary: LStr("Comme la variante sécurisée, mais transmet un sous-réseau client aux CDN (meilleur routage, moins de confidentialité).",
                          "Same as secured, but sends a client subnet to CDNs (better routing, less privacy)."),
            ipv4: ["9.9.9.11", "149.112.112.11"],
            ipv6: ["2620:fe::11", "2620:fe::fe:11"],
            doh: "https://dns11.quad9.net/dns-query",
            dot: "dns11.quad9.net",
            blocks: [.malware, .newDomains],
            dnssec: true, noLog: true, country: "CH",
            homepage: "https://quad9.net", verifiedOn: V),
    ]

    // MARK: - Cisco OpenDNS

    private static let openDNS: [DNSProvider] = [
        DNSProvider(
            id: "opendns-standard",
            vendor: "Cisco OpenDNS",
            variant: LStr("Standard", "Standard"),
            summary: LStr("Blocage du hameçonnage. Historiquement le résolveur public le plus ancien.",
                          "Phishing blocking. Historically the oldest public resolver."),
            ipv4: ["208.67.222.222", "208.67.220.220"],
            ipv6: ["2620:119:35::35", "2620:119:53::53"],
            doh: "https://doh.opendns.com/dns-query",
            dot: "dns.opendns.com",
            blocks: [.malware],
            dnssec: true, noLog: false, country: "US",
            homepage: "https://opendns.com", verifiedOn: V),

        DNSProvider(
            id: "opendns-familyshield",
            vendor: "Cisco OpenDNS",
            variant: LStr("FamilyShield", "FamilyShield"),
            summary: LStr("Hameçonnage et contenu adulte, sans configuration de compte.",
                          "Phishing and adult content, with no account setup."),
            ipv4: ["208.67.222.123", "208.67.220.123"],
            ipv6: [],
            doh: "https://doh.familyshield.opendns.com/dns-query",
            dot: "familyshield.opendns.com",
            blocks: [.malware, .adult],
            dnssec: true, noLog: false, country: "US",
            homepage: "https://opendns.com", verifiedOn: V),
    ]

    // MARK: - Mullvad (chiffré uniquement — aucune adresse en clair publiée)

    private static func mullvadEntry(_ id: String, _ host: String,
                                     _ variant: LStr, _ summary: LStr,
                                     _ blocks: Set<BlockCategory>) -> DNSProvider {
        DNSProvider(
            id: id, vendor: "Mullvad", variant: variant, summary: summary,
            ipv4: [], ipv6: [],
            doh: "https://\(host)/dns-query", dot: host,
            blocks: blocks, dnssec: true, noLog: true, country: "SE",
            homepage: "https://mullvad.net/help/dns-over-https-and-dns-over-tls",
            verifiedOn: V)
    }

    private static let mullvad: [DNSProvider] = [
        mullvadEntry("mullvad-unfiltered", "dns.mullvad.net",
                     LStr("Sans filtrage", "Unfiltered"),
                     LStr("Résolveur sans journalisation, sans blocage. Chiffré uniquement.",
                          "No-logging resolver with no blocking. Encrypted only."),
                     []),
        mullvadEntry("mullvad-adblock", "adblock.dns.mullvad.net",
                     LStr("Anti-publicité", "Ad blocking"),
                     LStr("Publicités et traqueurs.", "Ads and trackers."),
                     [.ads, .trackers]),
        mullvadEntry("mullvad-base", "base.dns.mullvad.net",
                     LStr("Base", "Base"),
                     LStr("Publicités, traqueurs et logiciels malveillants.",
                          "Ads, trackers and malware."),
                     [.ads, .trackers, .malware]),
        mullvadEntry("mullvad-extended", "extended.dns.mullvad.net",
                     LStr("Étendu", "Extended"),
                     LStr("Base, plus les réseaux sociaux.", "Base, plus social media."),
                     [.ads, .trackers, .malware, .social]),
        mullvadEntry("mullvad-family", "family.dns.mullvad.net",
                     LStr("Famille", "Family"),
                     LStr("Base, plus contenu adulte et jeux d'argent.",
                          "Base, plus adult content and gambling."),
                     [.ads, .trackers, .malware, .adult, .gambling]),
        mullvadEntry("mullvad-all", "all.dns.mullvad.net",
                     LStr("Tout", "All"),
                     LStr("Toutes les listes actives. Le plus strict — faux positifs probables.",
                          "Every list enabled. The strictest — false positives likely."),
                     [.ads, .trackers, .malware, .adult, .gambling, .social]),
    ]

    // MARK: - DNS4EU (infrastructure européenne, cofinancée par l'UE)

    private static func dns4euEntry(_ id: String, _ suffix: String, _ lastOctet: String,
                                    _ secondary: [String],
                                    _ variant: LStr, _ summary: LStr,
                                    _ blocks: Set<BlockCategory>) -> DNSProvider {
        DNSProvider(
            id: id, vendor: "DNS4EU", variant: variant, summary: summary,
            ipv4: ["86.54.11.\(lastOctet)"] + secondary,
            ipv6: ["2a13:1001::86:54:11:\(lastOctet)"],
            doh: "https://\(suffix).joindns4.eu/dns-query", dot: "\(suffix).joindns4.eu",
            blocks: blocks, dnssec: true, noLog: true, country: "EU",
            homepage: "https://www.joindns4.eu", verifiedOn: V)
    }

    private static let dns4eu: [DNSProvider] = [
        dns4euEntry("dns4eu-protective", "protective", "1", ["86.54.11.201"],
                    LStr("Protection", "Protective"),
                    LStr("Blocage des menaces et des domaines fraîchement enregistrés.",
                         "Blocks threats and newly registered domains."),
                    [.malware, .newDomains]),
        dns4euEntry("dns4eu-noads", "noads", "13", [],
                    LStr("Protection + anti-publicité", "Protective + ad blocking"),
                    LStr("Menaces, publicités et traqueurs.", "Threats, ads and trackers."),
                    [.ads, .trackers, .malware, .newDomains]),
        dns4euEntry("dns4eu-child", "child", "12", [],
                    LStr("Protection + enfants", "Protective + child protection"),
                    LStr("Menaces et contenu inadapté aux mineurs.",
                         "Threats and content unsuitable for minors."),
                    [.malware, .adult, .newDomains]),
        dns4euEntry("dns4eu-child-noads", "child-noads", "11", [],
                    LStr("Protection + enfants + anti-publicité",
                         "Protective + child protection + ad blocking"),
                    LStr("La configuration la plus complète de DNS4EU.",
                         "The most complete DNS4EU configuration."),
                    [.ads, .trackers, .malware, .adult, .newDomains]),
        dns4euEntry("dns4eu-unfiltered", "unfiltered", "100", [],
                    LStr("Sans filtrage", "Unfiltered"),
                    LStr("Résolution européenne brute, aucun blocage.",
                         "Plain European resolution, no blocking."),
                    []),
    ]

    // MARK: - Control D (offre publique gratuite)

    private static func controlDEntry(_ id: String, _ profile: String, _ ipv4: [String],
                                      _ ipv6: [String], _ variant: LStr, _ summary: LStr,
                                      _ blocks: Set<BlockCategory>) -> DNSProvider {
        DNSProvider(
            id: id, vendor: "Control D", variant: variant, summary: summary,
            ipv4: ipv4, ipv6: ipv6,
            doh: "https://freedns.controld.com/\(profile)",
            dot: "\(profile).freedns.controld.com",
            blocks: blocks, dnssec: true, noLog: true, country: "CA",
            homepage: "https://controld.com/free-dns", verifiedOn: V)
    }

    private static let controlD: [DNSProvider] = [
        controlDEntry("controld-unfiltered", "p0", ["76.76.2.0", "76.76.10.0"],
                      ["2606:1a40::", "2606:1a40:1::"],
                      LStr("Sans filtrage", "Unfiltered"),
                      LStr("Résolution brute, sans journalisation.",
                           "Plain resolution, no logging."),
                      []),
        controlDEntry("controld-malware", "p1", ["76.76.2.1"], [],
                      LStr("Anti-malware", "Malware blocking"),
                      LStr("Domaines malveillants uniquement.", "Malicious domains only."),
                      [.malware]),
        controlDEntry("controld-ads", "p2", ["76.76.2.2"], [],
                      LStr("Anti-malware + publicités", "Malware + ads"),
                      LStr("Menaces, publicités et traqueurs.", "Threats, ads and trackers."),
                      [.ads, .trackers, .malware]),
        controlDEntry("controld-social", "p3", ["76.76.2.3"], [],
                      LStr("Anti-malware + pubs + réseaux sociaux", "Malware + ads + social"),
                      LStr("Ajoute le blocage des réseaux sociaux.",
                           "Adds social media blocking."),
                      [.ads, .trackers, .malware, .social]),
    ]

    // MARK: - CleanBrowsing

    private static func cleanBrowsingEntry(_ id: String, _ path: String, _ host: String,
                                           _ ipv4: [String], _ ipv6: [String],
                                           _ variant: LStr, _ summary: LStr,
                                           _ blocks: Set<BlockCategory>) -> DNSProvider {
        DNSProvider(
            id: id, vendor: "CleanBrowsing", variant: variant, summary: summary,
            ipv4: ipv4, ipv6: ipv6,
            doh: "https://doh.cleanbrowsing.org/doh/\(path)/",
            dot: "\(host)-dns.cleanbrowsing.org",
            blocks: blocks, dnssec: true, noLog: true, country: "US",
            homepage: "https://cleanbrowsing.org/filters/", verifiedOn: V)
    }

    private static let cleanBrowsing: [DNSProvider] = [
        cleanBrowsingEntry("cleanbrowsing-family", "family-filter", "family-filter",
                           ["185.228.168.168", "185.228.169.168"],
                           ["2a0d:2a00:1::", "2a0d:2a00:2::"],
                           LStr("Filtre familial", "Family filter"),
                           LStr("Contenu adulte, sites proxy et recherche sécurisée forcée.",
                                "Adult content, proxy sites and forced safe search."),
                           [.malware, .adult]),
        cleanBrowsingEntry("cleanbrowsing-adult", "adult-filter", "adult-filter",
                           ["185.228.168.10", "185.228.169.11"],
                           ["2a0d:2a00:1::1", "2a0d:2a00:2::1"],
                           LStr("Filtre adulte", "Adult filter"),
                           LStr("Contenu adulte uniquement, sans blocage des réseaux sociaux.",
                                "Adult content only, social media left untouched."),
                           [.adult]),
        cleanBrowsingEntry("cleanbrowsing-security", "security-filter", "security-filter",
                           ["185.228.168.9", "185.228.169.9"],
                           ["2a0d:2a00:1::2", "2a0d:2a00:2::2"],
                           LStr("Filtre sécurité", "Security filter"),
                           LStr("Hameçonnage, malware et domaines malveillants.",
                                "Phishing, malware and malicious domains."),
                           [.malware]),
    ]

    // MARK: - Résolveurs européens

    private static let european: [DNSProvider] = [
        DNSProvider(
            id: "cznic-odvr",
            vendor: "CZ.NIC",
            variant: LStr("ODVR", "ODVR"),
            summary: LStr("Résolveur ouvert du registre tchèque, validation DNSSEC, sans filtrage.",
                          "Open resolver run by the Czech registry, DNSSEC validating, no filtering."),
            ipv4: ["193.17.47.1", "185.43.135.1"],
            ipv6: ["2001:148f:ffff::1", "2001:148f:fffe::1"],
            doh: "https://odvr.nic.cz/doh",
            dot: "odvr.nic.cz",
            blocks: [],
            dnssec: true, noLog: true, country: "CZ",
            homepage: "https://www.nic.cz/odvr/", verifiedOn: V),

        DNSProvider(
            id: "digitale-gesellschaft",
            vendor: "Digitale Gesellschaft",
            variant: LStr("Résolveur public", "Public resolver"),
            summary: LStr("Résolveur associatif suisse, sans journalisation ni filtrage, financé par les dons.",
                          "Swiss non-profit resolver, no logging and no filtering, donation funded."),
            ipv4: ["185.95.218.42", "185.95.218.43"],
            ipv6: ["2a05:fc84::42", "2a05:fc84::43"],
            doh: "https://dns.digitale-gesellschaft.ch/dns-query",
            dot: "dns.digitale-gesellschaft.ch",
            blocks: [],
            dnssec: true, noLog: true, country: "CH",
            homepage: "https://www.digitale-gesellschaft.ch/dns/", verifiedOn: V),

        DNSProvider(
            id: "dnssb",
            vendor: "DNS.SB",
            variant: LStr("Résolveur public", "Public resolver"),
            summary: LStr("Résolveur anycast sans journalisation, validation DNSSEC, aucun filtrage.",
                          "Anycast resolver with no logging, DNSSEC validating, no filtering."),
            ipv4: ["185.222.222.222", "45.11.45.11"],
            ipv6: ["2a09::", "2a11::"],
            doh: "https://doh.dns.sb/dns-query",
            dot: "dot.sb",
            blocks: [],
            dnssec: true, noLog: true, country: "DE",
            homepage: "https://dns.sb", verifiedOn: V),

        DNSProvider(
            id: "libredns",
            vendor: "LibreDNS",
            variant: LStr("Sans filtrage", "Unfiltered"),
            summary: LStr("Résolveur associatif grec, sans journalisation.",
                          "Greek non-profit resolver, no logging."),
            ipv4: ["88.198.92.222"],
            ipv6: [],
            doh: "https://doh.libredns.gr/dns-query",
            dot: "dot.libredns.gr",
            blocks: [],
            dnssec: true, noLog: true, country: "GR",
            homepage: "https://libredns.gr", verifiedOn: V),

        DNSProvider(
            id: "libredns-ads",
            vendor: "LibreDNS",
            variant: LStr("Anti-publicité", "Ad blocking"),
            summary: LStr("Même résolveur, avec les listes anti-publicité activées.",
                          "Same resolver, with ad-blocking lists enabled."),
            ipv4: [],
            ipv6: [],
            doh: "https://doh.libredns.gr/ads",
            dot: nil,
            blocks: [.ads, .trackers],
            dnssec: true, noLog: true, country: "GR",
            homepage: "https://libredns.gr", verifiedOn: V),

        DNSProvider(
            id: "uncensoreddns-anycast",
            vendor: "UncensoredDNS",
            variant: LStr("Anycast", "Anycast"),
            summary: LStr("Résolveur danois non censuré, tenu par un particulier depuis 2009.",
                          "Uncensored Danish resolver, run by an individual since 2009."),
            ipv4: ["91.239.100.100"],
            ipv6: ["2001:67c:28a4::"],
            doh: nil,
            dot: "anycast.censurfridns.dk",
            blocks: [],
            dnssec: true, noLog: true, country: "DK",
            homepage: "https://blog.uncensoreddns.org", verifiedOn: V),

        DNSProvider(
            id: "uncensoreddns-unicast",
            vendor: "UncensoredDNS",
            variant: LStr("Unicast (Copenhague)", "Unicast (Copenhagen)"),
            summary: LStr("Nœud unique au Danemark, alternative si l'anycast est mal routé.",
                          "Single node in Denmark, an alternative if anycast routes poorly."),
            ipv4: ["89.233.43.71"],
            ipv6: ["2a01:3a0:53:53::"],
            doh: nil,
            dot: "unicast.censurfridns.dk",
            blocks: [],
            dnssec: true, noLog: true, country: "DK",
            homepage: "https://blog.uncensoreddns.org", verifiedOn: V),

        DNSProvider(
            id: "applied-privacy",
            vendor: "Applied Privacy",
            variant: LStr("Résolveur public", "Public resolver"),
            summary: LStr("Résolveur autrichien à but non lucratif, chiffré uniquement.",
                          "Austrian non-profit resolver, encrypted only."),
            ipv4: [],
            ipv6: [],
            doh: "https://doh.applied-privacy.net/query",
            dot: "dot1.applied-privacy.net",
            blocks: [],
            dnssec: true, noLog: true, country: "AT",
            homepage: "https://applied-privacy.net/services/dns/", verifiedOn: V),

        DNSProvider(
            id: "fdn",
            vendor: "FDN",
            variant: LStr("French Data Network", "French Data Network"),
            summary: LStr("Résolveur associatif français, neutre et sans journalisation. Aucun blocage.",
                          "French non-profit resolver, neutral and non-logging. No blocking."),
            ipv4: ["80.67.169.12", "80.67.169.40"],
            ipv6: ["2001:910:800::12", "2001:910:800::40"],
            doh: nil,
            dot: "ns0.fdn.fr",
            blocks: [],
            dnssec: true, noLog: true, country: "FR",
            homepage: "https://www.fdn.fr/actions/dns/", verifiedOn: nil),

        DNSProvider(
            id: "dns0-zero",
            vendor: "dns0.eu",
            variant: LStr("ZERO", "ZERO"),
            summary: LStr("Résolveur européen à but non lucratif, filtrage de menaces agressif.",
                          "European non-profit resolver with aggressive threat filtering."),
            ipv4: ["193.110.81.9", "185.253.5.9"],
            ipv6: ["2a0f:fc80::9", "2a0f:fc81::9"],
            doh: "https://zero.dns0.eu",
            dot: "zero.dns0.eu",
            blocks: [.malware, .newDomains],
            dnssec: true, noLog: true, country: "EU",
            homepage: "https://www.dns0.eu", verifiedOn: nil),

        DNSProvider(
            id: "dns0-kids",
            vendor: "dns0.eu",
            variant: LStr("KIDS", "KIDS"),
            summary: LStr("Variante familiale : menaces, contenu adulte et publicités.",
                          "Family variant: threats, adult content and ads."),
            ipv4: ["193.110.81.1", "185.253.5.1"],
            ipv6: ["2a0f:fc80::1", "2a0f:fc81::1"],
            doh: "https://kids.dns0.eu",
            dot: "kids.dns0.eu",
            blocks: [.ads, .malware, .adult, .newDomains],
            dnssec: true, noLog: true, country: "EU",
            homepage: "https://www.dns0.eu", verifiedOn: nil),
    ]

    // MARK: - Résolveurs orientés vie privée ou compte personnel

    private static let privacy: [DNSProvider] = [
        DNSProvider(
            id: "nextdns",
            vendor: "NextDNS",
            variant: LStr("Résolveur partagé", "Shared resolver"),
            summary: LStr("Point d'entrée public. Le filtrage sur mesure demande un identifiant de compte, à saisir comme résolveur personnalisé.",
                          "Public entry point. Custom filtering needs an account ID, entered as a custom resolver."),
            ipv4: [],
            ipv6: [],
            doh: "https://dns.nextdns.io/dns-query",
            dot: "dns.nextdns.io",
            blocks: [],
            dnssec: true, noLog: true, country: "US",
            homepage: "https://nextdns.io", verifiedOn: V),

        DNSProvider(
            id: "safedns",
            vendor: "SafeDNS",
            variant: LStr("Résolveur public", "Public resolver"),
            summary: LStr("Filtrage de contenu par catégories, offre publique en clair uniquement.",
                          "Category-based content filtering, public offering in plain DNS only."),
            ipv4: ["195.46.39.39", "195.46.39.40"],
            ipv6: [],
            doh: nil,
            dot: nil,
            blocks: [.malware, .adult],
            dnssec: true, noLog: false, country: "US",
            homepage: "https://www.safedns.com", verifiedOn: V),

        DNSProvider(
            id: "comss-one",
            vendor: "Comss.one",
            variant: LStr("Résolveur filtrant", "Filtering resolver"),
            summary: LStr("Résolveur russe bloquant publicités et traqueurs. Juridiction à évaluer avant usage.",
                          "Russian resolver blocking ads and trackers. Consider the jurisdiction before use."),
            ipv4: ["83.220.169.155", "212.109.195.93"],
            ipv6: [],
            doh: "https://dns.comss.one/dns-query",
            dot: "dns.comss.one",
            blocks: [.ads, .trackers, .malware],
            dnssec: true, noLog: true, country: "RU",
            homepage: "https://www.comss.ru/page.php?id=7315", verifiedOn: V),
    ]

    // MARK: - Résolveurs neutres

    private static let neutral: [DNSProvider] = [
        DNSProvider(
            id: "cira-family",
            vendor: "CIRA Canadian Shield",
            variant: LStr("Famille", "Family"),
            summary: LStr("Menaces et contenu adulte, opéré par le registre canadien.",
                          "Threats and adult content, run by the Canadian registry."),
            ipv4: ["149.112.121.30", "149.112.122.30"],
            ipv6: ["2620:10A:80BB::30", "2620:10A:80BC::30"],
            doh: "https://family.canadianshield.cira.ca/dns-query",
            dot: "family.canadianshield.cira.ca",
            blocks: [.malware, .adult],
            dnssec: true, noLog: true, country: "CA",
            homepage: "https://www.cira.ca/en/canadian-shield/", verifiedOn: nil),

        DNSProvider(
            id: "cira-private",
            vendor: "CIRA Canadian Shield",
            variant: LStr("Privé", "Private"),
            summary: LStr("Résolution sans filtrage ni journalisation.",
                          "Resolution with no filtering and no logging."),
            ipv4: ["149.112.121.10", "149.112.122.10"],
            ipv6: ["2620:10A:80BB::10", "2620:10A:80BC::10"],
            doh: "https://private.canadianshield.cira.ca/dns-query",
            dot: "private.canadianshield.cira.ca",
            blocks: [],
            dnssec: true, noLog: true, country: "CA",
            homepage: "https://www.cira.ca/en/canadian-shield/", verifiedOn: V),

        DNSProvider(
            id: "google-public",
            vendor: "Google",
            variant: LStr("Public DNS", "Public DNS"),
            summary: LStr("Très rapide et très disponible, aucun filtrage, journalisation partielle.",
                          "Very fast and highly available, no filtering, partial logging."),
            ipv4: ["8.8.8.8", "8.8.4.4"],
            ipv6: ["2001:4860:4860::8888", "2001:4860:4860::8844"],
            doh: "https://dns.google/dns-query",
            dot: "dns.google",
            blocks: [],
            dnssec: true, noLog: false, country: "US",
            homepage: "https://developers.google.com/speed/public-dns", verifiedOn: V),
    ]
}
