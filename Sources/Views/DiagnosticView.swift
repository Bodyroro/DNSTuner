//
//  DiagnosticView.swift · Ce que vaut la configuration DNS actuelle
//

import SwiftUI

struct DiagnosticView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var l10n: L10n

    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(icon: "stethoscope",
                      title: l10n.t("tab.diagnostic"),
                      subtitle: l10n.t("tab.diagnostic.sub")) {
                HStack(spacing: 10) {
                    if app.diagnostic.isRunningAll {
                        ProgressView(value: app.diagnostic.progress)
                            .progressViewStyle(.linear).frame(width: 90).tint(DTColor.mac)
                    }
                    Button(l10n.t("diag.runAll")) {
                        Task { await app.diagnostic.runAll(encrypted: app.isEncrypted) }
                    }
                    .disabled(app.diagnostic.isRunningAll)
                }
            }
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    AuditSection().riseIn(0)
                    sectionTitle(l10n.t("diag.sectionChecks"))
                    if app.diagnostic.hasResults { summaryCard.riseIn(0) }
                    ForEach(Array(DiagnosticCheck.allCases.enumerated()), id: \.element.id) { i, check in
                        checkRow(check).riseInCascade(i, step: 0.03, cap: 0.4)
                    }
                }
                .tabContent()
            }
            Rectangle().fill(DTColor.ligne).frame(height: 1)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "hand.raised").font(.caption).foregroundStyle(.secondary)
                Text(l10n.t("diag.disclaimer")).font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(DTColor.nuitHaute)
        }
        .background(DTColor.fond.ignoresSafeArea())
    }

    private func sectionTitle(_ text: String) -> some View {
        HStack(spacing: 9) {
            Text(text.uppercased()).font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary).kerning(0.8)
            Rectangle().fill(DTColor.ligne).frame(height: 1)
        }
        .padding(.top, 8)
    }

    // MARK: - Résumé

    private var summaryCard: some View {
        Card(padding: 14) {
            HStack(spacing: 22) {
                summaryTile(.pass, l10n.t("diag.summary.pass"), DTColor.vert)
                summaryTile(.warn, l10n.t("diag.summary.warn"), DTColor.ambre)
                summaryTile(.fail, l10n.t("diag.summary.fail"), DTColor.rouge)
                summaryTile(.info, l10n.t("diag.summary.info"), DTColor.mac)
                Spacer()
                Text(l10n.t("diag.summary.hint"))
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: 320, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summaryTile(_ status: CheckStatus, _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: status.icon).font(.title3).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(app.diagnostic.count(status))")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit().contentTransition(.numericText())
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Un test

    private func checkRow(_ check: DiagnosticCheck) -> some View {
        let outcome = app.diagnostic.outcome(for: check)
        let running = app.diagnostic.isRunning(check)
        let isOpen = expanded.contains(check.id)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                statusBadge(outcome?.status, running: running)

                VStack(alignment: .leading, spacing: 3) {
                    Text(check.title.current).font(.callout.weight(.medium))
                    Text(outcome?.summary ?? check.explanation.current)
                        .font(.caption)
                        .foregroundStyle(outcome == nil ? .secondary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                if outcome != nil {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if isOpen { expanded.remove(check.id) } else { expanded.insert(check.id) }
                        }
                    } label: {
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button(l10n.t("test.run")) {
                    Task { await app.diagnostic.run(check, encrypted: app.isEncrypted) }
                }
                .controlSize(.small)
                .disabled(running || app.diagnostic.isRunningAll)
            }

            if isOpen, let outcome {
                VStack(alignment: .leading, spacing: 7) {
                    Text(check.explanation.current)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(outcome.detail)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.04)))
                }
                .padding(.top, 10)
                .padding(.leading, 38)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(DTColor.carte))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(running ? DTColor.mac.opacity(0.4) : DTColor.ligne, lineWidth: 1))
    }

    @ViewBuilder
    private func statusBadge(_ status: CheckStatus?, running: Bool) -> some View {
        if running {
            ResolvePulse(active: true, tint: DTColor.mac, size: 20).frame(width: 26)
        } else if let status {
            Image(systemName: status.icon)
                .font(.title3)
                .foregroundStyle(tint(status))
                .frame(width: 26)
        } else {
            Image(systemName: "circle.dotted")
                .font(.title3).foregroundStyle(.tertiary).frame(width: 26)
        }
    }

    private func tint(_ status: CheckStatus) -> Color {
        switch status {
        case .pass:    return DTColor.vert
        case .warn:    return DTColor.ambre
        case .fail:    return DTColor.rouge
        case .info:    return DTColor.mac
        case .unknown: return .secondary
        }
    }
}
