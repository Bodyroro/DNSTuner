//
//  DNSTester.swift · Mesure de latence et vérification du blocage réel
//
//  Le tableau comparatif des fournisseurs annonce ce qu'ils *disent* bloquer.
//  Ce fichier vérifie ce qu'ils bloquent *vraiment*, en interrogeant directement
//  le résolveur — sans changer la configuration du système.
//
//  Deux chemins d'interrogation :
//   • `dig` pour les résolveurs joignables en clair ;
//   • une requête DoH en format filaire (RFC 1035 encapsulé RFC 8484) pour les
//     fournisseurs qui ne publient aucune adresse en clair, comme Mullvad.
//

import Foundation

// MARK: - Encodage / décodage DNS minimal

/// Construction et lecture des seules parties du message DNS dont l'app a besoin :
/// le code de retour et les adresses IPv4 répondues.
enum DNSMessage {

    /// Requête A pour un nom de domaine, en format filaire.
    static func queryA(_ domain: String, id: UInt16 = 0) -> Data {
        var data = Data()
        data.append(contentsOf: [UInt8(id >> 8), UInt8(id & 0xFF)])
        data.append(contentsOf: [0x01, 0x00])          // RD = 1 (récursion demandée)
        data.append(contentsOf: [0x00, 0x01])          // QDCOUNT = 1
        data.append(contentsOf: [0x00, 0x00])          // ANCOUNT
        data.append(contentsOf: [0x00, 0x00])          // NSCOUNT
        data.append(contentsOf: [0x00, 0x00])          // ARCOUNT
        for label in domain.split(separator: ".") {
            let bytes = Array(label.utf8).prefix(63)
            data.append(UInt8(bytes.count))
            data.append(contentsOf: bytes)
        }
        data.append(0x00)                              // fin du nom
        data.append(contentsOf: [0x00, 0x01])          // QTYPE = A
        data.append(contentsOf: [0x00, 0x01])          // QCLASS = IN
        return data
    }

    struct Response {
        let rcode: UInt8
        let addresses: [String]
        var isNXDomain: Bool { rcode == 3 }
    }

    /// Lit le code de retour et les adresses A. Renvoie `nil` si le message est
    /// tronqué ou malformé — jamais d'interprétation optimiste.
    static func parse(_ data: Data) -> Response? {
        let b = [UInt8](data)
        guard b.count >= 12 else { return nil }
        let rcode = b[3] & 0x0F
        let qdCount = Int(b[4]) << 8 | Int(b[5])
        let anCount = Int(b[6]) << 8 | Int(b[7])

        var i = 12
        // Section question : on la saute, seuls les noms sont de longueur variable.
        for _ in 0..<qdCount {
            guard let next = skipName(b, from: i) else { return nil }
            i = next + 4                                // QTYPE + QCLASS
            guard i <= b.count else { return nil }
        }

        var addresses: [String] = []
        for _ in 0..<anCount {
            guard let afterName = skipName(b, from: i) else { break }
            i = afterName
            guard i + 10 <= b.count else { break }
            let type = Int(b[i]) << 8 | Int(b[i + 1])
            let rdLength = Int(b[i + 8]) << 8 | Int(b[i + 9])
            i += 10
            guard i + rdLength <= b.count else { break }
            if type == 1, rdLength == 4 {
                addresses.append("\(b[i]).\(b[i+1]).\(b[i+2]).\(b[i+3])")
            }
            i += rdLength
        }
        return Response(rcode: rcode, addresses: addresses)
    }

    /// Avance après un nom, qu'il soit écrit en toutes lettres ou compressé
    /// (pointeur 0xC0, qui occupe deux octets et termine le nom).
    private static func skipName(_ b: [UInt8], from start: Int) -> Int? {
        var i = start
        while i < b.count {
            let len = b[i]
            if len == 0 { return i + 1 }
            if len & 0xC0 == 0xC0 { return i + 2 }
            i += Int(len) + 1
        }
        return nil
    }
}

// MARK: - Cas de test

/// Domaine témoin associé à une catégorie de blocage.
/// Ce sont des domaines publics de test ou des domaines emblématiques de leur
/// catégorie : l'app les interroge, elle ne s'y connecte jamais.
struct BlockProbe: Identifiable {
    let category: BlockCategory
    let domain: String
    var id: String { "\(category.rawValue)-\(domain)" }

    static let all: [BlockProbe] = [
        BlockProbe(category: .ads,      domain: "doubleclick.net"),
        BlockProbe(category: .ads,      domain: "googleadservices.com"),
        BlockProbe(category: .trackers, domain: "google-analytics.com"),
        BlockProbe(category: .trackers, domain: "scorecardresearch.com"),
        BlockProbe(category: .malware,  domain: "internetbadguys.com"),
        BlockProbe(category: .adult,    domain: "exampleadultsite.com"),
        BlockProbe(category: .adult,    domain: "pornhub.com"),
        BlockProbe(category: .gambling, domain: "bet365.com"),
        BlockProbe(category: .social,   domain: "facebook.com"),
    ]

    /// Domaine neutre servant à mesurer la latence : jamais filtré nulle part.
    static let latencyProbe = "example.com"
}

enum ProbeOutcome {
    case resolved([String])
    case blocked
    case failed(String)

    var isBlocked: Bool { if case .blocked = self { return true }; return false }
}

struct CategoryResult: Identifiable {
    let category: BlockCategory
    let blocked: Bool
    let tested: Int
    let blockedCount: Int
    var id: String { category.rawValue }
}

struct TestReport {
    let provider: DNSProvider
    let transport: DNSTransport
    /// Latence médiane en millisecondes, `nil` si le résolveur n'a pas répondu.
    let latencyMS: Double?
    let categories: [CategoryResult]
    let unreachable: Bool
}

// MARK: - Testeur

@MainActor
final class DNSTester: ObservableObject {

    @Published private(set) var reports: [String: TestReport] = [:]   // clé = provider.id
    @Published private(set) var running: Set<String> = []

    private let dig = "/usr/bin/dig"

    func isRunning(_ provider: DNSProvider) -> Bool { running.contains(provider.id) }

    /// Teste un fournisseur sans toucher à la configuration du système.
    func test(_ provider: DNSProvider) async {
        guard !running.contains(provider.id) else { return }
        running.insert(provider.id)
        defer { running.remove(provider.id) }

        // On interroge en clair quand c'est possible (plus rapide et plus fidèle
        // à ce que fera le système), sinon en DoH.
        let transport: DNSTransport = provider.plainAddresses.isEmpty ? .https : .plain
        guard transport == .plain || provider.doh != nil else {
            reports[provider.id] = TestReport(provider: provider, transport: transport,
                                              latencyMS: nil, categories: [], unreachable: true)
            return
        }

        let latency = await measureLatency(provider, transport: transport)
        guard latency != nil else {
            reports[provider.id] = TestReport(provider: provider, transport: transport,
                                              latencyMS: nil, categories: [], unreachable: true)
            return
        }

        var perCategory: [BlockCategory: (tested: Int, blocked: Int)] = [:]
        for probe in BlockProbe.all {
            let outcome = await query(probe.domain, provider: provider, transport: transport)
            if case .failed = outcome { continue }
            var entry = perCategory[probe.category] ?? (0, 0)
            entry.tested += 1
            if outcome.isBlocked { entry.blocked += 1 }
            perCategory[probe.category] = entry
        }

        let categories = BlockCategory.allCases.compactMap { category -> CategoryResult? in
            guard let e = perCategory[category], e.tested > 0 else { return nil }
            return CategoryResult(category: category, blocked: e.blocked > 0,
                                  tested: e.tested, blockedCount: e.blocked)
        }

        reports[provider.id] = TestReport(provider: provider, transport: transport,
                                          latencyMS: latency, categories: categories,
                                          unreachable: false)
        Journal.shared.log(.info, T("journal.tested", provider.displayName))
    }

    /// Latence médiane sur trois requêtes, pour lisser une valeur aberrante.
    private func measureLatency(_ provider: DNSProvider, transport: DNSTransport) async -> Double? {
        var samples: [Double] = []
        for _ in 0..<3 {
            let start = Date()
            let outcome = await query(BlockProbe.latencyProbe, provider: provider, transport: transport)
            if case .failed = outcome { continue }
            samples.append(Date().timeIntervalSince(start) * 1000)
        }
        guard !samples.isEmpty else { return nil }
        return samples.sorted()[samples.count / 2]
    }

    // MARK: - Interrogation

    private func query(_ domain: String, provider: DNSProvider,
                       transport: DNSTransport) async -> ProbeOutcome {
        switch transport {
        case .plain:
            guard let server = provider.ipv4.first ?? provider.ipv6.first else {
                return .failed("no server")
            }
            return queryWithDig(domain, server: server)
        case .https, .tls:
            guard let doh = provider.doh, let url = URL(string: doh) else {
                return .failed("no DoH endpoint")
            }
            return await queryWithDoH(domain, url: url)
        }
    }

    /// Interrogation en clair. `dig` est fourni par macOS et gère IPv4 comme IPv6.
    private func queryWithDig(_ domain: String, server: String) -> ProbeOutcome {
        let r = Shell.runResult(dig, ["@\(server)", domain, "A",
                                      "+time=3", "+tries=1", "+noall", "+answer", "+comments"])
        guard r.ok else { return .failed(r.err) }
        let out = r.out
        if out.contains("status: NXDOMAIN") { return .blocked }
        if out.contains("connection timed out") || out.contains("no servers could be reached") {
            return .failed("timeout")
        }
        let addresses = out.split(separator: "\n")
            .filter { $0.contains("\tA\t") || $0.contains(" A ") }
            .compactMap { $0.split(separator: "\t").last.map(String.init)
                            ?? $0.split(separator: " ").last.map(String.init) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { IPAddress.isIPv4($0) }
        return classify(addresses)
    }

    /// Interrogation DoH en format filaire (RFC 8484), pour les fournisseurs sans
    /// adresse en clair. Aucune donnée de l'utilisateur n'est envoyée : seuls les
    /// domaines témoins de `BlockProbe` sont interrogés.
    private func queryWithDoH(_ domain: String, url: URL) async -> ProbeOutcome {
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        request.httpBody = DNSMessage.queryA(domain)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .failed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            guard let parsed = DNSMessage.parse(data) else { return .failed("malformed") }
            if parsed.isNXDomain { return .blocked }
            return classify(parsed.addresses)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Un résolveur filtrant répond soit NXDOMAIN, soit une adresse « puits »
    /// (0.0.0.0 ou une boucle locale), soit rien du tout.
    private func classify(_ addresses: [String]) -> ProbeOutcome {
        if addresses.isEmpty { return .blocked }
        let sinkholes: Set<String> = ["0.0.0.0", "127.0.0.1"]
        if addresses.allSatisfy({ sinkholes.contains($0) }) { return .blocked }
        return .resolved(addresses)
    }
}
