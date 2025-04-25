//
//  SoundManager.swift
//  Whist
//
//  Created by Tony Buffard on 2025-01-15.
//

import AudioToolbox

class SoundManager {
    private var soundIDs: [String: SystemSoundID] = [:]
    private let soundFiles: [String] = [
        "card shuffle.mp3",
        "applaud.wav",
        "fail.wav",
        "impact.wav",
        "Confetti.wav",
        "pouet.wav",
        "normal-click.wav",
        "play card.mp3"
    ]

    init() {
        preloadAllSounds()
    }

    /// Preload all sound files listed in `soundFiles`
    private func preloadAllSounds() {
        for soundFile in soundFiles {
            let components = soundFile.split(separator: ".")
            guard components.count == 2 else {
                logger.log("Invalid sound file name: \(soundFile)")
                continue
            }
            let name = String(components[0])
            let ext = String(components[1])
            preloadSound(named: name, withExtension: ext)
        }
    }
    
    /// Preload a sound to reduce latency during playback
    func preloadSound(named fileName: String, withExtension fileExtension: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            logger.log("Sound file \(fileName).\(fileExtension) not found.")
            return
        }

        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        soundIDs[fileName] = soundID
    }

    /// Play a preloaded sound
    func playSound(named fileName: String) {
        guard fileName != "normal-click" else {
            return
        }
        guard let soundID = soundIDs[fileName] else {
            logger.log("Sound \(fileName) not preloaded. Call preloadSound() first.")
            return
        }
        AudioServicesPlaySystemSound(soundID)
    }

    /// Unload a sound to free up memory
    func unloadSound(named fileName: String) {
        guard let soundID = soundIDs[fileName] else { return }
        AudioServicesDisposeSystemSoundID(soundID)
        soundIDs.removeValue(forKey: fileName)
    }

    /// Unload all sounds
    func unloadAllSounds() {
        for soundID in soundIDs.values {
            AudioServicesDisposeSystemSoundID(soundID)
        }
        soundIDs.removeAll()
    }
}

extension GameManager {
    func playSound(named filename: String) {
        soundManager.playSound(named: filename)
    }
}
