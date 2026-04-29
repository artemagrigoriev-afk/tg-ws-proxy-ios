import AppIntents

@available(macOS 13.0, iOS 16.0, tvOS 16.0, *)
///Stop Telegram WS Proxy shortcut
struct StopTgWsProxyIntent: AudioPlaybackIntent {
    
    static let title = LocalizedStringResource("appIntentStopTgWsProxyTitle", defaultValue: "Stop TgWsProxy", table: "AppIntent")
    static let description = IntentDescription(LocalizedStringResource("appIntentStopTgWsProxyDesc", defaultValue: "Stops Telegram WS Proxy", table: "AppIntent"))
    
    func perform() async throws -> some IntentResult {
        await ProxyManager.shared.stopProxy()
        PlaybackController.shared.stopPlaySilentAudio()
        return .result()
    }
}
