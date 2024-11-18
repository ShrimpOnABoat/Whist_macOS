//
//  TestManager.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-20.
//

// TestManager.swift

import Foundation

class TestManager: ObservableObject {
    static let shared = TestManager()
    @Published var playerID: PlayerId = .toto

    private init() {
        if Constants.TEST_MODE {
            // Optionally, prompt the user to enter a player name or assign one automatically
            playerID = .toto
        }
    }
}
