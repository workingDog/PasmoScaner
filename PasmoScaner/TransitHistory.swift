//
//  TransitHistory.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/04.
//
import Foundation


struct TransitHistory: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Int
}

extension Data {
    func hexString() -> String {
        map { String(format: "%02X", $0) }.joined()
    }
}

