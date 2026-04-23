import Foundation

/// Service to interact with Gemini API
class GeminiService {
    static let shared = GeminiService()
    
    /// Gemini API Key
    private let apiKey = "AIzaSyC9YlDHFP3TrB3iViWOzUU7wAmUR6rGMI8"
    
    func getSongSuggestion(genres: [String], time: Date, language: String = "Turkish") async throws -> SongSuggestion {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        // Construct prompt depending on language (so Gemini understands the context better)
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        let timeString = formatter.string(from: time)
        
        let genreString = genres.joined(separator: ", ")
        
        let prompt = """
        User's local time: \(timeString).
        User's favorite genres: \(genreString).
        Recommend a specific song for the user's "morning energy".
        If there's a specific morning vibe based on the time, shape the recommendation around it.
        SADECE aşağıdaki JSON formatında ve SADECE \(language) dilinde SOHBET MESAJI (message) oluşturarak yanıt ver. Başlık ve sanatçı orijinal kalabilir.
        Please return ONLY in this JSON format:
        {
          "title": "Song Title",
          "artist": "Artist name",
          "message": "A short and energetic good morning message in \(language)"
        }
        """

        
        // Construct the request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]
        
        let requestData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Parse the Gemini Response
        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable {
                        let text: String
                    }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let jsonText = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw URLError(.cannotParseResponse)
        }
        
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        
        let suggestion = try JSONDecoder().decode(SongSuggestion.self, from: jsonData)
        return suggestion
    }
}
