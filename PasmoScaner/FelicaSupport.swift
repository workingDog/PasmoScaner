//
//  FelicaSupport.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/13.
//
import SwiftUI
import Foundation
import CoreNFC


struct FelicaTransaction: Identifiable {
    let id = UUID()
    var date: Date
    var machineType: FelicaMachineType
    var type: FelicaProcessType
    var kind: FelicaTransactionKind
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
    var romanjiName: String?
}

enum FelicaTransactionKind {
    case train(station: CardStation)
    case bus(stop: CardBusStop)
    case retail(RetailTransaction)
    case charge(ChargeTransaction)
    case unknown
}

struct CardBusStop {
    let operatorCode: Int
    let stopCode: Int
}

struct RetailTransaction {
    let terminalType: UInt8
}

struct ChargeTransaction {
    let amount: Int
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
