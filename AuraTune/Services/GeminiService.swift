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
        songLanguagePreference: SongLanguagePreference = .random
    ) async throws -> SongSuggestion {
        let prompt = buildPrompt(
            genres: genres,
            time: time,
            responseLanguage: responseLanguage,
            songLanguagePreference: songLanguagePreference
        )
        #if DEBUG
        print("[AIService] Primary: Groq → llama-3.3-70b-versatile")
        #endif
        do {
            return try await fetchFromGroq(prompt: prompt)
        } catch AIError.rateLimited {
            #if DEBUG
            print("[AIService] Groq rate limited (429) → Fallback: Gemini 2.5 Flash Lite")
            #endif
            return try await fetchFromGemini(prompt: prompt)
        }
    }

    func getSongSuggestionForMood(
        mood: String,
        genres: [String],
        responseLanguage: String = "Turkish",
        songLanguagePreference: SongLanguagePreference = .random
    ) async throws -> SongSuggestion {
        let prompt = buildMoodPrompt(
            mood: mood,
            genres: genres,
            responseLanguage: responseLanguage,
            songLanguagePreference: songLanguagePreference
        )
        #if DEBUG
        print("[AIService] Discover request — mood: \(mood)")
        print("[AIService] Primary: Groq → llama-3.3-70b-versatile")
        #endif
        do {
            return try await fetchFromGroq(prompt: prompt)
        } catch AIError.rateLimited {
            #if DEBUG
            print("[AIService] Groq rate limited (429) → Fallback: Gemini 2.5 Flash Lite")
            #endif
            return try await fetchFromGemini(prompt: prompt)
        }
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
        songLanguagePreference: SongLanguagePreference
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        let timeString = formatter.string(from: time)
        let genreString = genres.joined(separator: ", ")
        let seed = Int.random(in: 1...9999)
        let moods = ["uplifting", "chill", "energetic", "soulful", "nostalgic", "powerful", "dreamy", "warm", "vibrant", "peaceful"]
        let randomMood = moods.randomElement() ?? "uplifting"
        return """
        User's local time: \(timeString).
        User's favorite genres: \(genreString).
        Variety seed: \(seed). Use this to ensure a unique, non-repeated recommendation.
        Pick a song with a \(randomMood) feel.
                \(songLanguagePreference.promptInstruction)
        Recommend a DIFFERENT specific song each time — do not repeat popular or obvious choices.
        Explore deep cuts, hidden gems, or lesser-known tracks when possible.
                SADECE aşağıdaki JSON formatında ve SADECE \(responseLanguage) dilinde SOHBET MESAJI (message) oluşturarak yanıt ver. Başlık ve sanatçı orijinal kalabilir.
        Please return ONLY in this JSON format:
        {
          "title": "Song Title",
          "artist": "Artist name",
                    "message": "A short and energetic good morning message in \(responseLanguage)"
        }
        """
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
                SADECE aşağıdaki JSON formatında ve SADECE \(responseLanguage) dilinde SOHBET MESAJI (message) oluşturarak yanıt ver. Başlık ve sanatçı orijinal kalabilir.
        Please return ONLY in this JSON format:
        {
          "title": "Song Title",
          "artist": "Artist name",
                    "message": "A short personalized message matching the mood in \(responseLanguage)"
        }
        """
    }

    // MARK: Groq (primary)

    private func fetchFromGroq(prompt: String) async throws -> SongSuggestion {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw URLError(.badURL)
        }

        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [["role": "user", "content": prompt]],
            "response_format": ["type": "json_object"],
            "temperature": 1.2
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
        return try parseGroqResponse(data: data)
    }

    private func parseGroqResponse(data: Data) throws -> SongSuggestion {
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
        return try JSONDecoder().decode(SongSuggestion.self, from: jsonData)
    }

    // MARK: Gemini (fallback)

    private func fetchFromGemini(prompt: String) async throws -> SongSuggestion {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(Secrets.geminiAPIKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 1.2
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
        return try parseGeminiResponse(data: data)
    }

    private func parseGeminiResponse(data: Data) throws -> SongSuggestion {
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
        return try JSONDecoder().decode(SongSuggestion.self, from: jsonData)
    }
}
