// Copyright 2025 H2so4 Consulting LLC
// File: Services/OpenAIPhotoLinkService.swift

import Foundation

/// Service that asks ChatGPT (gpt-4o-mini) for a single **public-domain** iconic image link.
/// Logs presence of OPENAI_API_KEY with a masked print so you can confirm it's loaded.
/// OpenAIPhotoLinkService
struct OpenAIPhotoLinkService {

    enum ErrorType: Swift.Error {
        case missingKey
        case badResponse
        case decode
        case noContent
    } // end enum ErrorType

    /// Suggests a photo for the given location name and returns a TripImage.
    /// It prefers downloading & saving the image locally; if that fails, it
    /// still returns a TripImage with only `remoteURL` set.
    func suggestPhoto(for locationName: String) async throws -> TripImage {
        print("[OpenAI] suggestPhoto(for: \"\(locationName)\")")

        // First attempt
        let firstLink = try await fetchLink(from: locationName)
        if let downloaded = try? await saveImageFromRemote(firstLink) {
            return downloaded
        }

        // Fallback attempt with a second link to avoid broken URLs that render gray boxes.
        print("[OpenAI] First link failed to download, retrying with a new suggestion…")
        let retryLink = try await fetchLink(from: "\(locationName) landmark")
        if let downloaded = try? await saveImageFromRemote(retryLink) {
            return downloaded
        }

        print("[OpenAI] All attempts to download a suggested photo failed")
        throw ErrorType.badResponse
    } // end func suggestPhoto

    // MARK: - Private helpers

    /// Returns the OPENAI_API_KEY from Info.plist, or throws if missing.
    private func apiKey() throws -> String {
        let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String
        guard let value = key, !value.isEmpty else {
            print("[OpenAI] OPENAI_API_KEY not found in Info.plist")
            throw ErrorType.missingKey
        }
        let masked = String(value.prefix(5)) + "…" + String(value.suffix(4))
        print("[OpenAI] API key loaded: \(masked) (len: \(value.count))")
        return value
    } // end func apiKey

    /// Calls the OpenAI chat/completions endpoint and extracts a direct image URL.
    private func fetchLink(from locationName: String) async throws -> URL {
        let key = try apiKey()
        let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

        var req = URLRequest(url: endpoint, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        struct ChatMessage: Encodable {
            let role: String
            let content: String
        } // end struct ChatMessage

        struct ChatRequest: Encodable {
            let model: String
            let messages: [ChatMessage]
            let temperature: Double
        } // end struct ChatRequest

        let systemPrompt = """
        You are an image URL selector. Return EXACTLY ONE direct URL to a public-domain or freely usable iconic image for the requested location.

        Rules:
        - The URL MUST point directly to an image file and end with .jpg, .jpeg, .png, or .webp.
        - DO NOT return any page URLs like "https://commons.wikimedia.org/wiki/File:...".
        - DO NOT return markdown, HTML, captions, or extra text. Only the bare URL.
        """

        let userPrompt = """
        Give me one direct URL to a public-domain or freely usable iconic image for this location: "\(locationName)".
        Remember: the URL must be a direct image URL ending in .jpg, .jpeg, .png, or .webp.
        """

        let payload = ChatRequest(
            model: "gpt-4o-mini",
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.3
        )

        let body = try JSONEncoder().encode(payload)
        req.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            print("[OpenAI] HTTP failure: \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            throw ErrorType.badResponse
        }

        struct ChoiceMessage: Decodable {
            let content: String
        } // end struct ChoiceMessage

        struct Choice: Decodable {
            let message: ChoiceMessage
        } // end struct Choice

        struct ChatResponse: Decodable {
            let choices: [Choice]
        } // end struct ChatResponse

        let decoded: ChatResponse
        do {
            decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            print("[OpenAI] Decode error: \(error)")
            throw ErrorType.decode
        }

        guard let text = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            print("[OpenAI] Empty content in response")
            throw ErrorType.noContent
        }

        guard let urlString = extractFirstImageURL(in: text),
              let url = URL(string: urlString) else {
            print("[OpenAI] Could not parse direct image URL from response: \(text)")
            throw ErrorType.noContent
        }

        print("[OpenAI] Suggested URL: \(url.absoluteString)")
        return url
    } // end func fetchLink(from:)

    /// Extracts the first URL that looks like a direct image URL.
    private func extractFirstImageURL(in text: String) -> String? {
        // Match URLs ending with .jpg, .jpeg, .png, or .webp
        let pattern = #"https?://\S+\.(?:jpg|jpeg|png|webp)"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    } // end func extractFirstImageURL

    /// Simple binary download helper that throws if status != 200.
    private func downloadBinary(from url: URL) async throws -> Data {
        print("[OpenAI] downloadBinary: \(url.absoluteString)")
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "GET"
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            print("[OpenAI] downloadBinary: HTTP \(code) for \(url.absoluteString)")
            throw ErrorType.badResponse
        }
        return data
    } // end func downloadBinary

    /// Downloads a remote image and stores it locally when possible. Returns nil if the download fails.
    private func saveImageFromRemote(_ link: URL) async throws -> TripImage? {
        do {
            let data = try await downloadBinary(from: link)
            if let saved = try? ImageStore.shared.saveImage(data, source: .ai) {
                print("[OpenAI] Download & save succeeded: \(saved.fileURL?.absoluteString ?? "no local URL")")
                return TripImage(
                    id: saved.id,
                    fileURL: saved.fileURL,
                    remoteURL: link,
                    createdAt: saved.createdAt,
                    source: .ai
                )
            } else {
                print("[OpenAI] Downloaded image but failed to persist, using remote URL")
                return TripImage(
                    id: UUID(),
                    fileURL: nil,
                    remoteURL: link,
                    createdAt: Date(),
                    source: .ai
                )
            }
        } catch {
            print("[OpenAI] Unable to download suggested image: \(error)")
            return nil
        }
    } // end func saveImageFromRemote
} // end struct OpenAIPhotoLinkService

