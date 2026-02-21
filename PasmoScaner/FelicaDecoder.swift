//
//  FelicaDecoder.swift
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

struct FelicaDecoder {
    
    func readBalance(from card: NFCFeliCaTag) async throws -> Int {
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
    
    func readHistory(from card: NFCFeliCaTag, count: Int) async throws -> [FelicaTransaction] {
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
            guard decodeHistoryDate(from: block) != nil else { return nil }
            let felicaTrans = decodeTransaction(from: block)
            return felicaTrans
        }
        
        for i in 0..<allTrans.count - 1 {
            allTrans[i].previousBalance = allTrans[i + 1].balance
        }
        
        for i in 0..<allTrans.count {
            allTrans[i].kind = determineKind(for: allTrans[i])
        }
        
        return allTrans.dropLast()
    }
    
    private func decodeHistoryDate(from block: Data) -> Date? {
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
    private func dumpBlock(_ block: Data, label: String) {
        let hex = block.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("\(label): \(hex)")
    }
    
    private func decodeTransaction(from block: Data) -> FelicaTransaction {
        
        let machine = FelicaMachineType(raw: block[0])
        let process = FelicaProcessType(raw: block[1])
        
        let date = decodeHistoryDate(from: block) ?? Date()
        let balanceI16 = Int16(bitPattern: UInt16(block[11]) << 8 | UInt16(block[10]))
        let balance = Int(balanceI16)
        let cardStation = decodeCardStation(from: block)
        
        return FelicaTransaction(
            date: date,
            machineType: machine,
            processType: process,
            kind: .unknown(block[1]),  // placeholder
            station: cardStation,
            balance: balance
        )
    }
    
    private func decodeCardStation(from block: Data) -> CardStation? {
        let area = Int(block[3])
        let line = Int(block[4])
        let station = Int(block[5])
        return CardStation(areaCode: area, lineCode: line, stationCode: station, romanjiName: nil)
    }
    
    // need to redo this, very brittle  <-----
    private func determineKind(for tx: FelicaTransaction) -> FelicaTransactionKind {
        
        let txDelta = tx.delta ?? 0
        
        switch (tx.processType, tx.machineType) {
            
            // 🚃 Train gate
        case (.farePayment, .gate):
            return .train(station: tx.station ?? CardStation(areaCode: 0, lineCode: 0, stationCode: 0, stationName: "", romanjiName: nil))
            
            // 🚌 Bus
        case (.busFare, _), (.farePayment, .bus):
            return .bus(stop: CardBusStop(operatorCode: 0, stopCode: 0, stopName: nil))
            
            // 💳 Charge anywhere
        case (.charge, _):
            return .charge(ChargeTransaction(amount: abs(txDelta)))
            
            // 🛒 Retail purchase
        case (.retail, _):
            return .retail(RetailTransaction(terminalType: 0, amount: abs(txDelta)))
            
            // 🎫 Ticket purchase
        case (.ticketPurchase, _):
            return .retail(RetailTransaction(terminalType: 0, amount: abs(txDelta)))
            
            // 🔧 Adjustment
        case (.adjustment, _):
            return .retail(RetailTransaction(terminalType: 0, amount: abs(txDelta)))
            
        default:
            return determineMachineType(for: tx)  // <----
        }
    }
    
    private func determineProcessType(for tx: FelicaTransaction) -> FelicaTransactionKind {
        
        let txDelta = tx.delta ?? 0
        let process = tx.processType
        
        switch process {
            
            // 🚃 Train fare (gate)
        case .farePayment:
            return .train(
                station: tx.station ??
                CardStation(areaCode: 0, lineCode: 0, stationCode: 0, stationName: "", romanjiName: nil)
            )
            
            // 🚌 Bus
        case .busFare:
            return .bus(stop: CardBusStop(operatorCode: 0, stopCode: 0, stopName: nil))
            
            // 💳 Charge
        case .charge:
            return .charge(ChargeTransaction(amount: txDelta))
            
            // 🛒 Retail purchase
        case .retail:
            return .retail(RetailTransaction(terminalType: 0, amount: abs(txDelta)))
            
            // 🎫 Ticket purchase
        case .ticketPurchase:
            return .retail(RetailTransaction(terminalType: 0, amount: abs(txDelta)))
            
            // 🔧 Adjustment
        case .adjustment:
            return .retail(RetailTransaction(terminalType: 0, amount: abs(txDelta)))
            
        case .unknown:
            return .unknown(process.rawValue)
        }
    }
    
    private func determineMachineType(for tx: FelicaTransaction) -> FelicaTransactionKind {
        
        let txDelta = tx.delta ?? 0
        
        switch tx.machineType {
            
            // 🚃 TRAIN GATE
        case .gate:
            return .train(
                station: tx.station ?? CardStation(areaCode: 0, lineCode: 0, stationCode: 0, stationName: "", romanjiName: nil)
            )
            
            // 🚌 BUS
        case .bus:
            return .bus(stop: CardBusStop(operatorCode: 0, stopCode: 0, stopName: nil))
            
            // 🛒 RETAIL
        case .retail:
            return .retail(RetailTransaction(terminalType: 0, amount: abs(txDelta)))
            
            // 💳 CHARGE MACHINE
        case .chargeMachine:
            if abs(txDelta) > 0 {
                return .charge(
                    ChargeTransaction(amount: txDelta)
                )
            }
            
        default:
            return determineProcessType(for: tx)  // <----
        }
        
        return .unknown(tx.processType.rawValue)
    }
    
    

/*
    private func decodeStation(from block: Data) -> FelicaTransactionKind {
        let area = Int(block[3])
        let line = Int(block[4])
        let station = Int(block[5])
        let cardStation = CardStation(areaCode: area, lineCode: line, stationCode: station, romanjiName: nil)
        
        return .train(station: cardStation)
    }
    
    private func decodeBus(from block: Data) -> FelicaTransactionKind {
        let operatorCode = Int(block[3])
        let stopCode = Int(block[4])
        let busStop = CardBusStop(operatorCode: operatorCode, stopCode: stopCode, stopName: nil)
        
        return .bus(stop: busStop)
    }
    
    private func handleRetail(from block: Data) -> FelicaTransactionKind {
        let amount = Int(block[1]) == 0 ? nil : Int(block[1])
        let retail = RetailTransaction(terminalType: block[0], amount: amount)
        
        return .retail(retail)
    }
    
    private func handleCharge(from block: Data) -> FelicaTransactionKind {
        let balanceI16 = Int16(bitPattern: UInt16(block[11]) << 8 | UInt16(block[10]))
        let balance = Int(balanceI16)
        let charge = ChargeTransaction(amount: balance)
        
        return .charge(charge)
    }
    */
 
}
