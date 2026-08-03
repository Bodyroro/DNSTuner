//
//  DashboardView.swift · Tout l'essentiel en un écran
//
//  Répond à une seule question, sans avoir à cliquer : « à quoi mon Mac
//  confie-t-il ses requêtes DNS en ce moment, et est-ce protégé ? »
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var l10n: L10n

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(icon: "gauge.with.dots.needle.67percent",
                      title: l10n.t("tab.dashboard"),
                      subtitle: l10n.t("tab.dashboard.sub")) {
                HStack(spacing: 10) {
                    Button(l10n.t("action.refresh")) {
                        withAnimation(.easeOut(duration: 0.25)) { app.refresh() }
                    }
                    Button(l10n.t("dash.testCurrent")) { Task { await testCurrent() } }
                        .disabled(app.engine.appliedProvider == nil)
                }
                .disabled(app.engine.busy)
            }
            Divider()
            ScrollView {
                VStack(spacing: 14) {
                    heroCard.riseIn(0)
                    // HStack et non grille : dans une pile horizontale, les
                    // cartes qui demandent toute la hauteur s'alignent sur la
                    // plus grande. La grille les laissait de hauteurs inégales.
                    HStack(alignment: .top, spacing: 14) {
                        protectionCard.frame(maxHeight: .infinity).riseIn(0.06)
                        servicesCard.frame(maxHeight: .infinity).riseIn(0.10)
                        catalogCard.frame(maxHeight: .infinity).riseIn(0.14)
                        coverageCard.frame(maxHeight: .infinity).riseIn(0.18)
                    }
                    HStack(alignment: .top, spacing: 14) {
                        AuditSummaryCard().frame(maxHeight: .infinity).riseIn(0.22)
                        activityCard.frame(maxHeight: .infinity).riseIn(0.26)
                        quickActionsCard.frame(maxHeight: .infinity).riseIn(0.30).frame(width: 280)
                    }
                }
                .tabContent()
            }
        }
        .background(DTColor.fond.ignoresSafeArea())
        .onAppear { app.refresh() }
    }

    private func testCurrent() async {
        guard let provider = app.engine.appliedProvider else { return }
        await app.tester.test(provider)
    }

    // MARK: - Carte principale : le résolveur actif

    private var heroCard: some View {
        Card(padding: 18) {
            HStack(alignment: .center, spacing: 22) {
                RingGauge(value: protectionScore,
                          gradient: scoreGradient,
                          center: "\(Int(protectionScore * 100))",
                          sub: l10n.t("dash.score"),
                          size: 128,
                          icon: app.statusIcon)

                if let provider = app.engine.appliedProvider ?? app.encryptedProvider {
                    FlagView(country: provider.country, height: 38)
                    VStack(alignment: .leading, spacing: 9) {
                        Text(provider.vendor).font(.title2.weight(.semibold))
                        Text(provider.variant.current).font(.title3).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            CountryTag(country: provider.country)
                            Badge(text: app.isEncrypted ? l10n.t("dash.encrypted")
                                                        : l10n.t("dash.plain"),
                                  systemImage: app.isEncrypted ? "lock.fill" : "lock.open",
                                  tint: app.isEncrypted ? DTColor.indigo : DTColor.ambre)
                            if provider.noLog {
                                Badge(text: l10n.t("provider.noLog"), systemImage: "nosign",
                                      tint: DTColor.vert)
                            }
                        }
                        BlockingChips(categories: provider.blocks)
                    }
                } else {
                    unknownResolverIdentity
                }
                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    latencyBlock
                    resolverBlock
                }
                .frame(width: 210)
            }
        }
    }

    /// Le résolveur actif n'est pas au catalogue : c'est la box du fournisseur
    /// d'accès, ou un serveur d'entreprise. On le nomme plutôt que d'afficher
    /// « DNS du réseau » et une adresse nue.
    @ViewBuilder
    private var unknownResolverIdentity: some View {
        let identity = app.engine.resolverIdentity
        let country = identity?.country ?? ""

        if !country.isEmpty {
            FlagView(country: country, height: 38)
        } else {
            Image(systemName: "wifi.router")
                .font(.system(size: 26)).foregroundStyle(.secondary)
                .frame(width: 51, height: 38)
        }

        VStack(alignment: .leading, spacing: 9) {
            Text(title(for: identity))
                .font(.title2.weight(.semibold))
                .contentTransition(.opacity)
            // Le détail complète le titre sans jamais le répéter : nom d'hôte
            // s'il existe, puis l'adresse — affichée une seule fois.
            Text(subtitle(for: identity))
                .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            Text(identity?.isLocal == false ? l10n.t("dash.unknownPublicHint")
                                            : l10n.t("dash.noProviderHint"))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if identity?.isGateway == true {
                    Badge(text: l10n.t("dash.fromRouter"), systemImage: "wifi.router",
                          tint: DTColor.ambre)
                } else if identity?.isLocal == true {
                    Badge(text: l10n.t("dash.localResolver"), systemImage: "house",
                          tint: DTColor.ambre)
                }
                Button(l10n.t("dash.chooseProvider")) { app.tab = .providers }
            }
        }
        .animation(.easeOut(duration: 0.25), value: identity)
    }

    /// Titre : le nom qu'on a su établir ; à défaut « Votre box » si le
    /// résolveur est la passerelle, sinon un libellé générique. Jamais l'adresse,
    /// qui figure déjà en sous-titre.
    private func title(for identity: ResolverIdentity?) -> String {
        if let name = identity?.displayName { return name }
        if identity?.isGateway == true { return l10n.t("dash.routerTitle") }
        if identity?.isLocal == true { return l10n.t("dash.localTitle") }
        return l10n.t("dash.noProviderTitle")
    }

    private func subtitle(for identity: ResolverIdentity?) -> String {
        guard let identity else { return "" }
        var parts: [String] = []
        // Le nom d'hôte complet n'est repris que s'il n'est pas déjà le titre.
        if let hostname = identity.hostname, hostname != identity.displayName {
            parts.append(hostname)
        }
        parts.append(identity.address)
        return parts.joined(separator: " · ")
    }

    /// Note de protection : moitié pour le chiffrement, moitié pour l'étendue du
    /// filtrage. Volontairement simple — c'est un repère, pas un score de sécurité.
    private var protectionScore: Double {
        guard let provider = app.engine.appliedProvider ?? app.encryptedProvider else { return 0 }
        let encryption = app.isEncrypted ? 0.5 : 0.0
        let filtering = Double(provider.blocks.count) / Double(BlockCategory.allCases.count) * 0.5
        return min(encryption + filtering, 1)
    }

    private var scoreGradient: [Color] {
        if protectionScore >= 0.66 { return [DTColor.vert, DTColor.mac] }
        if protectionScore >= 0.33 { return [DTColor.mac, DTColor.indigo] }
        return [DTColor.ambre, DTColor.rouge]
    }

    private var latencyBlock: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(l10n.t("dash.latency")).font(.caption2).foregroundStyle(.secondary)
            Text(latencyText)
                .font(.system(.title, design: .monospaced).weight(.medium))
                .foregroundStyle(latencyTint)
                .contentTransition(.numericText())
            LatencyBar(ms: currentReport?.latencyMS, scale: 120).frame(width: 120)
        }
    }

    private var resolverBlock: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(l10n.t("dash.activeResolvers")).font(.caption2).foregroundStyle(.secondary)
            ForEach(Array(app.engine.activeResolvers.prefix(2).enumerated()), id: \.offset) { _, r in
                Text(r).font(.system(.caption, design: .monospaced))
                    .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
            }
            if app.engine.activeResolvers.isEmpty {
                Text("—").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
    }

    private var currentReport: TestReport? {
        guard let id = (app.engine.appliedProvider ?? app.encryptedProvider)?.id else { return nil }
        return app.tester.reports[id]
    }

    private var latencyText: String {
        guard let ms = currentReport?.latencyMS else { return "—" }
        return String(format: "%.0f ms", ms)
    }

    private var latencyTint: Color {
        guard let ms = currentReport?.latencyMS else { return .secondary }
        if ms < 30 { return DTColor.vert }
        if ms < 80 { return DTColor.mac }
        return DTColor.ambre
    }

    // MARK: - Cartes secondaires

    private var protectionCard: some View {
        TitledCard(title: l10n.t("dash.protectionTitle"),
                   subtitle: l10n.t("dash.protectionSub"),
                   systemImage: "shield.lefthalf.filled") {
            VStack(spacing: 10) {
                statusLine(l10n.t("dash.encryption"),
                           ok: app.isEncrypted,
                           okText: l10n.t("dash.encryptionOn"),
                           koText: l10n.t("dash.encryptionOff"),
                           tint: DTColor.indigo)
                statusLine(l10n.t("dash.filtering"),
                           ok: (app.engine.appliedProvider?.isFiltering ?? false)
                               || (app.encryptedProvider?.isFiltering ?? false),
                           okText: l10n.t("dash.filteringOn"),
                           koText: l10n.t("dash.filteringOff"),
                           tint: DTColor.mac)
                statusLine("DNSSEC",
                           ok: (app.engine.appliedProvider ?? app.encryptedProvider)?.dnssec ?? false,
                           okText: l10n.t("dash.dnssecOn"),
                           koText: l10n.t("dash.dnssecOff"),
                           tint: DTColor.vert)
                statusLine(l10n.t("dash.rollback"),
                           ok: app.canRestore,
                           okText: l10n.t("dash.rollbackReady"),
                           koText: l10n.t("dash.rollbackNothing"),
                           tint: DTColor.ambre)
            }
        }
    }

    private func statusLine(_ label: String, ok: Bool, okText: String,
                            koText: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ok ? tint : Color.secondary)
                .font(.callout)
            Text(label).font(.callout)
            Spacer()
            Text(ok ? okText : koText)
                .font(.caption)
                .foregroundStyle(ok ? tint : .secondary)
        }
        .animation(.easeOut(duration: 0.25), value: ok)
    }

    private var servicesCard: some View {
        TitledCard(title: l10n.t("status.servicesTitle"),
                   subtitle: l10n.t("dash.servicesSub", app.engine.services.count),
                   systemImage: "network") {
            VStack(spacing: 8) {
                ForEach(Array(app.engine.services.enumerated()), id: \.element.id) { i, service in
                    let dns = app.engine.declaredDNS[service.name] ?? []
                    HStack(spacing: 9) {
                        Circle()
                            .fill(service.isUp ? DTColor.vert : Color.white.opacity(0.18))
                            .frame(width: 7, height: 7)
                            .shadow(color: service.isUp ? DTColor.vert.opacity(0.7) : .clear,
                                    radius: 4)
                        Text(service.name).font(.callout).lineLimit(1)
                        Spacer(minLength: 8)
                        Image(systemName: dns.isEmpty ? "wifi.router" : "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(dns.isEmpty ? Color.secondary : DTColor.vert)
                            .help(dns.isEmpty ? l10n.t("status.fromRouter")
                                              : dns.joined(separator: ", "))
                    }
                    .riseInCascade(i)
                }
                if app.engine.services.isEmpty {
                    Text(l10n.t("status.noService")).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var catalogCard: some View {
        TitledCard(title: l10n.t("dash.catalogTitle"),
                   subtitle: l10n.t("dash.catalogSub", ProviderCatalog.verificationDate),
                   systemImage: "books.vertical") {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    StatTile(value: "\(ProviderCatalog.all.count)",
                             label: l10n.t("dash.statResolvers"),
                             icon: "server.rack")
                    StatTile(value: "\(ProviderCatalog.vendorCount)",
                             label: l10n.t("dash.statVendors"),
                             icon: "building.2", tint: DTColor.indigo)
                }
                HStack(spacing: 14) {
                    StatTile(value: "\(ProviderCatalog.countryCount)",
                             label: l10n.t("dash.statCountries"),
                             icon: "globe.europe.africa", tint: DTColor.vert)
                    StatTile(value: "\(ProviderCatalog.encryptedCount)",
                             label: l10n.t("dash.statEncrypted"),
                             icon: "lock.shield", tint: DTColor.ambre)
                }
                Button(l10n.t("dash.openCatalog")) { app.tab = .providers }
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var coverageCard: some View {
        TitledCard(title: l10n.t("dash.coverageTitle"),
                   subtitle: l10n.t("dash.coverageSub"),
                   systemImage: "chart.bar.xaxis") {
            VStack(spacing: 8) {
                ForEach(Array(BlockCategory.allCases.enumerated()), id: \.element.id) { i, cat in
                    CategoryBar(category: cat,
                                count: ProviderCatalog.all.filter { $0.blocks.contains(cat) }.count,
                                total: ProviderCatalog.all.count)
                        .riseInCascade(i)
                }
            }
        }
    }

    private var activityCard: some View {
        TitledCard(title: l10n.t("dash.activityTitle"),
                   subtitle: l10n.t("dash.activitySub"),
                   systemImage: "clock.arrow.circlepath") {
            VStack(spacing: 8) {
                let entries = Array(Journal.shared.entries.prefix(4))
                if entries.isEmpty {
                    Text(l10n.t("journal.empty")).font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                        HStack(spacing: 10) {
                            Image(systemName: entry.icon).font(.caption)
                                .foregroundStyle(entry.kind == .failure ? DTColor.rouge
                                                 : entry.kind == .success ? DTColor.vert
                                                 : DTColor.mac)
                                .frame(width: 16)
                            Text(entry.message).font(.callout).lineLimit(1)
                            Spacer(minLength: 10)
                            Text(entry.date, style: .time)
                                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .riseInCascade(i)
                    }
                    Button(l10n.t("dash.openJournal")) { app.tab = .journal }
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Trois gestes couvrant l'essentiel de l'usage quotidien, sans chercher
    /// dans les onglets.
    private var quickActionsCard: some View {
        TitledCard(title: l10n.t("dash.quickTitle"),
                   subtitle: l10n.t("dash.quickSub"),
                   systemImage: "bolt.horizontal") {
            VStack(spacing: 9) {
                quickAction(l10n.t("dash.quickCompare"), icon: "tablecells") {
                    app.tab = .compare
                }
                quickAction(l10n.t("dash.quickTestAll"), icon: "speedometer") {
                    app.tab = .test
                }
                quickAction(l10n.t("action.flush"), icon: "arrow.clockwise") {
                    _ = app.engine.flushCache()
                }
                quickAction(l10n.t("action.restore"), icon: "arrow.uturn.backward",
                            tint: DTColor.ambre, enabled: app.canRestore) {
                    app.restore()
                }
            }
        }
    }

    private func quickAction(_ label: String, icon: String, tint: Color = DTColor.mac,
                             enabled: Bool = true,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.callout).foregroundStyle(tint).frame(width: 18)
                Text(label).font(.callout).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11).padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(DTColor.ligne, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}
