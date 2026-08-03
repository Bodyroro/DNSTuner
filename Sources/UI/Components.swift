//
//  Components.swift · DNSTuner
//
//  Système visuel commun, repris de l'identité du site bodyroro.github.io :
//  encre de nuit biaisée bleu, jamais de gris neutre, signature tricolore rare.
//

import SwiftUI
import AppKit

// MARK: - Palette du site (bodyroro.github.io) : encre de nuit + tricolore

/// Couleurs reprises de `assets/site.css`, sombre biaisé bleu, jamais gris neutre.
enum DTColor {
    static let bleu = Color(red: 0.302, green: 0.490, blue: 1.0)        // #4d7dff
    static let rouge = Color(red: 0.961, green: 0.282, blue: 0.235)     // #f5483c
    static let blanc = Color(red: 0.949, green: 0.961, blue: 0.992)     // #f2f5fd
    static let nuit = Color(red: 0.039, green: 0.055, blue: 0.102)      // #0a0e1a
    static let nuitHaute = Color(red: 0.063, green: 0.086, blue: 0.165) // #10162a
    /// Accent des apps macOS de l'écosystème.
    static let mac = Color(red: 0.557, green: 0.722, blue: 1.0)         // #8eb8ff
    /// Indigo du logo : réservé au DNS chiffré, pour que « chiffré » se voie d'un coup d'œil.
    static let indigo = Color(red: 0.427, green: 0.361, blue: 1.0)      // #6d5cff
    /// Ambre franc pour les avertissements : reste « or » sur l'encre de nuit,
    /// là où un orange translucide virerait au marron.
    static let ambre = Color(red: 1.0, green: 0.78, blue: 0.36)         // #ffc75c
    static let vert = Color(red: 0.290, green: 0.871, blue: 0.502)      // #4ade80
    static let ligne = Color(red: 0.592, green: 0.678, blue: 1.0).opacity(0.14)
    /// Fond de carte SOLIDE (bleu nuit élevé). Un matériau translucide se
    /// désature en gris-marron sur le dégradé de fond.
    static let carte = Color(red: 0.075, green: 0.098, blue: 0.176)        // #131928
    static let carteHaute = Color(red: 0.098, green: 0.125, blue: 0.212)   // #192036
    static let bouton = Color(red: 0.102, green: 0.133, blue: 0.216)       // #1a2237
    static let boutonPresse = Color(red: 0.149, green: 0.188, blue: 0.294) // #26304b

    /// Fond « encre de nuit » commun aux vues à fond libre.
    static var fond: LinearGradient {
        LinearGradient(colors: [nuitHaute, nuit], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Animations partagées

/// Apparition « montée en fondu » façon site web (`mt-item-in`) : opacité +
/// glissement, avec un délai pour les entrées en cascade.
struct RiseIn: ViewModifier {
    var delay: Double = 0
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    func riseIn(_ delay: Double = 0) -> some View { modifier(RiseIn(delay: delay)) }

    /// Cascade bornée : au-delà d'une douzaine d'entrées, le délai plafonne pour
    /// qu'une longue liste ne mette pas plusieurs secondes à finir d'apparaître.
    func riseInCascade(_ index: Int, step: Double = 0.035, cap: Double = 0.42) -> some View {
        modifier(RiseIn(delay: min(Double(index) * step, cap)))
    }
}

/// Onde de résolution : trois arcs concentriques qui pulsent, signalant qu'une
/// interrogation DNS est en cours. Repos = arcs figés, aucune animation inutile.
struct ResolvePulse: View {
    var active: Bool
    var tint: Color = DTColor.mac
    var size: CGFloat = 18

    var body: some View {
        Group {
            if active {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    arcs { i in
                        // Chaque arc pulse avec un tiers de période de décalage.
                        let phase = (t * 1.1 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                        return 0.25 + 0.75 * sin(phase * .pi)
                    }
                }
            } else {
                arcs { _ in 0.35 }
            }
        }
        .frame(width: size, height: size)
    }

    private func arcs(_ opacity: @escaping (Int) -> Double) -> some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .trim(from: 0.62, to: 0.88)
                    .stroke(tint.opacity(opacity(i)),
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .frame(width: size * (0.4 + Double(i) * 0.3),
                           height: size * (0.4 + Double(i) * 0.3))
            }
            Circle().fill(tint.opacity(0.9)).frame(width: size * 0.16, height: size * 0.16)
        }
        .rotationEffect(.degrees(-90))
    }
}

// MARK: - Signature et chrome

/// Signature tricolore du site, volontairement rare : une seule par vue.
struct TricoloreBar: View {
    var width: CGFloat = 64
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(DTColor.bleu)
            Rectangle().fill(DTColor.blanc)
            Rectangle().fill(DTColor.rouge)
        }
        .frame(width: width, height: 3)
        .clipShape(Capsule())
    }
}

/// Drapeau + nom du pays, forme compacte utilisée dans les fiches.
struct CountryTag: View {
    let country: String

    var body: some View {
        HStack(spacing: 6) {
            FlagView(country: country, height: 11)
            Text(Country.name(country).current)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(DTColor.ligne, lineWidth: 1))
        .foregroundStyle(.secondary)
    }
}

/// Bouton d'action sombre et homogène pour toute l'app. Seul le texte/l'icône
/// porte l'accent ; le fond reste sombre dans tous les états, désactivé compris.
struct DarkButton: ButtonStyle {
    var accent: Color = DTColor.mac
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(configuration.isPressed ? DTColor.boutonPresse : DTColor.bouton))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(accent.opacity(configuration.isPressed ? 0.55 : 0.30), lineWidth: 1))
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Bouton rond de la barre d'outils : un cercle plein de la hauteur de la barre,
/// avec l'icône dedans. Aucun fond d'onglet gris autour.
struct RoundToolbarButton: View {
    let icon: String
    var tint: Color = DTColor.mac
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(DTColor.bouton)
                Circle().strokeBorder(tint.opacity(0.55), lineWidth: 1.5)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 29, height: 29)
            .contentShape(Circle())
        }
        .help(help)
        .buttonStyle(.plain)
    }
}

/// Enveloppe de feuille modale : dimensionne une vue et ajoute un bouton de
/// fermeture rond au-dessus du contenu. Échap ferme aussi.
struct ModalSheet<Content: View>: View {
    @ViewBuilder let content: Content
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    ZStack {
                        Circle().fill(DTColor.bouton)
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 26, height: 26).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
            content
        }
        .frame(width: 980, height: 700)
        .background(DTColor.nuit)
    }
}

// MARK: - Gabarit commun des onglets

/// En-tête d'onglet unique pour toute l'app : icône teintée, titre, sous-titre,
/// actions à droite. Toujours suivi d'un `Divider` par l'appelant.
struct TabHeader<Trailing: View>: View {
    let icon: String
    var tint: Color = DTColor.mac
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
        .padding(12)
    }
}

/// Largeur et marge de contenu communes à tous les onglets.
enum TabLayout {
    static let maxWidth: CGFloat = 1400
    static let padding: CGFloat = 16
}

extension View {
    /// Applique le gabarit de contenu standard (marge + largeur maximale centrée).
    func tabContent() -> some View {
        self.padding(TabLayout.padding)
            .frame(maxWidth: TabLayout.maxWidth)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Cartes et lignes

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    var minHeight: CGFloat? = nil
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(padding)
            // maxHeight infini : une carte placée dans une pile horizontale
            // s'étire à la hauteur de la plus grande de la rangée.
            .frame(maxWidth: .infinity, minHeight: minHeight,
                   maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DTColor.carte))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DTColor.ligne, lineWidth: 1))
    }
}

/// Carte titrée : en-tête icône + titre + sous-titre, puis contenu.
struct TitledCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var tint: Color = DTColor.mac
    @ViewBuilder var content: Content

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    if let systemImage {
                        Image(systemName: systemImage).font(.callout).foregroundStyle(tint)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline)
                        if let subtitle {
                            Text(subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                content
            }
        }
    }
}

/// Petite étiquette colorée (catégorie bloquée, avertissement, transport…).
struct Badge: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = DTColor.mac

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1))
        .foregroundStyle(tint)
    }
}

/// Ligne « libellé → valeur » alignée, pour les fiches d'état.
struct InfoRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
        }
        .font(.callout)
    }
}

/// Rangée d'étiquettes listant les catégories bloquées par un fournisseur.
struct BlockingChips: View {
    let categories: Set<BlockCategory>
    @EnvironmentObject private var l10n: L10n

    var body: some View {
        if categories.isEmpty {
            Badge(text: l10n.t("provider.noFiltering"),
                  systemImage: "circle.dashed", tint: .secondary)
        } else {
            FlowRow(spacing: 6) {
                ForEach(BlockCategory.allCases.filter { categories.contains($0) }) { category in
                    Badge(text: category.label.current, systemImage: category.icon,
                          tint: DTColor.mac)
                }
            }
        }
    }
}

/// Anneau de progression du tableau de bord : valeur 0…1, dégradé angulaire,
/// libellé au centre. Repris du gabarit de MacTuner.
struct RingGauge: View {
    let value: Double            // 0…1
    let gradient: [Color]
    let center: String
    let sub: String
    var size: CGFloat = 112
    var icon: String? = nil

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.07), lineWidth: 11)
            Circle()
                .trim(from: 0, to: max(0.001, min(value, 1)))
                .stroke(AngularGradient(colors: gradient, center: .center),
                        style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.85), value: value)
            VStack(spacing: 2) {
                if let icon {
                    Image(systemName: icon).font(.system(size: size * 0.15))
                        .foregroundStyle(gradient.first ?? DTColor.mac)
                }
                Text(center)
                    .font(.system(size: size * 0.19, weight: .bold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .animation(.default, value: center)
                Text(sub).font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 14)
        }
        .frame(width: size, height: size)
    }
}

/// Tuile chiffrée compacte du tableau de bord : grande valeur, libellé, icône.
struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    var tint: Color = DTColor.mac

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: icon).font(.callout).foregroundStyle(tint)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit().contentTransition(.numericText())
                Text(label).font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Barre horizontale d'une catégorie : combien de résolveurs du catalogue la
/// bloquent, rapporté au total.
struct CategoryBar: View {
    let category: BlockCategory
    let count: Int
    let total: Int

    private var fraction: Double { total > 0 ? Double(count) / Double(total) : 0 }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: category.icon).font(.caption)
                .foregroundStyle(DTColor.mac).frame(width: 16)
            // Libellé court : le nom complet passait sur deux lignes et
            // désalignait toute la colonne.
            Text(category.shortLabel.current).font(.caption)
                .lineLimit(1)
                .frame(width: 82, alignment: .leading)
                .help(category.label.current)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(LinearGradient(colors: [DTColor.mac, DTColor.indigo],
                                                  startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(3, geo.size.width * fraction))
                        .animation(.spring(response: 0.7, dampingFraction: 0.85), value: fraction)
                }
            }
            .frame(height: 6)
            Text("\(count)").font(.caption.weight(.semibold)).monospacedDigit()
                .foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
        }
    }
}

/// Barre de latence : piste sombre, remplissage teinté par palier de qualité.
struct LatencyBar: View {
    /// Latence mesurée en millisecondes, `nil` si non testé.
    let ms: Double?
    /// Latence de référence pour l'échelle (le plus lent du tableau).
    var scale: Double = 120

    private var fraction: Double {
        guard let ms else { return 0 }
        return min(max(ms / max(scale, 1), 0.02), 1)
    }

    private var tint: Color {
        guard let ms else { return .secondary }
        if ms < 30 { return DTColor.vert }
        if ms < 80 { return DTColor.mac }
        return DTColor.ambre
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                Capsule().fill(tint.opacity(0.85))
                    .frame(width: max(3, geo.size.width * fraction))
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: fraction)
            }
        }
        .frame(height: 5)
    }
}

/// Pastille d'état d'une catégorie dans la matrice comparative.
struct CategoryDot: View {
    enum State { case declared, confirmed, unconfirmed, open, unknown }
    let state: State

    var body: some View {
        switch state {
        case .declared:
            Image(systemName: "circle.fill").font(.system(size: 8))
                .foregroundStyle(DTColor.mac)
        case .confirmed:
            Image(systemName: "checkmark.circle.fill").font(.callout)
                .foregroundStyle(DTColor.vert)
        case .unconfirmed:
            Image(systemName: "exclamationmark.circle.fill").font(.callout)
                .foregroundStyle(DTColor.ambre)
        case .open:
            Image(systemName: "minus").font(.caption)
                .foregroundStyle(.white.opacity(0.18))
        case .unknown:
            Image(systemName: "minus").font(.caption)
                .foregroundStyle(.white.opacity(0.18))
        }
    }
}

/// Disposition en lignes qui passe à la ligne quand la largeur manque.
/// SwiftUI n'offre pas de flow layout natif : celui-ci reste minimal et suffit
/// aux rangées d'étiquettes.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Sélecteur de langue

/// Choix de langue : deux pastilles drapeau + nom, la sélection remplie en accent.
struct LanguagePicker: View {
    @ObservedObject var loc: L10n
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Lang.allCases) { l in
                let selected = loc.lang == l
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { loc.set(l) }
                } label: {
                    HStack(spacing: 7) {
                        FlagView(country: l == .fr ? "FR" : "GB", height: 13)
                        Text(l.displayName).font(.callout.weight(.medium))
                        if selected {
                            Image(systemName: "checkmark.circle.fill").font(.caption)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .frame(minWidth: 128)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selected ? DTColor.mac : Color.white.opacity(0.06))
                    )
                    .foregroundStyle(selected ? DTColor.nuit : Color.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selected ? Color.clear : DTColor.ligne, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Bandeau d'état permanent

/// Bandeau affiché en haut de tous les onglets : ce que le système résout
/// vraiment, et le retour arrière toujours à portée de clic.
struct StatusBanner: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var l10n: L10n

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(app.statusTint.opacity(0.14)).frame(width: 34, height: 34)
                Circle().strokeBorder(app.statusTint.opacity(0.35), lineWidth: 1)
                    .frame(width: 34, height: 34)
                Image(systemName: app.statusIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(app.statusTint)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: app.statusIcon)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.statusTitle).font(.callout.weight(.medium))
                    .contentTransition(.opacity)
                Text(app.statusDetail).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer()

            if app.engine.busy { ProgressView().controlSize(.small) }

            Button(l10n.t("action.restore")) { app.restore() }
                .buttonStyle(DarkButton(accent: DTColor.ambre))
                .disabled(app.engine.busy || !app.canRestore)
                .opacity(app.canRestore ? 1 : 0.45)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(DTColor.nuitHaute)
        .overlay(alignment: .bottom) { Rectangle().fill(DTColor.ligne).frame(height: 1) }
    }
}
