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
        matchRequest.minPlayers = 3
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
#endif
