//
//  STWMTProtoTag.swift
//  SwTgWs
//
//  Created by developer on 27.04.2026.
//

public enum STWMTProtoTag: UInt32, Sendable {
    case abridged = 0xEFEFEFEF
    case intermediate = 0xEEEEEEEE
    case secure = 0xDDDDDDDD
}

extension STWMTProtoTag {
    
    public static func fromBytes(_ bytes: [UInt8]) -> STWMTProtoTag? {
        let intVal = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
        guard let safeParsed = STWMTProtoTag(rawValue: intVal) else {
#if DEBUG
            print("Unknown Proto tag value - " + bytes.map { String(format: "%02x", $0) }.joined())
#endif
            return nil
        }
        return safeParsed
    }
    
    public var tagBytes: [UInt8] {
        get {
            switch (self) {
            case .abridged: return [0xEF, 0xEF, 0xEF, 0xEF]
            case .intermediate: return [0xEE, 0xEE, 0xEE, 0xEE]
            case .secure: return [0xDD, 0xDD, 0xDD, 0xDD]
            }
        }
    }
    
}
