//
//  TestView.swift · Mesure réelle : latence et blocage effectif
//
//  Les tests interrogent directement les résolveurs, sans modifier la
//  configuration du système : on peut donc comparer avant de basculer.
//

import SwiftUI

struct TestView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var l10n: L10n

    @State private var testingAll = false
    @State private var progress = 0.0

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(icon: "speedometer",
                      title: l10n.t("test.title"),
                      subtitle: l10n.t("tab.test.sub")) {
                HStack(spacing: 10) {
                    if testingAll {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .frame(width: 90)
                            .tint(DTColor.mac)
                    }
                    Button(l10n.t("test.runFavorites")) { Task { await run(favoritesOnly: true) } }
                        .disabled(testingAll || Store.favorites.isEmpty)
                    Button(l10n.t("test.runAll")) { Task { await run(favoritesOnly: false) } }
                        .disabled(testingAll)
                }
            }
            Divider()
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(ProviderCatalog.all.enumerated()), id: \.element.id) { i, provider in
                        resultRow(provider).riseInCascade(i, step: 0.02, cap: 0.5)
                    }
                }
                .tabContent()
            }
            Rectangle().fill(DTColor.ligne).frame(height: 1)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "hand.raised").font(.caption).foregroundStyle(.secondary)
                Text(l10n.t("test.disclaimer")).font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(DTColor.nuitHaute)
        }
        .background(DTColor.fond.ignoresSafeArea())
    }

    /// Une ligne compacte : tout tient sur une rangée, et les catégories
    /// mesurées n'apparaissent qu'une fois le test passé. Étalée sur trois
    /// niveaux, la liste ne montrait que sept résolveurs sur quarante-six.
    private func resultRow(_ provider: DNSProvider) -> some View {
        let report = app.tester.reports[provider.id]
        let running = app.tester.isRunning(provider)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ResolvePulse(active: running,
                             tint: running ? DTColor.mac : .secondary, size: 16)
                FlagView(country: provider.country, height: 11)

                Text(provider.vendor).font(.callout.weight(.medium)).lineLimit(1)
                Text(provider.variant.current).font(.callout)
                    .foregroundStyle(.secondary).lineLimit(1)

                Spacer(minLength: 12)

                if report?.unreachable == true {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(DTColor.ambre)
                        .help(l10n.t("test.unreachable"))
                }
                LatencyBar(ms: report?.latencyMS, scale: latencyScale).frame(width: 70)
                Text(latencyText(report))
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                    .foregroundStyle(latencyTint(report))
                    .contentTransition(.numericText())
                    .frame(width: 58, alignment: .trailing)
                Button(l10n.t("test.run")) { Task { await app.tester.test(provider) } }
                    .controlSize(.small)
                    .disabled(running)
            }

            if let report, !report.unreachable, !report.categories.isEmpty {
                FlowRow(spacing: 5) {
                    ForEach(report.categories) { result in
                        Badge(text: result.category.shortLabel.current,
                              systemImage: result.blocked ? "checkmark.circle.fill" : "circle",
                              tint: result.blocked ? DTColor.vert : .secondary)
                    }
                }
                .padding(.leading, 37)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DTColor.carte))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(running ? DTColor.mac.opacity(0.4) : DTColor.ligne, lineWidth: 1))
        .animation(.easeOut(duration: 0.3), value: report?.latencyMS)
    }

    private var latencyScale: Double {
        let values = app.tester.reports.values.compactMap(\.latencyMS)
        return max(values.max() ?? 120, 40)
    }

    private func latencyText(_ report: TestReport?) -> String {
        guard let report else { return "—" }
        guard let ms = report.latencyMS else { return "✕" }
        return String(format: "%.0f ms", ms)
    }

    private func latencyTint(_ report: TestReport?) -> Color {
        guard let ms = report?.latencyMS else { return .secondary }
        if ms < 30 { return DTColor.vert }
        if ms < 80 { return DTColor.mac }
        return DTColor.ambre
    }

    // MARK: - Exécution

    private func run(favoritesOnly: Bool) async {
        let targets = favoritesOnly
            ? ProviderCatalog.all.filter { Store.favorites.contains($0.id) }
            : ProviderCatalog.all
        guard !targets.isEmpty else { return }

        testingAll = true
        progress = 0
        defer { testingAll = false; progress = 0 }

        for (i, provider) in targets.enumerated() {
            await app.tester.test(provider)
            withAnimation(.easeOut(duration: 0.2)) {
                progress = Double(i + 1) / Double(targets.count)
            }
        }
    }
}
