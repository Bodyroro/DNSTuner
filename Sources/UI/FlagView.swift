//
//  FlagView.swift · Drapeaux dessinés, en rectangle net
//
//  L'emoji drapeau d'Apple est un dessin ondulant avec ombre et coins arrondis :
//  à petite taille il bavait et jurait avec le reste de l'interface. Ces drapeaux
//  sont donc tracés à la main, en rectangle plein, sans bordure — même ratio 3:2
//  pour tous, parce qu'il s'agit d'un jeu d'icônes, pas d'une planche héraldique.
//

import SwiftUI

/// Composition d'un drapeau, réduite à ce qui reste lisible à 20 pixels de haut.
enum FlagDesign {
    /// Bandes du guindant vers le battant (France, Italie…).
    case vertical([Color])
    /// Bandes du haut vers le bas (Allemagne, Autriche, Russie…).
    case horizontal([Color])
    /// Croix grecque centrée (Suisse).
    case centeredCross(field: Color, cross: Color)
    /// Croix scandinave, décalée vers le guindant (Danemark, Suède).
    case nordicCross(field: Color, cross: Color)
    /// Bandes horizontales et canton chargé (États-Unis).
    case unitedStates
    /// Champ uni et couronne d'étoiles (Union européenne).
    case europeanUnion
    /// Bandes et canton à croix (Grèce).
    case greece
    /// Deux bandes et coin triangulaire (Tchéquie).
    case czechia
    /// Champ blanc et charge centrale (Chypre).
    case cyprus
    /// Bandes verticales et charge centrale (Canada).
    case canada
    /// Croix droite et croix de Saint-André (Royaume-Uni).
    case unitedKingdom
}

private func hex(_ value: UInt32) -> Color {
    Color(red: Double((value >> 16) & 0xFF) / 255,
          green: Double((value >> 8) & 0xFF) / 255,
          blue: Double(value & 0xFF) / 255)
}

extension Country {
    /// Composition du drapeau d'un pays. Tout code inconnu retombe sur les
    /// couleurs de l'app plutôt que sur un rectangle vide.
    static func design(_ code: String) -> FlagDesign {
        switch code {
        case "FR": return .vertical([hex(0x002395), .white, hex(0xED2939)])
        case "DE": return .horizontal([.black, hex(0xDD0000), hex(0xFFCE00)])
        case "AT": return .horizontal([hex(0xED2939), .white, hex(0xED2939)])
        case "RU": return .horizontal([.white, hex(0x0039A6), hex(0xD52B1E)])
        case "CH": return .centeredCross(field: hex(0xD52B1E), cross: .white)
        case "DK": return .nordicCross(field: hex(0xC8102E), cross: .white)
        case "SE": return .nordicCross(field: hex(0x006AA7), cross: hex(0xFECC00))
        case "US": return .unitedStates
        case "EU": return .europeanUnion
        case "GR": return .greece
        case "CZ": return .czechia
        case "CY": return .cyprus
        case "CA": return .canada
        case "GB": return .unitedKingdom
        default:   return .vertical([hex(0x4D7DFF), hex(0xF2F5FD), hex(0xF5483C)])
        }
    }
}

/// Drapeau du pays d'un résolveur : rectangle plein, sans bordure ni ombre.
struct FlagView: View {
    let country: String
    var height: CGFloat = 26

    private var width: CGFloat { height * 1.5 }   // ratio 3:2, commun à tous

    var body: some View {
        Group {
            if country.isEmpty {
                // Juridiction inconnue (résolveur personnalisé) : un aplat neutre.
                // Y mettre les couleurs de l'app ferait croire à un drapeau français.
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(Image(systemName: "questionmark")
                        .font(.system(size: height * 0.55, weight: .semibold))
                        .foregroundStyle(.secondary))
            } else {
                Canvas { context, size in
                    draw(Country.design(country), in: CGRect(origin: .zero, size: size),
                         context: &context)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            }
        }
        .frame(width: width, height: height)
        .accessibilityLabel(country.isEmpty ? "" : Country.name(country).current)
        .help(country.isEmpty ? "" : Country.name(country).current)
    }

    private func draw(_ design: FlagDesign, in rect: CGRect,
                      context: inout GraphicsContext) {
        switch design {
        case .vertical(let colors):
            let w = rect.width / CGFloat(colors.count)
            for (i, color) in colors.enumerated() {
                context.fill(Path(CGRect(x: CGFloat(i) * w, y: 0,
                                         width: w + 0.5, height: rect.height)),
                             with: .color(color))
            }

        case .horizontal(let colors):
            let h = rect.height / CGFloat(colors.count)
            for (i, color) in colors.enumerated() {
                context.fill(Path(CGRect(x: 0, y: CGFloat(i) * h,
                                         width: rect.width, height: h + 0.5)),
                             with: .color(color))
            }

        case .centeredCross(let field, let cross):
            context.fill(Path(rect), with: .color(field))
            let arm = rect.height * 0.20
            let length = rect.height * 0.66
            context.fill(Path(CGRect(x: rect.midX - length / 2, y: rect.midY - arm / 2,
                                     width: length, height: arm)), with: .color(cross))
            context.fill(Path(CGRect(x: rect.midX - arm / 2, y: rect.midY - length / 2,
                                     width: arm, height: length)), with: .color(cross))

        case .nordicCross(let field, let cross):
            context.fill(Path(rect), with: .color(field))
            let arm = rect.height * 0.22
            let x = rect.width * 0.34               // croix décalée vers le guindant
            context.fill(Path(CGRect(x: 0, y: rect.midY - arm / 2,
                                     width: rect.width, height: arm)), with: .color(cross))
            context.fill(Path(CGRect(x: x - arm / 2, y: 0,
                                     width: arm, height: rect.height)), with: .color(cross))

        case .unitedStates:
            let red = hex(0xB22234), blue = hex(0x3C3B6E)
            context.fill(Path(rect), with: .color(.white))
            let stripe = rect.height / 13
            for i in stride(from: 0, to: 13, by: 2) {
                context.fill(Path(CGRect(x: 0, y: CGFloat(i) * stripe,
                                         width: rect.width, height: stripe + 0.4)),
                             with: .color(red))
            }
            context.fill(Path(CGRect(x: 0, y: 0,
                                     width: rect.width * 0.42, height: stripe * 7)),
                         with: .color(blue))
            // Étoiles suggérées par une grille de points : à cette taille, des
            // étoiles dessinées formeraient une bouillie.
            let dot = max(0.7, rect.height * 0.045)
            for row in 0..<4 {
                for col in 0..<5 {
                    let cx = rect.width * 0.42 * (CGFloat(col) + 0.75) / 5.2
                    let cy = stripe * 7 * (CGFloat(row) + 0.75) / 4.2
                    context.fill(Path(ellipseIn: CGRect(x: cx, y: cy,
                                                        width: dot, height: dot)),
                                 with: .color(.white))
                }
            }

        case .europeanUnion:
            context.fill(Path(rect), with: .color(hex(0x003399)))
            let radius = rect.height * 0.28
            let star = max(0.9, rect.height * 0.055)
            for i in 0..<12 {
                let angle = Double(i) / 12 * 2 * .pi - .pi / 2
                let cx = rect.midX + CGFloat(cos(angle)) * radius - star / 2
                let cy = rect.midY + CGFloat(sin(angle)) * radius - star / 2
                context.fill(Path(ellipseIn: CGRect(x: cx, y: cy, width: star, height: star)),
                             with: .color(hex(0xFFCC00)))
            }

        case .greece:
            let blue = hex(0x0D5EAF)
            context.fill(Path(rect), with: .color(.white))
            let stripe = rect.height / 9
            for i in stride(from: 0, to: 9, by: 2) {
                context.fill(Path(CGRect(x: 0, y: CGFloat(i) * stripe,
                                         width: rect.width, height: stripe + 0.4)),
                             with: .color(blue))
            }
            let canton = stripe * 5
            context.fill(Path(CGRect(x: 0, y: 0, width: canton, height: canton)),
                         with: .color(blue))
            let arm = canton * 0.22
            context.fill(Path(CGRect(x: 0, y: canton / 2 - arm / 2,
                                     width: canton, height: arm)), with: .color(.white))
            context.fill(Path(CGRect(x: canton / 2 - arm / 2, y: 0,
                                     width: arm, height: canton)), with: .color(.white))

        case .czechia:
            context.fill(Path(CGRect(x: 0, y: 0, width: rect.width, height: rect.midY)),
                         with: .color(.white))
            context.fill(Path(CGRect(x: 0, y: rect.midY,
                                     width: rect.width, height: rect.height - rect.midY)),
                         with: .color(hex(0xD7141A)))
            var triangle = Path()
            triangle.move(to: .zero)
            triangle.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.midY))
            triangle.addLine(to: CGPoint(x: 0, y: rect.height))
            triangle.closeSubpath()
            context.fill(triangle, with: .color(hex(0x11457E)))

        case .cyprus:
            context.fill(Path(rect), with: .color(.white))
            // Silhouette de l'île : un quadrilatère effilé vers l'est, plus
            // reconnaissable qu'un ovale et encore lisible à douze pixels.
            var island = Path()
            island.move(to: CGPoint(x: rect.width * 0.20, y: rect.height * 0.44))
            island.addLine(to: CGPoint(x: rect.width * 0.58, y: rect.height * 0.30))
            island.addLine(to: CGPoint(x: rect.width * 0.86, y: rect.height * 0.24))
            island.addLine(to: CGPoint(x: rect.width * 0.62, y: rect.height * 0.46))
            island.addLine(to: CGPoint(x: rect.width * 0.30, y: rect.height * 0.56))
            island.closeSubpath()
            context.fill(island, with: .color(hex(0xD57800)))
            // Les deux rameaux d'olivier, en chevron.
            let green = hex(0x4E9F45)
            let armW = rect.width * 0.22, armH = rect.height * 0.055
            context.fill(Path(CGRect(x: rect.midX - armW, y: rect.height * 0.68,
                                     width: armW, height: armH)), with: .color(green))
            context.fill(Path(CGRect(x: rect.midX, y: rect.height * 0.68,
                                     width: armW, height: armH)), with: .color(green))

        case .canada:
            let red = hex(0xD80621)
            context.fill(Path(rect), with: .color(.white))
            let band = rect.width * 0.25
            context.fill(Path(CGRect(x: 0, y: 0, width: band, height: rect.height)),
                         with: .color(red))
            context.fill(Path(CGRect(x: rect.width - band, y: 0,
                                     width: band, height: rect.height)),
                         with: .color(red))
            // Feuille d'érable suggérée par un losange : à cette taille, ses
            // onze pointes ne seraient qu'une tache.
            var leaf = Path()
            leaf.move(to: CGPoint(x: rect.midX, y: rect.height * 0.22))
            leaf.addLine(to: CGPoint(x: rect.midX + rect.height * 0.20, y: rect.midY))
            leaf.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.78))
            leaf.addLine(to: CGPoint(x: rect.midX - rect.height * 0.20, y: rect.midY))
            leaf.closeSubpath()
            context.fill(leaf, with: .color(red))

        case .unitedKingdom:
            let blue = hex(0x012169), red = hex(0xC8102E)
            context.fill(Path(rect), with: .color(blue))
            // Saltire blanc, puis croix de Saint-Georges bordée de blanc.
            var saltire = Path()
            saltire.move(to: .zero)
            saltire.addLine(to: CGPoint(x: rect.width, y: rect.height))
            saltire.move(to: CGPoint(x: rect.width, y: 0))
            saltire.addLine(to: CGPoint(x: 0, y: rect.height))
            context.stroke(saltire, with: .color(.white),
                           style: StrokeStyle(lineWidth: rect.height * 0.20))
            let armW = rect.height * 0.30, armR = rect.height * 0.18
            context.fill(Path(CGRect(x: 0, y: rect.midY - armW / 2,
                                     width: rect.width, height: armW)), with: .color(.white))
            context.fill(Path(CGRect(x: rect.midX - armW / 2, y: 0,
                                     width: armW, height: rect.height)), with: .color(.white))
            context.fill(Path(CGRect(x: 0, y: rect.midY - armR / 2,
                                     width: rect.width, height: armR)), with: .color(red))
            context.fill(Path(CGRect(x: rect.midX - armR / 2, y: 0,
                                     width: armR, height: rect.height)), with: .color(red))
        }
    }
}
