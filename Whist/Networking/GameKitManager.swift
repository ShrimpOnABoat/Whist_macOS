//
//  GameKitManager.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Handles Game Center authentication, matchmaking, and UI interactions.

#if !TEST_MODE
import Foundation

import GameKit
import AppKit // Import AppKit for macOS

class GameKitManager: NSObject, ObservableObject {
    // Authentication properties
    @Published var isAuthenticated = false
    @Published var authenticationErrorMessage: String? = nil
    
    @Published var match: GKMatch?
    @Published var playersInMatch: [GKPlayer] = []
    
    // Map to store GKPlayer to PlayerId associations
    private var matchRequest: GKMatchRequest
    private var inviteViewController: GKMatchmakerViewController?
    
    weak var connectionManager: ConnectionManager?

    override init() {
        // Configure the match request
        matchRequest = GKMatchRequest()
        matchRequest.minPlayers = 3
        matchRequest.maxPlayers = 3

        // Optionally set player attributes or groups
        super.init()
    }

        // MARK: authenticatePlayer
    
    func authenticateLocalPlayer(completion: @escaping (String, NSImage) -> Void) {
        DispatchQueue.main.async {
            let defaultPlayerImage = NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: "Default Player Avatar") ?? NSImage(size: NSSize(width: 50, height: 50))
            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                DispatchQueue.main.async {
                    guard let strongSelf = self else {
                        completion("", defaultPlayerImage) // Return default values if self is nil
                        return
                    }

                    if let error = error {
                        strongSelf.authenticationErrorMessage = error.localizedDescription
                        strongSelf.logWithTimestamp("Authentication error: \(error.localizedDescription)")
                        completion("", defaultPlayerImage) // Return default image
                        return
                    }

                    if let vc = viewController {
                        strongSelf.presentViewController(vc)
                    } else if GKLocalPlayer.local.isAuthenticated {
                        strongSelf.isAuthenticated = true
                        strongSelf.authenticationErrorMessage = nil
                        strongSelf.logWithTimestamp("Game Center authentication successful.")

                        GKLocalPlayer.local.register(strongSelf)

                        let playerName = GKLocalPlayer.local.displayName

                        // Attempt to load the player's photo
                        GKLocalPlayer.local.loadPhoto(for: .normal) { image, error in
                            if let error = error {
                                strongSelf.logWithTimestamp("Error loading player photo: \(error.localizedDescription)")
                            }

                            let playerImage = image ?? defaultPlayerImage
                            completion(playerName, playerImage) // Return the player's name and either the loaded or default image
                        }

                    } else {
                        strongSelf.isAuthenticated = false
                        strongSelf.authenticationErrorMessage = "Game Center authentication failed."
                        strongSelf.logWithTimestamp("Game Center authentication failed.")
                        completion("", defaultPlayerImage) // Return default image
                    }
                }
            }
        }
    }

    // MARK: - UI Presentation
    
    private func presentViewController(_ viewController: NSViewController) {
        // Present the view controller in your app
        if let window = NSApplication.shared.windows.first {
            window.contentViewController?.presentAsModalWindow(viewController)
        } else {
            logWithTimestamp("No window available to present the view controller.")
        }
    }
    
    // MARK: - Matchmaking Methods
    
    func loadLocalPlayerInfo(completion: @escaping (String, NSImage?) -> Void) {
        let localPlayer = GKLocalPlayer.local
        guard localPlayer.isAuthenticated else {
            completion("", nil)
            return
        }
        
        let name = localPlayer.displayName
        
        // Attempt to load the small (50x50) player photo
        localPlayer.loadPhoto(for: .small) { image, error in
            if let error = error {
                print("Error loading local player photo: \(error.localizedDescription)")
            }
            completion(name, image)
        }
    }
    
    func inviteFriends() {
        guard isAuthenticated else {
            logWithTimestamp("Local player not authenticated, cannot invite.")
            return
        }

        let request = GKMatchRequest()
        request.minPlayers = 3
        request.maxPlayers = 3
        request.inviteMessage = "C'est l'heure de ta leçon !"
        request.playerAttributes = 1 // should set the request to inviteOnly

        if let vc = GKMatchmakerViewController(matchRequest: request) {
            logWithTimestamp("Setting up matchmaker delegate")
            vc.matchmakerDelegate = self  // Set self as the delegate
            
            let delegateClass = type(of: self)
            let wasCancelled = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewControllerWasCancelled(_:)))
            let didFail = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewController(_:didFailWithError:)))
            let didFind = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewController(_:didFind:)))
            
            logWithTimestamp("Delegate methods implemented: wasCancelled=\(wasCancelled), didFail=\(didFail), didFind=\(didFind)")
            
            if let mainWindow = NSApplication.shared.mainWindow,
               let contentViewController = mainWindow.contentViewController {
                contentViewController.presentAsSheet(vc)
                inviteViewController = vc
                logWithTimestamp("Presenting invite friends UI.")
            }
        } else {
            logWithTimestamp("Failed to create GKMatchmakerViewController.")
        }
    }

    func logWithTimestamp(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        print("[\(timestamp)] \(message)")
    }
}

// MARK: - GKLocalPlayerListener Implementation
extension GameKitManager: GKLocalPlayerListener {
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        logWithTimestamp("Player \(player.displayName) accepted invite")
        guard let matchmakerVC = GKMatchmakerViewController(invite: invite) else {
            logWithTimestamp("Failed to create matchmaker VC from invite")
            return
        }

        // Set self as the delegate
        matchmakerVC.matchmakerDelegate = self

        // IMPORTANT: Store this view controller so we can dismiss it later
        self.inviteViewController = matchmakerVC
                
        // On macOS, present the matchmaker as a sheet:
        if let window = NSApplication.shared.windows.first {
            window.contentViewController?.presentAsSheet(matchmakerVC)
        }
        
        logWithTimestamp("Invite acceptance workflow started - presented GKMatchmakerViewController")
    }
}

// MARK: - GKMatchmakerViewControllerDelegate Implementation
extension GameKitManager: GKMatchmakerViewControllerDelegate {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        logWithTimestamp("GameKitManager: matchmakerViewControllerWasCancelled called")
        viewController.dismiss(nil)
        inviteViewController = nil
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        logWithTimestamp("GameKitManager: matchmakerViewController:didFailWithError: \(error.localizedDescription)")
        viewController.dismiss(nil)
        inviteViewController = nil
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        /// This function is invoked at the same time in all 3 apps, once the last player joins the match
        logWithTimestamp("🫑 GameKitManager: matchmakerViewController:didFind: called with players: \(match.players.map { $0.displayName })")
        
        // Store the match and update state
        self.match = match
        match.delegate = self
        
        // Configure the connection BEFORE dismissing
        connectionManager?.configureMatch(match)
        
        // Now dismiss the view controller
        viewController.dismiss(nil)
        inviteViewController = nil
    }
}

// MARK: - GKMatchDelegate Implementation
extension GameKitManager: GKMatchDelegate {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        logWithTimestamp("Received data from \(player.displayName)")
        
        // Forward the received data to ConnectionManager
        connectionManager?.handleReceivedGameKitData(data, from: player)
    }
    
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        /// This function is invoked on all remaining apps when a player connects or disconnects, but only after matchmakerViewController(_:didFind:) has been invoked
        logWithTimestamp("🫑 Player \(player.displayName) connection state changed to: \(state.rawValue)")
        
        if let playerId = determinePlayerId(for: player) {
            connectionManager?.updatePlayerConnectionStatus(playerID: playerId, isConnected: state == .connected ? true: false)
        } else {
            logWithTimestamp("Warning: Could not determine PlayerId for \(player.displayName)")
        }
    }
    
    func match(_ match: GKMatch, didFailWithError error: Error?) {
        logWithTimestamp("Match failed with error: \(error?.localizedDescription ?? "Unknown error")")
        
        connectionManager?.handleMatchFailure(error: error)
    }
    
    private func determinePlayerId(for player: GKPlayer) -> PlayerId? {
        let name = player.displayName
        guard let localPlayerID = GCPlayerIdAssociation[name] else {
            // Provide a fallback or handle the error
            logWithTimestamp("No matching PlayerId for \(name)")
            return nil
        }
        return localPlayerID
    }
}
#endif
