//
//  AppError.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import Foundation

/// App-wide error enumeration for clearer diagnostics
enum AppError: Error, CustomStringConvertible {
    case missingAPIKey
    case badURL(String)
    case httpStatus(Int, String)
    case decoding(String)
    case noResults(String)

    var description: String {
        switch self {
        case .missingAPIKey: return "Missing API key"
        case .badURL(let u): return "Bad URL: \(u)"
        case .httpStatus(let c, let b): return "HTTP \(c): \(b)"
        case .decoding(let m): return "Decoding error: \(m)"
        case .noResults(let what): return "No results: \(what)"
        }
    }
} // AppError
