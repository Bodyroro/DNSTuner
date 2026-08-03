//
//  SettingsView.swift · Langue, résolveur personnalisé, limites du filtrage DNS
//
//  Ouverte en feuille modale depuis l'icône ronde de la barre d'outils.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var l10n: L10n

    @State private var customName = Store.customName
    @State private var customIPs = Store.customIPs
    @State private var customDoH = Store.customDoH
    @State private var saved = false

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(icon: "gearshape.fill",
                      title: l10n.t("tab.settings"),
                      subtitle: l10n.t("tab.settings.sub")) { EmptyView() }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    languageCard.riseIn(0)
                    customCard.riseIn(0.06)
                    limitsCard.riseIn(0.12)
                    aboutCard.riseIn(0.18)
                }
                .tabContent()
            }
        }
        .background(DTColor.fond.ignoresSafeArea())
    }

    private var languageCard: some View {
        TitledCard(title: l10n.t("settings.language"), systemImage: "globe") {
            LanguagePicker(loc: l10n)
        }
    }

    private var customCard: some View {
        TitledCard(title: l10n.t("settings.customTitle"),
                   subtitle: l10n.t("settings.customSubtitle"),
                   systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 9) {
                field(l10n.t("settings.customName"), text: $customName, mono: false)
                field(l10n.t("settings.customIPs"), text: $customIPs, mono: true)
                field(l10n.t("settings.customDoH"), text: $customDoH, mono: true)
                Text(l10n.t("settings.customHint")).font(.caption).foregroundStyle(.secondary)

                if !invalidAddresses.isEmpty {
                    Label(l10n.t("settings.customInvalid",
                                 invalidAddresses.joined(separator: ", ")),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(DTColor.ambre)
                        .transition(.opacity)
                }

                HStack(spacing: 10) {
                    Button(l10n.t("action.save")) { saveCustom() }
                        .disabled(!invalidAddresses.isEmpty)
                    if saved {
                        Badge(text: l10n.t("settings.saved"),
                              systemImage: "checkmark.circle.fill", tint: DTColor.vert)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
            }
            .animation(.easeOut(duration: 0.2), value: invalidAddresses.count)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: saved)
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, mono: Bool) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(mono ? .system(.callout, design: .monospaced) : .callout)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(DTColor.ligne, lineWidth: 1))
    }

    /// Adresses saisies qui ne sont ni IPv4 ni IPv6 valides : les écrire dans
    /// `networksetup` couperait la résolution DNS de la machine.
    private var invalidAddresses: [String] {
        customIPs
            .components(separatedBy: CharacterSet(charactersIn: ", \n\t"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !IPAddress.isValid($0) }
    }

    private func saveCustom() {
        Store.customName = customName
        Store.customIPs = customIPs
        Store.customDoH = customDoH
        app.refresh()
        Journal.shared.log(.info, l10n.t("journal.customSaved"))
        saved = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            saved = false
        }
    }

    /// Section volontairement présente dans l'app, et pas seulement dans la doc :
    /// un utilisateur qui croit tout bloqué par le DNS se trompe de modèle mental.
    private var limitsCard: some View {
        TitledCard(title: l10n.t("settings.limitsTitle"),
                   subtitle: l10n.t("settings.limitsSubtitle"),
                   systemImage: "exclamationmark.triangle", tint: DTColor.ambre) {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array((1...5).enumerated()), id: \.offset) { i, n in
                    HStack(alignment: .top, spacing: 9) {
                        Text("\(n)")
                            .font(.caption2.weight(.bold)).monospacedDigit()
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(DTColor.ambre.opacity(0.16)))
                            .foregroundStyle(DTColor.ambre)
                        Text(l10n.t("limits.\(n)")).font(.callout)
                        Spacer(minLength: 0)
                    }
                    .riseInCascade(i)
                }
            }
        }
    }

    private var aboutCard: some View {
        TitledCard(title: l10n.t("settings.about"), systemImage: "info.circle") {
            VStack(spacing: 7) {
                InfoRow(label: l10n.t("settings.version"),
                        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                InfoRow(label: l10n.t("settings.catalogVerified"),
                        value: ProviderCatalog.verificationDate)
                InfoRow(label: l10n.t("settings.providerCount"),
                        value: "\(ProviderCatalog.all.count)")
                Divider().overlay(DTColor.ligne)
                HStack {
                    TricoloreBar(width: 44)
                    Spacer()
                    Link(destination: URL(string: "https://bodyroro.github.io/dnstuner.html")!) {
                        HStack(spacing: 4) {
                            Text("bodyroro.github.io")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption)
                        .foregroundStyle(DTColor.mac)
                    }
                }
            }
        }
    }
}
