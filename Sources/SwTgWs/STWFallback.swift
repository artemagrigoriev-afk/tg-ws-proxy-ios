//
//  Fallback.swift
//  SwTgWs
//
//  Created by developer on 26.04.2026.
//

#if swift(<5.5)
/// Fallback empty Sendable protocol
protocol Sendable {}
#endif
