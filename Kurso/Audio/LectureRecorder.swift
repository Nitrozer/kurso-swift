#if os(iOS)
import Foundation
import AVFoundation
import Observation

/// Enregistrement du cours, colle a l'ecriture (§7).
///
/// AAC 32 kbps mono : environ 15 Mo pour deux heures. Le fichier reste dans le
/// conteneur de l'app et hors CloudKit par defaut — deux heures de cours par
/// jour satureraient l'iCloud de l'etudiant.
@MainActor @Observable final class LectureRecorder {
    private(set) var isRecording = false
    private(set) var elapsed: Double = 0
    private(set) var fileName: String?

    private var recorder: AVAudioRecorder?
    private var ticker: Task<Void, Never>?
    private var player: AVAudioPlayer?

    static var directory: URL {
        let base = URL.documentsDirectory.appending(path: "Audio", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func url(for fileName: String) -> URL { directory.appending(path: fileName) }

    /// Demande le micro puis demarre. Rend faux si l'autorisation manque.
    func start() async -> Bool {
        guard !isRecording else { return true }
        guard await AVAudioApplication.requestRecordPermission() else { return false }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let name = "\(UUID().uuidString).m4a"
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
        ]
        guard let made = try? AVAudioRecorder(url: Self.url(for: name), settings: settings),
              made.record() else { return false }

        recorder = made
        fileName = name
        isRecording = true
        elapsed = 0
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, let recorder = self.recorder else { return }
                self.elapsed = recorder.currentTime
            }
        }
        return true
    }

    /// L'instant courant, pour horodater un trait.
    var currentTime: Double { recorder?.currentTime ?? 0 }

    @discardableResult
    func stop() -> (fileName: String, duration: Double)? {
        guard let recorder, let name = fileName else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        ticker?.cancel()
        ticker = nil
        self.recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        return (name, duration)
    }

    /// Joue le fichier a partir de cet instant.
    func play(_ fileName: String, from time: Double) {
        player?.stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let made = try? AVAudioPlayer(contentsOf: Self.url(for: fileName)) else { return }
        made.currentTime = min(max(0, time), made.duration)
        made.play()
        player = made
    }

    func stopPlaying() {
        player?.stop()
        player = nil
    }
}
#endif
