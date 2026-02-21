import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    // Track transition state
    @State private var isTransitioning: Bool = false
    @State private var showTrackInfo: Bool = true
    @State private var showFacts: Bool = true

    // Store displayed track info to avoid showing new track during exit animation
    @State private var displayedTrack: Track?

    // Track whether we have content to show
    private var hasContent: Bool {
        !appState.facts.isEmpty && showFacts
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = GridLayout(windowSize: geometry.size)

            // Calculate the vertical offset for centered vs top position
            let centeredY = (layout.gridSize - layout.rowHeight) / 2 - layout.outerPadding
            let topY: CGFloat = 0
            let albumOffset = hasContent ? topY : centeredY

            ZStack {
                // Ambient animated background
                AmbientBackgroundView(colors: appState.artworkColors)

                // Main content
                HStack {
                    Spacer()
                    ZStack(alignment: .top) {
                        // Grid container
                        VStack(spacing: 0) {
                            // Album row - animated position
                            albumRow(layout: layout)
                                .frame(height: layout.rowHeight)
                                .offset(y: albumOffset)

                            Spacer()
                        }
                        .frame(width: layout.gridSize, height: layout.gridSize)

                        // Text content - fades in and appears below
                        if hasContent {
                            VStack {
                                Spacer()
                                    .frame(height: layout.rowHeight + layout.rowSpacing + layout.outerPadding)

                                MultiColumnFlowingText(
                                    facts: appState.facts,
                                    textColor: appState.artworkColors.textColor,
                                    textColorSecondary: appState.artworkColors.textColorSecondary,
                                    layout: layout
                                )
                                .frame(height: layout.rowHeight * 2 + layout.rowSpacing)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))

                                Spacer()
                            }
                            .frame(width: layout.gridSize, height: layout.gridSize)
                            .padding(.horizontal, layout.outerPadding)
                        }
                    }
                    Spacer()
                }

                // Connection status overlay
                if !appState.isConnected {
                    ConnectionOverlayView(error: appState.error, sizing: layout.sizing)
                }
            }
            .animation(.spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0), value: hasContent)
        }
        .ignoresSafeArea()
        .onAppear {
            appState.start()
            displayedTrack = appState.currentTrack
        }
        .onDisappear {
            appState.stop()
        }
        .onChange(of: appState.currentTrack?.id) { _ in
            // Initialize displayedTrack on first track (when no transition happens)
            if displayedTrack == nil {
                displayedTrack = appState.currentTrack
            }
        }
        .background(KeyboardHandlerView { event in
            handleKeyPress(event)
        })
    }

    // MARK: - Keyboard Handling

    private func handleKeyPress(_ event: NSEvent) {
        switch event.keyCode {
        case 49:  // Spacebar
            appState.playPause()
        case 53:  // Escape - exit full screen
            if let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        case 123:  // Left arrow
            appState.previousTrack()
        case 124:  // Right arrow
            appState.nextTrack()
        default:
            break
        }
    }

    // MARK: - Album Row: Vinyl + Track Info

    @ViewBuilder
    private func albumRow(layout: GridLayout) -> some View {
        HStack(spacing: layout.columnSpacing) {
            Spacer()

            // Vinyl + Cover composition
            AlbumArtView(
                artwork: appState.albumArtwork,
                size: layout.vinylSize,
                isPlaying: appState.currentTrack?.isPlaying ?? false,
                labelImage: appState.vinylLabel,
                isGeneratingLabel: appState.isGeneratingLabel,
                trackId: appState.currentTrack?.id,
                onTransitionStart: {
                    // Fade out text when transition starts (keep showing old track info)
                    withAnimation(.easeOut(duration: 0.25)) {
                        showTrackInfo = false
                        showFacts = false
                    }
                },
                onTransitionEnd: {
                    // Update displayed track to new track, then fade in
                    displayedTrack = appState.currentTrack
                    withAnimation(.easeIn(duration: 0.3)) {
                        showTrackInfo = true
                        showFacts = true
                    }
                },
                onTap: {
                    appState.playPause()
                },
                onDoubleTap: {
                    appState.nextTrack()
                }
            )

            // Track info - with fade animation, uses displayedTrack to avoid flash during transition
            if let track = displayedTrack ?? appState.currentTrack {
                VStack(alignment: .leading, spacing: layout.trackInfoLineSpacing) {
                    Text(track.name)
                        .font(.system(size: layout.trackTitleSize, weight: .semibold, design: .serif))
                        .foregroundColor(appState.artworkColors.textColor)
                        .lineLimit(2)

                    Text(track.artist)
                        .font(.system(size: layout.artistSize, weight: .regular, design: .serif))
                        .foregroundColor(appState.artworkColors.textColorSecondary)
                        .lineLimit(1)

                    if !track.album.isEmpty && track.album != track.name {
                        Text(track.album)
                            .font(.system(size: layout.albumTextSize, weight: .light, design: .serif))
                            .italic()
                            .foregroundColor(appState.artworkColors.textColorSecondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: layout.trackInfoWidth, alignment: .leading)
                .opacity(showTrackInfo ? 1.0 : 0.0)
            }

            Spacer()
        }
        .padding(.horizontal, layout.outerPadding)
    }
}

// MARK: - Grid Layout Calculator

struct GridLayout {
    let windowSize: CGSize
    let sizing: ResponsiveSizing

    init(windowSize: CGSize) {
        self.windowSize = windowSize
        self.sizing = ResponsiveSizing(for: windowSize)
    }

    // MARK: - Square Grid Size

    /// The grid is a square that fits within the window (with padding)
    var gridSize: CGFloat {
        let maxSize = min(windowSize.width, windowSize.height)
        // Leave some margin around the square
        return maxSize * 0.95
    }

    /// Master scale factor - everything derives from this
    var scale: CGFloat {
        gridSize / 600.0  // Base size is 600px
    }

    // MARK: - Grid Structure

    var outerPadding: CGFloat {
        12 * scale
    }

    var rowSpacing: CGFloat {
        12 * scale
    }

    var columnSpacing: CGFloat {
        14 * scale
    }

    /// Content area after padding
    var contentSize: CGFloat {
        gridSize - outerPadding * 2
    }

    /// Each row is 1/3 of content height (minus spacing)
    var rowHeight: CGFloat {
        (contentSize - rowSpacing * 2) / 3
    }

    // MARK: - Vinyl Sizing

    var vinylSize: CGFloat {
        // Vinyl should fit in top row
        rowHeight * 0.92
    }

    // MARK: - Track Info

    var trackInfoWidth: CGFloat {
        contentSize * 0.4
    }

    var trackTitleSize: CGFloat {
        18 * scale
    }

    var artistSize: CGFloat {
        14 * scale
    }

    var albumTextSize: CGFloat {
        12 * scale
    }

    var trackInfoLineSpacing: CGFloat {
        5 * scale
    }

    // MARK: - Text Columns

    /// Number of columns (always 3)
    var columnCount: Int {
        return 3
    }

    var textColumnWidth: CGFloat {
        let availableWidth = contentSize - (columnSpacing * CGFloat(columnCount - 1))
        return availableWidth / CGFloat(columnCount)
    }

    // MARK: - Typography (all scale with grid)

    var bodyFontSize: CGFloat {
        11 * scale
    }

    var headerFontSize: CGFloat {
        8 * scale
    }

    var lineSpacing: CGFloat {
        2.5 * scale
    }

    var paragraphSpacing: CGFloat {
        5 * scale
    }
}

// MARK: - Multi-Column Flowing Text

struct MultiColumnFlowingText: NSViewRepresentable {
    let facts: [Fact]
    let textColor: Color
    let textColorSecondary: Color
    let layout: GridLayout

    func makeNSView(context: Context) -> MultiColumnTextNSView {
        let view = MultiColumnTextNSView()
        view.wantsLayer = true
        view.alphaValue = 0
        return view
    }

    func updateNSView(_ nsView: MultiColumnTextNSView, context: Context) {
        nsView.update(
            facts: facts,
            textColor: NSColor(textColor),
            textColorSecondary: NSColor(textColorSecondary),
            layout: layout
        )
    }
}

// MARK: - Multi-Column NSView

class MultiColumnTextNSView: NSView {
    private var textStorage: NSTextStorage?
    private var layoutManager: NSLayoutManager?
    private var textContainers: [NSTextContainer] = []
    private var currentColumnCount: Int = 3
    private var currentColumnSpacing: CGFloat = 16
    private var lastFactsHash: Int = 0

    override var isFlipped: Bool { true }

    func update(
        facts: [Fact],
        textColor: NSColor,
        textColorSecondary: NSColor,
        layout: GridLayout
    ) {
        // Check if content actually changed
        let newHash = facts.map { $0.content }.joined().hashValue
        let contentChanged = newHash != lastFactsHash
        lastFactsHash = newHash

        currentColumnCount = layout.columnCount
        currentColumnSpacing = layout.columnSpacing

        // Calculate column dimensions
        let availableWidth = layout.contentSize
        let columnWidth = (availableWidth - (layout.columnSpacing * CGFloat(layout.columnCount - 1))) / CGFloat(layout.columnCount)
        let columnHeight = layout.rowHeight * 2 + layout.rowSpacing

        // Find the right font size that fits
        let fittedFontSize = findFittingFontSize(
            facts: facts,
            textColor: textColor,
            textColorSecondary: textColorSecondary,
            layout: layout,
            columnWidth: columnWidth,
            columnHeight: columnHeight,
            columnCount: layout.columnCount
        )

        // Create text storage with the fitted font size
        let attributedString = buildAttributedString(
            facts: facts,
            textColor: textColor,
            textColorSecondary: textColorSecondary,
            layout: layout,
            fontSize: fittedFontSize
        )

        // Set up text system
        let storage = NSTextStorage(attributedString: attributedString)
        let manager = NSLayoutManager()
        storage.addLayoutManager(manager)

        // Create text containers for each column
        textContainers.removeAll()
        for _ in 0..<layout.columnCount {
            let container = NSTextContainer(size: NSSize(width: columnWidth, height: columnHeight))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container)
            textContainers.append(container)
        }

        self.textStorage = storage
        self.layoutManager = manager

        // Force layout
        if let lastContainer = textContainers.last {
            manager.ensureLayout(for: lastContainer)
        }

        // Animate in only if content changed
        if contentChanged && !facts.isEmpty {
            self.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().alphaValue = 1.0
            }
        }

        setNeedsDisplay(bounds)
    }

    /// Binary search to find the largest font size that fits all content
    private func findFittingFontSize(
        facts: [Fact],
        textColor: NSColor,
        textColorSecondary: NSColor,
        layout: GridLayout,
        columnWidth: CGFloat,
        columnHeight: CGFloat,
        columnCount: Int
    ) -> CGFloat {
        let minFontSize: CGFloat = 6 * layout.scale
        let maxFontSize: CGFloat = 14 * layout.scale
        var bestFit = minFontSize

        var low = minFontSize
        var high = maxFontSize

        for _ in 0..<10 {
            let mid = (low + high) / 2

            if textFitsInColumns(
                facts: facts,
                textColor: textColor,
                textColorSecondary: textColorSecondary,
                layout: layout,
                fontSize: mid,
                columnWidth: columnWidth,
                columnHeight: columnHeight,
                columnCount: columnCount
            ) {
                bestFit = mid
                low = mid
            } else {
                high = mid
            }
        }

        return bestFit * 0.93
    }

    /// Check if text fits within the given columns
    private func textFitsInColumns(
        facts: [Fact],
        textColor: NSColor,
        textColorSecondary: NSColor,
        layout: GridLayout,
        fontSize: CGFloat,
        columnWidth: CGFloat,
        columnHeight: CGFloat,
        columnCount: Int
    ) -> Bool {
        let testString = buildAttributedString(
            facts: facts,
            textColor: textColor,
            textColorSecondary: textColorSecondary,
            layout: layout,
            fontSize: fontSize
        )

        let storage = NSTextStorage(attributedString: testString)
        let manager = NSLayoutManager()
        storage.addLayoutManager(manager)

        var containers: [NSTextContainer] = []
        for _ in 0..<columnCount {
            let container = NSTextContainer(size: NSSize(width: columnWidth, height: columnHeight))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container)
            containers.append(container)
        }

        if let lastContainer = containers.last {
            manager.ensureLayout(for: lastContainer)
        }

        let totalGlyphs = manager.numberOfGlyphs
        if totalGlyphs == 0 { return true }

        let lastContainerGlyphRange = manager.glyphRange(for: containers.last!)
        let lastGlyphInLayout = lastContainerGlyphRange.location + lastContainerGlyphRange.length

        return lastGlyphInLayout >= totalGlyphs
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let layoutManager = layoutManager else { return }

        let columnWidth = (bounds.width - (currentColumnSpacing * CGFloat(currentColumnCount - 1))) / CGFloat(currentColumnCount)

        for (index, container) in textContainers.enumerated() {
            let xOffset = CGFloat(index) * (columnWidth + currentColumnSpacing)
            let origin = NSPoint(x: xOffset, y: 0)

            let glyphRange = layoutManager.glyphRange(for: container)
            if glyphRange.length > 0 {
                layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
                layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
            }
        }
    }

    private func buildAttributedString(
        facts: [Fact],
        textColor: NSColor,
        textColorSecondary: NSColor,
        layout: GridLayout,
        fontSize: CGFloat
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let headerFontSize = fontSize * 0.65
        let lineSpacing = fontSize * 0.12
        let paragraphSpacing = fontSize * 0.5  // Bottom margin after paragraphs
        let sectionGap = fontSize * 1.2

        // Fonts
        let bodyFont = NSFont(name: "Georgia", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        let boldFont = NSFont(name: "Georgia-Bold", size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
        let italicFont = NSFont(name: "Georgia-Italic", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        let headerFont = NSFont.systemFont(ofSize: headerFontSize, weight: .semibold)

        // Body paragraph style
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = lineSpacing
        bodyStyle.paragraphSpacing = paragraphSpacing

        // Header style
        let headerStyle = NSMutableParagraphStyle()
        headerStyle.lineSpacing = 0
        headerStyle.paragraphSpacing = fontSize * 0.15
        headerStyle.paragraphSpacingBefore = sectionGap

        // First header style (no space before)
        let firstHeaderStyle = NSMutableParagraphStyle()
        firstHeaderStyle.lineSpacing = 0
        firstHeaderStyle.paragraphSpacing = fontSize * 0.15

        for (index, fact) in facts.enumerated() {
            // Section header
            let headerText = fact.category.sectionTitle.uppercased()
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: textColorSecondary.withAlphaComponent(0.6),
                .paragraphStyle: index == 0 ? firstHeaderStyle : headerStyle,
                .kern: 1.2
            ]
            result.append(NSAttributedString(string: headerText + "\n", attributes: headerAttrs))

            // Content - parse paragraphs
            let contentText = fact.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let paragraphs = contentText.components(separatedBy: "\n\n")

            for (pIndex, paragraph) in paragraphs.enumerated() {
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                let parsedContent = parseMarkdown(
                    trimmed,
                    bodyFont: bodyFont,
                    boldFont: boldFont,
                    italicFont: italicFont,
                    textColor: textColor,
                    paragraphStyle: bodyStyle
                )
                result.append(parsedContent)

                // Add newline after paragraph (except last)
                if pIndex < paragraphs.count - 1 {
                    result.append(NSAttributedString(string: "\n", attributes: [
                        .font: bodyFont,
                        .paragraphStyle: bodyStyle
                    ]))
                }
            }

            // Add newline after section content
            if index < facts.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: bodyFont,
                    .paragraphStyle: bodyStyle
                ]))
            }
        }

        return result
    }

    /// Parse markdown
    private func parseMarkdown(
        _ text: String,
        bodyFont: NSFont,
        boldFont: NSFont,
        italicFont: NSFont,
        textColor: NSColor,
        paragraphStyle: NSParagraphStyle
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        var currentIndex = text.startIndex
        let endIndex = text.endIndex

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        while currentIndex < endIndex {
            if text[currentIndex...].hasPrefix("**") {
                if let closeRange = text[text.index(currentIndex, offsetBy: 2)...].range(of: "**") {
                    let boldStart = text.index(currentIndex, offsetBy: 2)
                    let boldText = String(text[boldStart..<closeRange.lowerBound])
                    var boldAttrs = baseAttrs
                    boldAttrs[.font] = boldFont
                    result.append(NSAttributedString(string: boldText, attributes: boldAttrs))
                    currentIndex = closeRange.upperBound
                    continue
                }
            }

            if text[currentIndex] == "*" || text[currentIndex] == "_" {
                let marker = text[currentIndex]
                let nextIndex = text.index(after: currentIndex)
                if nextIndex < endIndex && text[nextIndex] != marker {
                    if let closeIndex = text[nextIndex...].firstIndex(of: marker) {
                        let italicText = String(text[nextIndex..<closeIndex])
                        var italicAttrs = baseAttrs
                        italicAttrs[.font] = italicFont
                        result.append(NSAttributedString(string: italicText, attributes: italicAttrs))
                        currentIndex = text.index(after: closeIndex)
                        continue
                    }
                }
            }

            result.append(NSAttributedString(string: String(text[currentIndex]), attributes: baseAttrs))
            currentIndex = text.index(after: currentIndex)
        }

        return result
    }
}

// MARK: - Fact Category Section Titles

extension Fact.Category {
    var sectionTitle: String {
        switch self {
        case .lyrics: return "About the Lyrics"
        case .track: return "The Track"
        case .artist: return "The Artist"
        case .album: return "The Album"
        case .genre: return "More"
        }
    }
}

// MARK: - Responsive Sizing (kept for compatibility)

struct ResponsiveSizing {
    let windowSize: CGSize

    var scaleFactor: CGFloat {
        let baseWidth: CGFloat = 800
        let baseHeight: CGFloat = 600
        let widthScale = windowSize.width / baseWidth
        let heightScale = windowSize.height / baseHeight
        let scale = min(widthScale, heightScale)
        return max(1.0, min(1.8, scale))
    }

    var albumArtSize: CGFloat {
        let baseSize = min(windowSize.width, windowSize.height) * 0.35
        let scaled = baseSize * pow(scaleFactor, 0.7)
        return max(160, min(500, scaled))
    }

    var albumArtSizeHorizontal: CGFloat {
        let baseSize = min(windowSize.width * 0.3, windowSize.height * 0.45)
        return max(180, min(350, baseSize))
    }

    var trackTitleSize: CGFloat { scale(24, min: 18, max: 40) }
    var artistSize: CGFloat { scale(16, min: 13, max: 28) }
    var albumSize: CGFloat { scale(14, min: 11, max: 22) }
    var factSize: CGFloat { scale(17, min: 14, max: 26) }
    var factCategorySize: CGFloat { scale(11, min: 9, max: 14) }

    var spacing: CGFloat { scale(32, min: 20, max: 60) }
    var horizontalPadding: CGFloat { scale(40, min: 24, max: 80) }
    var verticalPadding: CGFloat { scale(30, min: 20, max: 60) }

    var factCardMaxWidth: CGFloat { min(windowSize.width * 0.5, 550) }
    var factCardPadding: CGFloat { scale(20, min: 16, max: 36) }
    var factCardCornerRadius: CGFloat { scale(16, min: 12, max: 28) }

    var dotSize: CGFloat { scale(5, min: 4, max: 8) }
    var dotSpacing: CGFloat { scale(6, min: 5, max: 10) }

    init(for size: CGSize) {
        self.windowSize = size
    }

    private func scale(_ base: CGFloat, min minVal: CGFloat, max maxVal: CGFloat) -> CGFloat {
        let scaled = base * scaleFactor
        return Swift.max(minVal, Swift.min(maxVal, scaled))
    }
}

// MARK: - Connection Overlay

struct ConnectionOverlayView: View {
    let error: String?
    let sizing: ResponsiveSizing

    var body: some View {
        VStack(spacing: sizing.spacing * 0.4) {
            Image(systemName: "music.note.house")
                .font(.system(size: sizing.trackTitleSize * 1.5))
                .foregroundColor(.white.opacity(0.5))

            Text("Waiting for Spotify...")
                .font(.system(size: sizing.artistSize, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            if let error = error {
                Text(error)
                    .font(.system(size: sizing.albumSize, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            Text("Open Spotify and play some music")
                .font(.system(size: sizing.albumSize, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
    }
}

// MARK: - Keyboard Handler

struct KeyboardHandlerView: NSViewRepresentable {
    let onKeyPress: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyboardNSView {
        let view = KeyboardNSView()
        view.onKeyPress = onKeyPress
        return view
    }

    func updateNSView(_ nsView: KeyboardNSView, context: Context) {
        nsView.onKeyPress = onKeyPress
    }
}

class KeyboardNSView: NSView {
    var onKeyPress: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onKeyPress?(event)
    }
}

// MARK: - Previews

#Preview("Full Screen") {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 1440, height: 900)
}

#Preview("Medium") {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 1000, height: 700)
}

#Preview("Small") {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}

#Preview("Compact") {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 600, height: 500)
}
