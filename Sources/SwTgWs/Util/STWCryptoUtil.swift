//
//  STWCryptoUtil.swift
//  SwTgWs
//
//  Created by developer on 26.04.2026.
//

import Foundation
#if canImport(CommonCrypto)
import CommonCrypto
#else
import CryptoSwift
#endif

public final class STWCryptoUtil {
    
    fileprivate init() {}
    
    public static func aesCtrEncrypt(data: Data, key: [UInt8], iv: [UInt8]) -> [UInt8] {
        let bytes = [UInt8].init(data)
        return aesCtrEncrypt(bytes: bytes, key: key, iv: iv)
    }
    
#if canImport(CommonCrypto)
    public static func aesCtrEncrypt(bytes: [UInt8], key: [UInt8], iv: [UInt8]) -> [UInt8] {
        var out = [UInt8].init(repeating: 0, count: bytes.count)
        var counter: [UInt8] = iv           // 16-byte big-endian counter (= IV)
        var keystreamBuffer: [UInt8] = []
        var keystreamOffset: Int = 0
        var offset = 0

        while offset < bytes.count {
            if keystreamOffset >= keystreamBuffer.count {
                keystreamBuffer = encryptBlock(counter, key: key)
                keystreamOffset = 0
                //increment counter
                for i in stride(from: 15, through: 0, by: -1) {
                    counter[i] &+= 1
                    if counter[i] != 0 { break }
                }
            }

            let available = keystreamBuffer.count - keystreamOffset
            let needed = bytes.count - offset
            let chunk = min(available, needed)

            for i in 0..<chunk {
                out[offset + i] = bytes[offset + i] ^ keystreamBuffer[keystreamOffset + i]
            }
            offset += chunk
            keystreamOffset += chunk
        }
        
        return out
    }
    
    private static func encryptBlock(_ block: [UInt8], key: [UInt8]) -> [UInt8] {
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
#else
    public static func aesCtrEncrypt(bytes: [UInt8], key: [UInt8], iv: [UInt8]) -> [UInt8] {
        do {
            let aesEng = try AES(key: key, blockMode: CTR(iv: iv), padding: .noPadding)
            let out = try aesEng.encrypt(bytes)
            return out
        } catch {
#if DEBUG
            print("AES-CTR error")
            print(error)
#endif
            return []
        }
    }
#endif
    
#if canImport(CommonCrypto)
    public static func sha256(buffer: [UInt8]) -> [UInt8] {
        var digest: [UInt8] = [UInt8].init(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        let data = Data(buffer)
        data.withUnsafeBytes{ (unsafePointer) -> Void in
            guard let addr = unsafePointer.baseAddress else {return}
            let bufferPointer: UnsafePointer<UInt8> = addr.assumingMemoryBound(to: UInt8.self)
            let rawPtr = UnsafeRawPointer(bufferPointer)
            CC_SHA256(rawPtr, CC_LONG(data.count), &digest)
        }
        return digest
    }
#else
    public static func sha256(buffer: [UInt8]) -> [UInt8] {
        let shaEng = SHA2(variant: .sha256)
        let digest = shaEng.calculate(for: buffer)
        return digest
    }
#endif

    
    public static func secureRandomBytes(_ count: Int) -> [UInt8] {
        return STWBinaryUtil.randomBytesArr(count: count)
    }
}
