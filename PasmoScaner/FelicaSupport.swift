//
//  FelicaSupport.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/13.
//
import SwiftUI
import Foundation
import CoreNFC


struct TransactionDescriptor {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let category: TransactionCategory
    let amount: Int?
}

enum TransactionCategory {
    case transport
    case shopping
    case charge
    case unknown
}

struct FelicaTransaction: Identifiable {
    let id = UUID()
    var date: Date
    var machineType: FelicaMachineType
    var processType: FelicaProcessType
    var kind: FelicaTransactionKind
    var station: CardStation?
    var balance: Int
    var previousBalance: Int?
    var event: TransitEvent = .entry
}

extension FelicaTransaction {
    
    var descriptor: TransactionDescriptor {
        let amount = signedAmount
        
        return switch kind {
            
            // 🚃 TRAIN
            case .train(let station):
                TransactionDescriptor(
                    title: station.displayName,
                    subtitle: "Train • Balance ¥\(balance)",
                    systemImage: "tram.fill",
                    color: .blue,
                    category: .transport,
                    amount: nil
                )
            
            // 🚌 BUS
            case .bus(let stop):
                TransactionDescriptor(
                    title: stop.displayName,
                    subtitle: "Bus • Balance ¥\(balance)",
                    systemImage: "bus.fill",
                    color: .green,
                    category: .transport,
                    amount: nil
                )
            
            // 🛒 RETAIL
            case .retail:
                 TransactionDescriptor(
                    title: "Retail Purchase",
                    subtitle: amount != nil ? "¥\(abs(amount!))" : "Retail",
                    systemImage: "cart.fill",
                    color: .pink,
                    category: .shopping,
                    amount: amount
                )
            
            // 💳 CHARGE
            case .charge:
                 TransactionDescriptor(
                    title: "Card Charge",
                    subtitle: amount != nil ? "¥\(abs(amount!))" : "Charge",
                    systemImage: "creditcard.fill",
                    color: .purple,
                    category: .charge,
                    amount: amount
                )
            
            // ❓ UNKNOWN
            case .unknown(let raw):
                TransactionDescriptor(
                    title: "Unknown Transaction",
                    subtitle: "Type 0x\(String(format: "%02X", raw))",
                    systemImage: "questionmark.circle",
                    color: .gray,
                    category: .unknown,
                    amount: nil
                )
        }
    }
    
    var signedAmount: Int? {
        guard let previous = previousBalance else { return nil }
        return balance - previous
    }
   
}


enum TransitEvent: String, Codable {
    case entry
    case exit
}

struct CardStation: Identifiable, Hashable {
    let areaCode: Int
    let lineCode: Int
    let stationCode: Int
    let stationName: String  = ""
    let romanjiName: String?

    var id: String { "\(areaCode)-\(lineCode)-\(stationCode)" }
    var displayName: String { romanjiName ?? stationName  }
    var subtitle: String { "Area \(areaCode) • Line \(lineCode)" }
    var systemImage: String { "tram.fill" }
    var color: Color { .blue }
}

enum FelicaTransactionKind: Identifiable {

    case train(station: CardStation)
    case bus(stop: CardBusStop)
    case retail(RetailTransaction)
    case charge(ChargeTransaction)
    case unknown(UInt8)

    var id: UUID {
        UUID()
    }

    var displayName: String {
        switch self {
            case .train(let station): station.displayName
            case .bus(let stop): stop.displayName
            case .retail(let retail): retail.displayName
            case .charge(let charge): charge.displayName
            case .unknown: "Unknown Transaction"
        }
    }

    var subtitle: String {
        switch self {
            case .train(let station): station.subtitle
            case .bus(let stop): stop.subtitle
            case .retail(let retail): retail.subtitle
            case .charge(let charge): charge.subtitle
            case .unknown(let raw): "Type 0x\(String(format: "%02X", raw))"
        }
    }

    var systemImage: String {
        switch self {
            case .train: return "tram.fill"
            case .bus: return "bus.fill"
            case .retail: return "cart.fill"
            case .charge: return "plus.circle.fill"
            case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
            case .train: return .blue
            case .bus: return .green
            case .retail: return .pink
            case .charge: return .purple
            case .unknown: return .gray
        }
    }
}

struct CardBusStop: Identifiable, Hashable {
    let operatorCode: Int
    let stopCode: Int
    let stopName: String?

    var id: String { "\(operatorCode)-\(stopCode)" }
    var displayName: String { stopName ?? "Bus Stop \(stopCode)" }
    var subtitle: String { "Operator \(operatorCode)" }
    var systemImage: String { "bus.fill" }
    var color: Color { .green }
}

struct RetailTransaction: Identifiable, Hashable {
    let terminalType: UInt8
    let amount: Int?

    var id: UUID = UUID()

    var displayName: String { "Retail Purchase" }
    var systemImage: String { "cart.fill" }
    var color: Color { .pink }
    var subtitle: String {
        if let amount {
            return "¥\(amount)"
        }
        return "Point of Sale"
    }
}

struct ChargeTransaction: Identifiable, Hashable {
    let amount: Int

    var id: UUID = UUID()
    var displayName: String { "Card Charge" }
    var subtitle: String { "Added ¥\(amount)" }
    var systemImage: String { "plus.circle.fill" }
    var color: Color { .purple }
}

enum FelicaProcessType: UInt8, CaseIterable, Identifiable {

    case farePayment    = 0x01
    case charge         = 0x02
    case ticketPurchase = 0x03
    case adjustment     = 0x04
    case busFare        = 0x05
    case retail         = 0x0F
    case unknown        = 0xFF   // internal fallback

    var id: UInt8 { rawValue }

    init(raw: UInt8) {
        self = FelicaProcessType(rawValue: raw) ?? .unknown
    }

    var title: String {
        switch self {
            case .farePayment: "Train Fare"
            case .charge: "Charge"
            case .ticketPurchase: "Ticket Purchase"
            case .adjustment: "Fare Adjustment"
            case .busFare: "Bus Fare"
            case .retail: "Retail Purchase"
            case .unknown: "Unknown"
        }
    }

    var systemImage: String {
        switch self {
            case .farePayment: "tram.fill"
            case .charge: "plus.circle.fill"
            case .ticketPurchase: "ticket.fill"
            case .adjustment: "arrow.triangle.2.circlepath"
            case .busFare: "bus.fill"
            case .retail: "cart.fill"
            case .unknown: "questionmark.circle"
        }
    }
}

enum FelicaMachineType: Identifiable {

    case gate
    case bus
    case vendingMachine
    case chargeMachine
    case retail
    case mobile
    case ticketOffice
    case unknown(UInt8)

    var id: String { title }

    init(raw: UInt8) {
        switch raw {
            case 0x03: self = .gate
            case 0x05, 0xC7: self = .bus
            case 0x07, 0x16: self = .vendingMachine
            case 0x08, 0x1C: self = .chargeMachine
            case 0x09, 0x1F: self = .retail
            case 0x12: self = .mobile
            case 0x17: self = .ticketOffice
            default: self = .unknown(raw)
        }
    }

    var title: String {
        switch self {
            case .gate: "Ticket Gate"
            case .bus: "Bus Reader"
            case .vendingMachine: "Ticket Machine"
            case .chargeMachine: "Charge Machine"
            case .retail: "Retail Terminal"
            case .mobile: "Mobile Device"
            case .ticketOffice: "Ticket Office"
            case .unknown(let raw): "Unknown (0x\(String(format: "%02X", raw)))"
        }
    }

    var systemImage: String {
        switch self {
            case .gate: "tram.fill"
            case .bus: "bus.fill"
            case .vendingMachine: "ticket.fill"
            case .chargeMachine: "plus.circle.fill"
            case .retail: "cart.fill"
            case .mobile: "iphone"
            case .ticketOffice: "person.fill"
            case .unknown: "questionmark.circle"
        }
    }
}
