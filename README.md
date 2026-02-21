# Overture

A calm, educational music companion for macOS that displays Spotify now-playing information with AI-generated insights.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Spotify Integration** - Automatically detects currently playing track via AppleScript
- **Album Art Display** - Beautiful album artwork with adaptive color extraction
- **AI-Generated Insights** - Lyrics analysis, artist background, album context
- **Vinyl Label Generation** - AI-generated or real labels from Discogs
- **Ambient UI** - Smooth animations and color transitions
- **Playback Controls** - Keyboard and mouse shortcuts for play/pause and track navigation

## Controls

### Keyboard

| Key | Action |
|-----|--------|
| `Space` | Play / Pause |
| `←` | Previous track |
| `→` | Next track |

### Mouse

| Action | Effect |
|--------|--------|
| Single click on record | Play / Pause |
| Double click on record | Next track |

## Screenshots

*Coming soon*

## Requirements

- macOS 13.0 or later
- Spotify desktop app
- An AI provider API key (see Configuration)

## Installation

### From Release

1. Download the latest `Overture.dmg` from [Releases](https://github.com/oferhalevi/Overture/releases)
2. Open the DMG and drag Overture to Applications
3. On first run, right-click → Open (to bypass Gatekeeper for unsigned apps)
4. Grant permission to control Spotify when prompted

### Build from Source

```bash
git clone https://github.com/oferhalevi/Overture.git
cd Overture
open Overture.xcodeproj
```

Then build and run in Xcode (⌘R).

## Configuration

Open Settings (⌘,) to configure your AI provider.

### Supported AI Providers

| Provider | Chat | Vision | Image Gen | API Key Required |
|----------|------|--------|-----------|------------------|
| **OpenAI** | ✅ | ✅ | ✅ | Yes |
| **Anthropic** | ✅ | ✅ | ❌ | Yes |
| **OpenRouter** | ✅ | ✅ | ❌ | Yes |
| **Ollama** | ✅ | ❌ | ❌ | No |
| **Custom** | ✅ | ✅ | ✅ | Optional |

### Default Models

- **OpenAI**: `gpt-4o-mini` (chat), `dall-e-3` (images)
- **Anthropic**: `claude-3-haiku-20240307`
- **OpenRouter**: `anthropic/claude-3-haiku`
- **Ollama**: `llama3`
- **Custom**: `gpt-4.1-mini`, `gpt-image-1`

### Getting API Keys

- **OpenAI**: https://platform.openai.com/api-keys
- **Anthropic**: https://console.anthropic.com/
- **OpenRouter**: https://openrouter.ai/keys

### Custom/Local Endpoints

For local LLM servers (LM Studio, Ollama, etc.), select "Custom" provider and set your endpoint URL. The app uses OpenAI-compatible API format:

- Chat: `{endpoint}/v1/chat/completions`
- Images: `{endpoint}/v1/images/generations`

## How It Works

1. **Track Detection** - Polls Spotify every second via AppleScript
2. **Artwork Fetching** - Gets album art from Spotify Web API, iTunes, or MusicBrainz
3. **Color Extraction** - Analyzes dominant colors for UI adaptation
4. **Content Generation** - Fetches Wikipedia data and generates AI summaries
5. **Label Generation** - Searches Discogs for real vinyl labels, falls back to AI generation

## Privacy

- API keys are stored securely in macOS Keychain
- No data is sent to any server except your configured AI provider
- Wikipedia and Discogs are used for factual content (no authentication required)

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Album artwork from Spotify, iTunes, and MusicBrainz/Cover Art Archive
- Vinyl labels from Discogs
- Factual content from Wikipedia
