//
//  GameKitManager.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Handles Game Center authentication, matchmaking, and UI interactions.

import Foundation

#if !TEST_MODE
import GameKit
import AppKit // Import AppKit for macOS
#endif

class GameKitManager: NSObject, ObservableObject {
    // Authentication properties
    @Published var isAuthenticated = false
    @Published var authenticationErrorMessage: String? = nil
    
    // Matchmaking properties
    @Published var isMatchmaking = false
    @Published var gameStarted = false
    
#if !TEST_MODE
    @Published var match: GKMatch?
    @Published var playersInMatch: [GKPlayer] = []
    
    // Map to store GKPlayer to PlayerId associations
    private var playerIdMapping: [GKPlayer: PlayerId] = [:]
    private var matchRequest: GKMatchRequest
    private var inviteViewController: GKMatchmakerViewController?
#endif
    
    weak var connectionManager: ConnectionManager?

    override init() {
#if !TEST_MODE
        // Configure the match request
        matchRequest = GKMatchRequest()
        matchRequest.minPlayers = 3
        matchRequest.maxPlayers = 3
        // Optionally set player attributes or groups
#endif
        
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
                        strongSelf.presentViewController(vc)
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
    // MARK: - Player ID Mapping
    
    private func determinePlayerId(for player: GKPlayer) -> PlayerId? {
        let name = player.displayName
        guard let localPlayerID = GCPlayerIdAssociation[name] else {
            // Provide a fallback or handle the error
            logWithTimestamp("No matching PlayerId for \(name)")
            return nil
        }
        return localPlayerID
    }

    func mapPlayer(_ gkPlayer: GKPlayer, to playerId: PlayerId) {
        playerIdMapping[gkPlayer] = playerId
    }

    func getPlayerId(for gkPlayer: GKPlayer) -> PlayerId? {
        return playerIdMapping[gkPlayer]
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
    
    private func presentAsSheet(_ viewController: NSViewController) {
        if let rootViewController = NSApplication.shared.windows.first?.contentViewController {
            rootViewController.presentAsSheet(viewController)
        } else {
            logWithTimestamp("No window available to present sheet.")
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
        guard GKLocalPlayer.local.isAuthenticated else {
            logWithTimestamp("Local player not authenticated, cannot invite.")
            return
        }

        let request = GKMatchRequest()
        request.minPlayers = 3
        request.maxPlayers = 3
        request.inviteMessage = "C'est l'heure de ta leçon !"

        if let vc = GKMatchmakerViewController(matchRequest: request) {
            logWithTimestamp("Setting up matchmaker delegate")
            vc.matchmakerDelegate = self  // Set self as the delegate
            
            // Store a strong reference to the view controller
            inviteViewController = vc
            
            // Debug: Check if delegate methods are implemented
            let delegateClass = type(of: self)
            let wasCancelled = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewControllerWasCancelled(_:)))
            let didFail = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewController(_:didFailWithError:)))
            let didFind = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewController(_:didFind:)))
            
            logWithTimestamp("Delegate methods implemented: wasCancelled=\(wasCancelled), didFail=\(didFail), didFind=\(didFind)")
            
            presentAsSheet(vc)
            logWithTimestamp("Presenting invite friends UI.")
        } else {
            logWithTimestamp("Failed to create GKMatchmakerViewController.")
        }
    }

    func dismissInviteUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let vc = self.inviteViewController {
                logWithTimestamp("Dismissing invite UI")
                vc.dismiss(nil)
                self.inviteViewController = nil
            } else {
                logWithTimestamp("No invite UI to dismiss")
            }
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

#if !TEST_MODE
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
        isMatchmaking = false
        viewController.dismiss(nil)
        if let window = viewController.view.window {
            window.sheetParent?.endSheet(window)
        }
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        logWithTimestamp("GameKitManager: matchmakerViewController:didFailWithError: \(error.localizedDescription)")
        isMatchmaking = false
        viewController.dismiss(nil)
        if let window = viewController.view.window {
            window.sheetParent?.endSheet(window)
        }
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        logWithTimestamp("GameKitManager: matchmakerViewController:didFind: called with players: \(match.players.map { $0.displayName })")
        
        // Store the match and update state
        isMatchmaking = false
        self.match = match
        match.delegate = self
        
        // Configure the connection BEFORE dismissing
        connectionManager?.configureMatch(match)
        
        // Now dismiss the view controller
        DispatchQueue.main.async {
            viewController.dismiss(nil)
            if self.inviteViewController === viewController {
                self.inviteViewController = nil
            }
            if let window = viewController.view.window {
                window.sheetParent?.endSheet(window)
            }
            
            // Log the state after configuration
            self.logWithTimestamp("Match configuration completed, waiting for all players to connect")
        }
    }
}

// MARK: - GKMatchDelegate Implementation
extension GameKitManager: GKMatchDelegate {
    // Implement required GKMatchDelegate methods here
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        logWithTimestamp("Player \(player.displayName) connection state changed to: \(state.rawValue)")
        // Handle player connection state changes
    }
}
#endif

//==========================================================================================================

////
////  GameKitManager.swift
////  Whist
////
////  Created by Tony Buffard on 2024-11-18.
////  Handles Game Center authentication and matchmaking.
//
//import Foundation
//
//#if !TEST_MODE
//import GameKit
//import AppKit // Import AppKit for macOS
//#endif
//
//class GameKitManager: NSObject, ObservableObject, GKLocalPlayerListener, GKMatchDelegate {
//    var matchmakingViewModel: MatchmakingViewModel?
//
//    @Published var isAuthenticated = false
//    @Published var authenticationErrorMessage: String? = nil
//    
//#if !TEST_MODE
//    @Published var match: GKMatch?
//    @Published var playersInMatch: [GKPlayer] = []
//    // Map to store GKPlayer to PlayerId associations
//    private var playerIdMapping: [GKPlayer: PlayerId] = [:]
//    #endif
//    
//    weak var connectionManager: ConnectionManager?
//
//    override init() {
//        super.init()
//    }
//
//    func authenticateLocalPlayer() {
//        #if !TEST_MODE
//        DispatchQueue.main.async {
//            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
//                DispatchQueue.main.async {
//                    guard let strongSelf = self else {
//                        return
//                    }
//                    
//                    if let error = error {
//                        strongSelf.authenticationErrorMessage = error.localizedDescription  // Set error message
//                        strongSelf.logWithTimestamp("Authentication error: \(error.localizedDescription)")
//                        return
//                    }
//
//                    if let vc = viewController {
//                        strongSelf.presentAuthenticationViewController(vc)
//                    } else if GKLocalPlayer.local.isAuthenticated {
//                        strongSelf.isAuthenticated = true
//                        strongSelf.authenticationErrorMessage = nil  // Clear any previous error
//                        strongSelf.logWithTimestamp("Game Center authentication successful.")
//                        
//                        GKLocalPlayer.local.register(strongSelf)
//                        
//                        // Assign a PlayerId based on the authenticated player's name
//                        if let playerId = strongSelf.determinePlayerId(for: GKLocalPlayer.local) {
//                            strongSelf.connectionManager?.setLocalPlayerID(playerId)
//                        }
//                    } else {
//                        strongSelf.isAuthenticated = false
//                        strongSelf.authenticationErrorMessage = "Game Center authentication failed."
//                        strongSelf.logWithTimestamp("Game Center authentication failed.")
//                    }
//                }
//            }
//        }
//        #else
//        // In test mode, simulate successful authentication
//        self.isAuthenticated = true
//        self.authenticationErrorMessage = nil
//        logWithTimestamp("Test mode: Authentication simulated as successful.")
//        #endif
//    }
//
//    #if !TEST_MODE
//    // MARK: Release functions
//    private func determinePlayerId(for player: GKPlayer) -> PlayerId? {
//        let name = player.displayName
//        guard let localPlayerID = GCPlayerIdAssociation[name] else {
//            // Provide a fallback or handle the error
//            logWithTimestamp("No matching PlayerId for \(name)")
//            return nil
//        }
//        return localPlayerID
//    }
//
//    func mapPlayer(_ gkPlayer: GKPlayer, to playerId: PlayerId) {
//        playerIdMapping[gkPlayer] = playerId
//    }
//
//    func getPlayerId(for gkPlayer: GKPlayer) -> PlayerId? {
//        return playerIdMapping[gkPlayer]
//    }
//    
//    private func presentAuthenticationViewController(_ viewController: NSViewController) {
//        // Present the view controller in your app
//        if let window = NSApplication.shared.windows.first {
//            window.contentViewController?.presentAsModalWindow(viewController)
//        } else {
//            logWithTimestamp("No window available to present the authentication view controller.")
//        }
//    }
//
//    #endif
//
//    func logWithTimestamp(_ message: String) {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm:ss"
//        let timestamp = formatter.string(from: Date())
//        print("[\(timestamp)] \(message)")
//    }
//}
