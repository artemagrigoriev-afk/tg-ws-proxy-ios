import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

///'Silent' audio play controller
final class PlaybackController: NSObject, Sendable {
    ///Audio play singleton
    static let shared = PlaybackController()
    
    ///System audio player
    fileprivate static let _player = try! AVAudioPlayer(data: PlaybackController.generateSilentWAV(durationSeconds: 5, sampleRate: 8000), fileTypeHint: "wav")
#if DEBUG
    fileprivate let periodicObserveTimer: Timer
#endif
    
    ///'Silent' audio playing flag
    var playing: Bool {
        get {
            return PlaybackController._player.isPlaying
        }
    }
    
    fileprivate override init() {
#if DEBUG
        periodicObserveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if (!PlaybackController._player.isPlaying) {
                return
            }
            let currTime = PlaybackController._player.currentTime
            let duration = PlaybackController._player.duration
            print("Playback time", currTime, "/", duration)
        }
#endif
        super.init()
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main, using: onAudioRouteChange)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main, using: onAVInterruption)
#if canImport(UIKit)
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main, using: stopAudioForFgState)
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: stopAudioForFgState)
#endif

        //let periodTime = CMTimeMakeWithSeconds(1, preferredTimescale: Int32(NSEC_PER_SEC))
        //_ = PlaybackController._player.addPeriodicTimeObserver(forInterval: periodTime, queue: DispatchQueue.main, using: onPlaybackProgress)
    }
    
    deinit {
#if DEBUG
        periodicObserveTimer.invalidate()
#endif
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
#if canImport(UIKit)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
#endif
    }
    
    ///Tries to play looped 'silent' audio
    func startPlaySilentAudio() -> Bool {
        if (playing) {
            return true
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } catch {
            print(error)
            return false
        }
        do {
            PlaybackController._player.volume = 0.0
            PlaybackController._player.numberOfLoops = -1
            try AVAudioSession.sharedInstance().setActive(true)
            PlaybackController._player.play(atTime: 0)
        } catch {
            print(error)
            return false
        }
        return true
    }
    
    ///Stops playing looped 'silent' audio and releases audio session
    func stopPlaySilentAudio() {
        PlaybackController._player.pause()
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print(error)
        }
    }
    
    ///Audio session interruption state event handler
    fileprivate func onAVInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let interruptionTypeRawValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeRawValue)
        else {return}
        switch interruptionType {
        case .began:
            stopPlaySilentAudio()
            break
        case .ended:
            stopPlaySilentAudio()
            Task { @MainActor in
                if (!ProxyManager.shared.isRunning) {
                    return
                }
                _ = startPlaySilentAudio()
            }
            break
        default:
            break
        }
    }
    
    ///Output audio device change event handler
    ///- Parameter notification: Event details
    fileprivate func onAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue)
        else {return}
        if (reason == .oldDeviceUnavailable) {
            if let previousRoute =
                userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                for output in previousRoute.outputs {
                    if output.portType == AVAudioSession.Port.headphones || output.portType == AVAudioSession.Port.airPlay || output.portType == AVAudioSession.Port.bluetoothA2DP {
                        stopPlaySilentAudio()
                        _ = startPlaySilentAudio()
                        break
                    }
                }
            }
        }
    }
    
    fileprivate func stopAudioForFgState(_ notification: Notification) {
        Task { @MainActor in
            if (!ProxyManager.shared.isRunning) {
                stopPlaySilentAudio()
                return
            }
            if (playing) {
                return
            }
            _ = startPlaySilentAudio()
        }
    }
    
    /// Generates a minimal silent WAV file in memory.
    fileprivate static func generateSilentWAV(durationSeconds: Int, sampleRate: Int) -> Data {
        let numSamples = sampleRate * durationSeconds
        let bitsPerSample = 16
        let numChannels = 1
        let byteRate = sampleRate * numChannels * (bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = numSamples * numChannels * (bitsPerSample / 8)
        let fileSize = 36 + dataSize

        var data = Data()

        // RIFF header
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt subchunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // subchunk size
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM format
        data.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) })

        // data subchunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        data.append(Data(count: dataSize)) // silent samples (all zeros)

        return data
    }
}
