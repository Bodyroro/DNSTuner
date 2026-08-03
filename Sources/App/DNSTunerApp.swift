//
//  DNSTunerApp.swift · DNSTuner
//

import SwiftUI
import AppKit

// MARK: - Racine

struct ContentView: View {
    @StateObject private var app = AppModel()
    @EnvironmentObject private var loc: L10n

    var body: some View {
        VStack(spacing: 0) {
            StatusBanner()
            TabView(selection: $app.tab) {
                DashboardView()
                    .tabItem { Label(AppTab.dashboard.label.current,
                                     systemImage: AppTab.dashboard.icon) }
                    .tag(AppTab.dashboard)
                ProvidersView()
                    .tabItem { Label(AppTab.providers.label.current,
                                     systemImage: AppTab.providers.icon) }
                    .tag(AppTab.providers)
                StatusView()
                    .tabItem { Label(AppTab.status.label.current,
                                     systemImage: AppTab.status.icon) }
                    .tag(AppTab.status)
                CompareView()
                    .tabItem { Label(AppTab.compare.label.current,
                                     systemImage: AppTab.compare.icon) }
                    .tag(AppTab.compare)
                TestView()
                    .tabItem { Label(AppTab.test.label.current,
                                     systemImage: AppTab.test.icon) }
                    .tag(AppTab.test)
                DiagnosticView()
                    .tabItem { Label(AppTab.diagnostic.label.current,
                                     systemImage: AppTab.diagnostic.icon) }
                    .tag(AppTab.diagnostic)
                JournalView()
                    .tabItem { Label(AppTab.journal.label.current,
                                     systemImage: AppTab.journal.icon) }
                    .tag(AppTab.journal)
            }
        }
        .environmentObject(app)
        .frame(minWidth: 1180, minHeight: 720)
        .buttonStyle(DarkButton())
        // Encre de nuit derrière la bande d'onglets et les en-têtes : sans ça,
        // ces zones affichent le gris système.
        .background(DTColor.nuit.ignoresSafeArea())
        .toolbarBackground(DTColor.nuit, for: .windowToolbar)
        .navigationTitle("DNSTuner")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                RoundToolbarButton(icon: app.isEncrypted ? "lock.fill" : "lock.open",
                                   tint: app.isEncrypted ? DTColor.indigo : .secondary,
                                   help: loc.t("toolbar.encryption")) {
                    app.tab = .status
                }
                RoundToolbarButton(icon: "gearshape.fill", tint: DTColor.mac,
                                   help: loc.t("toolbar.settings")) {
                    app.showSettings = true
                }
            }
        }
        .sheet(isPresented: $app.showSettings) {
            ModalSheet {
                SettingsView()
                    .environmentObject(app)
                    .environmentObject(loc)
            } onClose: {
                app.showSettings = false
            }
            .buttonStyle(DarkButton())
        }
        .alert(loc.t("alert.title"),
               isPresented: Binding(get: { app.alert != nil },
                                    set: { if !$0 { app.alert = nil } })) {
            Button("OK", role: .cancel) { app.alert = nil }
        } message: {
            Text(app.alert ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            // Un profil peut avoir été validé ou retiré depuis Réglages Système
            // pendant que l'app était en arrière-plan.
            app.refresh()
        }
    }
}

// MARK: - Application

@main
struct DNSTunerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(L10n.shared)
                // Identité visuelle du site : encre de nuit, sombre en permanence.
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1280, height: 820)
        .windowResizability(.contentMinSize)
    }
}
