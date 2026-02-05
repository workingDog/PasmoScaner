//
//  FelicaDecoder.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/04.
//
import SwiftUI
import Foundation
import CoreNFC


struct FelicaDecoder {
    
    func decodeHistoryDate(from block: Data) -> Date? {
        guard block.count >= 6 else { return nil }
        
        // correct big-endian bit-packed date
        let raw = Int(block[4]) << 8 | Int(block[5])
        
        let year  = 2000 + ((raw >> 9) & 0x7F)
        let month = (raw >> 5) & 0x0F
        let day   = raw & 0x1F
        
        guard (1...12).contains(month), (1...31).contains(day) else {
            return nil
        }
        
        return Calendar(identifier: .gregorian).date(
            from: DateComponents(year: year, month: month, day: day)
        )
    }
    
    // for testing
    func dumpBlock(_ block: Data, label: String) {
        let hex = block.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("\(label): \(hex)")
    }

    func decodeTransaction(from block: Data) -> FelicaTransaction {
        let type = block[1]
        let dateData = decodeHistoryDate(from: block)
        let date = dateData != nil ? dateData! : Date()
        let station = CardStation(areaCode: Int(block[3]), lineCode: Int(block[4]), stationCode: Int(block[5]))
        let balanceI16 = Int16(bitPattern: UInt16(block[11]) << 8 | UInt16(block[10]))
        let balance = Int(balanceI16)
        
        return FelicaTransaction(date: date, type: type, station: station, balance: balance)
    }
 
}

struct FelicaTransaction: Identifiable {
    let id = UUID()
    var date: Date
    var type: UInt8
    var station: CardStation?
    var balance: Int
    var event: TransitEvent = .entry
}

enum TransitEvent: String, Codable {
    case entry
    case exit
}

struct CardStation {
    var areaCode: Int
    var lineCode: Int
    var stationCode: Int
    var stationName: String = ""
}
