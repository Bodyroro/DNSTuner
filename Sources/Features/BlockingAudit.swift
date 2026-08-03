//
//  BlockingAudit.swift · Note de blocage, mesurée domaine par domaine
//
//  Un test de bloqueur classique juge trois choses : le masquage cosmétique, le
//  chargement des scripts, et la résolution des domaines. Un DNS n'agit que sur
//  la troisième — il ne voit ni le contenu d'une page ni le chemin d'un script.
//  L'audit porte donc uniquement là-dessus, et le dit.
//

import Foundation

/// Famille d'un domaine témoin. Seules les trois premières entrent dans la note :
/// ce sont celles qu'un utilisateur cherche à bloquer par défaut. Les autres
/// relèvent d'un choix particulier et sont affichées à part.
enum ProbeFamily: String, CaseIterable, Identifiable, Codable {
    case advertising
    case tracking
    case telemetry
    case social
    case malware
    case adult

    var id: String { rawValue }

    /// Vrai si la famille compte dans la note globale.
    var isScored: Bool {
        switch self {
        case .advertising, .tracking, .telemetry: return true
        case .social, .malware, .adult: return false
        }
    }

    var label: LStr {
        switch self {
        case .advertising: return LStr("Régies publicitaires", "Ad networks")
        case .tracking:    return LStr("Traqueurs et mesure d'audience", "Trackers and analytics")
        case .telemetry:   return LStr("Télémétrie applicative", "App telemetry")
        case .social:      return LStr("Widgets sociaux", "Social widgets")
        case .malware:     return LStr("Malware et hameçonnage", "Malware and phishing")
        case .adult:       return LStr("Contenu adulte", "Adult content")
        }
    }

    var icon: String {
        switch self {
        case .advertising: return "rectangle.on.rectangle.slash"
        case .tracking:    return "eye.slash"
        case .telemetry:   return "antenna.radiowaves.left.and.right.slash"
        case .social:      return "bubble.left.and.bubble.right"
        case .malware:     return "exclamationmark.shield"
        case .adult:       return "figure.and.child.holdinghands"
        }
    }
}

/// Un domaine témoin et ce qu'il représente.
struct AuditProbe: Identifiable {
    let domain: String
    let family: ProbeFamily
    /// Ce que ce domaine sert réellement, pour que le détail soit compréhensible.
    let role: LStr

    var id: String { domain }
}

enum ProbeVerdict: String {
    case blocked      // NXDOMAIN, aucune réponse, ou adresse puits
    case resolved     // le domaine répond normalement : rien ne le bloque
    case failed       // la mesure n'a pas abouti
}

struct ProbeResult: Identifiable {
    let probe: AuditProbe
    let verdict: ProbeVerdict
    /// Adresse obtenue, ou raison du blocage.
    let answer: String
    var id: String { probe.domain }
}

/// Niveau de protection, repris de la façon dont les tests de bloqueurs les
/// présentent : il n'y a pas lieu de viser 100 %, une note verte suffit.
enum ProtectionLevel {
    case insufficient   // < 40 %
    case improvable     // 40 – 74 %
    case good           // ≥ 75 %

    static func from(score: Double) -> ProtectionLevel {
        if score >= 0.75 { return .good }
        if score >= 0.40 { return .improvable }
        return .insufficient
    }

    var label: LStr {
        switch self {
        case .insufficient: return LStr("Protection insuffisante", "Insufficient protection")
        case .improvable:   return LStr("Protection perfectible", "Protection could be better")
        case .good:         return LStr("Protection satisfaisante", "Protection is good")
        }
    }

    var advice: LStr {
        switch self {
        case .insufficient:
            return LStr("Presque rien n'est filtré. Un résolveur bloquant publicités et traqueurs changerait tout.",
                        "Almost nothing is filtered. A resolver that blocks ads and trackers would change everything.")
        case .improvable:
            return LStr("Une partie passe encore. Un résolveur plus strict, ou sa variante familiale, comblerait l'écart.",
                        "Some of it still gets through. A stricter resolver, or its family variant, would close the gap.")
        case .good:
            return LStr("L'essentiel est filtré. Inutile de viser 100 % : au-delà, les faux positifs coûtent plus qu'ils ne rapportent.",
                        "The bulk is filtered. No need to chase 100%: beyond this, false positives cost more than they gain.")
        }
    }
}

// MARK: - Panel de domaines témoins

enum AuditPanel {
    static let probes: [AuditProbe] = advertising + tracking + telemetry + social + malware + adult

    static func probes(in family: ProbeFamily) -> [AuditProbe] {
        probes.filter { $0.family == family }
    }

    /// Domaines comptant dans la note.
    static var scoredCount: Int { probes.filter { $0.family.isScored }.count }

    private static func p(_ domain: String, _ family: ProbeFamily,
                          _ fr: String, _ en: String) -> AuditProbe {
        AuditProbe(domain: domain, family: family, role: LStr(fr, en))
    }

    private static let advertising: [AuditProbe] = [
        p("doubleclick.net", .advertising, "Régie publicitaire de Google", "Google's ad network"),
        p("googlesyndication.com", .advertising, "Diffusion des annonces AdSense", "AdSense ad delivery"),
        p("googleadservices.com", .advertising, "Suivi des clics publicitaires Google", "Google ad click tracking"),
        p("amazon-adsystem.com", .advertising, "Régie publicitaire d'Amazon", "Amazon's ad network"),
        p("adnxs.com", .advertising, "Place de marché Xandr (AppNexus)", "Xandr (AppNexus) ad exchange"),
        p("rubiconproject.com", .advertising, "Place de marché Magnite", "Magnite ad exchange"),
        p("pubmatic.com", .advertising, "Place de marché publicitaire", "Ad exchange"),
        p("criteo.com", .advertising, "Reciblage publicitaire", "Retargeting ads"),
        p("taboola.com", .advertising, "Recommandations sponsorisées", "Sponsored content recommendations"),
        p("outbrain.com", .advertising, "Recommandations sponsorisées", "Sponsored content recommendations"),
        p("openx.net", .advertising, "Place de marché publicitaire", "Ad exchange"),
        p("casalemedia.com", .advertising, "Place de marché Index Exchange", "Index Exchange marketplace"),
        p("smartadserver.com", .advertising, "Serveur publicitaire Equativ", "Equativ ad server"),
        p("adform.net", .advertising, "Plateforme publicitaire", "Ad platform"),
        p("teads.tv", .advertising, "Publicité vidéo", "Video advertising"),
        p("33across.com", .advertising, "Place de marché publicitaire", "Ad exchange"),
    ]

    private static let tracking: [AuditProbe] = [
        p("google-analytics.com", .tracking, "Mesure d'audience de Google", "Google's analytics"),
        p("googletagmanager.com", .tracking, "Chargeur de balises de suivi", "Tracking tag loader"),
        p("scorecardresearch.com", .tracking, "Panel de mesure Comscore", "Comscore measurement panel"),
        p("hotjar.com", .tracking, "Enregistrement des sessions", "Session recording"),
        p("mixpanel.com", .tracking, "Analyse comportementale", "Behavioural analytics"),
        p("amplitude.com", .tracking, "Analyse produit", "Product analytics"),
        p("fullstory.com", .tracking, "Rejeu de sessions", "Session replay"),
        p("quantserve.com", .tracking, "Mesure d'audience Quantcast", "Quantcast measurement"),
        p("chartbeat.com", .tracking, "Audience temps réel", "Real-time audience analytics"),
        p("segment.com", .tracking, "Collecte et redistribution de données", "Data collection hub"),
    ]

    private static let telemetry: [AuditProbe] = [
        p("app-measurement.com", .telemetry, "Télémétrie Firebase", "Firebase telemetry"),
        p("crashlytics.com", .telemetry, "Rapports de plantage", "Crash reporting"),
        p("branch.io", .telemetry, "Attribution d'installations", "Install attribution"),
        p("adjust.com", .telemetry, "Attribution mobile", "Mobile attribution"),
        p("appsflyer.com", .telemetry, "Attribution mobile", "Mobile attribution"),
        p("kochava.com", .telemetry, "Attribution mobile", "Mobile attribution"),
        p("bat.bing.com", .telemetry, "Suivi de conversion Microsoft", "Microsoft conversion tracking"),
        p("analytics.tiktok.com", .telemetry, "Mesure d'audience TikTok", "TikTok analytics"),
    ]

    private static let social: [AuditProbe] = [
        p("connect.facebook.net", .social, "Pixel et widgets Facebook", "Facebook pixel and widgets"),
        p("ads.linkedin.com", .social, "Publicité LinkedIn", "LinkedIn advertising"),
        p("facebook.com", .social, "Réseau social", "Social network"),
    ]

    private static let malware: [AuditProbe] = [
        p("internetbadguys.com", .malware, "Domaine de test de Cisco OpenDNS", "Cisco OpenDNS test domain"),
    ]

    private static let adult: [AuditProbe] = [
        p("exampleadultsite.com", .adult, "Domaine de test du filtrage familial", "Family-filter test domain"),
        p("pornhub.com", .adult, "Site pour adultes", "Adult site"),
    ]
}

// MARK: - Moteur

@MainActor
final class BlockingAudit: ObservableObject {

    @Published private(set) var results: [String: ProbeResult] = [:]
    @Published private(set) var isRunning = false
    @Published private(set) var progress: Double = 0
    /// Date de la dernière campagne, pour dire si la note est fraîche.
    @Published private(set) var lastRun: Date?

    private let dig = "/usr/bin/dig"

    var hasResults: Bool { !results.isEmpty }

    // MARK: Note

    /// Part des domaines témoins bloqués, sur les seules familles notées.
    var score: Double {
        let scored = AuditPanel.probes.filter { $0.family.isScored }
        let measured = scored.compactMap { results[$0.domain] }
            .filter { $0.verdict != .failed }
        guard !measured.isEmpty else { return 0 }
        let blocked = measured.filter { $0.verdict == .blocked }.count
        return Double(blocked) / Double(measured.count)
    }

    var level: ProtectionLevel { .from(score: score) }

    /// Nombre bloqué / nombre mesuré, pour une famille.
    func tally(_ family: ProbeFamily) -> (blocked: Int, measured: Int) {
        let measured = AuditPanel.probes(in: family).compactMap { results[$0.domain] }
            .filter { $0.verdict != .failed }
        return (measured.filter { $0.verdict == .blocked }.count, measured.count)
    }

    func result(for probe: AuditProbe) -> ProbeResult? { results[probe.domain] }

    // MARK: Campagne

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        progress = 0
        results.removeAll()
        defer { isRunning = false; progress = 0; lastRun = Date() }

        let sinkholes = await detectSinkholes()
        let probes = AuditPanel.probes
        let batchSize = 8   // assez pour aller vite, pas au point de noyer le résolveur
        var done = 0

        for start in stride(from: 0, to: probes.count, by: batchSize) {
            let batch = Array(probes[start..<min(start + batchSize, probes.count)])
            let batchResults = await withTaskGroup(of: ProbeResult.self) { group in
                for probe in batch {
                    group.addTask { [dig] in
                        await Self.measure(probe, dig: dig, sinkholes: sinkholes)
                    }
                }
                var out: [ProbeResult] = []
                for await r in group { out.append(r) }
                return out
            }
            for r in batchResults { results[r.probe.domain] = r }
            done += batch.count
            progress = Double(done) / Double(probes.count)
        }
    }

    func clear() {
        results.removeAll()
        lastRun = nil
    }

    // MARK: Mesure

    private nonisolated static func measure(_ probe: AuditProbe, dig: String,
                                            sinkholes: Set<String>) async -> ProbeResult {
        let short = Shell.runResult(dig, ["+short", probe.domain, "+time=3", "+tries=1"])
        guard short.ok || !short.trimmedOut.isEmpty else {
            return ProbeResult(probe: probe, verdict: .failed, answer: "")
        }
        let ips = short.trimmedOut.split(separator: "\n").map(String.init)
            .filter { IPAddress.isValid($0) }

        if ips.isEmpty {
            // Ni adresse ni erreur exploitable : le domaine est filtré.
            return ProbeResult(probe: probe, verdict: .blocked, answer: "NXDOMAIN")
        }
        let sink: Set<String> = ["0.0.0.0", "127.0.0.1", "::", "::1"]
        if ips.allSatisfy({ sink.contains($0) || sinkholes.contains($0) }) {
            return ProbeResult(probe: probe, verdict: .blocked,
                               answer: ips.joined(separator: ", "))
        }
        return ProbeResult(probe: probe, verdict: .resolved,
                           answer: ips.prefix(2).joined(separator: ", "))
    }

    /// Adresse de page de blocage : celle qui répond pour des domaines de
    /// catégories sans rapport. Aucune liste codée en dur.
    private func detectSinkholes() async -> Set<String> {
        let witnesses = ["doubleclick.net", "internetbadguys.com", "exampleadultsite.com"]
        var seen: [String: Int] = [:]
        for domain in witnesses {
            let out = await Task.detached(priority: .userInitiated) { [dig] in
                Shell.runResult(dig, ["+short", domain, "+time=3", "+tries=1"]).trimmedOut
            }.value
            for ip in Set(out.split(separator: "\n").map(String.init).filter(IPAddress.isValid)) {
                seen[ip, default: 0] += 1
            }
        }
        return Set(seen.filter { $0.value >= 2 }.keys)
    }
}
