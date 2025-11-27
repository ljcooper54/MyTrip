//
//  OnChangeCompat.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import SwiftUI

/// Back-compat `.onChange` that uses the modern two-parameter closure on iOS 17+
/// and the classic single-parameter version on iOS 16.
extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(
        of value: V,
        perform: @escaping (_ newValue: V) -> Void
    ) -> some View {
        if #available(iOS 17, *) {
            self.onChange(of: value) { _, newValue in perform(newValue) }
        } else {
            self.onChange(of: value) { newValue in perform(newValue) }
        }
    } // onChangeCompat
} // extension View
