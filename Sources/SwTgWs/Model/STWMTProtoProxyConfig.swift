import Foundation

public final class STWMTProtoProxyConfig: Codable, Sendable {
    
    public static let mtprotoSecretLen = 16
    
    public static let defaultHost = "127.0.0.1"
    public static let defaultPort: UInt16 = 1443
    public static let defaultDC: [Int: String] = [
        2: "149.154.167.220",
        4: "149.154.167.220"
    ]
    public static let defaultDCOverrides: [Int: Int] = [203: 2]
    public static let defaultBufSizeInBytes: UInt32 = 262144 // 256 kb
    public static let defaultPoolSize: Int = 4
    
    public let host: String
    public let port: UInt16
    public let secretBytes: [UInt8]
    public let dcRedirects: [Int: String]
    public let dcOverrides: [Int: Int]
    public let bufSize: UInt32
    public let poolSize: Int
    
    public var bufSizeKb: UInt32 {
        get {
            return bufSize / 1024
        }
    }
    
    public var secret: String {
        get {
            return secretBytes.map { String(format: "%02x", $0) }.joined()
        }
    }
    
    public var tgConnectDeeplinkString: String {
        get {
            return "tg://proxy?server=\(host)&port=\(port)&secret=dd\(secret)"
        }
    }
    
    public init(host: String = STWMTProtoProxyConfig.defaultHost, port: UInt16 = STWMTProtoProxyConfig.defaultPort, secret: [UInt8]? = nil, dcRedirects: [Int : String] = STWMTProtoProxyConfig.defaultDC, dcOverrides: [Int: Int] = STWMTProtoProxyConfig.defaultDCOverrides, bufSize: UInt32 = STWMTProtoProxyConfig.defaultBufSizeInBytes, poolSize: Int = STWMTProtoProxyConfig.defaultPoolSize) {
        self.host = host
        self.port = port
        if let safeSecret = secret, safeSecret.count == STWMTProtoProxyConfig.mtprotoSecretLen {
            self.secretBytes = safeSecret
        } else {
            self.secretBytes = STWMTProtoProxyConfig.generateRandomSecret()
        }
        self.dcRedirects = dcRedirects
        self.dcOverrides = dcOverrides
        self.bufSize = bufSize
        self.poolSize = poolSize
    }
    
    public func copyWith(host: String? = nil, port: UInt16? = nil, secret: [UInt8]? = nil, dcRedirects: [Int : String]? = nil, dcOverrides: [Int: Int]? = nil, bufSize: UInt32? = nil, poolSize: Int? = nil) -> STWMTProtoProxyConfig {
        return STWMTProtoProxyConfig(host: host ?? self.host, port: port ?? self.port, secret: secret ?? self.secretBytes, dcRedirects: dcRedirects ?? self.dcRedirects, dcOverrides: dcOverrides ?? self.dcOverrides, bufSize: bufSize ?? self.bufSize, poolSize: poolSize ?? self.poolSize)
    }
    
    public static func generateRandomSecretHexString() -> String {
        return generateRandomSecret().map { String(format: "%02x", $0) }.joined()
    }
    
    public static func generateRandomSecret() -> [UInt8] {
        let bytes = STWCryptoUtil.secureRandomBytes(STWMTProtoProxyConfig.mtprotoSecretLen)
        return bytes
    }
}
