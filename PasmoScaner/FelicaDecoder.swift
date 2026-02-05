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
        let type = block[1]
        
        let date = decodeHistoryDate(from: block)!
        
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
}

struct CardStation {
    var areaCode: Int
    var lineCode: Int
    var stationCode: Int
    var stationName: String = ""
}

// for file stationcodes2.json
struct StationCode: Identifiable, Codable {
    let id = UUID()
    
    var areaCode, lineCode, stationCode: Int?
    var company, line, stationName: String
    
    enum CodingKeys: String, CodingKey {
        case areaCode, lineCode, stationCode
        case company, line, stationName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Area code is already decimal
        self.areaCode = try container.decodeIfPresent(Int.self, forKey: .areaCode)

        // Decode HEX strings
        let lineCodeHex = try container.decodeIfPresent(String.self, forKey: .lineCode)
        let stationCodeHex = try container.decodeIfPresent(String.self, forKey: .stationCode)

        // Convert hex → decimal
        self.lineCode = lineCodeHex.flatMap { Int($0, radix: 16) }
        self.stationCode = stationCodeHex.flatMap { Int($0, radix: 16) }

        self.company = try container.decode(String.self, forKey: .company)
        self.line = try container.decode(String.self, forKey: .line)
        self.stationName = try container.decode(String.self, forKey: .stationName)
    }

    // for file stationcodes.json
//    struct StationCode2: Identifiable, Codable {
//        let id = UUID()
//        
//        var areaCode, lineCode, stationCode: Int?
//        var company, line, stationName: String
//
//        enum CodingKeys: String, CodingKey {
//            case areaCode = "RegionCode"
//            case lineCode = "LineCode"
//            case stationCode = "StationCode"
//            
//            case company = "Company"
//            case line = "Line"
//            case stationName = "StationName"
//        }
//    }

}
