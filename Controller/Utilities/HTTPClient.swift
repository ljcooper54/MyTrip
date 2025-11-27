//
//  HTTPClient.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import Foundation

/// Thin HTTP helper adding uniform logging and status/body surfacing
struct HTTPClient {
    /// GET and return (data, httpResponse) or throw AppError.httpStatus
    static func get(_ url: URL, tag: String) async throws -> (Data, HTTPURLResponse) {
        dlog(tag, "GET → \(url.absoluteString)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse else {
            throw AppError.httpStatus(-1, "<no http>") // HTTPClient.get
        }
        if !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            dlog(tag, "HTTP \(http.statusCode) body: \(body)")
            throw AppError.httpStatus(http.statusCode, body) // HTTPClient.get
        }
        return (data, http)
    } // get
} // HTTPClient
