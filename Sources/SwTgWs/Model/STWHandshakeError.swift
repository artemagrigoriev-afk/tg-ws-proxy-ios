//
//  WsHandshakeError.swift
//  SwTgWs
//
//  Created by developer on 27.04.2026.
//

import Foundation

struct STWHandshakeError: Error, Sendable {
    let statusCode: Int
    let statusLine: String
    let headers: [String: String]
    let location: String?

    var isRedirect: Bool {
        [301, 302, 303, 307, 308].contains(statusCode)
    }
}
