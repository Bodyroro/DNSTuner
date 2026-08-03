//
//  JournalView.swift · Historique des actions
//

import SwiftUI

struct JournalView: View {
    @EnvironmentObject private var l10n: L10n
    @ObservedObject private var journal = Journal.shared

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(icon: "text.alignleft",
                      title: l10n.t("tab.journal"),
                      subtitle: l10n.t("tab.journal.sub")) {
                Button(l10n.t("action.clearLog")) {
                    withAnimation(.easeOut(duration: 0.25)) { journal.clear() }
                }
                .buttonStyle(DarkButton(accent: DTColor.rouge))
                .disabled(journal.entries.isEmpty)
            }
            Divider()
            if journal.entries.isEmpty {
                ContentUnavailableView(l10n.t("journal.empty"), systemImage: "text.alignleft")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(journal.entries.enumerated()), id: \.element.id) { i, entry in
                            entryRow(entry).riseInCascade(i)
                        }
                    }
                    .tabContent()
                }
            }
        }
        .background(DTColor.fond.ignoresSafeArea())
    }

    private func entryRow(_ entry: JournalEntry) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                Circle().fill(tint(entry.kind).opacity(0.14)).frame(width: 26, height: 26)
                Image(systemName: entry.icon).font(.caption)
                    .foregroundStyle(tint(entry.kind))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message).font(.callout).textSelection(.enabled)
                Text(Self.formatter.string(from: entry.date))
                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(DTColor.carte))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(DTColor.ligne, lineWidth: 1))
    }

    private func tint(_ kind: JournalEntry.Kind) -> Color {
        switch kind {
        case .info:    return DTColor.mac
        case .success: return DTColor.vert
        case .failure: return DTColor.rouge
        }
    }
}
