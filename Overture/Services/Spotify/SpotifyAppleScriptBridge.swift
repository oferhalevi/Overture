import Foundation

/// Bridge to Spotify via AppleScript for getting current playback state
actor SpotifyAppleScriptBridge {
    enum SpotifyError: Error, LocalizedError {
        case notRunning
        case scriptError(String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .notRunning:
                return "Spotify is not running"
            case .scriptError(let message):
                return "AppleScript error: \(message)"
            case .parseError:
                return "Failed to parse Spotify response"
            }
        }
    }

    /// Check if Spotify is running
    func isSpotifyRunning() async -> Bool {
        let script = """
        tell application "System Events"
            return (name of processes) contains "Spotify"
        end tell
        """

        do {
            let result = try await runAppleScript(script)
            return result.lowercased() == "true"
        } catch {
            return false
        }
    }

    /// Get current track information from Spotify
    func getCurrentTrack() async throws -> Track? {
        guard await isSpotifyRunning() else {
            throw SpotifyError.notRunning
        }

        let script = """
        tell application "Spotify"
            if player state is stopped then
                return "STOPPED"
            end if

            set trackName to name of current track
            set artistName to artist of current track
            set albumName to album of current track
            set trackDuration to duration of current track
            set trackPosition to player position
            set playState to player state as string

            return trackName & "|||" & artistName & "|||" & albumName & "|||" & trackDuration & "|||" & trackPosition & "|||" & playState
        end tell
        """

        let result = try await runAppleScript(script)

        if result == "STOPPED" {
            return nil
        }

        let components = result.components(separatedBy: "|||")
        guard components.count >= 6 else {
            throw SpotifyError.parseError
        }

        let name = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let album = components[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let duration = (Double(components[3]) ?? 0) / 1000 // Spotify returns milliseconds
        let position = Double(components[4]) ?? 0
        let isPlaying = components[5].lowercased().contains("playing")

        return Track(
            name: name,
            artist: artist,
            album: album,
            duration: duration,
            position: position,
            isPlaying: isPlaying
        )
    }

    /// Execute an AppleScript and return the result
    private func runAppleScript(_ source: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)
                let result = script?.executeAndReturnError(&error)

                if let error = error {
                    let message = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                    continuation.resume(throwing: SpotifyError.scriptError(message))
                    return
                }

                let stringValue = result?.stringValue ?? ""
                continuation.resume(returning: stringValue)
            }
        }
    }
}
