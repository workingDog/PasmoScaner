//
//  TransitCardModel.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/04.
//
import SwiftUI
import Foundation
import CoreNFC


enum NFCError: Error {
    case readFailed
    case invalidBlock
}

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
            balance = try await readBalance(from: card)
            history = try await readHistory(from: card, count: 10)
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
    
    private func readBalance(from card: NFCFeliCaTag) async throws -> Int {
        let serviceCode: UInt16 = 0x008B
        let serviceCodeList = [
            Data([UInt8(serviceCode & 0xFF), UInt8(serviceCode >> 8)])
        ]
        let blockList = [ Data([0x80, 0x00]) ]
        let (sf1, sf2, blocks) = try await card.readWithoutEncryption(
            serviceCodeList: serviceCodeList,
            blockList: blockList
        )
        guard sf1 == 0x00, sf2 == 0x00 else {
            throw NFCError.readFailed
        }
        guard let block = blocks.first, block.count == 16 else {
            throw NFCError.invalidBlock
        }
        // PASMO/Suica balance = bytes 11–12 (little-endian)
        let balance = Int(block[11]) | (Int(block[12]) << 8)
        return balance
    }
    
    private func readHistory(from card: NFCFeliCaTag, count: Int) async throws -> [FelicaTransaction] {
        let serviceCode: UInt16 = 0x090F
        let serviceCodeList = [Data([UInt8(serviceCode & 0xFF), UInt8(serviceCode >> 8)])]
        let blockList = (0..<count).map {
            Data([0x80, UInt8($0)])
        }
        let (sf1, sf2, blocks) = try await card.readWithoutEncryption(
            serviceCodeList: serviceCodeList,
            blockList: blockList
        )
        guard sf1 == 0x00, sf2 == 0x00 else {
            throw NFCError.readFailed
        }
        
        var allTrans = blocks.compactMap { block -> FelicaTransaction? in
            guard block.count == 16 else { return nil }
            guard felicaDecoder.decodeHistoryDate(from: block) != nil else { return nil }
            let felicaTrans = felicaDecoder.decodeTransaction(from: block)
            return felicaTrans
        }
        
        for i in 0..<allTrans.count - 1 {
            allTrans[i].previousBalance = allTrans[i + 1].balance
        }
        
        return allTrans
    }
    
}
