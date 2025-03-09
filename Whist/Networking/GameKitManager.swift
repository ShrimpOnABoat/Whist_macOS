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
    
    @Published var localUsername: String = "Pas connecté encore"
    @Published var localImage: NSImage = NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: "Default Player Avatar") ?? NSImage(size: NSSize(width: 50, height: 50))

    
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
                        logger.log("Authentication error: \(error.localizedDescription)")
                        completion("", defaultPlayerImage) // Return default image
                        return
                    }

                    if let vc = viewController {
                        strongSelf.presentViewController(vc)
                    } else if GKLocalPlayer.local.isAuthenticated {
                        strongSelf.isAuthenticated = true
                        strongSelf.authenticationErrorMessage = nil
                        logger.log("Game Center authentication successful.")

                        GKLocalPlayer.local.register(strongSelf)

                        let playerName = GKLocalPlayer.local.displayName
                        strongSelf.localUsername = playerName

                        // Attempt to load the player's photo
                        GKLocalPlayer.local.loadPhoto(for: .normal) { image, error in
                            if let error = error {
                                logger.log("Error loading player photo: \(error.localizedDescription)")
                            }

                            let playerImage = image ?? defaultPlayerImage
                            strongSelf.localImage = playerImage
                            completion(playerName, playerImage) // Return the player's name and either the loaded or default image
                        }

                    } else {
                        strongSelf.isAuthenticated = false
                        strongSelf.authenticationErrorMessage = "Game Center authentication failed."
                        logger.log("Game Center authentication failed.")
                        completion("", defaultPlayerImage) // Return default image
                    }
                }
            }
        }
    }

    // MARK: - UI Presentation
    
    private func presentViewController(_ viewController: NSViewController) {
        // Present the view controller in your app
        if let window = NSApplication.shared.mainWindow {
//            window.contentViewController?.presentAsModalWindow(viewController)
            window.contentViewController?.presentAsSheet(viewController)
        } else {
            logger.log("No window available to present the view controller.")
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
                logger.log("Error loading local player photo: \(error.localizedDescription)")
            }
            completion(name, image)
        }
    }
    
    func inviteFriends() {
        guard isAuthenticated else {
            logger.log("Local player not authenticated, cannot invite.")
            return
        }

        let request = GKMatchRequest()
        request.minPlayers = 3
        request.maxPlayers = 3
        request.inviteMessage = "C'est l'heure de ta leçon !"
        request.playerAttributes = 1 // should set the request to inviteOnly

        if let vc = GKMatchmakerViewController(matchRequest: request) {
            logger.log("Setting up matchmaker delegate")
            vc.matchmakerDelegate = self  // Set self as the delegate
            
            let delegateClass = type(of: self)
            let wasCancelled = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewControllerWasCancelled(_:)))
            let didFail = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewController(_:didFailWithError:)))
            let didFind = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewController(_:didFind:)))
            
            logger.log("Delegate methods implemented: wasCancelled=\(wasCancelled), didFail=\(didFail), didFind=\(didFind)")
            
            if let mainWindow = NSApplication.shared.mainWindow,
               let contentViewController = mainWindow.contentViewController {
                contentViewController.presentAsSheet(vc)
                inviteViewController = vc
                logger.log("Presenting invite friends UI.")
            }
        } else {
            logger.log("Failed to create GKMatchmakerViewController.")
        }
    }
}

// MARK: - GKLocalPlayerListener
extension GameKitManager: GKLocalPlayerListener {
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        logger.log("Player \(player.displayName) accepted invite")
        guard let matchmakerVC = GKMatchmakerViewController(invite: invite) else {
            logger.log("Failed to create matchmaker VC from invite")
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
        
        logger.log("Invite acceptance workflow started - presented GKMatchmakerViewController")
    }
}

// MARK: - GKMatchmakerViewControllerDelegate
// MARK: - GKMatchmakerViewControllerDelegate
extension GameKitManager: GKMatchmakerViewControllerDelegate {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        logger.log("GameKitManager: matchmakerViewControllerWasCancelled called")
        
        // Dispatch UI updates to the main thread
        DispatchQueue.main.async { [weak self] in
            viewController.dismiss(nil)
            self?.inviteViewController = nil
        }
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        logger.log("GameKitManager: matchmakerViewController:didFailWithError: \(error.localizedDescription)")
        
        // Dispatch UI updates to the main thread
        DispatchQueue.main.async { [weak self] in
            viewController.dismiss(nil)
            self?.inviteViewController = nil
        }
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        /// This function is invoked at the same time in all 3 apps, once the last player joins the match
        logger.log("🫑 GameKitManager: matchmakerViewController:didFind: called with players: \(match.players.map { $0.displayName })")
        
        // Process initial match setup on a background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Store the match and update state
            DispatchQueue.main.async {
                self.match = match
            }
            
            match.delegate = self
            
            // Configure the connection BEFORE dismissing
            DispatchQueue.main.async {
                self.connectionManager?.configureMatch(match)
            }
            
            // Now dismiss the view controller on the main thread
            DispatchQueue.main.async {
                viewController.dismiss(nil)
                self.inviteViewController = nil
            }
        }
    }
}

// MARK: - GKMatchDelegate
extension GameKitManager: GKMatchDelegate {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        logger.log("Received data from \(player.displayName)")
        
        // Process received data on a background queue to prevent blocking the GameKit thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Forward the received data to ConnectionManager
            self.connectionManager?.handleReceivedGameKitData(data, from: player)
        }
    }
    
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        /// This function is invoked on all remaining apps when a player connects or disconnects, but only after matchmakerViewController(_:didFind:) has been invoked
        logger.log("🫑 Player \(player.displayName) connection state changed to: \(state.rawValue)")
        
        // Process player connection state changes on a background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let playerId = self.determinePlayerId(for: player)
            
            // Update UI and connection status on the main thread if needed
            DispatchQueue.main.async {
                if let playerId = playerId {
                    self.connectionManager?.updatePlayerConnectionStatus(playerID: playerId, isConnected: state == .connected)
                } else {
                    logger.log("Warning: Could not determine PlayerId for \(player.displayName)")
                }
                
                // Update any UI-related properties if needed
                if state == .connected {
                    // Handle player connected UI updates if needed
                } else {
                    // Handle player disconnected UI updates if needed
                }
            }
        }
    }
    
    func match(_ match: GKMatch, didFailWithError error: Error?) {
        // Log the error
        logger.log("Match failed with error: \(error?.localizedDescription ?? "Unknown error")")
        
        // Handle match failure on a background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Handle failure and update UI on the main thread
            DispatchQueue.main.async {
                self.connectionManager?.handleMatchFailure(error: error)
                
                // Additional UI updates if needed
                // self.someUIProperty = someNewValue
            }
        }
    }
    
    private func determinePlayerId(for player: GKPlayer) -> PlayerId? {
        let name = player.displayName
        guard let localPlayerID = GCPlayerIdAssociation[name] else {
            // Provide a fallback or handle the error
            logger.log("No matching PlayerId for \(name)")
            return nil
        }
        return localPlayerID
    }
}
#endif
