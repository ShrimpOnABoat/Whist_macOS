//
//  SoundManager.swift
//  Whist
//
//  Created by Tony Buffard on 2025-01-15.
//

import AudioToolbox

class SoundManager {
    private var soundIDs: [String: SystemSoundID] = [:]

    /// Preload a sound to reduce latency during playback
    func preloadSound(named fileName: String, withExtension fileExtension: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("Sound file \(fileName).\(fileExtension) not found.")
            return
        }

        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        soundIDs[fileName] = soundID
    }

    /// Play a preloaded sound
    func playSound(named fileName: String) {
        guard let soundID = soundIDs[fileName] else {
            print("Sound \(fileName) not preloaded. Call preloadSound() first.")
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
