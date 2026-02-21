import SwiftUI

/// Animated ambient background with floating orbs
struct AmbientBackgroundView: View {
    let colors: ArtworkColors

    @State private var animationPhase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [
                        colors.primary.opacity(0.9),
                        colors.secondary.opacity(0.8),
                        colors.tertiary.opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Floating orbs
                ForEach(0..<5, id: \.self) { index in
                    FloatingOrb(
                        color: orbColor(for: index),
                        size: orbSize(for: index, in: geometry.size),
                        position: orbPosition(for: index, in: geometry.size),
                        animationPhase: animationPhase,
                        index: index
                    )
                }

                // Overlay gradient for depth
                RadialGradient(
                    colors: [
                        .clear,
                        colors.primary.opacity(0.3)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.7
                )
            }
        }
        .onAppear {
            withAnimation(
                .linear(duration: 20)
                .repeatForever(autoreverses: false)
            ) {
                animationPhase = 1
            }
        }
    }

    private func orbColor(for index: Int) -> Color {
        switch index % 3 {
        case 0: return colors.primary
        case 1: return colors.secondary
        default: return colors.tertiary
        }
    }

    private func orbSize(for index: Int, in size: CGSize) -> CGFloat {
        let baseSize = min(size.width, size.height) * 0.3
        let variation = CGFloat(index % 3) * 0.15
        return baseSize * (1 + variation)
    }

    private func orbPosition(for index: Int, in size: CGSize) -> CGPoint {
        let positions: [CGPoint] = [
            CGPoint(x: 0.2, y: 0.2),
            CGPoint(x: 0.8, y: 0.3),
            CGPoint(x: 0.3, y: 0.7),
            CGPoint(x: 0.7, y: 0.8),
            CGPoint(x: 0.5, y: 0.5)
        ]
        let pos = positions[index % positions.count]
        return CGPoint(x: size.width * pos.x, y: size.height * pos.y)
    }
}

// MARK: - Floating Orb

struct FloatingOrb: View {
    let color: Color
    let size: CGFloat
    let position: CGPoint
    let animationPhase: CGFloat
    let index: Int

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.6),
                        color.opacity(0.2),
                        color.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .blur(radius: size * 0.3)
            .position(animatedPosition)
    }

    private var animatedPosition: CGPoint {
        let phase = animationPhase * .pi * 2
        let offsetX = cos(phase + Double(index) * 0.5) * 30
        let offsetY = sin(phase + Double(index) * 0.7) * 30
        return CGPoint(
            x: position.x + offsetX,
            y: position.y + offsetY
        )
    }
}

#Preview {
    AmbientBackgroundView(colors: .default)
        .frame(width: 800, height: 600)
}
