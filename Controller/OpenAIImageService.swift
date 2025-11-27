//
//  OpenAIImageService.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/26/25.
//


// =======================================
// File: Services/OpenAIImageService.swift
// =======================================

import Foundation

struct OpenAIImageService {
    struct GenerationResponse: Decodable {
        struct DataItem: Decodable { let b64_json: String }
        let data: [DataItem]
    }

    enum ServiceError: Error {
        case invalidKey, badResponse, noData
    }

    private let apiKey: String

    init() throws {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !key.isEmpty else {
            throw ServiceError.invalidKey
        }
        self.apiKey = key
    }

    mutating func generateIconicImage(for trip: Trip) async throws -> TripImage {
        let prompt = """
        A realistic, photorealistic iconic landmark photograph of \(trip.locationName).
        Golden-hour, professional travel photography, 50mm lens, high detail.
        """
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-image-1",
            "prompt": prompt,
            "size": "1024x1024",
            "response_format": "b64_json"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw ServiceError.badResponse }

        let decoded = try JSONDecoder().decode(GenerationResponse.self, from: data)
        guard let base64 = decoded.data.first?.b64_json, let imgData = Data(base64Encoded: base64) else {
            throw ServiceError.noData
        }
        return try ImageStore.shared.saveImage(imgData, source: .ai)
    }
}
