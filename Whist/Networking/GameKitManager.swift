//
//  GameKitManager.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Handles Game Center authentication and matchmaking.

import Foundation

#if !TEST_MODE
import GameKit
import AppKit // Import AppKit for macOS
#endif

class GameKitManager: NSObject, ObservableObject {

    @Published var isAuthenticated = false

    #if !TEST_MODE
    @Published var match: GKMatch?
    @Published var playersInMatch: [GKPlayer] = []
    #endif

    override init() {
        super.init()
    }

    func authenticateLocalPlayer() {
        #if !TEST_MODE
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let error = error {
                print("Authentication error: \(error.localizedDescription)")
            }

            if let vc = viewController {
                self?.presentAuthenticationViewController(vc)
            } else if GKLocalPlayer.local.isAuthenticated {
                self?.isAuthenticated = true
                print("Game Center authentication successful.")
            } else {
                self?.isAuthenticated = false
                print("Game Center authentication failed.")
            }
        }
        #else
        // In test mode, simulate successful authentication
        self.isAuthenticated = true
        print("Test mode: Authentication simulated as successful.")
        #endif
    }

    #if !TEST_MODE
    private func presentAuthenticationViewController(_ viewController: NSViewController) {
        // Present the view controller in your app
        if let window = NSApplication.shared.windows.first {
            window.contentViewController?.presentAsModalWindow(viewController)
        } else {
            print("No window available to present the authentication view controller.")
        }
    }
    #endif
}
