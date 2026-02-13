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
        let machine = FelicaMachineType(raw: block[0])
        let process = FelicaProcessType(raw: block[1])
        let date = decodeHistoryDate(from: block) ?? Date()
        let balanceI16 = Int16(bitPattern: UInt16(block[11]) << 8 | UInt16(block[10]))
        let balance = Int(balanceI16)
        
        let kind = decodeTransactionKind(from: block)
        
        return FelicaTransaction(
            date: date,
            machineType: machine,
            processType: process,
            kind: kind,
            balance: balance
        )
    }
    
    func decodeTransactionKind(from block: Data) -> FelicaTransactionKind {
        let machineType = FelicaMachineType(raw: block[0])

        return switch machineType {
            case .gate: decodeStation(from: block)
            case .bus: decodeBus(from: block)
            case .retail: handleRetail(from: block)
            case .chargeMachine, .vendingMachine: handleCharge(from: block)
            default: .unknown(block[0])
        }
    }
    
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
 
}
