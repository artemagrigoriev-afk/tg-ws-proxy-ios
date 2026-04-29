//
//  STWAESCTR.swift
//  SwTgWs
//
//  Created by developer on 28.04.2026.
//

import Foundation
#if canImport(CommonCrypto)
import CommonCrypto
#else
import CryptoSwift
#endif

#if canImport(CommonCrypto)
public final class STWAESCTR {
    private var key: [UInt8]
    private var counter: [UInt8]             // 16-byte big-endian counter (= IV)
    private var keystreamBuffer: [UInt8] = []
    private var keystreamOffset: Int = 0

    public init(key: [UInt8], iv: [UInt8]) {
        precondition(key.count == 32, "AES-256 key must be 32 bytes")
        precondition(iv.count == 16, "IV must be 16 bytes")
        self.key = key
        self.counter = iv
    }

    public func process(_ data: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: data.count)
        var offset = 0

        while offset < data.count {
            if keystreamOffset >= keystreamBuffer.count {
                keystreamBuffer = encryptBlock(counter)
                keystreamOffset = 0
                incrementCounter()
            }

            let available = keystreamBuffer.count - keystreamOffset
            let needed = data.count - offset
            let chunk = min(available, needed)

            for i in 0..<chunk {
                out[offset + i] = data[offset + i] ^ keystreamBuffer[keystreamOffset + i]
            }
            offset += chunk
            keystreamOffset += chunk
        }
        return out
    }

    public func process(_ data: Data) -> Data {
        return Data(process([UInt8](data)))
    }

    private func encryptBlock(_ block: [UInt8]) -> [UInt8] {
        var encrypted = [UInt8](repeating: 0, count: block.count + kCCBlockSizeAES128)
        var numBytesEncrypted: size_t = 0

        let status = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionECBMode),
            key, key.count,
            nil,
            block, block.count,
            &encrypted, encrypted.count,
            &numBytesEncrypted
        )
        precondition(status == kCCSuccess, "AES ECB encrypt failed: \(status)")
        return Array(encrypted.prefix(16))
    }

    private func incrementCounter() {
        for i in stride(from: 15, through: 0, by: -1) {
            counter[i] &+= 1
            if counter[i] != 0 { break }
        }
    }
}
#else
public final class STWAESCTR {
    
    private var aesEng: AES
    private var counter: [UInt8]             // 16-byte big-endian counter (= IV)
    private var keystreamBuffer: [UInt8] = []
    private var keystreamOffset: Int = 0
    
    public init(key: [UInt8], iv: [UInt8]) {
        precondition(key.count == 32, "AES-256 key must be 32 bytes")
        precondition(iv.count == 16, "IV must be 16 bytes")
        self.counter = iv
        aesEng = try! AES(key: key, blockMode: ECB(), padding: .noPadding)
    }
    
    public func process(_ data: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: data.count)
        var offset = 0

        while offset < data.count {
            if keystreamOffset >= keystreamBuffer.count {
                do {
                    keystreamBuffer = try encryptBlock(counter)
                } catch {
        #if DEBUG
                    print("AES-CTR error")
                    print(error)
        #endif
                }
                keystreamOffset = 0
                incrementCounter()
            }

            let available = keystreamBuffer.count - keystreamOffset
            let needed = data.count - offset
            let chunk = min(available, needed)

            for i in 0..<chunk {
                out[offset + i] = data[offset + i] ^ keystreamBuffer[keystreamOffset + i]
            }
            offset += chunk
            keystreamOffset += chunk
        }
        return out
    }
    
    public func process(_ data: Data) -> Data {
        return Data(process([UInt8](data)))
    }
    
    private func encryptBlock(_ block: [UInt8]) throws -> [UInt8] {
        let encrypted = try aesEng.encrypt(block)
        return Array(encrypted.prefix(16))
    }

    private func incrementCounter() {
        for i in stride(from: 15, through: 0, by: -1) {
            counter[i] &+= 1
            if counter[i] != 0 { break }
        }
    }
}
#endif
