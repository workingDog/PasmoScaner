//
//  JRStation.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/04.
//
import Foundation
import SwiftUI


struct JRStation3: Codable {
    var areaCode: String
    var lineCode: String
    var stationOrderCode: String
    var companyName: String
    var lineName: String
    var stationName: String
    var remarks: StationRemark

    enum CodingKeys: String, CodingKey {
        case areaCode = "地区コード(16進)"
        case lineCode = "線区コード(16進)"
        case stationOrderCode = "駅順コード(16進)"
        case companyName = "会社名"
        case lineName = "線区名"
        case stationName = "駅名"
        case remarks = "備考"
    }
}

enum StationRemark: Equatable {
    case none
    case discontinued
    case temporary
    case former(code: String)
    case unknown(raw: String)
}

extension StationRemark: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
            case "":  self = .none
            case "廃止": self = .discontinued
            case "臨時駅": self = .temporary
            default:
                if rawValue.hasPrefix("旧 ") {
                    let code = rawValue.replacingOccurrences(of: "旧 ", with: "")
                    self = .former(code: code)
                } else {
                    self = .unknown(raw: rawValue)
                }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        let value: String
        switch self {
            case .none: value = ""
            case .discontinued: value = "廃止"
            case .temporary: value = "臨時駅"
            case .former(let code): value = "旧 \(code)"
            case .unknown(let raw): value = raw
        }

        try container.encode(value)
    }
}
