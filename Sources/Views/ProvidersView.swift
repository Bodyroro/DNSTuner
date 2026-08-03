//
//  ProvidersView.swift · Catalogue et application d'un fournisseur
//

import SwiftUI

struct ProvidersView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var l10n: L10n

    @State private var search = ""
    @State private var requiredCategories: Set<BlockCategory> = []
    @State private var favoritesOnly = false

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(icon: "list.bullet.rectangle",
                      title: l10n.t("tab.providers"),
                      subtitle: l10n.t("tab.providers.sub")) {
                Text(l10n.t("providers.count", visibleCount))
                    .font(.caption).foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: visibleCount)
            }
            Divider()
            HSplitView {
                listPane.frame(minWidth: 300, idealWidth: 340, maxWidth: 430)
                detailPane.frame(minWidth: 430)
            }
        }
        .background(DTColor.fond.ignoresSafeArea())
    }

    private var visibleCount: Int {
        filteredByVendor.reduce(0) { $0 + $1.providers.count }
    }

    // MARK: - Liste

    private var listPane: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if let custom = Store.customProvider(), matches(custom) {
                        sectionTitle(l10n.t("providers.customSection"))
                        row(custom, index: 0)
                    }
                    ForEach(Array(filteredByVendor.enumerated()), id: \.element.vendor) { gi, group in
                        sectionTitle(group.vendor).riseInCascade(gi)
                        ForEach(Array(group.providers.enumerated()), id: \.element.id) { i, provider in
                            row(provider, index: gi * 2 + i)
                        }
                    }
                    if visibleCount == 0 {
                        Text(l10n.t("providers.noMatch"))
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    }
                }
                .padding(12)
            }
        }
        .background(DTColor.nuit)
    }

    private func sectionTitle(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .kerning(0.8)
            Rectangle().fill(DTColor.ligne).frame(height: 1)
        }
        .padding(.top, 6)
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.callout)
                TextField(l10n.t("providers.search"), text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { search = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(DTColor.ligne, lineWidth: 1))

            FlowRow(spacing: 6) {
                filterChip(l10n.t("providers.favorites"), icon: "star.fill",
                           tint: DTColor.ambre, isOn: favoritesOnly) {
                    withAnimation(.easeOut(duration: 0.2)) { favoritesOnly.toggle() }
                }
                ForEach(BlockCategory.allCases) { category in
                    filterChip(category.label.current, icon: category.icon,
                               tint: DTColor.mac,
                               isOn: requiredCategories.contains(category)) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if requiredCategories.contains(category) {
                                requiredCategories.remove(category)
                            } else {
                                requiredCategories.insert(category)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(DTColor.nuitHaute)
    }

    private func filterChip(_ text: String, icon: String, tint: Color,
                            isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(text)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(isOn ? tint.opacity(0.22) : Color.white.opacity(0.05)))
            .overlay(Capsule().strokeBorder(isOn ? tint.opacity(0.6) : DTColor.ligne, lineWidth: 1))
            .foregroundStyle(isOn ? tint : Color.secondary)
        }
        .buttonStyle(.plain)
        .help(l10n.t("providers.filterHelp"))
    }

    private func row(_ provider: DNSProvider, index: Int) -> some View {
        let selected = app.selectedProviderID == provider.id
        let applied = app.engine.appliedProvider == provider

        return Button {
            withAnimation(.easeOut(duration: 0.18)) { app.selectedProviderID = provider.id }
        } label: {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(selected ? DTColor.mac : Color.clear)
                    .frame(width: 2.5)
                    .clipShape(Capsule())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        FlagView(country: provider.country, height: 11)
                        Text(provider.variant.current)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)
                        if Store.favorites.contains(provider.id) {
                            Image(systemName: "star.fill").font(.system(size: 9))
                                .foregroundStyle(DTColor.ambre)
                        }
                        if !provider.isVerified {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9)).foregroundStyle(DTColor.ambre)
                                .help(l10n.t("provider.unverified"))
                        }
                        if applied {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10)).foregroundStyle(DTColor.vert)
                        }
                    }
                    HStack(spacing: 5) {
                        if provider.blocks.isEmpty {
                            Text(l10n.t("provider.noFiltering"))
                                .font(.caption2).foregroundStyle(.secondary)
                        } else {
                            ForEach(BlockCategory.allCases.filter { provider.blocks.contains($0) }) { c in
                                Image(systemName: c.icon)
                                    .font(.system(size: 9))
                                    .foregroundStyle(DTColor.mac.opacity(0.75))
                                    .help(c.label.current)
                            }
                        }
                        Spacer(minLength: 0)
                        // Un seul repère de transport dans la liste : le détail
                        // des trois protocoles appartient à la fiche, pas ici.
                        if provider.doh != nil || provider.dot != nil {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(DTColor.indigo)
                                .help(l10n.t("providers.encryptedAvailable"))
                        }
                    }
                }
                .padding(.vertical, 8).padding(.trailing, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? DTColor.carteHaute : DTColor.carte.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selected ? DTColor.mac.opacity(0.45) : DTColor.ligne, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .riseInCascade(index)
    }

    private var filteredByVendor: [(vendor: String, providers: [DNSProvider])] {
        ProviderCatalog.byVendor.compactMap { group in
            let kept = group.providers.filter(matches)
            return kept.isEmpty ? nil : (group.vendor, kept)
        }
    }

    private func matches(_ provider: DNSProvider) -> Bool {
        if favoritesOnly, !Store.favorites.contains(provider.id) { return false }
        if !requiredCategories.isSubset(of: provider.blocks) { return false }
        guard !search.isEmpty else { return true }
        let haystack = [provider.vendor, provider.variant.current, provider.summary.current,
                        provider.doh ?? "", provider.dot ?? ""] + provider.plainAddresses
        return haystack.contains { $0.localizedCaseInsensitiveContains(search) }
    }

    // MARK: - Détail

    @ViewBuilder
    private var detailPane: some View {
        if let provider = app.selectedProvider {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(provider).riseIn(0)
                    if !provider.isVerified { unverifiedWarning.riseIn(0.04) }
                    addressesCard(provider).riseIn(0.08)
                    applyCard(provider).riseIn(0.12)
                    encryptedCard(provider).riseIn(0.16)
                }
                .tabContent()
            }
            .id(provider.id)   // relance la cascade à chaque changement de fournisseur
        } else {
            ContentUnavailableView(l10n.t("providers.empty"),
                                   systemImage: "questionmark.folder")
        }
    }

    private func header(_ provider: DNSProvider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                FlagView(country: provider.country, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.vendor).font(.title2.weight(.semibold))
                    Text(provider.variant.current).font(.title3).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        Store.toggleFavorite(provider.id)
                        app.objectWillChange.send()
                    }
                } label: {
                    Image(systemName: Store.favorites.contains(provider.id) ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(Store.favorites.contains(provider.id)
                                         ? DTColor.ambre : Color.secondary)
                        .scaleEffect(Store.favorites.contains(provider.id) ? 1.1 : 1)
                }
                .buttonStyle(.plain)
                .help(l10n.t("providers.favoriteToggle"))
            }
            Text(provider.summary.current).foregroundStyle(.secondary)
            BlockingChips(categories: provider.blocks)
            FlowRow(spacing: 6) {
                if !provider.country.isEmpty { CountryTag(country: provider.country) }
                if provider.dnssec {
                    Badge(text: "DNSSEC", systemImage: "checkmark.seal", tint: DTColor.vert)
                }
                if provider.noLog {
                    Badge(text: l10n.t("provider.noLog"), systemImage: "nosign", tint: DTColor.vert)
                }
            }
            if !provider.homepage.isEmpty, let url = URL(string: provider.homepage) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text(l10n.t("provider.officialDoc"))
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.callout)
                    .foregroundStyle(DTColor.mac)
                }
            }
        }
    }

    private var unverifiedWarning: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(DTColor.ambre)
            Text(l10n.t("provider.unverifiedDetail")).font(.callout)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(DTColor.ambre.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(DTColor.ambre.opacity(0.30), lineWidth: 1))
    }

    private func addressesCard(_ provider: DNSProvider) -> some View {
        TitledCard(title: l10n.t("provider.addresses"), systemImage: "number") {
            VStack(spacing: 7) {
                if !provider.ipv4.isEmpty {
                    InfoRow(label: "IPv4", value: provider.ipv4.joined(separator: "\n"),
                            monospaced: true)
                }
                if !provider.ipv6.isEmpty {
                    InfoRow(label: "IPv6", value: provider.ipv6.joined(separator: "\n"),
                            monospaced: true)
                }
                if let doh = provider.doh { InfoRow(label: "DoH", value: doh, monospaced: true) }
                if let dot = provider.dot {
                    InfoRow(label: "DoT", value: "tls://\(dot)", monospaced: true)
                }
                if provider.plainAddresses.isEmpty {
                    Text(l10n.t("provider.encryptedOnly"))
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func applyCard(_ provider: DNSProvider) -> some View {
        TitledCard(title: l10n.t("apply.title"),
                   subtitle: l10n.t("apply.subtitle"),
                   systemImage: "lock.open") {
            VStack(alignment: .leading, spacing: 10) {
                if provider.plainAddresses.isEmpty {
                    Text(l10n.t("apply.unavailable")).font(.callout).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        Button(l10n.t("action.apply")) { app.apply(provider) }
                            .disabled(app.engine.busy)
                        if app.engine.appliedProvider == provider {
                            Badge(text: l10n.t("apply.active"),
                                  systemImage: "checkmark.circle.fill", tint: DTColor.vert)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Spacer()
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8),
                               value: app.engine.appliedProvider)
                    Text(l10n.t("apply.services",
                                app.engine.services.map(\.name).joined(separator: ", ")))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func encryptedCard(_ provider: DNSProvider) -> some View {
        TitledCard(title: l10n.t("encrypted.title"),
                   subtitle: l10n.t("encrypted.subtitle"),
                   systemImage: "lock.shield", tint: DTColor.indigo) {
            VStack(alignment: .leading, spacing: 10) {
                transportRow(provider, .https)
                Divider().overlay(DTColor.ligne)
                transportRow(provider, .tls)
                if let pending = app.profiles.awaitingApproval,
                   pending.hasPrefix("\(ProfileBuilder.identifierPrefix).\(provider.id).") {
                    pendingApproval.transition(.opacity.combined(with: .move(edge: .top)))
                }
                Text(l10n.t("encrypted.note")).font(.caption).foregroundStyle(.secondary)
            }
            .animation(.easeOut(duration: 0.25), value: app.profiles.awaitingApproval)
        }
    }

    @ViewBuilder
    private func transportRow(_ provider: DNSProvider, _ transport: DNSTransport) -> some View {
        let available = transport == .https ? provider.doh != nil : provider.dot != nil
        let identifier = ProfileBuilder.identifier(for: provider, transport: transport)
        let installed = app.profiles.installed.contains(identifier)

        HStack(spacing: 10) {
            Image(systemName: transport.icon)
                .foregroundStyle(installed ? DTColor.indigo : .secondary)
                .frame(width: 18)
            Text(transport.label.current).font(.callout)
            Spacer()
            if installed {
                Badge(text: l10n.t("encrypted.installed"),
                      systemImage: "checkmark.circle.fill", tint: DTColor.vert)
                Button(l10n.t("action.disable")) { app.removeProfile(identifier) }
                    .buttonStyle(DarkButton(accent: DTColor.rouge))
            } else {
                Button(l10n.t("action.install")) { app.install(provider, transport: transport) }
                    .buttonStyle(DarkButton(accent: DTColor.indigo))
                    .disabled(!available)
                    .opacity(available ? 1 : 0.4)
            }
        }
    }

    private var pendingApproval: some View {
        HStack(spacing: 10) {
            ResolvePulse(active: true, tint: DTColor.indigo, size: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t("encrypted.pending")).font(.callout.weight(.medium))
                Text(l10n.t("encrypted.pendingHint")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(l10n.t("action.openSettings")) { app.profiles.openDeviceManagementSettings() }
            Button(l10n.t("action.cancel")) { app.profiles.cancelPending() }
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(DTColor.indigo.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(DTColor.indigo.opacity(0.35), lineWidth: 1))
    }
}
