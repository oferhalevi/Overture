import SwiftUI
import AppKit

/// The reveal state of the vinyl disc
enum VinylRevealState: Equatable {
    case hidden      // Disc inside cover (0% visible)
    case partial     // Disc 50% out
    case full        // Disc 80% out (label visible)

    var offsetMultiplier: CGFloat {
        switch self {
        case .hidden: return 0.0
        case .partial: return 0.50
        case .full: return 0.80
        }
    }
}

/// Spinning vinyl LP with album art label and overlapping cover
struct AlbumArtView: View {
    let artwork: NSImage?
    let size: CGFloat
    let isPlaying: Bool
    let labelImage: NSImage?
    let isGeneratingLabel: Bool
    let trackId: String?  // To detect track changes

    @State private var rotation: Double = 0
    @State private var isAnimating = false
    @State private var revealState: VinylRevealState = .hidden
    @State private var previousTrackId: String?

    // 33 1/3 RPM = 33.333 rotations per minute = 0.556 rotations per second
    // Full rotation (360°) takes 1.8 seconds
    private let rotationDuration: Double = 1.8

    // Vinyl is slightly smaller than album cover
    private var vinylSize: CGFloat { size * 0.96 }
    private var coverSize: CGFloat { size }

    // Calculate offset based on reveal state
    private var vinylOffset: CGFloat {
        vinylSize * revealState.offsetMultiplier
    }

    // Total width of the composition for centering
    private var totalWidth: CGFloat {
        coverSize + vinylOffset
    }

    init(artwork: NSImage?, size: CGFloat, isPlaying: Bool, labelImage: NSImage? = nil, isGeneratingLabel: Bool = false, trackId: String? = nil) {
        self.artwork = artwork
        self.size = size
        self.isPlaying = isPlaying
        self.labelImage = labelImage
        self.isGeneratingLabel = isGeneratingLabel
        self.trackId = trackId
    }

    var body: some View {
        // Container that keeps the composition horizontally centered
        ZStack {
            // Offset container to center the cover+disc composition
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                ZStack(alignment: .leading) {
                    // Spinning vinyl record (behind cover, slides out to the right)
                    SpinningVinylView(
                        artwork: artwork,
                        labelImage: labelImage,
                        size: vinylSize,
                        rotation: rotation,
                        isGeneratingLabel: isGeneratingLabel
                    )
                    .offset(x: coverSize * 0.02 + vinylOffset) // Small base offset + animated offset

                    // Album cover (in front, on the left)
                    AlbumCoverView(artwork: artwork, size: coverSize)
                }
                .frame(width: totalWidth, alignment: .leading)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            startRotation()
            // Animate to partial reveal on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    revealState = .partial
                }
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing && !isAnimating {
                startRotation()
            }
        }
        .onChange(of: trackId) { newTrackId in
            // Track changed - animate disc back in, then out again
            if newTrackId != previousTrackId && previousTrackId != nil {
                // First, slide disc back in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    revealState = .hidden
                }
                // Then slide back out to partial after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        revealState = .partial
                    }
                }
            }
            previousTrackId = newTrackId
        }
        .onChange(of: labelImage) { newLabel in
            // When label becomes available, animate to full reveal
            if newLabel != nil && revealState != .full {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    revealState = .full
                }
            }
        }
    }

    private func startRotation() {
        guard !isAnimating else { return }
        isAnimating = true

        withAnimation(
            .linear(duration: rotationDuration)
            .repeatForever(autoreverses: false)
        ) {
            rotation = 360
        }
    }
}

// MARK: - Spinning Vinyl (rotates) + Static Light Overlay (doesn't rotate)

struct SpinningVinylView: View {
    let artwork: NSImage?
    let labelImage: NSImage?
    let size: CGFloat
    let rotation: Double
    let isGeneratingLabel: Bool

    var body: some View {
        ZStack {
            // The vinyl disc that actually spins
            VinylDiscView(
                artwork: artwork,
                labelImage: labelImage,
                size: size,
                isGeneratingLabel: isGeneratingLabel
            )
            .rotationEffect(.degrees(rotation))

            // Static light reflection overlay (does NOT rotate)
            VinylLightOverlay(size: size)
        }
        .shadow(color: .black.opacity(0.5), radius: size * 0.05, x: 4, y: 8)
    }
}

// MARK: - Vinyl Disc (the part that spins)

struct VinylDiscView: View {
    let artwork: NSImage?
    let labelImage: NSImage?
    let size: CGFloat
    let isGeneratingLabel: Bool

    var body: some View {
        ZStack {
            // Solid black vinyl base
            Circle()
                .fill(Color(white: 0.02))
                .frame(width: size, height: size)

            // Vinyl grooves
            VinylGroovesView(size: size)

            // Center label
            CenterLabelView(
                artwork: artwork,
                labelImage: labelImage,
                size: size * 0.38,
                isGeneratingLabel: isGeneratingLabel
            )

            // Spindle hole
            Circle()
                .fill(Color.black)
                .frame(width: size * 0.02, height: size * 0.02)
        }
    }
}

// MARK: - Static Light Overlay (doesn't spin)

struct VinylLightOverlay: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Main specular highlight - top left
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.2
                    )
                )
                .frame(width: size * 0.4, height: size * 0.2)
                .offset(x: -size * 0.15, y: -size * 0.2)
                .blendMode(.screen)

            // Subtle rim light
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.12)
                        ],
                        center: .center,
                        startAngle: .degrees(-45),
                        endAngle: .degrees(315)
                    ),
                    lineWidth: 2
                )
                .frame(width: size - 2, height: size - 2)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Vinyl Grooves

struct VinylGroovesView: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let maxRadius = min(canvasSize.width, canvasSize.height) / 2

            // Draw fine grooves from label edge to outer rim
            for i in stride(from: 0.40, to: 0.97, by: 0.008) {
                let radius = maxRadius * i
                let path = Path { p in
                    p.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .zero,
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                }

                // Alternate subtle groove colors
                let opacity = (Int(i * 1000) % 2 == 0) ? 0.08 : 0.03
                context.stroke(
                    path,
                    with: .color(.white.opacity(opacity)),
                    lineWidth: 0.5
                )
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

// MARK: - Center Label

struct CenterLabelView: View {
    let artwork: NSImage?
    let labelImage: NSImage?
    let size: CGFloat
    let isGeneratingLabel: Bool

    @State private var glowPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Label base
            Circle()
                .fill(Color(white: 0.1))
                .frame(width: size, height: size)

            // AI-generated label or album art (show default/artwork while generating)
            if let label = labelImage {
                Image(nsImage: label)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size * 0.94, height: size * 0.94)
                    .clipShape(Circle())
                    .transition(.opacity)
            } else if let artwork = artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size * 0.94, height: size * 0.94)
                    .clipShape(Circle())
                    .saturation(0.85)
                    .brightness(-0.05)
            } else {
                // Default vintage label
                DefaultLabelView(size: size)
            }

            // AI generation glow effect - flicker-free Canvas-based
            if isGeneratingLabel && labelImage == nil {
                LabelGlowRing(size: size * 0.96, phase: glowPhase)
            }

            // Label rim
            Circle()
                .strokeBorder(Color.black.opacity(0.5), lineWidth: 1.5)
                .frame(width: size, height: size)

            // Inner spindle ring
            Circle()
                .strokeBorder(Color.black.opacity(0.6), lineWidth: 1)
                .frame(width: size * 0.12, height: size * 0.12)
        }
        .onAppear {
            if isGeneratingLabel {
                startGlowAnimation()
            }
        }
        .onChange(of: isGeneratingLabel) { generating in
            if generating {
                startGlowAnimation()
            }
        }
    }

    private func startGlowAnimation() {
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            glowPhase = 1.0
        }
    }
}

// MARK: - Label Glow Ring (flicker-free)

struct LabelGlowRing: View {
    let size: CGFloat
    let phase: CGFloat

    var body: some View {
        ZStack {
            // Blurred outer glow
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius = min(canvasSize.width, canvasSize.height) / 2 - 2

                let segmentCount = 60
                for i in 0..<segmentCount {
                    let startAngle = Angle(degrees: Double(i) / Double(segmentCount) * 360 + Double(phase) * 360)
                    let endAngle = Angle(degrees: Double(i + 1) / Double(segmentCount) * 360 + Double(phase) * 360)

                    let normalizedPosition = Double(i) / Double(segmentCount)
                    let opacity = glowOpacity(at: normalizedPosition)
                    let color = glowColor(at: normalizedPosition)

                    var path = Path()
                    path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)

                    context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 3)
                }
            }
            .frame(width: size, height: size)
            .blur(radius: 2)

            // Sharp inner ring
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius = min(canvasSize.width, canvasSize.height) / 2 - 2

                let segmentCount = 60
                for i in 0..<segmentCount {
                    let startAngle = Angle(degrees: Double(i) / Double(segmentCount) * 360 + Double(phase) * 360)
                    let endAngle = Angle(degrees: Double(i + 1) / Double(segmentCount) * 360 + Double(phase) * 360)

                    let normalizedPosition = Double(i) / Double(segmentCount)
                    let opacity = glowOpacity(at: normalizedPosition) * 1.2
                    let color = glowColor(at: normalizedPosition)

                    var path = Path()
                    path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)

                    context.stroke(path, with: .color(color.opacity(min(1.0, opacity))), lineWidth: 2)
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func glowOpacity(at position: Double) -> Double {
        let peak = 0.5
        let spread = 0.35
        let distance = abs(position - peak)
        return max(0, 1.0 - (distance / spread))
    }

    private func glowColor(at position: Double) -> Color {
        if position < 0.33 {
            return Color.cyan
        } else if position < 0.66 {
            return Color.purple
        } else {
            return Color.pink
        }
    }
}

// MARK: - Default Label

struct DefaultLabelView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Classic label background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.6, green: 0.1, blue: 0.1),
                            Color(red: 0.4, green: 0.05, blue: 0.05)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.47
                    )
                )
                .frame(width: size * 0.94, height: size * 0.94)

            VStack(spacing: 2) {
                Text("OVERTURE")
                    .font(.system(size: size * 0.09, weight: .bold, design: .serif))
                    .foregroundColor(.white.opacity(0.9))

                Text("HIGH FIDELITY")
                    .font(.system(size: size * 0.045, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Album Cover

struct AlbumCoverView: View {
    let artwork: NSImage?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let artwork = artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.2), Color(white: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.25))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }

            // Subtle cover edge
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.clear,
                            Color.black.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: size, height: size)
        }
        .shadow(color: .black.opacity(0.4), radius: 10, x: -3, y: 5)
    }
}

// MARK: - Preview

#Preview("Vinyl Player - Hidden") {
    ZStack {
        Color(white: 0.15)
        AlbumArtView(artwork: nil, size: 280, isPlaying: true, trackId: "test")
    }
    .frame(width: 650, height: 450)
}

#Preview("Vinyl Player - With Label") {
    ZStack {
        Color(white: 0.15)
        AlbumArtView(artwork: nil, size: 280, isPlaying: true, labelImage: nil, isGeneratingLabel: false, trackId: "test")
    }
    .frame(width: 650, height: 450)
}
