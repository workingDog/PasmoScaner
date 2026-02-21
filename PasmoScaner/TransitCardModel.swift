//
//  TransitCardModel.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/04.
//
import SwiftUI
import Foundation
import CoreNFC


@Observable
final class TransitCardModel {
    
    var balance: Int?
    var history: [FelicaTransaction] = []
    
    var isScanning = false
    var errorMessage: String?
    
    private let session = ReaderSession()
    private let felicaDecoder = FelicaDecoder()
    
    init() { }
    
    @MainActor
    func scan() async {
        isScanning = true
        errorMessage = nil
        do {
            let card = try await session.scan()
            balance = try await felicaDecoder.readBalance(from: card)
            history = try await felicaDecoder.readHistory(from: card, count: 11)
            session.invalidate()
        } catch {
            errorMessage = error.localizedDescription
            session.invalidate(errorMessage: "Scan failed")
        }
        isScanning = false    
    }
    
    func clear() {
        balance = nil
        history = []
        errorMessage = nil
    }
    
}
