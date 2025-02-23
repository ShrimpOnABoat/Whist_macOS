//
//  MatchMakingViewModel.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Manages the matchmaking interface state.

#if !TEST_MODE
import Foundation
import GameKit

class MatchmakingViewModel: NSObject, ObservableObject {
    @Published var isMatchmaking = false
    @Published var match: GKMatch?
    
    private var matchRequest: GKMatchRequest
    weak var gameKitManager: GameKitManager?
    weak var connectionManager: ConnectionManager?
    
    override init() {
        // Configure the match request
        matchRequest = GKMatchRequest()
        matchRequest.minPlayers = 2
        matchRequest.maxPlayers = 3
        // Optionally set player attributes or groups
        
        super.init()
    }
    
    func configure(gameKitManager: GameKitManager, connectionManager: ConnectionManager) {
        self.gameKitManager = gameKitManager
        self.connectionManager = connectionManager
    }
    
    func startMatchmaking() {
        isMatchmaking = true
        let matchmakerVC = GKMatchmakerViewController(matchRequest: matchRequest)
        matchmakerVC?.matchmakerDelegate = self
        
        // Present the matchmaking view controller
        if let vc = matchmakerVC {
            presentMatchmakerViewController(vc)
        }
    }
    
    private func presentMatchmakerViewController(_ viewController: NSViewController) {
        if let rootViewController = NSApplication.shared.windows.first?.contentViewController {
            rootViewController.presentAsSheet(viewController)
        }
    }
}

extension MatchmakingViewModel: GKMatchmakerViewControllerDelegate, GKMatchDelegate {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        isMatchmaking = false
        viewController.dismiss(nil)
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        isMatchmaking = false
        viewController.dismiss(nil)
        logWithTimestamp("Matchmaking failed: \(error.localizedDescription)")
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        logWithTimestamp("Match found with players: \(match.players)")
        logWithTimestamp("Match found: \(match.players.map { $0.displayName })")
        isMatchmaking = false
        viewController.dismiss(nil)
        self.match = match
        match.delegate = self
        gameKitManager?.match = match
        connectionManager?.configureMatch(match)
        logWithTimestamp("Match found with players: \(match.players)")
    }
    
    private func logWithTimestamp(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        print("[\(timestamp)] \(message)")
    }
}

extension MatchmakingViewModel {
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
            print("Local player not authenticated, cannot invite.")
            return
        }
        
        let request = GKMatchRequest()
        request.minPlayers = 2  // Change this to 2 for testing
        request.maxPlayers = 3
        request.inviteMessage = "C'est l'heure de ta leçon !"

        if let vc = GKMatchmakerViewController(matchRequest: request) {
            vc.matchmakerDelegate = self
            presentMatchmakerViewController(vc) // Ensure this is actually called
            print("Presenting invite friends UI.")
        } else {
            print("Failed to create GKMatchmakerViewController.")
        }
    }
}

#endif

