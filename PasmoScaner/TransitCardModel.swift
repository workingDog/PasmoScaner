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

    var isScanning = false
    var balance: Int?
    var history: [TransitHistory] = []
    var errorMessage: String?

    private let session = AsyncFeliCaSession()
    private let felicaDecoder = FelicaDecoder()
    
    init() { }

    @MainActor
    func scan() async {
        isScanning = true
        errorMessage = nil
        do {
            let tag = try await session.scan()
            balance = try await readBalance(from: tag)
            history = try await readHistory(from: tag)
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

    func readBalance(from tag: NFCFeliCaTag) async throws -> Int {

        let serviceCode: UInt16 = 0x008B

        let serviceCodeList = [
            Data([UInt8(serviceCode & 0xFF), UInt8(serviceCode >> 8)])
        ]

        let blockList = [ Data([0x80, 0x00]) ]

        let (sf1, sf2, blocks) = try await tag.readWithoutEncryption(
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

    func readHistory(from tag: NFCFeliCaTag, count: Int = 10) async throws -> [TransitHistory] {

        let serviceCode: UInt16 = 0x090F

        let serviceCodeList = [Data([UInt8(serviceCode & 0xFF), UInt8(serviceCode >> 8)])]

        let blockList = (0..<count).map {
            Data([0x80, UInt8($0)])
        }

        let (sf1, sf2, blocks) = try await tag.readWithoutEncryption(
            serviceCodeList: serviceCodeList,
            blockList: blockList
        )

        guard sf1 == 0x00, sf2 == 0x00 else {
            throw NFCError.readFailed
        }

        return blocks.compactMap { block -> TransitHistory? in
            guard block.count == 16 else { return nil }
            guard let date = felicaDecoder.decodeHistoryDate(from: block) else { return nil }

            let amount = felicaDecoder.decodeHistoryAmount(from: block)
            
//            felicaDecoder.dumpBlock(block, label: "readHistory")
//            let felica: FelicaTransaction = felicaDecoder.decodeTransaction(block: block)
//            print("----> felica: \(felica)\n")
            
            return TransitHistory(date: date, amount: amount)
        }
    }

}


