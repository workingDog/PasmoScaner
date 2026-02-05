//
//  StationCode.swift
//  PasmoScaner
//
//  Created by Ringo Wathelet on 2026/02/05.
//
import SwiftUI
import Foundation


// for reading file stationcodes.json
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

}
