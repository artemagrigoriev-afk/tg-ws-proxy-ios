import AppIntents

@available(macOS 13.0, iOS 16.0, tvOS 16.0, *)
///Start Telegram WS Proxy shortcut in foreground
struct StartTgWsProxyIntentBg: AudioPlaybackIntent {
    
    static let title = LocalizedStringResource("appIntentStartTgWsProxyBgTitle", defaultValue: "Start TgWsProxy", table: "AppIntent")
    static let description = IntentDescription(LocalizedStringResource("appIntentStartTgWsProxyDesc", defaultValue: "Starts Telegram WS Proxy In Background", table: "AppIntent"))
    static let openAppWhenRun = false
    
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        await ProxyManager.shared.startProxy()
        let opSuccess = PlaybackController.shared.startPlaySilentAudio()
        return .result(value: opSuccess)
    }
}
