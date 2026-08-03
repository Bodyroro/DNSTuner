//
//  DiagnosticEngine.swift · Tests sur la configuration réellement active
//
//  L'onglet Test compare des résolveurs qu'on n'utilise pas encore. Ici on
//  interroge le résolveur du système tel qu'il est configuré : ce qu'il bloque,
//  ce qu'il laisse fuir, ce qu'il valide. Aucun test ne modifie quoi que ce soit.
//

import Foundation

// MARK: - Résultat d'un test

enum CheckStatus {
    /// Le test constate un comportement souhaitable.
    case pass
    /// Comportement acceptable mais perfectible, ou dépendant du choix de chacun.
    case warn
    /// Comportement franchement problématique.
    case fail
    /// Renseignement sans jugement : il n'y a pas de « bonne » réponse.
    case info
    /// Le test n'a pas pu conclure (réseau injoignable, réponse inattendue).
    case unknown

    var icon: String {
        switch self {
        case .pass:    return "checkmark.circle.fill"
        case .warn:    return "exclamationmark.triangle.fill"
        case .fail:    return "xmark.octagon.fill"
        case .info:    return "info.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct CheckOutcome {
    let status: CheckStatus
    /// Verdict en une phrase, lisible sans connaissance technique.
    let summary: String
    /// Ce qu'on a mesuré : domaine interrogé, réponse obtenue.
    let detail: String
}

/// Les tests proposés, dans l'ordre d'affichage.
enum DiagnosticCheck: String, CaseIterable, Identifiable {
    case encryption
    case outboundResolver
    case clientSubnet
    case dnssec
    case nxdomain
    case rebind
    case blockAds
    case blockTrackers
    case blockMalware
    case blockAdult

    var id: String { rawValue }

    var title: LStr {
        switch self {
        case .encryption:       return LStr("Chiffrement des requêtes", "Query encryption")
        case .outboundResolver: return LStr("Qui voit vos requêtes", "Who sees your queries")
        case .clientSubnet:     return LStr("Transmission de votre sous-réseau",
                                            "Client subnet disclosure")
        case .dnssec:           return LStr("Validation DNSSEC", "DNSSEC validation")
        case .nxdomain:         return LStr("Détournement des erreurs", "Error page hijacking")
        case .rebind:           return LStr("Protection anti-rebinding", "Rebind protection")
        case .blockAds:         return LStr("Blocage des publicités", "Ad blocking")
        case .blockTrackers:    return LStr("Blocage des traqueurs", "Tracker blocking")
        case .blockMalware:     return LStr("Blocage du malware", "Malware blocking")
        case .blockAdult:       return LStr("Blocage du contenu adulte", "Adult content blocking")
        }
    }

    var explanation: LStr {
        switch self {
        case .encryption:
            return LStr("Sans chiffrement, chaque domaine que vous visitez circule en clair sur le réseau, lisible par votre opérateur et par tout point intermédiaire.",
                        "Without encryption, every domain you visit travels in the clear, readable by your operator and any intermediary.")
        case .outboundResolver:
            return LStr("L'adresse du serveur qui interroge réellement Internet pour vous. C'est lui qui voit passer vos domaines.",
                        "The address of the server that actually queries the Internet for you. It is the one that sees your domains.")
        case .clientSubnet:
            return LStr("Certains résolveurs transmettent une partie de votre adresse IP aux serveurs consultés, pour mieux vous router. C'est un compromis entre performance et vie privée.",
                        "Some resolvers pass part of your IP address to the servers they query, for better routing. It trades privacy for speed.")
        case .dnssec:
            return LStr("DNSSEC vérifie la signature cryptographique des réponses. Sans validation, une réponse falsifiée peut vous envoyer sur un faux site.",
                        "DNSSEC checks the cryptographic signature of answers. Without validation, a forged answer can send you to a fake site.")
        case .nxdomain:
            return LStr("Un domaine inexistant doit renvoyer une erreur. Certains opérateurs renvoient à la place une page de publicité.",
                        "A non-existent domain must return an error. Some operators return an ad page instead.")
        case .rebind:
            return LStr("Un domaine public qui pointe vers une adresse de votre réseau local peut servir à attaquer vos appareils depuis un navigateur.",
                        "A public domain pointing to an address on your local network can be used to attack your devices from a browser.")
        case .blockAds:
            return LStr("Domaines de régies publicitaires.", "Advertising network domains.")
        case .blockTrackers:
            return LStr("Domaines de mesure d'audience et de pistage.", "Analytics and tracking domains.")
        case .blockMalware:
            return LStr("Domaines de test reconnus comme malveillants.", "Test domains flagged as malicious.")
        case .blockAdult:
            return LStr("Domaines de test pour le filtrage familial.", "Test domains for family filtering.")
        }
    }

    var icon: String {
        switch self {
        case .encryption:       return "lock.shield"
        case .outboundResolver: return "eye"
        case .clientSubnet:     return "location"
        case .dnssec:           return "checkmark.seal"
        case .nxdomain:         return "exclamationmark.arrow.triangle.2.circlepath"
        case .rebind:           return "house.slash"
        case .blockAds:         return "rectangle.on.rectangle.slash"
        case .blockTrackers:    return "eye.slash"
        case .blockMalware:     return "exclamationmark.shield"
        case .blockAdult:       return "figure.and.child.holdinghands"
        }
    }

    /// Les tests de blocage partagent une même mécanique et une même catégorie.
    var blockedCategory: BlockCategory? {
        switch self {
        case .blockAds:      return .ads
        case .blockTrackers: return .trackers
        case .blockMalware:  return .malware
        case .blockAdult:    return .adult
        default:             return nil
        }
    }

    /// Domaines témoins interrogés pour un test de blocage.
    var probes: [String] {
        switch self {
        case .blockAds:      return ["doubleclick.net", "googleadservices.com"]
        case .blockTrackers: return ["google-analytics.com", "scorecardresearch.com"]
        case .blockMalware:  return ["internetbadguys.com"]
        case .blockAdult:    return ["exampleadultsite.com"]
        default:             return []
        }
    }
}

// MARK: - Moteur

@MainActor
final class DiagnosticEngine: ObservableObject {

    @Published private(set) var outcomes: [String: CheckOutcome] = [:]
    @Published private(set) var running: Set<String> = []
    @Published private(set) var isRunningAll = false
    /// Progression de la campagne complète, de 0 à 1.
    @Published private(set) var progress: Double = 0

    private let dig = "/usr/bin/dig"

    func outcome(for check: DiagnosticCheck) -> CheckOutcome? { outcomes[check.id] }
    func isRunning(_ check: DiagnosticCheck) -> Bool { running.contains(check.id) }

    var hasResults: Bool { !outcomes.isEmpty }

    /// Compte des tests par statut, pour le résumé en tête d'onglet.
    func count(_ status: CheckStatus) -> Int {
        outcomes.values.filter { sameStatus($0.status, status) }.count
    }

    private func sameStatus(_ a: CheckStatus, _ b: CheckStatus) -> Bool {
        switch (a, b) {
        case (.pass, .pass), (.warn, .warn), (.fail, .fail),
             (.info, .info), (.unknown, .unknown): return true
        default: return false
        }
    }

    // MARK: Exécution

    func runAll(encrypted: Bool) async {
        guard !isRunningAll else { return }
        isRunningAll = true
        progress = 0
        defer { isRunningAll = false; progress = 0 }

        // Les pages de blocage sont repérées une fois pour toutes, avant les
        // tests de blocage qui s'en servent.
        let sinkholes = await detectSinkholeAddresses()

        let checks = DiagnosticCheck.allCases
        for (i, check) in checks.enumerated() {
            await run(check, encrypted: encrypted, sinkholes: sinkholes)
            progress = Double(i + 1) / Double(checks.count)
        }
    }

    func run(_ check: DiagnosticCheck, encrypted: Bool,
             sinkholes: Set<String>? = nil) async {
        guard !running.contains(check.id) else { return }
        running.insert(check.id)
        defer { running.remove(check.id) }

        // Un test de blocage lancé seul doit repérer les pages de blocage
        // lui-même ; la campagne complète les lui fournit une fois pour toutes.
        var known: Set<String> = sinkholes ?? []
        if sinkholes == nil, check.blockedCategory != nil {
            known = await detectSinkholeAddresses()
        }
        let outcome: CheckOutcome

        switch check {
        case .encryption:       outcome = encryptionOutcome(encrypted)
        case .outboundResolver: outcome = await outboundResolverOutcome()
        case .clientSubnet:     outcome = await clientSubnetOutcome()
        case .dnssec:           outcome = await dnssecOutcome()
        case .nxdomain:         outcome = await nxdomainOutcome()
        case .rebind:           outcome = await rebindOutcome()
        default:                outcome = await blockingOutcome(check, sinkholes: known)
        }
        outcomes[check.id] = outcome
    }

    func clear() { outcomes.removeAll() }

    // MARK: Tests

    private func encryptionOutcome(_ encrypted: Bool) -> CheckOutcome {
        encrypted
            ? CheckOutcome(status: .pass,
                           summary: T("diag.encryption.on"),
                           detail: T("diag.encryption.onDetail"))
            : CheckOutcome(status: .fail,
                           summary: T("diag.encryption.off"),
                           detail: T("diag.encryption.offDetail"))
    }

    /// `whoami.akamai.net` renvoie l'adresse publique du résolveur récursif :
    /// c'est le serveur qui voit réellement passer les domaines demandés.
    private func outboundResolverOutcome() async -> CheckOutcome {
        let answer = await dig(["+short", "whoami.akamai.net"])
        guard let ip = answer.split(separator: "\n").first.map(String.init),
              IPAddress.isValid(ip) else {
            return CheckOutcome(status: .unknown, summary: T("diag.generic.noAnswer"),
                                detail: "whoami.akamai.net")
        }
        return CheckOutcome(status: .info,
                            summary: T("diag.outbound.summary", ip),
                            detail: "whoami.akamai.net → \(ip)")
    }

    /// Le résolveur de Google renvoie, en TXT, l'adresse vue et le sous-réseau
    /// client s'il lui a été transmis (EDNS Client Subnet).
    private func clientSubnetOutcome() async -> CheckOutcome {
        let answer = await dig(["-t", "txt", "o-o.myaddr.l.google.com", "+short"])
        guard !answer.isEmpty else {
            return CheckOutcome(status: .unknown, summary: T("diag.generic.noAnswer"),
                                detail: "o-o.myaddr.l.google.com TXT")
        }
        let lines = answer.split(separator: "\n").map {
            $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
        }
        if let subnet = lines.first(where: { $0.contains("edns0-client-subnet") }) {
            let value = subnet.replacingOccurrences(of: "edns0-client-subnet", with: "")
                .trimmingCharacters(in: .whitespaces)
            return CheckOutcome(status: .warn,
                                summary: T("diag.ecs.sent"),
                                detail: T("diag.ecs.sentDetail", value))
        }
        return CheckOutcome(status: .pass, summary: T("diag.ecs.notSent"),
                            detail: "o-o.myaddr.l.google.com TXT → \(lines.joined(separator: " · "))")
    }

    /// Deux domaines de l'université de Duisburg-Essen : l'un correctement
    /// signé, l'autre volontairement mal signé. Un résolveur qui valide refuse
    /// le second avec SERVFAIL ; un résolveur qui ne valide pas le résout.
    private func dnssecOutcome() async -> CheckOutcome {
        let ok = await digStatus("sigok.verteiltesysteme.net")
        let bad = await digStatus("sigfail.verteiltesysteme.net")

        guard !ok.isEmpty, !bad.isEmpty else {
            return CheckOutcome(status: .unknown, summary: T("diag.generic.noAnswer"),
                                detail: "sigok / sigfail.verteiltesysteme.net")
        }
        let detail = "sigok → \(ok) · sigfail → \(bad)"
        if bad == "SERVFAIL", ok == "NOERROR" {
            return CheckOutcome(status: .pass, summary: T("diag.dnssec.on"), detail: detail)
        }
        if bad == "NOERROR" {
            return CheckOutcome(status: .warn, summary: T("diag.dnssec.off"), detail: detail)
        }
        return CheckOutcome(status: .unknown, summary: T("diag.dnssec.unclear"), detail: detail)
    }

    /// Un nom aléatoire dans un domaine inexistant doit renvoyer NXDOMAIN.
    /// Une adresse en réponse signale un résolveur qui détourne les erreurs.
    private func nxdomainOutcome() async -> CheckOutcome {
        let random = UUID().uuidString.prefix(12).lowercased()
        let domain = "\(random)-dnstuner-check.com"
        let status = await digStatus(domain)
        let answer = await dig(["+short", domain])

        if status == "NXDOMAIN", answer.isEmpty {
            return CheckOutcome(status: .pass, summary: T("diag.nxdomain.clean"),
                                detail: "\(domain) → NXDOMAIN")
        }
        if !answer.isEmpty {
            let ip = answer.split(separator: "\n").first.map(String.init) ?? answer
            return CheckOutcome(status: .fail, summary: T("diag.nxdomain.hijacked"),
                                detail: "\(domain) → \(ip)")
        }
        return CheckOutcome(status: .unknown, summary: T("diag.generic.noAnswer"),
                            detail: "\(domain) → \(status)")
    }

    /// `localtest.me` est un domaine public qui pointe volontairement vers
    /// 127.0.0.1. Un résolveur protégeant du rebinding refuse de le résoudre.
    private func rebindOutcome() async -> CheckOutcome {
        let answer = await dig(["+short", "localtest.me"])
        let ip = answer.split(separator: "\n").first.map(String.init) ?? ""

        if ip.isEmpty {
            return CheckOutcome(status: .pass, summary: T("diag.rebind.protected"),
                                detail: "localtest.me → \(T("diag.generic.blocked"))")
        }
        if ip.hasPrefix("127.") || NetworkServices.isPrivate(ip) {
            return CheckOutcome(status: .info, summary: T("diag.rebind.unprotected"),
                                detail: "localtest.me → \(ip)")
        }
        return CheckOutcome(status: .unknown, summary: T("diag.generic.noAnswer"),
                            detail: "localtest.me → \(ip)")
    }

    private func blockingOutcome(_ check: DiagnosticCheck,
                                 sinkholes: Set<String>) async -> CheckOutcome {
        var blocked = 0, tested = 0
        var lines: [String] = []

        for domain in check.probes {
            let answer = await dig(["+short", domain])
            let status = await digStatus(domain)
            tested += 1
            let ips = answer.split(separator: "\n").map(String.init).filter { IPAddress.isValid($0) }

            if status == "NXDOMAIN" || ips.isEmpty {
                blocked += 1
                lines.append("\(domain) → \(T("diag.generic.blocked"))")
            } else if ips.allSatisfy({ isSinkhole($0, sinkholes) }) {
                blocked += 1
                lines.append("\(domain) → \(ips.joined(separator: ", ")) (\(T("diag.generic.blockPage")))")
            } else {
                lines.append("\(domain) → \(ips.joined(separator: ", "))")
            }
        }

        guard tested > 0 else {
            return CheckOutcome(status: .unknown, summary: T("diag.generic.noAnswer"), detail: "")
        }
        let detail = lines.joined(separator: "\n")
        if blocked == tested {
            return CheckOutcome(status: .pass, summary: T("diag.block.all"), detail: detail)
        }
        if blocked > 0 {
            return CheckOutcome(status: .warn,
                                summary: T("diag.block.partial", blocked, tested), detail: detail)
        }
        return CheckOutcome(status: .info, summary: T("diag.block.none"), detail: detail)
    }

    // MARK: Détection des pages de blocage

    /// Un résolveur filtrant renvoie souvent une adresse de « page de blocage »
    /// plutôt que rien. On la reconnaît sans liste codée en dur : c'est celle
    /// qui répond pour des domaines de catégories sans rapport entre elles.
    private func detectSinkholeAddresses() async -> Set<String> {
        let probes = ["doubleclick.net", "internetbadguys.com", "exampleadultsite.com"]
        var seen: [String: Int] = [:]
        for domain in probes {
            let answer = await dig(["+short", domain])
            let ips = Set(answer.split(separator: "\n").map(String.init).filter(IPAddress.isValid))
            for ip in ips { seen[ip, default: 0] += 1 }
        }
        return Set(seen.filter { $0.value >= 2 }.keys)
    }

    private func isSinkhole(_ ip: String, _ detected: Set<String>) -> Bool {
        if ip == "0.0.0.0" || ip == "127.0.0.1" || ip == "::" || ip == "::1" { return true }
        return detected.contains(ip)
    }

    // MARK: Interrogation

    /// Toutes les interrogations passent par le résolveur du système : c'est
    /// précisément sa configuration qu'on mesure. Rien n'est modifié.
    private func dig(_ args: [String]) async -> String {
        await Task.detached(priority: .userInitiated) { [dig] in
            Shell.runResult(dig, args + ["+time=3", "+tries=1"]).trimmedOut
        }.value
    }

    private func digStatus(_ domain: String) async -> String {
        let out = await Task.detached(priority: .userInitiated) { [dig] in
            Shell.runResult(dig, [domain, "+noall", "+comments", "+time=3", "+tries=1"]).out
        }.value
        guard let range = out.range(of: "status: ") else { return "" }
        return out[range.upperBound...].prefix(while: { $0 != "," }).trimmingCharacters(in: .whitespaces)
    }
}
