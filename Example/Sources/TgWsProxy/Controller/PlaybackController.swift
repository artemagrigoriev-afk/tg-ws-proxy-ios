import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

///'Silent' audio play controller
final class PlaybackController: NSObject, Sendable {
    
    ///Audio play singleton
    static let shared = PlaybackController()
    
    ///System audio player
    fileprivate static let _player = AVPlayer()
    
    ///Playing item last tracked 'currentTime' for preventing multiple 'progressListener' events fire
    fileprivate var _lastCurrTime: CMTime?
    ///Silent audio url
    fileprivate let _audioDataUrl: URL
    
    ///'Silent' audio playing flag
    var playing: Bool {
        get {
            guard let safeCurrItem = PlaybackController._player.currentItem, safeCurrItem.duration.seconds > 0.0, safeCurrItem.error == nil else {return false}
            return PlaybackController._player.timeControlStatus == .playing && PlaybackController._player.rate != 0
        }
    }
    
    ///'Silent' audio duration in seconds
    fileprivate var _trackDuration: TimeInterval {
        get
        {
            guard let safePlayingItem = PlaybackController._player.currentItem else {return 0}
            return safePlayingItem.duration.seconds
        }
    }
    
    fileprivate override init() {
        _audioDataUrl = Bundle.main.url(forResource: "blank", withExtension: "mp3")!
        super.init()
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main, using: onAudioRouteChange)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main, using: onAVInterruption)
#if canImport(UIKit)
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main, using: handleFgState)
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: handleFgState)
#endif
        let periodTime = CMTimeMakeWithSeconds(1, preferredTimescale: Int32(NSEC_PER_SEC))
        _ = PlaybackController._player.addPeriodicTimeObserver(forInterval: periodTime, queue: DispatchQueue.main, using: onPlaybackProgress)
    }
    
    deinit {
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
        if (PlaybackController._player.currentItem == nil) {
            PlaybackController._player.replaceCurrentItem(with: AVPlayerItem(url: _audioDataUrl))
        } else {
            _ = setPlaybackPosition(position: 0.0)
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            PlaybackController._player.play()
        } catch {
            print(error)
            return false
        }
        return true
    }
    
    ///Stops playing looped 'silent' audio and releases audio session
    func stopPlaySilentAudio() {
        PlaybackController._player.pause()
        _ = setPlaybackPosition(position: 0.0)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print(error)
        }
    }
    
    ///Sets playing looped 'silent' audio position
    ///- Parameter position: Desired audio position
    ///- Returns: Set playback position result
    fileprivate func setPlaybackPosition(position: TimeInterval) -> Bool {
        if (PlaybackController._player.currentItem == nil || position < 0 || _trackDuration < position) {
            return false
        }
        let seekTime: CMTime = CMTimeMakeWithSeconds(position, preferredTimescale: Int32(NSEC_PER_SEC))
        PlaybackController._player.seek(to: seekTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        return true
    }
        
    ///Audio playing progress handler: loops audio
    ///- Parameter currentTime: Audio playback position
    fileprivate func onPlaybackProgress(currentTime: CMTime) {
        if (_lastCurrTime?.seconds.rounded() == currentTime.seconds.rounded()) {
            return
        }
        _lastCurrTime = currentTime
#if DEBUG
        print(currentTime)
#endif
        if (currentTime.seconds <= 4.2) {
            return
        }
        _ = setPlaybackPosition(position: 0.0)
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
    
    fileprivate func handleFgState(_ notification: Notification) {
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
}
