import AppIntents

@available(macOS 13.0, iOS 16.0, tvOS 16.0, *)
///Start Telegram WS Proxy shortcut in foreground
struct StartTgWsProxyIntentFg: AudioPlaybackIntent {
    
    static let title = LocalizedStringResource("appIntentStartTgWsProxyTitle", defaultValue: "Start TgWsProxy", table: "AppIntent")
    static let description = IntentDescription(LocalizedStringResource("appIntentStartTgWsProxyDesc", defaultValue: "Starts Telegram WS Proxy", table: "AppIntent"))
    static let openAppWhenRun = true
    
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        await ProxyManager.shared.startProxy()
        let opSuccess = PlaybackController.shared.startPlaySilentAudio()
        return .result(value: opSuccess)
    }
}
