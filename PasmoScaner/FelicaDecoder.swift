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
    
    func decodeHistoryAmount(from block: Data) -> Int {
        let raw = Int16(bitPattern: UInt16(block[11]) << 8 | UInt16(block[10]))
        return Int(raw)
    }
    
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
    
    func dumpBlock(_ block: Data, label: String) {
        let hex = block.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("\(label): \(hex)")
    }
    
    func decodeTransaction(from block: Data) -> FelicaTransaction {
        let type = TransactionType(raw: block[0])
        let date = decodeHistoryDate(from: block)!
        
        let station = Station(areaCode: String(format: "%02X", block[3]),lineCode: String(format: "%02X", block[4]), stationCode: String(format: "%02X", block[5]))
  
        let balanceI16 = Int16(bitPattern: UInt16(block[11]) << 8 | UInt16(block[10]))
        let balance = Int(balanceI16)
        
        return FelicaTransaction(date: date,type: type, station: station, balance: balance)
    }
 
}

struct FelicaTransaction: Identifiable {
    let id = UUID()
    var date: Date
    var type: TransactionType
    var station: Station?
    var balance: Int
}

struct Station {
    var areaCode: String
    var lineCode: String
    var stationCode: String
    var stationName: String = ""
}

enum TransactionType: UInt8 {
    case fare = 0x01
    case charge = 0x02
    case bus = 0x0D
    case unknown
    
    init(raw: UInt8) {
        self = TransactionType(rawValue: raw) ?? .unknown
    }
}

struct JRStation: Identifiable, Codable {
    let id = UUID()
    
    var lineCode: String
    var stationCode: String
    var stationName: String
    var areaCode: String
    var lineName: String

    enum CodingKeys: String, CodingKey {
        case areaCode = "地区コード(16進)"
        case lineCode = "線区コード(16進)"
        case stationCode = "駅順コード(16進)"
        case lineName = "線区名"
        case stationName = "駅名"
    }
}
