//
//  File.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//

// Copyright 2025 H2so4 Consulting LLC
import Foundation

/// Lightweight debug logger with timestamp and thread tag
@inline(__always) func dlog(_ tag: String, _ msg: @autoclosure () -> String) {
    #if DEBUG
    let t = Thread.isMainThread ? "MAIN" : "BG"
    let ts = ISO8601DateFormatter().string(from: Date())
    print("[\(ts)] [\(t)] [\(tag)] \(msg())")
    #endif
} // dlog
