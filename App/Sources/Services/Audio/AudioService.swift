import AVFoundation
import UIKit

enum SoundEffect: String, CaseIterable {
    case coin, tip, bell, tap, upgrade, unlock, decline

    var fileName: String { "sfx_\(rawValue)" }
}

/// Plays the bundled, original music loop and sound effects.
/// Uses the ambient session category so it mixes with (and never stops) other apps' audio.
@MainActor
final class AudioService {
    private var music: AVAudioPlayer?
    private var effects: [SoundEffect: AVAudioPlayer] = [:]
    private(set) var musicVolume: Float = 0.6
    private(set) var sfxVolume: Float = 0.8
    private var isActive = false

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        for effect in SoundEffect.allCases {
            if let url = Bundle.main.url(forResource: effect.fileName, withExtension: "wav"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                effects[effect] = player
            }
        }
        if let url = Bundle.main.url(forResource: "music_maple_corner", withExtension: "m4a"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.numberOfLoops = -1
            player.prepareToPlay()
            music = player
        }
    }

    func apply(musicVolume: Double, sfxVolume: Double) {
        self.musicVolume = Float(musicVolume)
        self.sfxVolume = Float(sfxVolume)
        music?.volume = self.musicVolume * 0.55
        updateMusicPlayback()
    }

    func setActive(_ active: Bool) {
        isActive = active
        if active { try? AVAudioSession.sharedInstance().setActive(true) }
        updateMusicPlayback()
    }

    private func updateMusicPlayback() {
        guard let music else { return }
        if isActive && musicVolume > 0.001 {
            if !music.isPlaying { music.play() }
        } else if music.isPlaying {
            music.pause()
        }
    }

    func play(_ effect: SoundEffect) {
        guard sfxVolume > 0.001, let player = effects[effect] else { return }
        player.volume = sfxVolume * 0.7
        player.currentTime = 0
        player.play()
    }
}

/// Gentle haptics that respect the in-game toggle.
@MainActor
final class HapticsService {
    var isEnabled = true
    private let light = UIImpactFeedbackGenerator(style: .soft)
    private let notify = UINotificationFeedbackGenerator()

    func tap() {
        guard isEnabled else { return }
        light.impactOccurred(intensity: 0.6)
    }

    func success() {
        guard isEnabled else { return }
        notify.notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        notify.notificationOccurred(.warning)
    }
}
