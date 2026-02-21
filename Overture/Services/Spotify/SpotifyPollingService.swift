import Foundation
import Combine

/// Service that polls Spotify for track changes
@MainActor
class SpotifyPollingService: ObservableObject {
    @Published private(set) var currentTrack: Track?
    @Published private(set) var isConnected = false
    @Published private(set) var error: Error?

    private let bridge = SpotifyAppleScriptBridge()
    private var pollingTask: Task<Void, Never>?
    private var onTrackChange: ((Track) -> Void)?

    func startPolling(onTrackChange: @escaping (Track) -> Void) {
        self.onTrackChange = onTrackChange
        stopPolling()

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollSpotify()
                try? await Task.sleep(nanoseconds: UInt64(Constants.Timing.spotifyPollInterval * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func pollSpotify() async {
        do {
            let track = try await bridge.getCurrentTrack()
            self.error = nil
            self.isConnected = true

            // Check if track changed (not just playback position)
            if let track = track, !track.isSameTrack(as: currentTrack) {
                self.currentTrack = track
                onTrackChange?(track)
            } else if let track = track {
                // Update position and playing state without triggering track change
                self.currentTrack = track
            } else {
                self.currentTrack = nil
            }
        } catch {
            self.error = error
            self.isConnected = false

            // Only clear track if Spotify is not running
            if case SpotifyAppleScriptBridge.SpotifyError.notRunning = error {
                self.currentTrack = nil
            }
        }
    }
}
