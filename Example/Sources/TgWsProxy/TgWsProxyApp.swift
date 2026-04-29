// TgWsProxy iOS — Telegram MTProto WebSocket Bridge Proxy
// Ported from the Python tg-ws-proxy project by Flowseal

import SwiftUI

#if DEBUG
let previewProxyManager = ProxyManager.shared
#endif

@main
struct TgWsProxyApp: App {
    
    @StateObject private var proxyManager = ProxyManager.shared

    var body: some Scene {
        WindowGroup {
            NavigationView {
                HomeScreen()
            }
            .environmentObject(proxyManager)
        }
    }
}
