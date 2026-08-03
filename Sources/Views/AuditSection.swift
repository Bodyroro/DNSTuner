//
//  AuditSection.swift · La note de blocage et son détail
//
//  Le but n'est pas d'afficher un chiffre, mais de rendre compréhensible ce qui
//  passe et ce qui ne passe pas : chaque domaine témoin est nommé, avec ce qu'il
//  sert et la réponse obtenue.
//

import SwiftUI

/// Bloc principal : la bille de note, le niveau, le conseil, et les familles.
struct AuditSection: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var l10n: L10n

    @State private var expandedFamilies: Set<String> = []

    private var audit: BlockingAudit { app.audit }

    var body: some View {
        VStack(spacing: 12) {
            headline
            if audit.hasResults {
                ForEach(Array(ProbeFamily.allCases.enumerated()), id: \.element.id) { i, family in
                    familyCard(family).riseInCascade(i, step: 0.04, cap: 0.3)
                }
            }
        }
    }

    // MARK: - Bille et verdict

    private var headline: some View {
        Card(padding: 18) {
            HStack(alignment: .center, spacing: 22) {
                LiquidGauge(value: audit.hasResults ? audit.score : 0,
                            tint: audit.hasResults ? audit.level.tint : .secondary,
                            center: audit.hasResults ? "\(Int((audit.score * 100).rounded()))" : "—",
                            caption: l10n.t("audit.outOf"),
                            size: 132,
                            animated: audit.isRunning || audit.hasResults)

                VStack(alignment: .leading, spacing: 9) {
                    Text(l10n.t("audit.title")).font(.title2.weight(.semibold))

                    if audit.hasResults {
                        Text(audit.level.label.current)
                            .font(.title3).foregroundStyle(audit.level.tint)
                        Text(audit.level.advice.current)
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(l10n.t("audit.intro"))
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Le DNS ne peut pas tout : le dire ici évite de laisser
                    // croire qu'une note verte remplace un bloqueur de contenu.
                    Label(l10n.t("audit.dnsOnly"), systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    if audit.isRunning {
                        ProgressView(value: audit.progress)
                            .progressViewStyle(.linear).frame(width: 130).tint(DTColor.mac)
                    }
                    Button(audit.hasResults ? l10n.t("audit.rerun") : l10n.t("audit.run")) {
                        Task { await audit.run() }
                    }
                    .buttonStyle(DarkButton(accent: DTColor.mac))
                    .disabled(audit.isRunning)

                    if audit.hasResults {
                        Text(l10n.t("audit.panelSize", AuditPanel.scoredCount,
                                    AuditPanel.probes.count))
                            .font(.caption2).foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .frame(width: 190)
            }
        }
    }

    // MARK: - Une famille

    private func familyCard(_ family: ProbeFamily) -> some View {
        let tally = audit.tally(family)
        let isOpen = expandedFamilies.contains(family.id)
        let ratio = tally.measured > 0 ? Double(tally.blocked) / Double(tally.measured) : 0

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.22)) {
                    if isOpen { expandedFamilies.remove(family.id) }
                    else { expandedFamilies.insert(family.id) }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: family.icon).font(.callout)
                        .foregroundStyle(DTColor.mac).frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 7) {
                            Text(family.label.current).font(.callout.weight(.medium))
                            if !family.isScored {
                                Badge(text: l10n.t("audit.notScored"), tint: .secondary)
                            }
                        }
                        Text(l10n.t("audit.blockedOf", tally.blocked, tally.measured))
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 16)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule().fill(ProtectionLevel.from(score: ratio).tint.opacity(0.85))
                                .frame(width: max(3, geo.size.width * ratio))
                                .animation(.spring(response: 0.7, dampingFraction: 0.85),
                                           value: ratio)
                        }
                    }
                    .frame(width: 130, height: 6)

                    Text("\(Int((ratio * 100).rounded())) %")
                        .font(.system(.callout, design: .monospaced).weight(.medium))
                        .foregroundStyle(ProtectionLevel.from(score: ratio).tint)
                        .frame(width: 56, alignment: .trailing)

                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: 5) {
                    ForEach(AuditPanel.probes(in: family)) { probe in
                        probeRow(probe)
                    }
                }
                .padding(.top, 11)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(DTColor.carte))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(DTColor.ligne, lineWidth: 1))
    }

    /// Une ligne de détail : le domaine, ce qu'il sert, et ce qu'il a répondu.
    private func probeRow(_ probe: AuditProbe) -> some View {
        let result = audit.result(for: probe)
        return HStack(spacing: 10) {
            Image(systemName: icon(for: result?.verdict))
                .font(.caption)
                .foregroundStyle(tint(for: result?.verdict))
                .frame(width: 16)

            Text(probe.domain)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(width: 200, alignment: .leading)

            Text(probe.role.current)
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(answerText(result))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(tint(for: result?.verdict))
                .lineLimit(1)
                .frame(width: 190, alignment: .trailing)
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.white.opacity(0.03)))
    }

    private func answerText(_ result: ProbeResult?) -> String {
        guard let result else { return "—" }
        switch result.verdict {
        case .blocked:  return l10n.t("audit.verdict.blocked") + " · " + result.answer
        case .resolved: return result.answer
        case .failed:   return l10n.t("audit.verdict.failed")
        }
    }

    private func icon(for verdict: ProbeVerdict?) -> String {
        switch verdict {
        case .blocked:  return "checkmark.circle.fill"
        case .resolved: return "arrow.right.circle"
        case .failed:   return "questionmark.circle"
        case nil:       return "circle.dotted"
        }
    }

    private func tint(for verdict: ProbeVerdict?) -> Color {
        switch verdict {
        case .blocked:  return DTColor.vert
        case .resolved: return DTColor.ambre
        case .failed:   return .secondary
        case nil:       return .secondary
        }
    }
}

/// Version compacte pour le tableau de bord.
struct AuditSummaryCard: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var l10n: L10n

    private var audit: BlockingAudit { app.audit }

    var body: some View {
        TitledCard(title: l10n.t("audit.cardTitle"),
                   subtitle: l10n.t("audit.cardSub"),
                   systemImage: "shield.checkered") {
            HStack(spacing: 16) {
                LiquidGauge(value: audit.hasResults ? audit.score : 0,
                            tint: audit.hasResults ? audit.level.tint : .secondary,
                            center: audit.hasResults ? "\(Int((audit.score * 100).rounded()))" : "—",
                            caption: l10n.t("audit.outOf"),
                            size: 84,
                            animated: audit.isRunning || audit.hasResults)

                VStack(alignment: .leading, spacing: 6) {
                    if audit.hasResults {
                        Text(audit.level.label.current)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(audit.level.tint)
                        ForEach(ProbeFamily.allCases.filter(\.isScored)) { family in
                            let t = audit.tally(family)
                            HStack(spacing: 6) {
                                Image(systemName: family.icon).font(.caption2)
                                    .foregroundStyle(.secondary).frame(width: 13)
                                Text(family.label.current).font(.caption2)
                                    .foregroundStyle(.secondary).lineLimit(1)
                                Spacer(minLength: 6)
                                Text("\(t.blocked)/\(t.measured)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text(l10n.t("audit.cardEmpty"))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if audit.isRunning {
                        ProgressView(value: audit.progress)
                            .progressViewStyle(.linear).tint(DTColor.mac)
                    } else {
                        Button(audit.hasResults ? l10n.t("audit.rerun") : l10n.t("audit.run")) {
                            Task { await audit.run() }
                        }
                        .controlSize(.small)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
