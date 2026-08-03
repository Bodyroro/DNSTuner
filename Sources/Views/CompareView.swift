//
//  CompareView.swift · Matrice « que bloque quoi »
//
//  Deux lectures superposées : ce que le fournisseur annonce, et — dès qu'un test
//  a été lancé depuis l'onglet Test — ce qu'il bloque réellement.
//

import SwiftUI

struct CompareView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var l10n: L10n

    @State private var showMeasured = true
    @State private var filteringOnly = false

    /// Le tableau occupe toute la largeur : seules les colonnes de tête et de
    /// queue sont fixes, les colonnes de catégories se partagent le reste.
    private let nameWidth: CGFloat = 250
    private let latencyWidth: CGFloat = 130

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(icon: "tablecells",
                      title: l10n.t("compare.title"),
                      subtitle: l10n.t("tab.compare.sub")) {
                HStack(spacing: 12) {
                    Toggle(l10n.t("compare.filteringOnly"), isOn: $filteringOnly)
                        .toggleStyle(.switch).controlSize(.small).tint(DTColor.mac)
                    Toggle(l10n.t("compare.showMeasured"), isOn: $showMeasured)
                        .toggleStyle(.switch).controlSize(.small).tint(DTColor.mac)
                }
            }
            Divider()
            headerRow
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(DTColor.nuitHaute)
            Rectangle().fill(DTColor.ligne).frame(height: 1)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, provider in
                        row(provider, index: i)
                            .padding(.horizontal, 20)
                            .background(i.isMultiple(of: 2) ? Color.clear
                                                            : Color.white.opacity(0.018))
                        Rectangle().fill(DTColor.ligne.opacity(0.5)).frame(height: 1)
                    }
                }
            }
            Rectangle().fill(DTColor.ligne).frame(height: 1)
            legend
        }
        .background(DTColor.fond.ignoresSafeArea())
    }

    private var rows: [DNSProvider] {
        filteringOnly ? ProviderCatalog.all.filter(\.isFiltering) : ProviderCatalog.all
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text(l10n.t("compare.provider"))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .frame(width: nameWidth, alignment: .leading)
            ForEach(BlockCategory.allCases) { category in
                VStack(spacing: 4) {
                    Image(systemName: category.icon).font(.callout)
                        .foregroundStyle(DTColor.mac.opacity(0.9))
                    Text(category.shortLabel.current)
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .help(category.label.current)
            }
            Text(l10n.t("compare.latency"))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .frame(width: latencyWidth, alignment: .trailing)
        }
    }

    private func row(_ provider: DNSProvider, index: Int) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 9) {
                FlagView(country: provider.country, height: 13)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(provider.vendor).font(.callout.weight(.medium)).lineLimit(1)
                        if app.engine.appliedProvider == provider {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9)).foregroundStyle(DTColor.vert)
                        }
                        if !provider.isVerified {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8)).foregroundStyle(DTColor.ambre)
                                .help(l10n.t("provider.unverified"))
                        }
                    }
                    Text(provider.variant.current).font(.caption)
                        .foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                // Un seul repère, comme dans la liste : trois cadenas côte à
                // côte se confondaient et n'apprenaient rien de plus.
                if provider.doh != nil || provider.dot != nil {
                    Image(systemName: "lock.fill").font(.system(size: 9))
                        .foregroundStyle(DTColor.indigo)
                        .help(l10n.t("providers.encryptedAvailable"))
                }
            }
            .frame(width: nameWidth, alignment: .leading)

            ForEach(BlockCategory.allCases) { category in
                CategoryDot(state: cellState(provider, category))
                    .frame(maxWidth: .infinity)
                    .help(helpText(provider, category))
            }

            HStack(spacing: 8) {
                LatencyBar(ms: app.tester.reports[provider.id]?.latencyMS, scale: latencyScale)
                    .frame(width: 60)
                Text(latencyText(provider))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 54, alignment: .trailing)
            }
            .frame(width: latencyWidth, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture {
            app.selectedProviderID = provider.id
            app.tab = .providers
        }
        .riseInCascade(index, step: 0.015, cap: 0.45)
    }

    /// Échelle commune des barres : la latence la plus lente mesurée, pour que
    /// les longueurs soient comparables d'une ligne à l'autre.
    private var latencyScale: Double {
        let values = app.tester.reports.values.compactMap(\.latencyMS)
        return max(values.max() ?? 120, 40)
    }

    private func cellState(_ provider: DNSProvider, _ category: BlockCategory) -> CategoryDot.State {
        let declared = provider.blocks.contains(category)
        guard showMeasured, let measured = measuredResult(provider, category) else {
            return declared ? .declared : .unknown
        }
        if measured { return .confirmed }
        return declared ? .unconfirmed : .open
    }

    private func helpText(_ provider: DNSProvider, _ category: BlockCategory) -> String {
        switch cellState(provider, category) {
        case .declared:    return l10n.t("compare.declared")
        case .confirmed:   return l10n.t("compare.measuredBlocked")
        case .unconfirmed: return l10n.t("compare.declaredNotMeasured")
        case .open:        return l10n.t("compare.measuredOpen")
        case .unknown:     return ""
        }
    }

    private func measuredResult(_ provider: DNSProvider, _ category: BlockCategory) -> Bool? {
        guard let report = app.tester.reports[provider.id], !report.unreachable else { return nil }
        guard let result = report.categories.first(where: { $0.category == category }) else { return nil }
        return result.blocked
    }

    private func latencyText(_ provider: DNSProvider) -> String {
        guard let report = app.tester.reports[provider.id] else { return "—" }
        guard let ms = report.latencyMS else { return l10n.t("compare.unreachable") }
        return String(format: "%.0f ms", ms)
    }

    private var legend: some View {
        FlowRow(spacing: 14) {
            legendItem(.declared, l10n.t("compare.declared"))
            legendItem(.confirmed, l10n.t("compare.measuredBlocked"))
            legendItem(.unconfirmed, l10n.t("compare.declaredNotMeasured"))
            Text(l10n.t("compare.footnote"))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(DTColor.nuitHaute)
    }

    private func legendItem(_ state: CategoryDot.State, _ text: String) -> some View {
        HStack(spacing: 5) {
            CategoryDot(state: state)
            Text(text)
        }
    }
}
