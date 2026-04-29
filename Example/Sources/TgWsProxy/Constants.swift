//
//  Constants.swift
//  SwTgWs
//
//  Created by developer on 28.04.2026.
//

import Foundation

final class Constants {
    
    static let PSEUDO_BUNDLE_ID = Bundle.main.bundleIdentifier ?? "org.app.unknown"
    static let PSEUDO_BUNDLE_VERSION = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let PSEUDO_BUNDLE_BUILD_NUMBER = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    static let buttonMinHeight = 40.0
    
    fileprivate init() {}
    
}
