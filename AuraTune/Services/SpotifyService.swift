import Foundation

final class SpotifyService {
    static let shared = SpotifyService()

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[SpotifyService] \(message)")
        #endif
    }

    private struct AccessToken {
        let value: String
        let expiresAt: Date

        var isValid: Bool {
            Date().addingTimeInterval(30) < expiresAt
        }
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let tokenType: String
        let expiresIn: Int

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
        }
    }

    private struct SearchResponse: Decodable {
        struct TrackContainer: Decodable {
            let items: [Track]

            enum CodingKeys: String, CodingKey {
                case items
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                items = try container.decodeIfPresent([Track].self, forKey: .items) ?? []
            }
        }

        struct Track: Decodable {
            struct Artist: Decodable {
                let name: String

                enum CodingKeys: String, CodingKey {
                    case name
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
                }
            }

            let name: String
            let artists: [Artist]
            let explicit: Bool
            let popularity: Int

            enum CodingKeys: String, CodingKey {
                case name
                case artists
                case explicit
                case popularity
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
                artists = try container.decodeIfPresent([Artist].self, forKey: .artists) ?? []
                explicit = try container.decodeIfPresent(Bool.self, forKey: .explicit) ?? false
                popularity = try container.decodeIfPresent(Int.self, forKey: .popularity) ?? 0
            }
        }

        let tracks: TrackContainer
    }

    enum SpotifyError: LocalizedError {
        case missingCredentials
        case unauthorized
        case badResponse
        case noCandidates

        var errorDescription: String? {
            switch self {
            case .missingCredentials:
                return "Spotify credentials are missing."
            case .unauthorized:
                return "Spotify authorization failed."
            case .badResponse:
                return "Spotify API returned an invalid response."
            case .noCandidates:
                return "Spotify could not find enough song candidates."
            }
        }
    }

    private var cachedToken: AccessToken?

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
            throw SpotifyError.noCandidates
        }

        debugLog("Daily suggestion picked: \(picked.name) | \(artistDisplay(from: picked.artists))")

        return SongSuggestion(
            title: picked.name,
            artist: artistDisplay(from: picked.artists),
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
            throw SpotifyError.noCandidates
        }

        debugLog("Daily mix selected successfully: count=\(selected.count)")

        return selected.map {
            SongSuggestion(
                title: $0.name,
                artist: artistDisplay(from: $0.artists),
                message: mixMessage(interfaceLanguage: interfaceLanguage)
            )
        }
    }

    func resolveTrackURI(title: String, artist: String) async -> String? {
        do {
            let token = try await accessToken()
            let query = "track:\"\(title)\" artist:\"\(artist)\""

            let strict = try await performSearchRequest(
                query: query,
                market: nil,
                token: token,
                limit: nil,
                offset: nil
            )

            if strict.statusCode == 200, let uri = extractTrackURI(from: strict.data) {
                debugLog("Resolved track URI (strict): \(uri)")
                return uri
            }

            let relaxed = try await performSearchRequest(
                query: "\(title) \(artist)",
                market: nil,
                token: token,
                limit: nil,
                offset: nil
            )

            if relaxed.statusCode == 200, let uri = extractTrackURI(from: relaxed.data) {
                debugLog("Resolved track URI (relaxed): \(uri)")
                return uri
            }

            debugLog("Could not resolve track URI for title=\(title), artist=\(artist)")
            return nil
        } catch {
            debugLog("Track URI resolve failed. error=\(error.localizedDescription)")
            return nil
        }
    }

    private func fetchCandidates(
        genres: [String],
        songLanguagePreference: SongLanguagePreference,
        excluding: [SongSuggestion],
        targetCount: Int
    ) async throws -> [SearchResponse.Track] {
        debugLog("Fetching candidates from Spotify API. targetCount=\(targetCount)")
        let token = try await accessToken()
        let market = market(for: songLanguagePreference)
        let excludedKeys = Set(excluding.map(\ .stableKey))
        let queries = buildQueries(from: genres, songLanguagePreference: songLanguagePreference)
        debugLog("Search plan. market=\(market), queries=\(queries.count)")

        var uniqueTracks: [SearchResponse.Track] = []
        var seenKeys = Set<String>()

        for query in queries {
            debugLog("Search query=\(query)")
            let tracks: [SearchResponse.Track]
            do {
                tracks = try await searchTracks(
                    query: query,
                    market: market,
                    token: token
                )
            } catch {
                debugLog("Search query failed and skipped. query=\(query), error=\(error.localizedDescription)")
                continue
            }
            debugLog("Search result count=\(tracks.count) for query=\(query)")

            for track in tracks where !track.explicit {
                guard !track.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                guard track.artists.contains(where: { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { continue }
                let stableKey = SongSuggestion(title: track.name, artist: artistDisplay(from: track.artists), message: "").stableKey
                if excludedKeys.contains(stableKey) { continue }
                if !seenKeys.insert(stableKey).inserted { continue }
                uniqueTracks.append(track)
            }

            if uniqueTracks.count >= targetCount {
                break
            }
        }

        debugLog("Unique candidate count after filtering=\(uniqueTracks.count)")

        return uniqueTracks.sorted { $0.popularity > $1.popularity }
    }

    private func buildQueries(from genres: [String], songLanguagePreference: SongLanguagePreference) -> [String] {
        let cleanedGenres = genres
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var queries: [String] = []

        switch songLanguagePreference {
        case .turkish:
            // Turkish-specific queries first for strong Turkish results
            let turkishPrefixes = ["türkçe", "turkish"]
            let turkishGenres = ["pop", "rock", "rap", "indie", "slow", "arabesk", "akustik"]

            queries.append("türkçe pop 2024")
            queries.append("turkish hits")
            queries.append("türkçe şarkılar")

            // Add user genres with Turkish prefix
            for genre in cleanedGenres.shuffled().prefix(3) {
                let lowered = genre.lowercased()
                if !lowered.contains("türk") && !lowered.contains("turkish") {
                    queries.append("türkçe \(genre)")
                } else {
                    queries.append(genre)
                }
            }

            // Add some Turkish genre combos
            for tg in turkishGenres.shuffled().prefix(2) {
                queries.append("türkçe \(tg)")
            }

            queries.append("yeni türkçe müzik")

        case .english:
            let base = cleanedGenres.isEmpty ? ["pop", "indie", "alternative", "dance"] : Array(cleanedGenres.shuffled().prefix(4))
            queries = base.map { "\($0) music" }
            queries.insert("english pop hits", at: 0)
            queries.append("uk indie")
            queries.append("new music 2024")

        case .random:
            // Mix Turkish and English queries for variety
            let base = cleanedGenres.isEmpty ? ["pop", "indie", "alternative"] : Array(cleanedGenres.shuffled().prefix(3))
            // Half Turkish
            queries.append("türkçe pop 2024")
            queries.append("türkçe şarkılar")
            for genre in base.prefix(1) {
                queries.append("türkçe \(genre)")
            }
            // Half English
            queries.append("english pop hits")
            queries.append("new music 2024")
            for genre in base.suffix(from: min(1, base.count)) {
                queries.append("\(genre) music")
            }
        }

        return orderedUnique(queries)
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.lowercased()).inserted }
    }

    private func accessToken() async throws -> String {
        if let cachedToken, cachedToken.isValid {
            debugLog("Using cached access token")
            return cachedToken.value
        }

        let clientID = Secrets.spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = Secrets.spotifyClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            throw SpotifyError.missingCredentials
        }

        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let credentials = "\(clientID):\(clientSecret)"
        guard let credentialData = credentials.data(using: .utf8) else {
            throw SpotifyError.unauthorized
        }
        request.setValue("Basic \(credentialData.base64EncodedString())", forHTTPHeaderField: "Authorization")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard statusCode == 200 else {
            debugLog("Access token request failed with status=\(statusCode)")
            throw SpotifyError.unauthorized
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        let token = AccessToken(
            value: decoded.accessToken,
            expiresAt: Date().addingTimeInterval(Double(decoded.expiresIn))
        )
        cachedToken = token
        debugLog("Fetched new access token, expiresIn=\(decoded.expiresIn)s")
        return token.value
    }

    private func searchTracks(
        query: String,
        market: String,
        token: String
    ) async throws -> [SearchResponse.Track] {
        debugLog("Trying strict search. query=\(query), market=\(market)")
        let initialResult = try await performSearchRequest(
            query: query,
            market: market,
            token: token,
            limit: nil,
            offset: nil
        )

        if initialResult.statusCode == 200 {
            if let items = decodeTracks(from: initialResult.data, context: "strict") {
                return items
            }

            debugLog("Strict search returned 200 but payload was not decodable, continuing with fallback attempts")
        }

        debugLog("Search failed with status=\(initialResult.statusCode), query=\(query), body=\(errorBodySnippet(from: initialResult.data))")

        debugLog("Retrying without market. query=\(query)")
        let noMarketResult = try await performSearchRequest(
            query: query,
            market: nil,
            token: token,
            limit: nil,
            offset: nil
        )

        if noMarketResult.statusCode == 200, let items = decodeTracks(from: noMarketResult.data, context: "no-market") {
            return items
        }

        debugLog("No-market retry failed. status=\(noMarketResult.statusCode), query=\(query), body=\(errorBodySnippet(from: noMarketResult.data))")

        let relaxedQuery = relaxedQuery(from: query)
        debugLog("Retrying with relaxed query and no market. query=\(relaxedQuery)")

        let relaxedResult = try await performSearchRequest(
            query: relaxedQuery,
            market: nil,
            token: token,
            limit: nil,
            offset: nil
        )

        if relaxedResult.statusCode == 200, let items = decodeTracks(from: relaxedResult.data, context: "relaxed") {
            return items
        }

        debugLog("Relaxed search failed. status=\(relaxedResult.statusCode), query=\(relaxedQuery), body=\(errorBodySnippet(from: relaxedResult.data))")

        throw SpotifyError.badResponse
    }

    private func performSearchRequest(
        query: String,
        market: String?,
        token: String,
        limit: Int?,
        offset: Int?
    ) async throws -> (statusCode: Int, data: Data) {
        var components = URLComponents(string: "https://api.spotify.com/v1/search")
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track")
        ]

        if let limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }

        if let offset {
            queryItems.append(URLQueryItem(name: "offset", value: "\(offset)"))
        }

        if let market, !market.isEmpty {
            queryItems.append(URLQueryItem(name: "market", value: market))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        return (statusCode: statusCode, data: data)
    }

    private func decodeTracks(from data: Data, context: String) -> [SearchResponse.Track]? {
        do {
            return try JSONDecoder().decode(SearchResponse.self, from: data).tracks.items
        } catch {
            debugLog("Track decode failed in \(context). error=\(error.localizedDescription), body=\(errorBodySnippet(from: data))")
            return nil
        }
    }

    private func extractTrackURI(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tracks = json["tracks"] as? [String: Any],
              let items = tracks["items"] as? [[String: Any]] else {
            return nil
        }

        for item in items {
            if let uri = item["uri"] as? String, uri.hasPrefix("spotify:track:") {
                return uri
            }
        }

        return nil
    }

    private func relaxedQuery(from query: String) -> String {
        query
            .replacingOccurrences(of: "genre:\"", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func errorBodySnippet(from data: Data) -> String {
        let raw = String(data: data, encoding: .utf8) ?? "<non-utf8-body>"
        return String(raw.prefix(240))
    }

    private func market(for songLanguagePreference: SongLanguagePreference) -> String {
        switch songLanguagePreference {
        case .turkish:
            return "TR"
        case .english:
            return "US"
        case .random:
            return "TR"
        }
    }

    private func artistDisplay(from artists: [SearchResponse.Track.Artist]) -> String {
        artists.prefix(2).map(\ .name).joined(separator: ", ")
    }

    private func dailyMessage(interfaceLanguage: String) -> String {
        interfaceLanguage == "en"
            ? "Fresh pick from Spotify's catalog for today."
            : "Bugun senin icin Spotify katalogundan taze bir secim yaptim."
    }

    private func mixMessage(interfaceLanguage: String) -> String {
        interfaceLanguage == "en"
            ? "Built from Spotify with a fresh vibe."
            : "Spotify katalogundan cesitli bir Daily Mix hazirladim."
    }
}
