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
    
    var stationCodes: [StationCode] = []

    var isScanning = false
    var balance: Int?
    var history: [FelicaTransaction] = []
    var errorMessage: String?

    private let session = AsyncFeliCaSession()
    private let felicaDecoder = FelicaDecoder()
    
    init() {
        self.stationCodes = getStationCodes()
    }
    
    func getStationCodes() -> [StationCode] {
        do {
            let path = Bundle.main.path(forResource: "stationcodes2", ofType: "json")!
            let fileURL = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            return try JSONDecoder().decode([StationCode].self, from: data)
        } catch {
            print(error)
        }
        return []
    }

    @MainActor
    func scan() async {
        isScanning = true
        errorMessage = nil
        do {
            let tag = try await session.scan()
            balance = try await readBalance(from: tag)
            history = try await readHistory(from: tag, count: 10)
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

    func readHistory(from tag: NFCFeliCaTag, count: Int) async throws -> [FelicaTransaction] {
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
        
        let hist = blocks.compactMap { block -> FelicaTransaction? in
            guard block.count == 16 else { return nil }
            guard felicaDecoder.decodeHistoryDate(from: block) != nil else { return nil }
            let felicaTrans = felicaDecoder.decodeTransaction(from: block)
            return felicaTrans
        }

        return updatedHist(hist.reversed())
    }
    
    func updatedHist(_ hist: [FelicaTransaction]) -> [FelicaTransaction] {
        var enrichedHist: [FelicaTransaction] = []
        var hasOpenEntry = false

        for var trans in hist {

            // Ignore non-railway records
            guard trans.station != nil else {
                enrichedHist.append(trans)
                continue
            }

            let isExit: Bool

            if !hasOpenEntry {
                // Not currently in a trip → this must be entry
                isExit = false
                hasOpenEntry = true
            } else {
                // Already inside a trip → this must be exit
                isExit = true
                hasOpenEntry = false
            }
            
            if let station = trans.station,
               let jr = stationCodes.first(where: {
                   $0.areaCode == station.areaCode &&
                   $0.stationCode == station.stationCode
               }) {
                if isExit {
                    trans.station?.stationName = jr.stationName + " ->"
                } else {
                    trans.station?.stationName = "-> " + jr.stationName
                }
            }
            
            enrichedHist.append(trans)
        }
        
        return enrichedHist.reversed()
    }

}
