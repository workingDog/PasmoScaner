//
//  FelicaModels.swift
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
        let delta = delta ?? 0
        
        return switch kind {
            
            // 🚃 TRAIN
            case .train(let station):
                TransactionDescriptor(
//                    title: station.displayName,
//                    subtitle: "Train ¥\(abs(delta))",
                    title: "Train",
                    subtitle: "¥\(abs(delta))",
                    systemImage: "tram.fill",
                    color: .blue,
                    category: .transport,
                    amount: nil
                )
            
            // 🚌 BUS
            case .bus(let stop):
                TransactionDescriptor(
//                    title: stop.displayName,
//                    subtitle: "Bus ¥\(abs(delta))",
                    title: "Bus",
                    subtitle: "¥\(abs(delta))",
                    systemImage: "bus.fill",
                    color: .green,
                    category: .transport,
                    amount: nil
                )
            
            // 🛒 RETAIL
            case .retail:
                 TransactionDescriptor(
                    title: "Shop",
                    subtitle: "¥\(abs(delta))",
                    systemImage: "cart.fill",
                    color: .pink,
                    category: .shopping,
                    amount: delta
                )
            
            // 💳 CHARGE
            case .charge:
                 TransactionDescriptor(
                    title: "Card",
                    subtitle: "¥\(abs(delta))",
                    systemImage: "creditcard.fill",
                    color: .purple,
                    category: .charge,
                    amount: delta
                )
            
            // ❓ UNKNOWN
            case .unknown(let raw):
                TransactionDescriptor(
                    title: "Unknown",
                    subtitle: "0x\(String(format: "%02X", raw))",
                    systemImage: "questionmark.circle",
                    color: .gray,
                    category: .unknown,
                    amount: nil
                )
        }
    }
    
    var delta: Int? {
        guard let previous = previousBalance else { return nil }
        return balance - previous
    }
   
}

enum TransitEvent: String, Codable {
    case entry
    case exit
}

struct CardStation: Identifiable, Hashable, Codable {
    var areaCode: Int
    var lineCode: Int
    var stationCode: Int
    
    var stationName: String  = ""
    var company: String?
    var lineName: String?
    var romanjiName: String?

    var id: String { "\(areaCode)-\(lineCode)-\(stationCode)" }
    var displayName: String { romanjiName ?? stationName  }
    var subtitle: String { "Area \(areaCode) • Line \(lineCode)" }
    var systemImage: String { "tram.fill" }
    var color: Color { .blue }
    
    enum CodingKeys: String, CodingKey {
        case areaCode = "RegionCode"
        case lineCode = "LineCode"
        case stationCode = "StationCode"
        case stationName = "StationName"
        case company = "Company"
        case lineName = "Line"
        case romanjiName
    }
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
            case .unknown: "Unknown"
        }
    }

    var subtitle: String {
        switch self {
            case .train(let station): station.subtitle
            case .bus(let stop): stop.subtitle
            case .retail(let retail): retail.subtitle
            case .charge(let charge): charge.subtitle
            case .unknown(let raw): "Kind 0x\(String(format: "%02X", raw))"
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
 //   var displayName: String { stopName ?? "Bus" }
    var displayName: String { "Bus" }
    var subtitle: String { "Operator \(operatorCode)" }
    var systemImage: String { "bus.fill" }
    var color: Color { .green }
}

struct RetailTransaction: Identifiable, Hashable {
    let terminalType: UInt8
    let amount: Int?

    var id: UUID = UUID()

    var displayName: String { "Shop" }
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
    var displayName: String { "Card" }
    var subtitle: String { "¥\(amount)" }
    var systemImage: String { "plus.circle.fill" }
    var color: Color { .purple }
}


enum FelicaProcessType: UInt8, CaseIterable, Identifiable {
    case farePayment
    case charge
    case ticketPurchase
    case adjustment
    case busFare
    case retail
    case unknown

    var id: UInt8 { rawValue }

    init(raw: UInt8) {
        switch raw {
            case 0x01: self = .farePayment
            case 0x02: self = .charge
            case 0x03: self = .ticketPurchase
            case 0x04: self = .adjustment
            case 0x05: self = .busFare
            case 0x46, 0x4B: self = .retail
            default: self = .unknown
        }
    }

    var rawValue: UInt8 {
        switch self {
            case .farePayment: return 0x01
            case .charge: return 0x02
            case .ticketPurchase: return 0x03
            case .adjustment: return 0x04
            case .busFare: return 0x05
            case .retail: return 0x46
            case .unknown: return 0xFF
        }
    }
    
    var title: String {
        switch self {
            case .farePayment: "Train Fare"
            case .charge: "Charge"
            case .ticketPurchase: "Ticket Purchase"
            case .adjustment: "Fare Adjustment"
            case .busFare: "Bus Fare"
            case .retail: "Shop"
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

    var title: String {
        switch self {
            case .gate: "Ticket Gate"
            case .bus: "Bus Reader"
            case .vendingMachine: "Ticket Machine"
            case .chargeMachine: "Charge Machine"
            case .retail: "Shop Terminal"
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

    init(raw: UInt8) {
        switch raw {
            // 🚃 ALL KNOWN GATE TYPES
            case 0x03, 0x16, 0x17: self = .gate
            // 🚌 BUS
            case 0x05: self = .bus
            // 🎫 Ticket machines
            case 0x07: self = .vendingMachine
            // 💳 Charge machines
    //        case 0x08, 0x1C: self = .chargeMachine
            case 0x08, 0x09, 0x13, 0x14, 0x15, 0x1C, 0x1D, 0x46: self = .chargeMachine
            // 🛒 Retail
            case 0x1F, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB: self = .retail
            case 0x12: self = .mobile
            default: self = .unknown(raw)
        }
    }
}
