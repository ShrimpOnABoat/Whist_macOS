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

class GameKitManager: NSObject, ObservableObject, GKLocalPlayerListener, GKMatchmakerViewControllerDelegate, GKMatchDelegate {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        // The user cancelled matchmaking—dismiss the view controller.
        viewController.dismiss(nil)
        logWithTimestamp("Matchmaking was cancelled by the user.")
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: any Error) {
        // An error occurred during matchmaking—dismiss the view controller and log the error.
        viewController.dismiss(nil)
        logWithTimestamp("Matchmaking failed with error: \(error.localizedDescription)")
        // Optionally, update UI or notify your connectionManager of the failure.
    }
    
    @Published var isAuthenticated = false
    @Published var authenticationErrorMessage: String? = nil  // <-- Added property

    #if !TEST_MODE
    @Published var match: GKMatch?
    @Published var playersInMatch: [GKPlayer] = []
    // Map to store GKPlayer to PlayerId associations
    private var playerIdMapping: [GKPlayer: PlayerId] = [:]
    #endif
    
    weak var connectionManager: ConnectionManager?

    override init() {
        super.init()
    }

    func authenticateLocalPlayer() {
        #if !TEST_MODE
        DispatchQueue.main.async {
            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                DispatchQueue.main.async {
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if let error = error {
                        strongSelf.authenticationErrorMessage = error.localizedDescription  // Set error message
                        strongSelf.logWithTimestamp("Authentication error: \(error.localizedDescription)")
                        return
                    }

                    if let vc = viewController {
                        strongSelf.presentAuthenticationViewController(vc)
                    } else if GKLocalPlayer.local.isAuthenticated {
                        strongSelf.isAuthenticated = true
                        strongSelf.authenticationErrorMessage = nil  // Clear any previous error
                        strongSelf.logWithTimestamp("Game Center authentication successful.")
                        
                        GKLocalPlayer.local.register(strongSelf)
                        
                        // Assign a PlayerId based on the authenticated player's name
                        if let playerId = strongSelf.determinePlayerId(for: GKLocalPlayer.local) {
                            strongSelf.connectionManager?.setLocalPlayerID(playerId)
                        }
                    } else {
                        strongSelf.isAuthenticated = false
                        strongSelf.authenticationErrorMessage = "Game Center authentication failed."
                        strongSelf.logWithTimestamp("Game Center authentication failed.")
                    }
                }
            }
        }
        #else
        // In test mode, simulate successful authentication
        self.isAuthenticated = true
        self.authenticationErrorMessage = nil
        logWithTimestamp("Test mode: Authentication simulated as successful.")
        #endif
    }

    #if !TEST_MODE
    // MARK: Release functions
    private func determinePlayerId(for player: GKPlayer) -> PlayerId? {
        // TODO: Implement correct mapping when I know more about our IDs
        let name = player.displayName.lowercased()
        if name.contains("dd") {
            return .dd
        } else if name.contains("gg") {
            return .gg
        } else if name.contains("toto") {
            return .toto
        }
        return nil
    }

    func mapPlayer(_ gkPlayer: GKPlayer, to playerId: PlayerId) {
        playerIdMapping[gkPlayer] = playerId
    }

    func getPlayerId(for gkPlayer: GKPlayer) -> PlayerId? {
        return playerIdMapping[gkPlayer]
    }
    
    private func presentAuthenticationViewController(_ viewController: NSViewController) {
        // Present the view controller in your app
        if let window = NSApplication.shared.windows.first {
            window.contentViewController?.presentAsModalWindow(viewController)
        } else {
            logWithTimestamp("No window available to present the authentication view controller.")
        }
    }
    
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        // This is called when the user on macOS taps "Accept" in the Game Center invitation
        // Next, you must create a GKMatchmakerViewController or call GKMatchmaker.shared().match(for:).
        logWithTimestamp("Function player called")
        guard let matchmakerVC = GKMatchmakerViewController(invite: invite) else {
            return
        }
        matchmakerVC.matchmakerDelegate = self
        // On macOS, present the matchmaker as a modal window, sheet, or popover:
        if let window = NSApplication.shared.windows.first {
            window.contentViewController?.presentAsSheet(matchmakerVC)
        }
    }
    #endif

    func logWithTimestamp(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        print("[\(timestamp)] \(message)")
    }
}
