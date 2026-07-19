import Foundation

/// Service to interact with AI APIs with automatic fallback:
/// Primary: Groq (llama-3.3-70b) → Fallback: Gemini 2.5 Flash Lite
class GeminiService {
    static let shared = GeminiService()

    // MARK: - Public

    func getSongSuggestion(
        genres: [String],
        time: Date,
        responseLanguage: String = "Turkish",
        songLanguagePreference: SongLanguagePreference = .random,
        excluding excludedSongs: [SongSuggestion] = []
    ) async throws -> SongSuggestion {
        let excludedKeys = Set(excludedSongs.map(\ .stableKey))
        var attempts = 0

        while attempts < 8 {
            attempts += 1

            let prompt = buildPrompt(
                genres: genres,
                time: time.addingTimeInterval(Double(attempts) * 31),
                responseLanguage: responseLanguage,
                songLanguagePreference: songLanguagePreference,
                excludedSongs: excludedSongs
            )

            do {
                let suggestion = try await fetchSuggestion(prompt: prompt, responseLanguage: responseLanguage)
                let availability = await SpotifyService.shared.validateTrack(
                    title: suggestion.title,
                    artist: suggestion.artist
                )
                if !excludedKeys.contains(suggestion.stableKey), availability != false {
                    return suggestion
                }

                #if DEBUG
                print("[AIService] Rejected duplicate or unverified suggestion: \(suggestion.stableKey)")
                #endif
            } catch {
                #if DEBUG
                print("[AIService] Suggestion attempt \(attempts) failed: \(error.localizedDescription)")
                #endif
            }
        }

        throw AIError.badResponse
    }

    func getSongSuggestionForMood(
        mood: String,
        genres: [String],
        responseLanguage: String = "Turkish",
        songLanguagePreference: SongLanguagePreference = .random
    ) async throws -> SongSuggestion {
        var lastError: Error?

        for attempt in 1...3 {
            let prompt = buildMoodPrompt(
                mood: mood,
                genres: genres,
                responseLanguage: responseLanguage,
                songLanguagePreference: songLanguagePreference
            )
            #if DEBUG
            print("[AIService] Discover request — mood: \(mood), attempt: \(attempt)")
            #endif

            do {
                let suggestion: SongSuggestion
                do {
                    suggestion = try await fetchFromGroq(prompt: prompt, responseLanguage: responseLanguage)
                } catch {
                    suggestion = try await fetchFromGemini(prompt: prompt, responseLanguage: responseLanguage)
                }

                let availability = await SpotifyService.shared.validateTrack(
                    title: suggestion.title,
                    artist: suggestion.artist
                )
                if availability != false {
                    return suggestion
                }
            } catch {
                lastError = error
            }
        }

        throw lastError ?? AIError.badResponse
    }

    func generateSongCommentary(
        title: String,
        artist: String,
        responseLanguage: String = "Turkish",
        mood: String? = nil
    ) async -> String {
        let prompt = buildCommentaryPrompt(
            title: title,
            artist: artist,
            responseLanguage: responseLanguage,
            mood: mood
        )

        do {
            let message = try await fetchCommentaryFromGroq(prompt: prompt)
            return sanitizeMessage(message, responseLanguage: responseLanguage)
        } catch {
            #if DEBUG
            print("[AIService] Groq commentary failed (\(error.localizedDescription)) → Fallback Gemini")
            #endif

            do {
                let message = try await fetchCommentaryFromGemini(prompt: prompt)
                return sanitizeMessage(message, responseLanguage: responseLanguage)
            } catch {
                #if DEBUG
                print("[AIService] Gemini commentary failed (\(error.localizedDescription)) → Using default commentary")
                #endif
                return defaultCommentary(responseLanguage: responseLanguage, title: title, artist: artist)
            }
        }
    }

    // MARK: - Water Motivations

    /// Fetches a batch of motivational water-drinking messages from AI (Groq → Gemini fallback)
    func getWaterMotivationMessages(
        count: Int = 12,
        language: String = "Turkish",
        dailyGoalLiters: Double = 2.0
    ) async throws -> [String] {
        let targetGlasses = max(1, Int((dailyGoalLiters / 0.25).rounded()))
        let litersText = String(format: "%.1f", dailyGoalLiters)
        let varietySeed = Int.random(in: 10_000...99_999)
        let prompt = """
        Write exactly \(count) polished water-break notification messages in \(language) for a premium wellness app.
        Variety seed: \(varietySeed).
        The user's daily plan is \(litersText) liters (~\(targetGlasses) glasses), but mention the exact number in at most 2 messages.
        Each message must be one natural sentence between 45 and 110 characters.
        Build a genuinely varied set: calm, warm, lightly playful, focused, poetic, and practical.
        Cover morning, afternoon, and evening contexts without writing time labels.
        Do not reuse the same opening words, sentence structure, metaphor, call to action, or emoji.
        Use an emoji in no more than half of the messages, placed naturally at either end.
        Avoid generic slogans, exclamation-heavy copy, guilt, pressure, medical claims, detox claims, or promises about energy, skin, metabolism, focus, and weight.
        Never say that missing water is harmful. Never diagnose or prescribe.
        Return ONLY a valid JSON array of strings with no other text, no markdown, no code blocks:
        ["message1", "message2", ...]
        """
        do {
            return try await fetchMotivationMessagesFromGroq(prompt: prompt, expected: count)
        } catch {
            return try await fetchMotivationMessagesFromGemini(prompt: prompt, expected: count)
        }
    }

    private func fetchMotivationMessagesFromGroq(prompt: String, expected: Int) async throws -> [String] {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.95,
            "top_p": 0.9,
            "max_tokens": 1400
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if status == 429 { throw AIError.rateLimited }
        guard status == 200 else { throw AIError.badResponse }

        struct GroqResp: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String }
                let message: Msg
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(GroqResp.self, from: data)
        guard let content = decoded.choices.first?.message.content else { throw AIError.parseFailure }
        return try parseMessagesArray(from: content, expected: expected)
    }

    private func fetchMotivationMessagesFromGemini(prompt: String, expected: Int) async throws -> [String] {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(Secrets.geminiAPIKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.95,
                "topP": 0.9,
                "maxOutputTokens": 1400
            ]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AIError.badResponse }

        struct GemResp: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }
        let decoded = try JSONDecoder().decode(GemResp.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first?.text else { throw AIError.parseFailure }
        return try parseMessagesArray(from: text, expected: expected)
    }

    private func parseMessagesArray(from text: String, expected: Int) throws -> [String] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = cleaned.firstIndex(of: "["),
              let end = cleaned.lastIndex(of: "]") else {
            throw AIError.parseFailure
        }
        let jsonStr = String(cleaned[start...end])
        guard let jsonData = jsonStr.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: jsonData) else {
            throw AIError.parseFailure
        }

        var unique: [String] = []
        for rawMessage in array {
            let message = rawMessage
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !message.isEmpty, message.count <= 115 else { continue }
            guard !unique.contains(where: { waterMessagesAreTooSimilar(message, $0) }) else { continue }
            unique.append(message)
            if unique.count == expected { break }
        }

        guard unique.count >= min(expected, 6) else {
            throw AIError.parseFailure
        }
        return unique
    }

    private func waterMessagesAreTooSimilar(_ lhs: String, _ rhs: String) -> Bool {
        let leftTokens = waterMessageTokens(lhs)
        let rightTokens = waterMessageTokens(rhs)
        guard !leftTokens.isEmpty, !rightTokens.isEmpty else {
            return lhs.caseInsensitiveCompare(rhs) == .orderedSame
        }

        let overlap = leftTokens.intersection(rightTokens).count
        let total = leftTokens.union(rightTokens).count
        return Double(overlap) / Double(total) >= 0.68
    }

    private func waterMessageTokens(_ message: String) -> Set<String> {
        Set(
            message
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count > 2 }
        )
    }

    func getDailyMix(
        genres: [String],
        responseLanguage: String = "Turkish",
        songLanguagePreference: SongLanguagePreference = .random,
        excluding mainSuggestion: SongSuggestion,
        excludingSongs: [SongSuggestion] = []
    ) async throws -> [SongSuggestion] {
        var results: [SongSuggestion] = []
        var exclusionPool: [SongSuggestion] = [mainSuggestion] + excludingSongs
        var seenKeys: Set<String> = Set(exclusionPool.map(\ .stableKey))
        var attempts = 0

        while results.count < 5 && attempts < 20 {
            attempts += 1

            let candidate = try await getSongSuggestion(
                genres: genres,
                time: Date().addingTimeInterval(Double(attempts) * 97),
                responseLanguage: responseLanguage,
                songLanguagePreference: songLanguagePreference,
                excluding: exclusionPool
            )

            if seenKeys.contains(candidate.stableKey) {
                continue
            }

            seenKeys.insert(candidate.stableKey)
            results.append(candidate)
            exclusionPool.append(candidate)
        }

        guard results.count == 5 else {
            throw AIError.badResponse
        }

        return results
    }

    // MARK: - Private

    private enum AIError: Error {
        case rateLimited
        case badResponse
        case parseFailure
    }

    private func buildPrompt(
        genres: [String],
        time: Date,
        responseLanguage: String,
        songLanguagePreference: SongLanguagePreference,
        excludedSongs: [SongSuggestion]
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        let timeString = formatter.string(from: time)
        let genreString = genres.joined(separator: ", ")
        let seed = Int.random(in: 1...9999)
        let moods = ["uplifting", "chill", "energetic", "soulful", "nostalgic", "powerful", "dreamy", "warm", "vibrant", "peaceful"]
        let randomMood = moods.randomElement() ?? "uplifting"
        let avoidInstruction = makeAvoidedSongsInstruction(from: excludedSongs)
        return """
        User's local time: \(timeString).
        User's favorite genres: \(genreString).
        Variety seed: \(seed). Use this to ensure a unique, non-repeated recommendation.
        Pick a song with a \(randomMood) feel.
                \(songLanguagePreference.promptInstruction)
        Recommend a DIFFERENT specific song each time.
        The song and artist MUST be real, correctly spelled, officially released, and available on major streaming services.
        Never invent a title, artist, collaboration, remix, or release.
        Prioritize a strong match to the user's favorite genres, balancing trusted favorites with worthwhile discovery.
        \(avoidInstruction)
            SADECE aşağıdaki JSON formatında ve SADECE \(responseLanguage) dilinde SOHBET MESAJI (message) oluşturarak yanıt ver. Mesaj içinde başka dil, alfabe veya yabancı karakter kullanma. Başlık ve sanatçı orijinal kalabilir.
        Please return ONLY in this JSON format:
        {
          "title": "Song Title",
          "artist": "Artist name",
                    "message": "A short and energetic good morning message in \(responseLanguage)"
        }
        """
    }

    private func buildCommentaryPrompt(
        title: String,
        artist: String,
        responseLanguage: String,
        mood: String?
    ) -> String {
        let moodText = mood?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let moodInstruction = moodText.isEmpty ? "" : "Mood context: \(moodText). Use it naturally if it helps the line feel more relevant."

        return """
        You are a music-savvy friend writing a short, soulful recommendation line for a mobile music app.
        Song title: \(title)
        Artist: \(artist)
        \(moodInstruction)
        Language: \(responseLanguage)

        Rules:
        - Maximum 20 words.
        - One sentence only.
        - Capture the soul and emotional essence of this specific song.
        - If you know the song: describe what makes it special — its emotional turning point, the feeling in the vocals, the atmosphere it creates, or the story it tells. Be specific to THIS song.
        - If you don't know the song well: describe the artist's signature style and what kind of emotional journey to expect.
        - Use sensory, evocative language — describe sounds, feelings, imagery the song evokes.
        - Sound like a friend who truly loves this song sharing why it matters to them.
        - Be warm, intimate, and genuine — not like a critic or a review.
        - Avoid generic praise: no "harika", "efsane", "masterpiece", "must listen", "kesinlikle dinle", "mutlaka".
        - Do not use hashtags or emojis.
        - Do not use quotation marks.
        - Return only the sentence.

        Great style examples:
        - Piyanonun ilk notasından itibaren içini bir hüzün saracak, ama hoş bir hüzün.
        - Bas gitar omurganı titretirken vokal sanki kulağına fısıldıyor, garip ama bağımlılık yapıyor.
        - Sözleri basit ama tam kalbine dokunan cinsten, yalnız bir aksam için biçilmiş kaftan.
        - The guitar riff lingers like a memory you can't shake, and the chorus hits even harder the second time.
        - A slow burn that builds into something unexpectedly beautiful by the final verse.
        """
    }

    private func makeAvoidedSongsInstruction(from excludedSongs: [SongSuggestion]) -> String {
        let uniqueSongs = Dictionary(grouping: excludedSongs, by: \ .stableKey)
            .compactMap { $0.value.first }
            .prefix(10)

        guard !uniqueSongs.isEmpty else {
            return "Avoid exact repeats from recent suggestions and favorites."
        }

        let items = uniqueSongs
            .map { "- \($0.title) — \($0.artist)" }
            .joined(separator: "\n")

        return """
        NEVER recommend any of these songs exactly:
        \(items)
        """
    }

    private func fetchSuggestion(prompt: String, responseLanguage: String) async throws -> SongSuggestion {
        #if DEBUG
        print("[AIService] Primary: Groq → llama-3.3-70b-versatile")
        #endif
        do {
            return try await fetchFromGroq(prompt: prompt, responseLanguage: responseLanguage)
        } catch {
            #if DEBUG
            print("[AIService] Groq failed (\(error.localizedDescription)) → Fallback: Gemini 2.5 Flash Lite")
            #endif
            return try await fetchFromGemini(prompt: prompt, responseLanguage: responseLanguage)
        }
    }

    private func fetchCommentaryFromGroq(prompt: String) async throws -> String {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw URLError(.badURL)
        }

        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.7,
            "max_tokens": 80
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            throw AIError.badResponse
        }

        struct GroqResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(GroqResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw AIError.parseFailure
        }

        return content
    }

    private func fetchCommentaryFromGemini(prompt: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(Secrets.geminiAPIKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "responseMimeType": "text/plain",
                "temperature": 0.7
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            throw AIError.badResponse
        }

        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let content = decoded.candidates.first?.content.parts.first?.text.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw AIError.parseFailure
        }

        return content
    }

    private func defaultCommentary(responseLanguage: String, title: String, artist: String) -> String {
        if responseLanguage.lowercased() == "english" {
            return "\(title) by \(artist) has a steady pull that makes it easy to stay with."
        }

        return "\(artist) - \(title), duygusunu hızlı veren ve içine kolay girilen bir parça."
    }

        private func buildMoodPrompt(
                mood: String,
                genres: [String],
                responseLanguage: String,
                songLanguagePreference: SongLanguagePreference
        ) -> String {
        let genreString = genres.isEmpty ? "any genre" : genres.joined(separator: ", ")
        let seed = Int.random(in: 1...9999)
        let eras = ["60s", "70s", "80s", "90s", "2000s", "2010s", "recent"]
        let randomEra = eras.randomElement() ?? "recent"
        return """
        The user is currently feeling: \(mood).
        User's favorite genres: \(genreString).
        Variety seed: \(seed). Use this to ensure a unique, non-repeated recommendation.
                \(songLanguagePreference.promptInstruction)
        Try recommending a track from the \(randomEra) era if it fits the mood.
        Pick a DIFFERENT song each time — avoid repeating the same artist or song. Explore unexpected, creative choices.
        The song and artist MUST be real, correctly spelled, officially released, and available on major streaming services.
        Never invent a title, artist, collaboration, remix, or release.
                SADECE aşağıdaki JSON formatında ve SADECE \(responseLanguage) dilinde SOHBET MESAJI (message) oluşturarak yanıt ver. Mesaj içinde başka dil, alfabe veya yabancı karakter kullanma. Başlık ve sanatçı orijinal kalabilir.
        Please return ONLY in this JSON format:
        {
          "title": "Song Title",
          "artist": "Artist name",
                    "message": "A short personalized message matching the mood in \(responseLanguage)"
        }
        """
    }

    // MARK: Groq (primary)

    private func fetchFromGroq(prompt: String, responseLanguage: String) async throws -> SongSuggestion {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw URLError(.badURL)
        }

        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [["role": "user", "content": prompt]],
            "response_format": ["type": "json_object"],
            "temperature": 0.8
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1

        if status == 429 {
            #if DEBUG
            print("[AIService] Groq 429 rate limit hit")
            #endif
            throw AIError.rateLimited
        }

        guard status == 200 else {
            #if DEBUG
            print("[AIService] Groq error: status=\(status) body=\(String(data: data, encoding: .utf8) ?? "")")
            #endif
            throw AIError.badResponse
        }

        #if DEBUG
        print("[AIService] Groq response OK (status=200)")
        #endif
        return try parseGroqResponse(data: data, responseLanguage: responseLanguage)
    }

    private func parseGroqResponse(data: Data, responseLanguage: String) throws -> SongSuggestion {
        struct GroqResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let groqResponse = try JSONDecoder().decode(GroqResponse.self, from: data)
        guard let jsonText = groqResponse.choices.first?.message.content,
              let jsonData = jsonText.data(using: .utf8) else {
            throw AIError.parseFailure
        }
                let suggestion = try JSONDecoder().decode(SongSuggestion.self, from: jsonData)
                return sanitizeSuggestion(suggestion, responseLanguage: responseLanguage)
    }

    // MARK: Gemini (fallback)

    private func fetchFromGemini(prompt: String, responseLanguage: String) async throws -> SongSuggestion {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(Secrets.geminiAPIKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.8
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1

        guard status == 200 else {
            #if DEBUG
            print("[AIService] Gemini error: status=\(status) body=\(String(data: data, encoding: .utf8) ?? "")")
            #endif
            throw AIError.badResponse
        }

        #if DEBUG
        print("[AIService] Gemini response OK (status=200)")
        #endif
        return try parseGeminiResponse(data: data, responseLanguage: responseLanguage)
    }

    private func parseGeminiResponse(data: Data, responseLanguage: String) throws -> SongSuggestion {
        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let jsonText = geminiResponse.candidates.first?.content.parts.first?.text,
              let jsonData = jsonText.data(using: .utf8) else {
            throw AIError.parseFailure
        }
        let suggestion = try JSONDecoder().decode(SongSuggestion.self, from: jsonData)
        return sanitizeSuggestion(suggestion, responseLanguage: responseLanguage)
    }

    private func sanitizeSuggestion(_ suggestion: SongSuggestion, responseLanguage: String) -> SongSuggestion {
        SongSuggestion(
            title: suggestion.title,
            artist: suggestion.artist,
            message: sanitizeMessage(suggestion.message, responseLanguage: responseLanguage)
        )
    }

    private func sanitizeMessage(_ message: String, responseLanguage: String) -> String {
        guard ["turkish", "english"].contains(responseLanguage.lowercased()) else {
            return message
        }

        let tokens = message.split(whereSeparator: \ .isWhitespace)
        let cleanedTokens = tokens.filter { token in
            !containsUnexpectedScript(in: String(token))
        }

        let cleaned = cleanedTokens.joined(separator: " ")
            .replacingOccurrences(of: "\\s+([,.;:!?])", with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? message : cleaned
    }

    private func containsUnexpectedScript(in token: String) -> Bool {
        token.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF,
                 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xAC00...0xD7AF,
                 0x0600...0x06FF,
                 0x0400...0x04FF,
                 0x0900...0x097F:
                return true
            default:
                return false
            }
        }
    }
}
