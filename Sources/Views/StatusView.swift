//
//  StatusView.swift · Ce que le système utilise réellement, ici et maintenant
//

import SwiftUI

struct StatusView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var l10n: L10n

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(icon: "waveform.path.ecg",
                      title: l10n.t("tab.status"),
                      subtitle: l10n.t("tab.status.sub")) {
                Button(l10n.t("action.refresh")) {
                    withAnimation(.easeOut(duration: 0.25)) { app.refresh() }
                }
                .disabled(app.engine.busy)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    activeCard.riseIn(0)
                    servicesCard.riseIn(0.06)
                    profileCard.riseIn(0.12)
                    actionsCard.riseIn(0.18)
                }
                .tabContent()
            }
        }
        .background(DTColor.fond.ignoresSafeArea())
        .onAppear { app.refresh() }
    }

    /// `scutil --dns` est la vérité terrain : il reflète le DNS effectivement
    /// utilisé, y compris celui poussé par un profil chiffré ou par le routeur.
    private var activeCard: some View {
        TitledCard(title: l10n.t("status.activeTitle"),
                   subtitle: l10n.t("status.activeSubtitle"),
                   systemImage: "waveform.path.ecg") {
            VStack(spacing: 8) {
                if app.engine.activeResolvers.isEmpty {
                    Text(l10n.t("status.noResolver")).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(app.engine.activeResolvers.enumerated()), id: \.offset) { i, r in
                        HStack(spacing: 9) {
                            ResolvePulse(active: false, tint: DTColor.mac, size: 14)
                            Text("nameserver[\(i)]").foregroundStyle(.secondary).font(.callout)
                            Spacer(minLength: 12)
                            Text(r).font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .riseInCascade(i)
                    }
                }
                Divider().overlay(DTColor.ligne)
                HStack {
                    Image(systemName: app.isEncrypted ? "lock.fill" : "lock.open")
                        .foregroundStyle(app.isEncrypted ? DTColor.indigo : .secondary)
                    Text(l10n.t("status.encryption")).foregroundStyle(.secondary)
                    Spacer()
                    Badge(text: app.isEncrypted ? l10n.t("status.encryptionOn")
                                                : l10n.t("status.encryptionOff"),
                          systemImage: app.isEncrypted ? "checkmark.shield.fill" : "exclamationmark.shield",
                          tint: app.isEncrypted ? DTColor.indigo : DTColor.ambre)
                }
                .font(.callout)
            }
        }
    }

    private var servicesCard: some View {
        TitledCard(title: l10n.t("status.servicesTitle"),
                   subtitle: l10n.t("status.servicesSubtitle"),
                   systemImage: "network") {
            VStack(spacing: 9) {
                ForEach(Array(app.engine.services.enumerated()), id: \.element.id) { i, service in
                    let dns = app.engine.declaredDNS[service.name] ?? []
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(service.isUp ? DTColor.vert : Color.white.opacity(0.18))
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)
                            .shadow(color: service.isUp ? DTColor.vert.opacity(0.7) : .clear,
                                    radius: 4)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(service.name).font(.callout.weight(.medium))
                                if !service.device.isEmpty {
                                    Text(service.device).font(.caption2)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Capsule().fill(Color.white.opacity(0.06)))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            // Chasse fixe pour les adresses seulement : une
                            // phrase en monospace se lit mal et jure avec le reste.
                            if dns.isEmpty {
                                Text(l10n.t("status.fromRouter"))
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text(dns.joined(separator: ", "))
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                        Spacer()
                    }
                    .riseInCascade(i)
                }
                if app.engine.services.isEmpty {
                    Text(l10n.t("status.noService")).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var profileCard: some View {
        TitledCard(title: l10n.t("status.profileTitle"),
                   subtitle: l10n.t("status.profileSubtitle"),
                   systemImage: "lock.shield", tint: DTColor.indigo) {
            VStack(alignment: .leading, spacing: 8) {
                if app.profiles.installed.isEmpty {
                    Text(l10n.t("status.noProfile")).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(app.profiles.installed.sorted().enumerated()), id: \.element) { i, id in
                        HStack {
                            Image(systemName: "lock.fill").font(.caption)
                                .foregroundStyle(DTColor.indigo)
                            Text(id).font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            Button(l10n.t("action.remove")) { app.removeProfile(id) }
                                .buttonStyle(DarkButton(accent: DTColor.rouge))
                                .controlSize(.small)
                        }
                        .riseInCascade(i)
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        TitledCard(title: l10n.t("status.actionsTitle"),
                   systemImage: "wrench.and.screwdriver") {
            HStack(spacing: 10) {
                Button(l10n.t("action.flush")) { _ = app.engine.flushCache() }
                Button(l10n.t("action.restore")) { app.restore() }
                    .buttonStyle(DarkButton(accent: DTColor.ambre))
                    .disabled(!app.canRestore)
                Spacer()
            }
            .disabled(app.engine.busy)
        }
    }
}
