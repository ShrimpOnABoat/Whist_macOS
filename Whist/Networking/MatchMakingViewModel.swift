////
////  MatchMakingViewModel.swift
////  Whist
////
////  Created by Tony Buffard on 2024-11-18.
////  Manages the matchmaking interface state.
//
//#if !TEST_MODE
//import Foundation
//import GameKit
//
//class MatchmakingViewModel: NSObject, ObservableObject {
//    @Published var isMatchmaking = false
//    @Published var match: GKMatch?
//    @Published var gameStarted = false
//    
//    private var matchRequest: GKMatchRequest
//    private var inviteViewController: GKMatchmakerViewController?
//
//    weak var gameKitManager: GameKitManager?
//    weak var connectionManager: ConnectionManager?
//    
//    override init() {
//        // Configure the match request
//        matchRequest = GKMatchRequest()
//        matchRequest.minPlayers = 3
//        matchRequest.maxPlayers = 3
//        // Optionally set player attributes or groups
//        
//        super.init()
//    }
//    
//    func configure(gameKitManager: GameKitManager, connectionManager: ConnectionManager) {
//        self.gameKitManager = gameKitManager
//        self.connectionManager = connectionManager
//    }
//    
//    private func presentMatchmakerViewController(_ viewController: NSViewController) {
//        if let rootViewController = NSApplication.shared.windows.first?.contentViewController {
//            rootViewController.presentAsSheet(viewController)
//        }
//    }
//}
//
//extension MatchmakingViewModel: GKMatchmakerViewControllerDelegate, GKMatchDelegate {
//    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
//        logger.log("MatchmakingViewModel: matchmakerViewControllerWasCancelled called")
//        isMatchmaking = false
//        viewController.dismiss(nil)
//        if let window = viewController.view.window {
//            window.sheetParent?.endSheet(window)
//        }
//    }
//    
//    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
//        logger.log("MatchmakingViewModel: matchmakerViewController:didFailWithError: \(error.localizedDescription)")
//        isMatchmaking = false
//        viewController.dismiss(nil)
//        if let window = viewController.view.window {
//            window.sheetParent?.endSheet(window)
//        }
//    }
//    
//    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
//        logger.log("MatchmakingViewModel: matchmakerViewController:didFind: called with players: \(match.players.map { $0.displayName })")
//        
//        // Store the match and update state
//        isMatchmaking = false
//        self.match = match
//        match.delegate = self
//        
//        // Important: Store in gameKitManager too
//        gameKitManager?.match = match
//        
//        // Configure the connection BEFORE dismissing
//        connectionManager?.configureMatch(match)
//        
//        // Now dismiss the view controller
//        DispatchQueue.main.async {
//            viewController.dismiss(nil)
//            if self.inviteViewController === viewController {
//                self.inviteViewController = nil
//            }
//            if let window = viewController.view.window {
//                window.sheetParent?.endSheet(window)
//            }
//            
//            // Log the state after configuration
//            logger.log("Match configuration completed, waiting for allPlayersConnected to become true")
//        }
//    }
//    
//    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
//        logger.log("Player accepted invite")
//        guard let matchmakerVC = GKMatchmakerViewController(invite: invite) else {
//            logger.log("Failed to create matchmaker VC from invite")
//            return
//        }
//
//        // Since we're already in MatchmakingViewModel, set self as the delegate.
//        matchmakerVC.matchmakerDelegate = self
//
//        // IMPORTANT: Store this view controller so we can dismiss it later
//        self.inviteViewController = matchmakerVC
//                
//        // On macOS, present the matchmaker as a sheet:
//        if let window = NSApplication.shared.windows.first {
//            window.contentViewController?.presentAsSheet(matchmakerVC)
//        }
//        
//        logger.log("Invite acceptance workflow started - presented GKMatchmakerViewController")
//
//    }
//
//    private func logger.log(_ message: String) {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm:ss"
//        let timestamp = formatter.string(from: Date())
//        print("[\(timestamp)] \(message)")
//    }
//}
//
//extension MatchmakingViewModel {
//    func loadLocalPlayerInfo(completion: @escaping (String, NSImage?) -> Void) {
//        let localPlayer = GKLocalPlayer.local
//        guard localPlayer.isAuthenticated else {
//            completion("", nil)
//            return
//        }
//        
//        let name = localPlayer.displayName
//        
//        // Attempt to load the small (50x50) player photo
//        localPlayer.loadPhoto(for: .small) { image, error in
//            if let error = error {
//                print("Error loading local player photo: \(error.localizedDescription)")
//            }
//            completion(name, image)
//        }
//    }
//    
//    func inviteFriends() {
//        guard GKLocalPlayer.local.isAuthenticated else {
//            print("Local player not authenticated, cannot invite.")
//            return
//        }
//
//        let request = GKMatchRequest()
//        request.minPlayers = 3
//        request.maxPlayers = 3
//        request.inviteMessage = "C'est l'heure de ta leçon !"
//
//        if let vc = GKMatchmakerViewController(matchRequest: request) {
//            logger.log("Setting up matchmaker delegate")
//            vc.matchmakerDelegate = self  // Set self as the delegate
//            
//            // Store a strong reference to the view controller
//            inviteViewController = vc
//            
//            // Debug: Check if delegate methods are implemented
//            let delegateClass = type(of: self)
//            let wasCancelled = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewControllerWasCancelled(_:)))
//            let didFail = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewController(_:didFailWithError:)))
//            let didFind = delegateClass.instancesRespond(to: #selector(GKMatchmakerViewControllerDelegate.matchmakerViewController(_:didFind:)))
//            
//            logger.log("Delegate methods implemented: wasCancelled=\(wasCancelled), didFail=\(didFail), didFind=\(didFind)")
//            
//            presentMatchmakerViewController(vc)
//            logger.log("Presenting invite friends UI.")
//        } else {
//            logger.log("Failed to create GKMatchmakerViewController.")
//        }
//    }
//
//    func dismissInviteUI() {
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            
//            if let vc = self.inviteViewController {
//                logger.log("Dismissing invite UI")
//                vc.dismiss(nil)
//                self.inviteViewController = nil
//            } else {
//                logger.log("No invite UI to dismiss")
//            }
//        }
//    }
//}
//
//#endif
