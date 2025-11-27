// Copyright H2so4 Consulting LLC 2025
// File: Services/OpenAIPhotoLinkService.swift

import Foundation

/// Service that asks ChatGPT 4o-mini for a single **public-domain** iconic image link.
/// Logs presence of OPENAI_API_KEY with a masked print so you can confirm it's loaded.
/// end struct OpenAIPhotoLinkService
struct OpenAIPhotoLinkService {

    enum ErrorType: Swift.Error { case missingKey, badResponse, decode, noContent } // end enum ErrorType

    func suggestPhoto(for locationName: String) async throws -> TripImage {
        let link = try await fetchLink(from: locationName)
        if let data = try? await downloadBinary(from: link),
           let saved = try? ImageStore.shared.saveImage(data, source: .ai) {
            return TripImage(id: saved.id, fileURL: saved.fileURL, remoteURL: link, createdAt: saved.createdAt, source: .ai)
        } else {
            return TripImage(id: UUID(), fileURL: nil, remoteURL: link, createdAt: Date(), source: .ai)
        }
    } // end func suggestPhoto(for:)

    // MARK: - Internals

    private func apiKey() throws -> String {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String else {
            print("[OpenAI] OPENAI_API_KEY not found in Info.plist") // why: diagnose integration
            throw ErrorType.missingKey
        }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            print("[OpenAI] OPENAI_API_KEY is empty")
            throw ErrorType.missingKey
        }
        // Log masked key so you can verify Secrets.xcconfig is wired in.
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        print("[OpenAI] API key loaded: \(prefix)…\(suffix) (len: \(key.count))")
        return key
    } // end func apiKey

    private func fetchLink(from locationName: String) async throws -> URL {
        let key = try apiKey()
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = "Give me a link to a public-domain picture, drawing, or photograph that is iconic for the location: \(locationName)"
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0,
            "messages": [
                ["role": "system", "content": "You return only one direct HTTP URL (no markdown, no commentary). Prefer Wikimedia Commons or other public-domain sources."],
                ["role": "user", "content": prompt]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            print("[OpenAI] HTTP status: \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            throw ErrorType.badResponse
        }

        struct R: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
            let choices: [Choice]
        } // end struct R

        let decoded = try JSONDecoder().decode(R.self, from: data)
        guard let text = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw ErrorType.noContent
        }
        guard let url = extractFirstURL(in: text).flatMap(URL.init(string:)) else {
            print("[OpenAI] Could not parse URL from response: \(text)")
            throw ErrorType.noContent
        }
        print("[OpenAI] Suggested URL: \(url.absoluteString)")
        return url
    } // end func fetchLink(from:)

    private func extractFirstURL(in text: String) -> String? {
        let pattern = #"https?://\S+"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    } // end func extractFirstURL

    private func downloadBinary(from url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "GET"
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw ErrorType.badResponse }
        return data
    } // end func downloadBinary
} // end struct OpenAIPhotoLinkService

