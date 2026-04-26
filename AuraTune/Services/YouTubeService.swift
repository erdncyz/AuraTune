import Foundation

final class YouTubeService {
    static let shared = YouTubeService()

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[YouTubeService] \(message)")
        #endif
    }

    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            struct ItemID: Decodable {
                let videoId: String?
            }

            struct Snippet: Decodable {
                let title: String
                let channelTitle: String
            }

            let id: ItemID
            let snippet: Snippet
        }

        let items: [Item]
    }

    private struct Candidate {
        let title: String
        let artist: String
    }

    enum YouTubeError: LocalizedError {
        case missingAPIKey
        case badResponse
        case noCandidates

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "YouTube API key is missing."
            case .badResponse:
                return "YouTube API returned an invalid response."
            case .noCandidates:
                return "YouTube could not find enough song candidates."
            }
        }
    }

    private init() {}

    func getDailySuggestion(
        genres: [String],
        songLanguagePreference: SongLanguagePreference,
        interfaceLanguage: String,
        excluding: [SongSuggestion]
    ) async throws -> SongSuggestion {
        debugLog("Daily suggestion requested. genres=\(genres.count), langPref=\(songLanguagePreference.rawValue), excluding=\(excluding.count)")
        let candidates = try await fetchCandidates(
            genres: genres,
            songLanguagePreference: songLanguagePreference,
            excluding: excluding,
            targetCount: 25
        )

        debugLog("Daily suggestion candidates ready: count=\(candidates.count)")

        guard let picked = candidates.randomElement() else {
            throw YouTubeError.noCandidates
        }

        debugLog("Daily suggestion picked: \(picked.title) | \(picked.artist)")

        return SongSuggestion(
            title: picked.title,
            artist: picked.artist,
            message: dailyMessage(interfaceLanguage: interfaceLanguage)
        )
    }

    func getDailyMix(
        genres: [String],
        songLanguagePreference: SongLanguagePreference,
        interfaceLanguage: String,
        excluding: [SongSuggestion],
        count: Int
    ) async throws -> [SongSuggestion] {
        debugLog("Daily mix requested. count=\(count), genres=\(genres.count), excluding=\(excluding.count)")
        let candidates = try await fetchCandidates(
            genres: genres,
            songLanguagePreference: songLanguagePreference,
            excluding: excluding,
            targetCount: max(count * 8, 30)
        )

        debugLog("Daily mix candidates ready: count=\(candidates.count)")

        let selected = Array(candidates.shuffled().prefix(count))
        guard selected.count == count else {
            throw YouTubeError.noCandidates
        }

        debugLog("Daily mix selected successfully: count=\(selected.count)")

        return selected.map {
            SongSuggestion(
                title: $0.title,
                artist: $0.artist,
                message: mixMessage(interfaceLanguage: interfaceLanguage)
            )
        }
    }

    func resolveVideoID(title: String, artist: String) async -> String? {
        let key = Secrets.youtubeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        let strictQuery = "\(artist) \(title) official audio"
        let relaxedQuery = "\(artist) \(title)"

        do {
            let strictItems = try await searchVideos(query: strictQuery, regionCode: "TR", key: key)
            if let id = strictItems.compactMap(\ .id.videoId).first {
                debugLog("Resolved video ID (strict): \(id)")
                return id
            }

            let relaxedItems = try await searchVideos(query: relaxedQuery, regionCode: "TR", key: key)
            if let id = relaxedItems.compactMap(\ .id.videoId).first {
                debugLog("Resolved video ID (relaxed): \(id)")
                return id
            }

            debugLog("Could not resolve video ID for title=\(title), artist=\(artist)")
            return nil
        } catch {
            debugLog("Video ID resolve failed. error=\(error.localizedDescription)")
            return nil
        }
    }

    private func fetchCandidates(
        genres: [String],
        songLanguagePreference: SongLanguagePreference,
        excluding: [SongSuggestion],
        targetCount: Int
    ) async throws -> [Candidate] {
        debugLog("Fetching candidates from YouTube API. targetCount=\(targetCount)")
        let key = Secrets.youtubeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw YouTubeError.missingAPIKey
        }

        let excludedKeys = Set(excluding.map(\ .stableKey))
        let queries = buildQueries(from: genres, songLanguagePreference: songLanguagePreference)
        debugLog("Search plan. region=\(regionCode(for: songLanguagePreference)), queries=\(queries.count)")

        var uniqueCandidates: [Candidate] = []
        var seenKeys = Set<String>()

        for query in queries {
            debugLog("Search query=\(query)")
            let items = try await searchVideos(
                query: query,
                regionCode: regionCode(for: songLanguagePreference),
                key: key
            )
            debugLog("Search result count=\(items.count) for query=\(query)")

            for item in items {
                guard item.id.videoId != nil else { continue }
                let candidate = normalize(item: item)
                guard !candidate.title.isEmpty, !candidate.artist.isEmpty else { continue }

                let key = SongSuggestion(title: candidate.title, artist: candidate.artist, message: "").stableKey
                if excludedKeys.contains(key) { continue }
                if !seenKeys.insert(key).inserted { continue }

                uniqueCandidates.append(candidate)
            }

            if uniqueCandidates.count >= targetCount {
                break
            }
        }

        debugLog("Unique candidate count after filtering=\(uniqueCandidates.count)")

        return uniqueCandidates
    }

    private func searchVideos(query: String, regionCode: String, key: String) async throws -> [SearchResponse.Item] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoCategoryId", value: "10"),
            URLQueryItem(name: "maxResults", value: "25"),
            URLQueryItem(name: "safeSearch", value: "strict"),
            URLQueryItem(name: "regionCode", value: regionCode),
            URLQueryItem(name: "key", value: key)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            debugLog("Search failed with status=\(statusCode), query=\(query)")
            throw YouTubeError.badResponse
        }

        return try JSONDecoder().decode(SearchResponse.self, from: data).items
    }

    private func buildQueries(from genres: [String], songLanguagePreference: SongLanguagePreference) -> [String] {
        let cleanedGenres = genres
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var queries: [String] = []

        switch songLanguagePreference {
        case .turkish:
            queries.append("türkçe pop şarkılar official audio")
            queries.append("turkish music official audio")
            queries.append("yeni türkçe şarkılar")

            for genre in cleanedGenres.shuffled().prefix(3) {
                let lowered = genre.lowercased()
                if !lowered.contains("türk") && !lowered.contains("turkish") {
                    queries.append("türkçe \(genre) official audio")
                } else {
                    queries.append("\(genre) official audio")
                }
            }

            queries.append("türkçe slow şarkılar official")
            queries.append("türkçe rap official audio")

        case .english:
            let base = cleanedGenres.isEmpty ? ["pop", "indie", "dance"] : Array(cleanedGenres.shuffled().prefix(4))
            queries = base.map { "\($0) official audio" }
            queries.insert("english pop official audio", at: 0)
            queries.append("indie english song official")
            queries.append("new music official audio")

        case .random:
            // Mix Turkish and English queries for variety
            let base = cleanedGenres.isEmpty ? ["pop", "indie", "dance"] : Array(cleanedGenres.shuffled().prefix(3))
            // Half Turkish
            queries.append("türkçe pop şarkılar official audio")
            queries.append("yeni türkçe müzik")
            for genre in base.prefix(1) {
                queries.append("türkçe \(genre) official audio")
            }
            // Half English
            queries.append("english pop official audio")
            queries.append("new music official audio")
            for genre in base.suffix(from: min(1, base.count)) {
                queries.append("\(genre) official audio")
            }
        }

        return Array(Set(queries))
    }

    private func normalize(item: SearchResponse.Item) -> Candidate {
        let cleanedTitle = cleanupTitle(item.snippet.title)

        if let split = splitArtistAndTitle(cleanedTitle) {
            return Candidate(title: split.title, artist: split.artist)
        }

        return Candidate(
            title: cleanedTitle,
            artist: cleanupChannel(item.snippet.channelTitle)
        )
    }

    private func splitArtistAndTitle(_ value: String) -> (artist: String, title: String)? {
        let separators = [" - ", " | ", " : "]
        for separator in separators {
            let parts = value.components(separatedBy: separator)
            if parts.count >= 2 {
                let left = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let right = parts[1...].joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
                if !left.isEmpty, !right.isEmpty {
                    return (artist: left, title: right)
                }
            }
        }
        return nil
    }

    private func cleanupTitle(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)official|lyric video|lyrics|audio|video|hd|4k", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanupChannel(_ value: String) -> String {
        value
            .replacingOccurrences(of: "(?i)- topic", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func regionCode(for songLanguagePreference: SongLanguagePreference) -> String {
        switch songLanguagePreference {
        case .turkish:
            return "TR"
        case .english:
            return "US"
        case .random:
            return "TR"
        }
    }

    private func dailyMessage(interfaceLanguage: String) -> String {
        interfaceLanguage == "en"
            ? "Fresh pick from YouTube Music search today."
            : "Bugun senin icin YouTube Music tarafindan taze bir secim yaptim."
    }

    private func mixMessage(interfaceLanguage: String) -> String {
        interfaceLanguage == "en"
            ? "Built from YouTube Music with varied energy."
            : "YouTube Music tarafindan cesitli bir Daily Mix hazirladim."
    }
}
