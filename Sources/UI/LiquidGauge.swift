//
//  LiquidGauge.swift · Note de blocage, en bille remplie
//
//  Une barre de progression dirait la même chose, mais une note se retient mieux
//  sous forme de niveau qui monte. La couleur suffit à comprendre sans lire.
//

import SwiftUI

struct LiquidGauge: View {
    /// Remplissage, de 0 à 1.
    let value: Double
    let tint: Color
    /// Texte au centre — la note.
    let center: String
    /// Légende sous la note.
    let caption: String
    var size: CGFloat = 132
    /// Vagues figées quand rien ne tourne : une animation permanente fatigue.
    var animated: Bool = true

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.04))
            Circle().strokeBorder(tint.opacity(0.30), lineWidth: 1.5)

            wave
                .clipShape(Circle().inset(by: 2))

            VStack(spacing: 1) {
                Text(center)
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(caption)
                    .font(.system(size: size * 0.085))
                    .foregroundStyle(.secondary)
            }
            .shadow(color: .black.opacity(0.4), radius: 3)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: value)
    }

    @ViewBuilder
    private var wave: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                waveShapes(phase: t)
            }
        } else {
            waveShapes(phase: 0)
        }
    }

    private func waveShapes(phase: Double) -> some View {
        ZStack {
            // Deux vagues à vitesses différentes : le décalage donne l'impression
            // d'un liquide, là où une seule sinusoïde ferait mécanique.
            WaveShape(progress: value, phase: phase * 0.9, amplitude: 0.030)
                .fill(tint.opacity(0.35))
            WaveShape(progress: value, phase: phase * 1.4 + 1.2, amplitude: 0.022)
                .fill(tint.opacity(0.75))
        }
    }
}

/// Surface de liquide : une sinusoïde qui ondule, et tout ce qu'il y a dessous.
private struct WaveShape: Shape {
    /// Hauteur du liquide, de 0 (vide) à 1 (plein).
    var progress: Double
    /// Décalage horizontal de la vague, en radians.
    var phase: Double
    /// Amplitude, en fraction de la hauteur.
    var amplitude: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard progress > 0.001 else { return path }

        let surface = rect.height * (1 - progress)
        let amp = rect.height * amplitude
        let step: CGFloat = 2

        path.move(to: CGPoint(x: rect.minX, y: surface))
        var x = rect.minX
        while x <= rect.maxX {
            let relative = Double(x / max(rect.width, 1))
            let y = surface + amp * sin(relative * 2 * .pi * 1.6 + phase * 2)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Couleur d'un niveau de protection, commune à toutes les vues qui l'affichent.
extension ProtectionLevel {
    var tint: Color {
        switch self {
        case .insufficient: return DTColor.rouge
        case .improvable:   return DTColor.ambre
        case .good:         return DTColor.vert
        }
    }
}
