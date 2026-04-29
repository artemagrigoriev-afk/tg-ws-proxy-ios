//
//  STWMTProtoHandshake.swift
//  SwTgWs
//
//  Created by developer on 26.04.2026.
//

import Foundation

public final class STWMTProtoHandshake: Sendable {
    
    public static let handshakeLen: Int = 64
    public static let skipLen: Int = 8
    public static let preKeyLen: Int = 32
    public static let keyLen: Int = 32
    public static let ivLen: Int = 16
    public static let protoTagPos: Int = 56
    public static let dcIDxPos: Int = 60
    
    public static let reservedFirstBytes: Set<UInt8> = Set([0xEF])
    public static let reservedStarts: Set<[UInt8]> = Set([
        [0x48, 0x45, 0x41, 0x44],  // HEAD
        [0x50, 0x4F, 0x53, 0x54],  // POST
        [0x47, 0x45, 0x54, 0x20],  // GET
        [0xEE, 0xEE, 0xEE, 0xEE],
        [0xDD, 0xDD, 0xDD, 0xDD],
        [0x16, 0x03, 0x01, 0x02],
    ])
    public static let reservedContinue: [UInt8] = [0x00, 0x00, 0x00, 0x00]
    public static let zeroArr64 = [UInt8].init(repeating: 0, count: 64)
    
    public let dcIdx: Int16
    public let protoTag: STWMTProtoTag
    public let clientDecPrekey: [UInt8]
    public let clientDecIV: [UInt8]
    public let clientEncPrekey: [UInt8]
    public let clientEncIV: [UInt8]
    
    public var dcId: Int {
        get {
            return abs(Int(dcIdx))
        }
    }
    
    public var media: Bool {
        get {
            return dcIdx < 0
        }
    }
    
    public var clientDecPrekeyIV: [UInt8] {
        get {
            // 48 bytes: prekey(32) + iv(16)
            var bytes = [UInt8].init(clientDecPrekey)
            bytes.append(contentsOf: clientDecIV)
            return bytes
        }
    }
    
    public var clientEncPrekeyIV: [UInt8] {
        get {
            return clientDecPrekeyIV.reversed()
        }
    }
    
    public init(dcIdx: Int16, protoTag: STWMTProtoTag, clientDecPrekey: [UInt8], clientDecIV: [UInt8], clientEncPrekey: [UInt8], clientEncIV: [UInt8]) {
        self.dcIdx = dcIdx
        self.protoTag = protoTag
        self.clientDecPrekey = clientDecPrekey
        self.clientDecIV = clientDecIV
        self.clientEncPrekey = clientEncPrekey
        self.clientEncIV = clientEncIV
    }
    
    public func generateClientDecKey(secret: [UInt8]) -> [UInt8] {
        return STWMTProtoHandshake.generateClientDecKey(clientDecPrekey: clientDecPrekey, secret: secret)
    }
    
    public static func generateClientDecKey(clientDecPrekey: [UInt8], secret: [UInt8]) -> [UInt8] {
        var bytes = [UInt8].init(clientDecPrekey)
        bytes.append(contentsOf: secret)
        let digest = STWCryptoUtil.sha256(buffer: bytes)
        return digest
    }
    
    public func generateClientEncKey(secret: [UInt8]) -> [UInt8] {
        return STWMTProtoHandshake.generateClientEncKey(clientEncPrekey: clientEncPrekey, secret: secret)
    }
    
    public static func generateClientEncKey(clientEncPrekey: [UInt8], secret: [UInt8]) -> [UInt8] {
        var bytes = [UInt8].init(clientEncPrekey)
        bytes.append(contentsOf: secret)
        let digest = STWCryptoUtil.sha256(buffer: bytes)
        return digest
    }
    
    public func generateWsDomains(overrides: [Int: Int]) -> [String] {
        return STWMTProtoHandshake.generateWsDomains(dc: dcId, media: media, overrides: overrides)
    }

    public static func generateWsDomains(dc: Int, media: Bool, overrides: [Int: Int]) -> [String] {
        let effectiveDC = overrides[dc] ?? dc
        if (media) {
            return ["kws\(effectiveDC)-1.web.telegram.org", "kws\(effectiveDC).web.telegram.org"]
        }
        return ["kws\(effectiveDC).web.telegram.org", "kws\(effectiveDC)-1.web.telegram.org"]
    }
    
    public static func generateRelayInit(protoTag: STWMTProtoTag, dcIdx: Int16) -> [UInt8] {
        while true {
            var rnd = STWCryptoUtil.secureRandomBytes(STWMTProtoHandshake.handshakeLen)

            if (STWMTProtoHandshake.reservedFirstBytes.contains(rnd[0])) {
                continue
            }
            if (STWMTProtoHandshake.reservedStarts.contains(Array(rnd[0..<4]))) {
                continue
            }
            if (Array(rnd[4..<8]) == STWMTProtoHandshake.reservedContinue) {
                continue
            }

            var startIndex = STWMTProtoHandshake.skipLen
            var endIndex = startIndex + STWMTProtoHandshake.preKeyLen
            let encKey = Array(rnd[startIndex ..< endIndex])
            startIndex = endIndex
            endIndex = startIndex + STWMTProtoHandshake.ivLen
            let encIV = Array(rnd[startIndex ..< endIndex])

            // DC index as signed 16-bit little-endian
            let dcBytes: [UInt8] = STWBinaryUtil.getLEndianBytes(dcIdx)
            let tailPlain = protoTag.tagBytes + dcBytes + STWCryptoUtil.secureRandomBytes(2)

            let encryptedFull = STWCryptoUtil.aesCtrEncrypt(bytes: rnd, key: encKey, iv: encIV)
            var keystreamTail = [UInt8](repeating: 0, count: 8)
            for i in 0..<8 {
                keystreamTail[i] = encryptedFull[56 + i] ^ rnd[56 + i]
            }

            //Encrypted tail (56..64)
            for i in 0..<8 {
                rnd[STWMTProtoHandshake.protoTagPos + i] = tailPlain[i] ^ keystreamTail[i]
            }
            return rnd
        }
    }
    
    public static func tryParse(_ handshake: [UInt8], secret: [UInt8]) -> STWMTProtoHandshake? {
        if (handshake.count != STWMTProtoHandshake.handshakeLen) {
#if DEBUG
            print("Invalid handshake length: expected " + String(STWMTProtoHandshake.handshakeLen) + ", but was " + String(handshake.count))
#endif
            return nil
        }
        var startIndex = STWMTProtoHandshake.skipLen
        var endIndex = startIndex + STWMTProtoHandshake.preKeyLen + STWMTProtoHandshake.ivLen
        let decPrekeyAndIV = Array(handshake[startIndex ..< endIndex])
        endIndex = STWMTProtoHandshake.preKeyLen
        let prekey = Array(decPrekeyAndIV[0..<endIndex])
        startIndex = endIndex
        let decIV = Array(decPrekeyAndIV[startIndex...])
        let encPrekeyAndIV = Array(decPrekeyAndIV.reversed())
        endIndex = STWMTProtoHandshake.preKeyLen
        let enckey = Array(encPrekeyAndIV[0..<endIndex])
        startIndex = endIndex
        let encIV = Array(encPrekeyAndIV[startIndex...])

        var decKeyBasis = [UInt8].init(prekey)
        decKeyBasis.append(contentsOf: secret)
        let decKey = STWCryptoUtil.sha256(buffer: decKeyBasis)
        
        let aesProcessed = STWCryptoUtil.aesCtrEncrypt(bytes: handshake, key: decKey, iv: decIV)

        startIndex = STWMTProtoHandshake.protoTagPos
        let protoTag = Array(aesProcessed[startIndex ..< startIndex + 4])
        
        guard let safeProtoTag = STWMTProtoTag.fromBytes(protoTag) else {
            return nil
        }

        // DC index: signed 16-bit little-endian at position 60
        let dcIdx = readInt16LE(aesProcessed, at: STWMTProtoHandshake.dcIDxPos)

        return STWMTProtoHandshake(dcIdx: dcIdx, protoTag: safeProtoTag, clientDecPrekey: prekey, clientDecIV: decIV, clientEncPrekey: enckey, clientEncIV: encIV)
    }
    
    // MARK: - Safe little-endian readers

    @inline(__always)
    fileprivate static func readUInt16LE(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        precondition(offset >= 0 && offset + 2 <= bytes.count, "UInt16 read out of bounds")
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    @inline(__always)
    fileprivate static func readInt16LE(_ bytes: [UInt8], at offset: Int) -> Int16 {
        Int16(bitPattern: readUInt16LE(bytes, at: offset))
    }
}
