import Foundation

struct Fact: Identifiable, Equatable {
    let id: UUID
    let content: String
    let category: Category
    let source: String
    let isLongForm: Bool  // For longer insights/analysis

    enum Category: String, CaseIterable {
        case artist = "Artist"
        case track = "Track"
        case album = "Album"
        case genre = "Genre"
        case lyrics = "Lyrics"  // New category for lyrical analysis

        var icon: String {
            switch self {
            case .artist: return "person.fill"
            case .track: return "music.note"
            case .album: return "square.stack"
            case .genre: return "guitars"
            case .lyrics: return "text.quote"
            }
        }
    }

    init(content: String, category: Category, source: String = "Wikipedia", isLongForm: Bool = false) {
        self.id = UUID()
        self.content = content
        self.category = category
        self.source = source
        self.isLongForm = isLongForm
    }
}
