//
//  MsgSplitController.swift
//  SwTgWs
//
//  Created by developer on 27.04.2026.
//

import Foundation

public class STWMsgSplitController {
    
    fileprivate var decAesEng: STWAESCTR
    let proto: STWMTProtoTag
    
    fileprivate var cipherBuf: Data
    fileprivate var plainBuf: Data
    fileprivate var disabled: Bool
    
    fileprivate var nextPacketLen: Int? {
        get {
            if (plainBuf.isEmpty) {
                return nil
            }
            switch (proto) {
            case .abridged: return nextAbridgedLen()
            case .intermediate: return nextIntermediateLen()
            case .secure: return nextIntermediateLen()
            }
        }
    }
    
    public init(relayInit: [UInt8], proto: STWMTProtoTag) {
        let key = Array(relayInit[8..<40])
        let iv = Array(relayInit[40..<56])
        self.proto = proto
        self.decAesEng = STWAESCTR(key: key, iv: iv)
        _ = self.decAesEng.process(STWMTProtoHandshake.zeroArr64)  // skip first 64 bytes
        
        self.cipherBuf = Data()
        self.plainBuf = Data()
        self.disabled = false
    }
    
    public func split(_ chunk: Data) -> [Data] {
        if chunk.isEmpty { return [] }
        if disabled { return [chunk] }

        cipherBuf.append(chunk)
        plainBuf.append(Data(decAesEng.process([UInt8](chunk))))

        var parts: [Data] = []
        while !cipherBuf.isEmpty {
            guard let packetLen = nextPacketLen else { break }
            if packetLen <= 0 {
                parts.append(cipherBuf)
                cipherBuf.removeAll()
                plainBuf.removeAll()
                disabled = true
                break
            }
            parts.append(cipherBuf.prefix(packetLen))
            cipherBuf.removeFirst(packetLen)
            plainBuf.removeFirst(packetLen)
        }
        return parts
    }
    
    public func flush() -> [Data] {
        if cipherBuf.isEmpty { return [] }
        let tail = Data(cipherBuf)
        cipherBuf.removeAll()
        plainBuf.removeAll()
        return [tail]
    }
    
    fileprivate func nextAbridgedLen() -> Int? {
        let first = plainBuf[plainBuf.startIndex]
        let payloadLen: Int
        let headerLen: Int
        if (first == 0x7F || first == 0xFF) {
            if plainBuf.count < 4 { return nil }
            payloadLen = (Int(plainBuf[plainBuf.startIndex + 1]) |
                         (Int(plainBuf[plainBuf.startIndex + 2]) << 8) |
                         (Int(plainBuf[plainBuf.startIndex + 3]) << 16)) * 4
            headerLen = 4
        } else {
            payloadLen = Int(first & 0x7F) * 4
            headerLen = 1
        }
        if payloadLen <= 0 { return 0 }
        let packetLen = headerLen + payloadLen
        if (plainBuf.count < packetLen) {
            return nil
        }
        return packetLen
    }

    fileprivate func nextIntermediateLen() -> Int? {
        if plainBuf.count < 4 { return nil }
        // Do not use Data.withUnsafeBytes { $0.load(as: UInt32.self) } here.
        // After removeFirst(), Data may expose storage that is not 4-byte aligned,
        // and aligned raw loads can crash on iOS/ARM.
        let payloadLen = Int(STWMsgSplitController.readUInt32LE(plainBuf) & 0x7FFFFFFF)
        if payloadLen <= 0 { return 0 }
        let packetLen = 4 + payloadLen
        if plainBuf.count < packetLen { return nil }
        return packetLen
    }
    
    @inline(__always)
    fileprivate static func readUInt32LE(_ data: Data, at offset: Int = 0) -> UInt32 {
        precondition(offset >= 0 && offset + 4 <= data.count, "UInt32 read out of bounds")
        let i0 = data.index(data.startIndex, offsetBy: offset)
        let b0 = UInt32(data[i0])
        let b1 = UInt32(data[data.index(after: i0)]) << 8
        let b2 = UInt32(data[data.index(i0, offsetBy: 2)]) << 16
        let b3 = UInt32(data[data.index(i0, offsetBy: 3)]) << 24
        return b0 | b1 | b2 | b3
    }
}
