//
//  STWMTProtoHandshake+SaveLoad.swift
//  SwTgWs
//
//  Created by developer on 28.04.2026.
//

import Foundation
import SwTgWs

extension STWMTProtoProxyConfig {
    
    public static func load() -> STWMTProtoProxyConfig {
        guard let data = UserDefaults.standard.data(forKey: "proxyConfig"),
              let config = try? JSONDecoder().decode(STWMTProtoProxyConfig.self, from: data) else {
            return STWMTProtoProxyConfig()
        }
        return config
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "proxyConfig")
        }
    }
    
}
