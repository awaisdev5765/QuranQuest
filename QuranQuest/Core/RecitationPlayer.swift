import AVFoundation
import MediaPlayer
import SwiftUI

struct PlaybackPlan: Equatable {
    let ayahs: [Int]
    init(ayahs: [Int], repetitions: Int = 1, rounds: Int = 1) {
        let verseRepeats = ayahs.flatMap { Array(repeating: $0, count: max(1, min(20, repetitions))) }
        self.ayahs = Array(repeating: verseRepeats, count: max(1, min(10, rounds))).flatMap { $0 }
    }
}

@MainActor
final class RecitationPlayer: ObservableObject {
    struct Reciter: Codable, Identifiable, Hashable {
        let identifier: String
        let englishName: String
        let name: String
        var id: String { identifier }
    }
    enum State: String { case idle, loading, playing, paused, waiting, completed, failed }
    static let shared = RecitationPlayer()
    static let defaultReciters = [
        Reciter(identifier: "ar.alafasy", englishName: "Mishary Rashid Alafasy", name: "مشاري راشد العفاسي"),
        Reciter(identifier: "ar.abdulbasitmurattal", englishName: "Abdul Basit Abdul Samad", name: "عبد الباسط عبد الصمد"),
        Reciter(identifier: "ar.husary", englishName: "Mahmoud Khalil Al-Husary", name: "محمود خليل الحصري"),
        Reciter(identifier: "ar.minshawi", englishName: "Muhammad Siddiq Al-Minshawi", name: "محمد صديق المنشاوي"),
        Reciter(identifier: "ar.sudais", englishName: "Abdul Rahman Al-Sudais", name: "عبد الرحمن السديس")
    ]
    @Published private(set) var reciters = defaultReciters
    @Published private(set) var selectedIdentifier = UserDefaults.standard.string(forKey: "selectedReciter") ?? "ar.alafasy"
    @Published private(set) var state: State = .idle
    @Published private(set) var playingAyah: Int?
    @Published private(set) var title = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var queue: [Int] = []
    @Published private(set) var queueIndex = 0
    @Published private(set) var isLive = false
    @Published var speed: Float = 1 { didSet { if state == .playing && !isLive { player.rate = speed }; updateNowPlaying() } }
    @Published var offlineOnly = UserDefaults.standard.bool(forKey: "offlineAudioOnly") {
        didSet { UserDefaults.standard.set(offlineOnly, forKey: "offlineAudioOnly"); if offlineOnly { stop() } }
    }
    @Published private(set) var isLoadingReciters = false
    @Published private(set) var reciterError: String?
    private let player = AVPlayer()
    private var statusObservation: NSKeyValueObservation?
    private var controlObservation: NSKeyValueObservation?
    private var itemObservers: [NSObjectProtocol] = []
    private var sessionObservers: [NSObjectProtocol] = []
    private var timeObserver: Any?
    private var delayedAdvance: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var liveURL: URL?
    private var pauseSeconds: Double = 0
    private var titleOverride: String?
    private var pausedBetweenVerses = false
    private var wantsPlayback = false
    private var resumeAfterInterruption = false
    private var generation = UUID()
    var selectedReciterName: String { reciters.first { $0.identifier == selectedIdentifier }?.englishName ?? selectedIdentifier }
    var isActive: Bool { state != .idle }
    var canPause: Bool { [.playing, .loading, .waiting].contains(state) }

    private init() {
        controlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.syncPlaybackState() }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed = time.seconds.isFinite ? max(0, time.seconds) : 0
                let value = self.player.currentItem?.duration.seconds ?? 0
                self.duration = value.isFinite ? max(0, value) : 0
                self.updateNowPlaying()
            }
        }
        sessionObservers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    self.resumeAfterInterruption = self.canPause; self.pause()
                } else if self.resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                    self.resume()
                }
            }
        })
        sessionObservers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { Task { @MainActor in self?.pause() } }
        })
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success }
        commands.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        commands.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.next() }; return .success }
        commands.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.previous() }; return .success }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in self?.seek(position) }; return .success
        }
    }
    func select(_ reciter: Reciter) {
        stop(); selectedIdentifier = reciter.identifier
        UserDefaults.standard.set(reciter.identifier, forKey: "selectedReciter")
    }
    func loadReciters() async {
        guard !isLoadingReciters else { return }
        isLoadingReciters = true; reciterError = nil
        defer { isLoadingReciters = false }
        struct Response: Decodable { let data: [Reciter] }
        do {
            let (data, response) = try await URLSession.shared.data(from: URL(string: "https://api.alquran.cloud/v1/edition?format=audio&type=versebyverse&language=ar")!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let values = try JSONDecoder().decode(Response.self, from: data).data.filter { AudioDownloads.remoteURL(reciter: $0.identifier, ayah: 1) != nil }
            if !values.isEmpty {
                var seen: Set<String> = []
                reciters = (values + Self.defaultReciters).filter { seen.insert($0.id).inserted }.sorted { $0.englishName < $1.englishName }
            }
        } catch { reciterError = "Couldn't refresh reciters. The included reciters are still available." }
    }
    func toggle(ayahNumber: Int) {
        if playingAyah == ayahNumber && !isLive {
            canPause ? pause() : resume()
        } else { play(ayahs: [ayahNumber]) }
    }
    func play(ayahs: [Int], repetitions: Int = 1, rounds: Int = 1, pause: Double = 0, titleOverride: String? = nil) {
        stop()
        self.titleOverride = titleOverride
        queue = PlaybackPlan(ayahs: ayahs.filter { (1...6236).contains($0) }, repetitions: repetitions, rounds: rounds).ayahs
        pauseSeconds = max(0, pause); queueIndex = 0
        guard !queue.isEmpty else { return }
        loadCurrent()
    }
    func playRadio(name: String, url: URL) {
        stop(); isLive = true; liveURL = url; title = name
        if offlineOnly { fail("Live radio needs internet. Turn off offline-only audio in Settings."); return }
        load(url)
    }
    private func loadCurrent() {
        guard queue.indices.contains(queueIndex) else { state = .completed; wantsPlayback = false; updateNowPlaying(); return }
        let ayah = queue[queueIndex]
        playingAyah = ayah; title = titleOverride ?? QuranLibrary.shared.reference(ayah)
        if let local = AudioDownloads.shared.localURL(reciter: selectedIdentifier, ayah: ayah) { load(local) }
        else if offlineOnly { fail("This verse isn't downloaded for \(selectedReciterName). Download its surah or turn off offline-only audio.") }
        else if let url = AudioDownloads.remoteURL(reciter: selectedIdentifier, ayah: ayah) { load(url) }
    }
    private func cleanItem() {
        generation = UUID(); delayedAdvance?.cancel(); delayedAdvance = nil; watchdog?.cancel(); watchdog = nil
        statusObservation = nil
        itemObservers.forEach { NotificationCenter.default.removeObserver($0) }; itemObservers = []
        player.pause(); player.replaceCurrentItem(with: nil)
    }
    private func load(_ url: URL) {
        cleanItem(); elapsed = 0; duration = 0; errorMessage = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { fail("Audio couldn't start. \(error.localizedDescription)"); return }
        wantsPlayback = true; pausedBetweenVerses = false; state = .loading
        let item = AVPlayerItem(url: url)
        let token = generation
        player.replaceCurrentItem(with: item)
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                if item.status == .failed { self.fail("Unable to play this audio. Check your connection and retry.") }
                else if item.status == .readyToPlay && self.wantsPlayback { self.player.playImmediately(atRate: self.isLive ? 1 : self.speed) }
            }
        }
        itemObservers.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self, self.generation == token else { return }; self.finishedItem() }
        })
        itemObservers.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self, self.generation == token else { return }; self.fail("Playback was interrupted. Tap Retry to reconnect.") }
        })
        player.playImmediately(atRate: isLive ? 1 : speed)
        startWatchdog(); updateNowPlaying()
    }
    private func startWatchdog() {
        guard watchdog == nil else { return }
        let token = generation
        watchdog = Task {
            do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
            guard generation == token, state == .loading else { return }
            fail("Audio is taking too long to load. Check your connection and retry.")
        }
    }
    private func syncPlaybackState() {
        guard wantsPlayback, state != .failed, state != .waiting, state != .completed, state != .idle else { return }
        switch player.timeControlStatus {
        case .playing: state = .playing; watchdog?.cancel(); watchdog = nil
        case .waitingToPlayAtSpecifiedRate: state = .loading; startWatchdog()
        case .paused: break
        @unknown default: break
        }
        updateNowPlaying()
    }
    private func finishedItem() {
        guard !isLive else { fail("The live stream ended. Tap Retry to reconnect."); return }
        watchdog?.cancel(); watchdog = nil
        if queueIndex + 1 >= queue.count { wantsPlayback = false; state = .completed; updateNowPlaying(); return }
        if pauseSeconds > 0 {
            state = .waiting
            let token = generation
            delayedAdvance = Task {
                do { try await Task.sleep(nanoseconds: UInt64(pauseSeconds * 1_000_000_000)) } catch { return }
                guard generation == token, wantsPlayback else { return }
                queueIndex += 1; loadCurrent()
            }
        } else { queueIndex += 1; loadCurrent() }
    }
    func pause() {
        guard isActive else { return }
        pausedBetweenVerses = state == .waiting
        wantsPlayback = false; delayedAdvance?.cancel(); delayedAdvance = nil; watchdog?.cancel(); watchdog = nil
        player.pause(); state = .paused; updateNowPlaying()
    }
    func resume() {
        guard isActive else { return }
        if state == .failed { retry(); return }
        if state == .completed { queueIndex = 0; loadCurrent(); return }
        if isLive { retry(); return }
        if pausedBetweenVerses { pausedBetweenVerses = false; next(); return }
        if duration > 0 && elapsed >= duration - 0.2 { next(); return }
        do { try AVAudioSession.sharedInstance().setActive(true) } catch { fail(error.localizedDescription); return }
        wantsPlayback = true; state = .loading
        player.playImmediately(atRate: speed); startWatchdog()
    }
    func retry() {
        if isLive, let liveURL {
            guard !offlineOnly else { fail("Live radio needs internet. Turn off offline-only audio in Settings."); return }
            load(liveURL)
        } else { loadCurrent() }
    }
    func next() { guard !isLive, queueIndex + 1 < queue.count else { return }; queueIndex += 1; loadCurrent() }
    func previous() { guard !isLive, !queue.isEmpty else { return }; queueIndex = max(0, queueIndex - 1); loadCurrent() }
    func seek(_ seconds: Double) {
        guard !isLive, duration > 0 else { return }
        player.seek(to: CMTime(seconds: min(duration, max(0, seconds)), preferredTimescale: 600))
    }
    func stop() {
        wantsPlayback = false; cleanItem(); state = .idle; playingAyah = nil; queue = []; queueIndex = 0
        isLive = false; liveURL = nil; titleOverride = nil; pausedBetweenVerses = false; elapsed = 0; duration = 0; errorMessage = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func fail(_ message: String) {
        wantsPlayback = false; player.pause(); watchdog?.cancel(); watchdog = nil
        state = .failed; errorMessage = message; updateNowPlaying()
    }
    private func updateNowPlaying() {
        guard isActive else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: isLive ? "Live Quran radio" : selectedReciterName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? (isLive ? 1 : speed) : 0,
            MPNowPlayingInfoPropertyIsLiveStream: isLive
        ]
        let commands = MPRemoteCommandCenter.shared()
        commands.changePlaybackPositionCommand.isEnabled = !isLive && duration > 0
        commands.nextTrackCommand.isEnabled = !isLive && queueIndex + 1 < queue.count
        commands.previousTrackCommand.isEnabled = !isLive && !queue.isEmpty
    }
}
