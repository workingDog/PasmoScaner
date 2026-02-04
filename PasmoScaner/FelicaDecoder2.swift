//
//  FelicaDecoder2.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/04.
//
//import SwiftUI
//import Foundation
//import CoreNFC
//
//
//
//
//struct FelicaDecoder {
//    
//    func decodeHistoryAmount(from block: Data) -> Int {
//        let raw = Int16(bitPattern: UInt16(block[11]) << 8 | UInt16(block[10]))
//        return Int(raw)
//    }
//    
//    func decodeHistoryDate(from block: Data) -> Date? {
//        guard block.count >= 6 else { return nil }
//        
//        // correct big-endian bit-packed date
//        let raw = Int(block[4]) << 8 | Int(block[5])
//        
//        let year  = 2000 + ((raw >> 9) & 0x7F)
//        let month = (raw >> 5) & 0x0F
//        let day   = raw & 0x1F
//        
//        guard (1...12).contains(month), (1...31).contains(day) else {
//            return nil
//        }
//        
//        return Calendar(identifier: .gregorian).date(
//            from: DateComponents(year: year, month: month, day: day)
//        )
//    }
//    
//    func dumpBlock(_ block: Data, label: String) {
//        let hex = block.map { String(format: "%02X", $0) }.joined(separator: " ")
//        print("\(label): \(hex)")
//    }
//    
//    func decodeTransaction(block: Data) -> FelicaTransaction {
//        let type = TransactionType(raw: block[0])
//        
//        let date = decodeHistoryDate(from: block)!
//        //decodeFelicaDate(block[2], block[3])
//        
//        let entry = Station( lineCode: block[4], stationCode: block[5])
//        
//        let exit = Station(lineCode: block[6], stationCode: block[7] )
//        
//        let balance = Int(block[8]) << 8 | Int(block[9])
//        
//        return FelicaTransaction(date: date,type: type, entry: entry,exit: exit, balance: balance)
//    }
//}
//
//struct FelicaTransaction {
//    let raw: RawFelicaTransaction
//
//    let date: Date
//    let transactionType: TransactionType
//    let processType: ProcessType
//
//    let entryStation: Station?
//    let exitStation: Station?
//
//    let balanceAfter: Int
//    let regionCode: UInt8
//}
//
//struct RawFelicaTransaction {
//    let bytes: Data
//
//    var transactionType: UInt8 { bytes[0] }
//    var processType: UInt8 { bytes[1] }
//
//    var dateHigh: UInt8 { bytes[2] }
//    var dateLow: UInt8 { bytes[3] }
//
//    var entryLine: UInt8 { bytes[4] }
//    var entryStation: UInt8 { bytes[5] }
//
//    var exitLine: UInt8 { bytes[6] }
//    var exitStation: UInt8 { bytes[7] }
//
//    var balance: UInt16 {
//        UInt16(bytes[8]) << 8 | UInt16(bytes[9])
//    }
//
//    var regionCode: UInt8 { bytes[10] }
//}
//
//enum TransactionType: UInt8 {
//    case fare              = 0x01
//    case charge            = 0x02
//    case ticketPurchase    = 0x03
//    case adjustment        = 0x04
//    case bus               = 0x0D
//    case retail            = 0x46
//    case unknown
//}
//
//enum ProcessType: UInt8 {
//    case gateIn             = 0x01
//    case gateOut            = 0x02
//    case fareAdjustment     = 0x03
//    case charge             = 0x04
//    case bus                = 0x0D
//    case vendingMachine     = 0x46
//    case unknown
//}
//
//struct Station {
//    let lineCode: UInt8
//    let stationCode: UInt8
//    let name: String
//}
//
//
//
