import Foundation
import Combine
import os.log
import CoreLocation
import SwTgWs

private let logger = Logger(subsystem: Constants.PSEUDO_BUNDLE_ID, category: "ProxyManager")

// MARK: - Proxy Stats
struct ProxyStats {
    var connectionsTotal: Int = 0
    var connectionsActive: Int = 0
    var connectionsWS: Int = 0
    var connectionsTCPFallback: Int = 0
    var connectionsBad: Int = 0
    var wsErrors: Int = 0
    var bytesUp: UInt64 = 0
    var bytesDown: UInt64 = 0
}

// MARK: - Proxy Manager
@MainActor
class ProxyManager: ObservableObject {
    static let shared = ProxyManager()

    @Published var isRunning = false
    @Published var stats = ProxyStats()
    @Published var config = STWMTProtoProxyConfig.load()

    private var server: MTProtoProxyServer?

    func startProxy() {
        guard !isRunning else { return }

        logger.info("Starting proxy on \(self.config.host):\(self.config.port)")


        //Play silent audio for prevent app sleep at background by iOS
        _ = PlaybackController.shared.startPlaySilentAudio()

        server = MTProtoProxyServer(config: config, statsCallback: { [weak self] newStats in
            Task { @MainActor in
                self?.stats = newStats
            }
        })

        Task {
            do {
                try await server?.start()
                isRunning = true
                logger.info("Proxy started successfully")
            } catch {
                logger.error("Failed to start proxy: \(error)")
                isRunning = false
                PlaybackController.shared.stopPlaySilentAudio()
                //LocationManager.shared.stop()
            }
        }
    }

    func stopProxy() {
        guard isRunning else { return }
        logger.info("Stopping proxy")
        
        PlaybackController.shared.stopPlaySilentAudio()
        //LocationManager.shared.stop()
        
        server?.stop()
        server = nil
        isRunning = false
        stats = ProxyStats()
    }

    func saveConfig() {
        config.save()
        if isRunning {
            stopProxy()
            startProxy()
        }
    }
}
