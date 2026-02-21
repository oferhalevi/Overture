import SwiftUI
import AppKit
import Combine

/// Main application state that coordinates all services
@MainActor
class AppState: ObservableObject {
    // MARK: - Published State

    @Published private(set) var currentTrack: Track?
    @Published private(set) var albumArtwork: NSImage?
    @Published private(set) var vinylLabel: NSImage?
    @Published private(set) var artworkColors: ArtworkColors = .default
    @Published private(set) var facts: [Fact] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isGeneratingLabel: Bool = false
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var error: String?
    @Published private(set) var llmActivity: String? // Current LLM activity description

    // MARK: - Services

    private let spotifyService = SpotifyPollingService()
    private let spotifyBridge = SpotifyAppleScriptBridge()
    private let artworkService = ArtworkService()
    private let discogsService = DiscogsService()
    private let wikipediaService = WikipediaAPIService()
    private let llmService = LLMService()
    private let labelGenerator = LabelGeneratorService()
    private let colorExtractor = DominantColorExtractor()
    private let factsCache = FactsCache()
    private let aiService = AIService()

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var currentWorkTask: Task<Void, Never>?
    private var labelTask: Task<Void, Never>?
    private var lastProcessedTrackId: String?

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Public Methods

    func start() {
        spotifyService.startPolling { [weak self] track in
            Task { @MainActor in
                guard let self = self else { return }

                // Skip if we're already processing this track
                if track.id == self.lastProcessedTrackId {
                    self.currentTrack = track
                    return
                }

                print("New track detected: \(track.name) (id: \(track.id))")
                self.lastProcessedTrackId = track.id

                // Cancel previous work and start new
                self.currentWorkTask?.cancel()

                self.currentWorkTask = Task {
                    await self.handleTrackChange(track)
                }
            }
        }
    }

    func stop() {
        spotifyService.stopPolling()
        currentWorkTask?.cancel()
        labelTask?.cancel()
    }

    // MARK: - Playback Controls

    func playPause() {
        Task {
            do {
                try await spotifyBridge.playPause()
            } catch {
                print("Play/pause error: \(error)")
            }
        }
    }

    func nextTrack() {
        Task {
            do {
                try await spotifyBridge.nextTrack()
            } catch {
                print("Next track error: \(error)")
            }
        }
    }

    func previousTrack() {
        Task {
            do {
                try await spotifyBridge.previousTrack()
            } catch {
                print("Previous track error: \(error)")
            }
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        spotifyService.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.currentTrack = track
            }
            .store(in: &cancellables)

        spotifyService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isConnected = connected
            }
            .store(in: &cancellables)

        spotifyService.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.error = error?.localizedDescription
            }
            .store(in: &cancellables)
    }

    private func handleTrackChange(_ track: Track) async {
        print("=== Track changed to: \(track.name) by \(track.artist) ===")

        // Cancel any in-progress background tasks from previous track
        labelTask?.cancel()
        labelTask = nil

        isLoading = true
        error = nil
        vinylLabel = nil
        isGeneratingLabel = false
        facts = []

        // First priority: fetch artwork
        print("Fetching artwork...")
        await fetchArtwork(for: track)

        // Check for cancellation
        if Task.isCancelled {
            print("Task cancelled after artwork")
            return
        }

        // Check cache first
        if let cachedFacts = await factsCache.getFacts(for: track), !cachedFacts.isEmpty {
            print("Using cached facts for: \(track.name)")
            if track.id == currentTrack?.id {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.facts = cachedFacts
                }
            }
            isLoading = false
            llmActivity = nil
        } else {
            // Generate the story/analysis
            llmActivity = "Writing about this song..."

            // Fetch lyrics analysis and Wikipedia info in parallel
            print("Fetching lyrics analysis and Wikipedia summaries in parallel...")
            async let lyricsTask = fetchLyricsAnalysis(for: track)
            async let artistSummary = fetchWikipediaSummary(for: track.artistWikiQuery)
            async let trackSummary = fetchWikipediaSummary(for: "\(track.name) \(track.artist) song")
            async let albumSummary = fetchWikipediaSummary(for: "\(track.album) \(track.artist) album")

            let lyricsInsight = await lyricsTask
            let artist = await artistSummary
            let trackInfo = await trackSummary
            let album = await albumSummary

            // Check if track changed
            guard track.id == currentTrack?.id else {
                print("Track changed during fetch")
                return
            }

            // Use LLM to generate cohesive narrative from Wikipedia
            let narrativeFacts = await llmService.generateNarrativeFacts(
                track: track,
                artistSummary: artist,
                trackSummary: trackInfo,
                albumSummary: album
            )

            print("LLM returned \(narrativeFacts.count) facts")

            // Combine lyrics insight (first) with narrative facts
            var allFacts: [Fact] = []
            if let lyrics = lyricsInsight {
                allFacts.append(lyrics)
            }
            allFacts.append(contentsOf: narrativeFacts)

            if track.id == currentTrack?.id {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.facts = allFacts
                }
                // Cache the facts
                await factsCache.setFacts(allFacts, for: track)
            }

            isLoading = false
            llmActivity = nil
        }

        // Start background task for label generation
        labelTask = Task {
            await fetchLabel(for: track)
        }

        print("=== Track change handling complete ===")
    }

    /// Fetch lyrics analysis - focused on meaning, themes, and emotional content
    private func fetchLyricsAnalysis(for track: Track) async -> Fact? {
        print("Fetching lyrics analysis for: \(track.name)")

        let prompt = """
        I'm listening to "\(track.name)" by \(track.artist) from the album "\(track.album)".

        If this is a song with lyrics, write 2-3 paragraphs analyzing the LYRICS and MEANING:
        - What themes or stories do the lyrics explore?
        - What emotions or messages does the song convey?
        - Any notable imagery, metaphors, or poetic devices?
        - What might have inspired these lyrics?

        If this is an instrumental, classical piece, or has no significant lyrics, respond with just: "INSTRUMENTAL"

        Do NOT discuss production, musical style, chart performance, or the artist's biography - focus ONLY on lyrical content and meaning.

        Write in an engaging, insightful style - like a literary analysis of the song's words.
        Keep it around 120-150 words. Dive right into the analysis without preamble.
        """

        do {
            let content = try await aiService.chatCompletion(
                prompt: prompt,
                maxTokens: 350,
                temperature: 0.8
            )
            // Skip if instrumental or empty
            if content.isEmpty || content.uppercased().contains("INSTRUMENTAL") {
                print("Track is instrumental or has no significant lyrics")
                return nil
            }
            return Fact(
                content: content,
                category: .lyrics,
                source: "AI Analysis",
                isLongForm: true
            )
        } catch {
            print("Lyrics analysis error: \(error)")
        }

        return nil
    }

    private func fetchArtwork(for track: Track) async {
        print("fetchArtwork called for: \(track.name)")

        guard let image = await artworkService.fetchArtwork(for: track) else {
            print("No artwork found for: \(track.name)")
            withAnimation(.easeInOut(duration: Constants.Timing.colorTransitionDuration)) {
                self.albumArtwork = nil
                self.artworkColors = .default
            }
            return
        }

        print("Got artwork for: \(track.name), size: \(image.size)")

        // Extract colors from artwork
        let colors = colorExtractor.extractColors(from: image)

        withAnimation(.easeInOut(duration: Constants.Timing.colorTransitionDuration)) {
            self.albumArtwork = image
            self.artworkColors = colors
        }
        print("fetchArtwork: completed successfully")
    }

    private func fetchWikipediaSummary(for query: String) async -> String? {
        do {
            if let summary = try await wikipediaService.fetchSummary(for: query) {
                return summary.extract
            }
        } catch {
            print("Wikipedia fetch error: \(error)")
        }
        return nil
    }

    private func fetchLabel(for track: Track) async {
        print("fetchLabel called for: \(track.name)")

        // Capture the track ID we're generating for
        let targetTrackId = track.id

        isGeneratingLabel = true

        // First, try to get a real vinyl label image from Discogs
        print("Trying Discogs for vinyl label...")
        if let discogsLabel = await discogsService.fetchVinylLabel(artist: track.artist, album: track.album) {
            // Check if task was cancelled or track changed
            if Task.isCancelled {
                print("Label fetch task was cancelled")
                return
            }

            guard targetTrackId == currentTrack?.id else {
                print("Track changed during Discogs fetch, discarding result")
                return
            }

            print("Got vinyl label from Discogs!")
            withAnimation(.easeInOut(duration: 0.5)) {
                self.vinylLabel = discogsLabel
                self.isGeneratingLabel = false
            }
            return
        }

        print("No Discogs label, falling back to AI generation...")

        // Fallback: Generate AI label based on album artwork style
        let label = await labelGenerator.generateLabel(
            artist: track.artist,
            album: track.album,
            albumArtwork: albumArtwork
        )

        // Check if task was cancelled or track changed
        if Task.isCancelled {
            print("Label generation task was cancelled")
            return
        }

        print("Label generation completed: \(label == nil ? "nil" : "got image")")

        // Only set label if we're still on the same track
        guard targetTrackId == currentTrack?.id else {
            print("Track changed during label generation, discarding result")
            return
        }

        withAnimation(.easeInOut(duration: 0.5)) {
            self.vinylLabel = label
            self.isGeneratingLabel = false
        }
    }
}
