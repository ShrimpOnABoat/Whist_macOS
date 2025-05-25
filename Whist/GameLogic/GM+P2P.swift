//
//  GM+P2P.swift
//  Whist
//
//  Created by Tony Buffard on 2025-05-24.
//

import Foundation
import SwiftUI
import WebRTC
import FirebaseFirestore

extension GameManager {
    
    func updateLocalPlayer(_ playerId: PlayerId, name: String, image: Image) {
        guard let playerIndex = gameState.players.firstIndex(where: { $0.id == playerId }) else {
            logger.log("Error: Player with ID \(playerId) not found in gameState during update.")
            return
        }
        
        let player = gameState.players[playerIndex]
        player.username = name
        if player.image == nil {
            player.image = image
        }
        
        player.tablePosition = .local
        
        logger.log("Player \(playerId) updated successfully with name: \(name)")
        
        // Log connected players
        let connectedUsernames = gameState.players.filter { $0.isP2PConnected }.map { $0.username }
        logger.log("Players connected: \(connectedUsernames.joined(separator: ", "))")
        displayPlayers() // Log detailed player status
        
        if !gameState.playOrder.isEmpty {
            gameState.updatePlayerReferences()
        }
    }
    
    // MARK: Connection/Deconnection
    
//    func updatePlayerConnectionStatus(playerId: PlayerId, isConnected: Bool) {
//        // Find the player by ID
//        guard let index = gameState.players.firstIndex(where: { $0.id == playerId }) else {
//            logger.log("Could not find player \(playerId) to update connection status")
//            return
//        }
//        
//        // Update connection status
//        if gameState.players[index].isConnected != isConnected {
//            self.objectWillChange.send()
//            gameState.players[index].isConnected = isConnected
//            logger.log("Updated \(playerId) connection status to \(isConnected)")
//            
//            // Display current players for debugging
//            displayPlayers()
//            
//            checkAndAdvanceStateIfNeeded() // Might pause the game while the player reconnects
//            
//        } else {
//            logger.log("Player \(playerId) connection status did not change: \(isConnected)")
//        }
//    }
    
    // MARK: - Signaling Setup
    
    func startNetworkingIfNeeded() {
        guard !preferences.playerId.isEmpty else {
            print("🚫 Cannot start networking: playerId is empty.")
            return
        }
        
        guard !networkingStarted else {
            return
        }
        
        Task {
            networkingStarted = true
            
            let localPlayerIdEnum = PlayerId(rawValue: preferences.playerId)!
            let otherPlayerIds = PlayerId.allCases.filter { $0 != localPlayerIdEnum }
            
            // 1. Setup PresenceManager's callback for peer changes
            PresenceManager.shared.onPeerPresenceChanged = { [weak self] (changedPeerId, isOnline) in
                self?.handlePeerPresenceChange(peerId: changedPeerId, isOnline: isOnline)
            }
            // 2. Start monitoring other peers
            PresenceManager.shared.startMonitoringPeerPresence(for: otherPlayerIds, localPlayerId: localPlayerIdEnum)
            
            await clearSignalingDataIfNeeded()
            
            // Assign FSM callbacks
            signalingManager.onOfferReceived = { [weak self] (fromId, sdp) in
                self?.handleReceivedOffer(from: fromId, sdp: sdp)
            }
            signalingManager.onAnswerReceived = { [weak self] (fromId, sdp) in
                self?.handleReceivedAnswer(from: fromId, sdp: sdp)
            }
            signalingManager.onRemoteIceCandidateReceived = { [weak self] (fromId, candidate) in
                self?.handleReceivedRemoteIceCandidate(from: fromId, candidate: candidate)
            }
            
            setupConnectionManagerCallbacks(localPlayerId: PlayerId(rawValue: preferences.playerId)!)
            signalingManager.setupFirebaseListeners(localPlayerId: PlayerId(rawValue: preferences.playerId)!)
            setupSignaling()
        }
    }
    
    private func clearSignalingDataIfNeeded() async {
        // MODIFICATION: Only clear for the local player
        guard let localPlayerId = PlayerId(rawValue: preferences.playerId) else { // Make sure to get localPlayerId correctly
            logger.log("⚠️ Cannot clear signaling data: localPlayerId not set or invalid from preferences.")
            return
        }
        
        logger.debug("Clearing signaling data for local player: \(localPlayerId.rawValue).")
        do {
            // This clears documents where localPlayerId is the SENDER (e.g., localPlayer_to_peerX)
            try await self.signalingManager.clearSignalingData(for: localPlayerId.rawValue)
            logger.logRTC("Successfully initiated clearing of signaling data for \(localPlayerId.rawValue).")
        } catch {
            logger.log("🚨 Error initiating clearing of signaling data for \(localPlayerId.rawValue): \(error.localizedDescription)")
        }
    }
    
    private func setupSignaling() {
        guard !preferences.playerId.isEmpty else {
            logger.log("setupSignaling: Cannot setup, playerId is empty.")
            return
        }
        
        let localPlayerId = PlayerId(rawValue: preferences.playerId)!
        let otherPlayerIds = PlayerId.allCases.filter { $0 != localPlayerId }
        
        logger.debug("Setting up signaling for \(localPlayerId). Implementing deterministic offer chain.")
        
        Task {
            for peerId in otherPlayerIds {
                if peerId == localPlayerId { continue } // Can't connect to myself
                
                // Determine if the local player should offer to this peer
                var iShouldOffer = false
                switch localPlayerId {
                case .dd:
                    if peerId == .gg { iShouldOffer = true}
                case .gg:
                    if peerId == .toto { iShouldOffer = true}
                case .toto:
                    if peerId == .dd { iShouldOffer = true}
                }
                
                // Before checking presence, set a state
                self.updatePlayerConnectionPhase(playerId: peerId, phase: .initiating)
                
                if !gameState.getPlayer(by: peerId).firebasePresenceOnline {
                    logger.logRTC("Signaling: Peer \(peerId.rawValue) is offline. Will not attempt to offer/answer now.")
                    self.updatePlayerConnectionPhase(playerId: peerId, phase: .idle)
                    continue // Move to the next peer
                }
                
                if iShouldOffer {
                    logger.debug("\(localPlayerId.rawValue) is designated offerer to \(peerId.rawValue). Creating an offer...")
                    self.updatePlayerConnectionPhase(playerId: peerId, phase: .offering)
                    
                    let myOfferToThemDocRef = Firestore.firestore().collection("signaling").document("\(localPlayerId.rawValue)_to_\(peerId.rawValue)")
                    let myOfferSnapshot = try? await myOfferToThemDocRef.getDocument()
                    if let existingOfferData = myOfferSnapshot?.data(), existingOfferData["offer"] != nil {
                        logger.logRTC("Offer from \(localPlayerId.rawValue) to \(peerId.rawValue) already exists. Asusming it's being processed or waiting for answer.")
                        if self.gameState.getPlayer(by: peerId).connectionPhase == .offering {
                            self.updatePlayerConnectionPhase(playerId: peerId, phase: .waitingForAnswer)
                        }
                        continue // Skip creating a new offer if one is already in flight
                    }
                    
                    connectionManager.createOffer(to: peerId) { [weak self] _, result in
                        guard let self = self else {
                            logger.log("GM: attemptP2PConnection: createOffer completion - self is nil for peer \(peerId.rawValue)")
                            return
                        }
                        logger.logRTC("GM: attemptP2PConnection: createOffer completion for \(peerId.rawValue). Result: \(result)")

                        switch result {
                        case .success(let sdp):
                            logger.logRTC("GM: attemptP2PConnection: Offer successfully created for \(peerId.rawValue). Attempting to send via signaling.")
                            Task {
                                do {
                                    try await self.signalingManager.sendOffer(from: localPlayerId, to: peerId, sdp: sdp)
                                    logger.logRTC("GM: attemptP2PConnection: Offer SENT successfully from \(localPlayerId.rawValue) to \(peerId.rawValue).")
                                    self.updatePlayerConnectionPhase(playerId: peerId, phase: .waitingForAnswer)
                                    self.connectionManager.flushPendingIce(for: peerId)
                                } catch {
                                    logger.log("GM: attemptP2PConnection: Error SENDING offer from \(localPlayerId.rawValue) to \(peerId.rawValue): \(error.localizedDescription)")
                                    self.updatePlayerConnectionPhase(playerId: peerId, phase: .failed)
                                }
                            }
                        case .failure(let error):
                            logger.log("GM: attemptP2PConnection: Failed to CREATE offer for \(peerId.rawValue): \(error.localizedDescription)")
                            self.updatePlayerConnectionPhase(playerId: peerId, phase: .failed)
                        }
                    }
                } else {
                    logger.debug("\(localPlayerId.rawValue) is designated answerer for \(peerId.rawValue). Will wait for offer via listener.")
                    self.updatePlayerConnectionPhase(playerId: peerId, phase: .waitingForOffer)
                }
            }
        }
    }
    
    func decodeAndProcessAction(from peerId: PlayerId, message: String) {
        logger.log("Decoding and processing action from \(peerId)...")
        guard let actionData = message.data(using: .utf8) else {
            logger.log("Failed to convert message string to Data from \(peerId)")
            return
        }
        
        do {
            let gameAction = try JSONDecoder().decode(GameAction.self, from: actionData)
            logger.log("Successfully decoded action: \(gameAction.type)")
            // Use handleReceivedAction to process or queue the action
            handleReceivedAction(gameAction)
        } catch {
            logger.log("Failed to decode GameAction from \(peerId): \(error.localizedDescription)")
            logger.log("Raw message data: \(message)") // Log the raw message on error
        }
    }
    
    private func setupConnectionManagerCallbacks(localPlayerId: PlayerId) {
        logger.logRTC(" GM Setup: Setting up P2PConnectionManager callbacks for \(localPlayerId.rawValue).")
        
        connectionManager.onIceCandidateGenerated = { [weak self] (peerId, candidate) in
            // ADD: Log callback execution start
            logger.logRTC(" GM Callback: onIceCandidateGenerated called for peer \(peerId.rawValue).")
            guard let self = self else {
                logger.logRTC(" GM Callback: ERROR - self is nil in onIceCandidateGenerated.")
                return
            }
            // Update phase if it's still in offering/answering
            let player = self.gameState.getPlayer(by: peerId)
            if [.offering, .answering, .waitingForAnswer, .waitingForOffer, .initiating].contains(player.connectionPhase) {
                self.updatePlayerConnectionPhase(playerId: peerId, phase: .exchangingNetworkInfo)
            }
            logger.logRTC(" GM Callback: Starting Task to send ICE candidate from \(localPlayerId.rawValue) to \(peerId.rawValue).")
            Task {
                logger.logRTC(" GM Callback Task: Inside Task. Attempting to send ICE candidate via signalingManager...")
                do {
                    try await self.signalingManager.sendIceCandidate(from: localPlayerId, to: peerId, candidate: candidate)
                    logger.logRTC(" GM Callback Task: signalingManager.sendIceCandidate successful for \(peerId.rawValue).")
                } catch {
                    logger.log(" GM Callback Task: ERROR calling signalingManager.sendIceCandidate for \(peerId.rawValue): \(error)")
                }
            }
        }
        
        connectionManager.onConnectionEstablished = { [weak self] peerId in
            guard let self = self else { return }
            logger.logRTC("✅ P2P Connection established with \(peerId.rawValue)")
            self.updatePlayerConnectionPhase(playerId: peerId, phase: .connected)
        }
        
        connectionManager.onMessageReceived = { [weak self] (peerId, message) in
            guard let self = self else { return }
            logger.log("📩 P2P Message received from \(peerId.rawValue)")
            self.decodeAndProcessAction(from: peerId, message: message)
        }
        
        connectionManager.onError = { [weak self] (peerId, error) in
            guard let self = self else { return }
            logger.log("❌ P2P Error with \(peerId.rawValue): \(error.localizedDescription)")
            self.updatePlayerConnectionPhase(playerId: peerId, phase: .failed)
        }
        
        connectionManager.onIceConnectionStateChanged = { [weak self] (peerId, newState) in
            guard let self = self else { return }
            logger.logRTC("GM: ICE Connection State for \(peerId) changed to \(newState.rawValue)")
            // You can update player.connectionPhase based on these states too
            // For example, when .checking, you could set .exchangingNetworkInfo or .connecting
            // When .failed, .disconnected, onError will handle it.
            switch newState {
            case .checking:
                if self.gameState.getPlayer(by: peerId).connectionPhase != .connected &&
                    self.gameState.getPlayer(by: peerId).connectionPhase != .failed {
                    self.updatePlayerConnectionPhase(playerId: peerId, phase: .connecting) // Or more specific
                }
                // Other states are either handled by `onError` or `onConnectionEstablished`
            default:
                break
            }
        }
        
        connectionManager.onSignalingStateChanged = { [weak self] (peerId, newState) in
            guard self != nil else { return }
            logger.logRTC("GM: Signaling State for \(peerId) changed to \(newState.rawValue)")
        }
        
        logger.log(" GM Setup: Finished setting up P2PConnectionManager callbacks.")// ADD: Log setup finish
    }
    
    // Helper to update phase and trigger UI refresh
    private func updatePlayerConnectionPhase(playerId: PlayerId, phase: P2PConnectionPhase) {
        guard let playerIndex = gameState.players.firstIndex(where: { $0.id == playerId }) else {
            logger.log("Error: Player \(playerId) not found to update connection phase.")
            return
        }
        if gameState.players[playerIndex].connectionPhase != phase {
            gameState.players[playerIndex].connectionPhase = phase
            logger.logRTC("Player \(playerId) phase -> \(phase.rawValue)")
            if phase == .connected {
                checkAndAdvanceStateIfNeeded()
            }
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: Handler methods
    @MainActor
    func handleReceivedOffer(from peerId: PlayerId, sdp: RTCSessionDescription) {
        logger.logRTC("GM: handleReceivedOffer: CALLED for \(peerId.rawValue). SDP Type: \(sdp.type.rawValue). Current phase for \(peerId.rawValue): \(self.gameState.getPlayer(by: peerId).connectionPhase.rawValue)")
        
        // Pull or create the RTCPeerConnection for this peer
        let connection = connectionManager.makePeerConnection(for: peerId)
        // Only accept if WebRTC is in a state that can take a new remote offer
        var iShouldOffer = false // Recalculate my role with respect to peerId
        let localPlayerId = PlayerId(rawValue: preferences.playerId)!
        switch localPlayerId {
            case .dd: if peerId == .gg { iShouldOffer = true }
            case .gg: if peerId == .toto { iShouldOffer = true }
            case .toto: if peerId == .dd { iShouldOffer = true }
        }

        if iShouldOffer && (connection.signalingState == .haveLocalOffer || connection.signalingState == .stable) {
            // I am the offerer, and I've either sent an offer or connection is stable.
            // This incoming offer is either a glare case or a duplicate.
            logger.logRTC("GM: handleReceivedOffer: I am designated offerer (\(localPlayerId.rawValue) to \(peerId.rawValue)) and my state is \(connection.signalingState.rawValue). Ignoring incoming offer from \(peerId.rawValue) to prevent glare or reprocessing.")
            return
        }
        
        if !iShouldOffer { // I am the designated answerer...
            // ... and I have already processed an offer and sent an answer (my PC state for them is stable, or I'm exchanging ICE).
            // RTCSignalingState.stable (0) means negotiation is complete.
            // RTCSignalingState.haveLocalPrAnswer / haveRemotePrAnswer also indicate I've answered.
            // If player's connectionPhase indicates I've already answered or connected...
            let playerForPeer = gameState.getPlayer(by: peerId)
            if playerForPeer.connectionPhase == .answering ||
                playerForPeer.connectionPhase == .exchangingNetworkInfo ||
                playerForPeer.connectionPhase == .connecting ||
                playerForPeer.connectionPhase == .connected {
                if connection.signalingState == .stable {
                     logger.logRTC("GM: handleReceivedOffer: I am designated answerer (\(localPlayerId.rawValue) for \(peerId.rawValue)), but my PlayerPhase for them is \(playerForPeer.connectionPhase.rawValue) and PC state is stable. Ignoring likely duplicate/late offer from \(peerId.rawValue).")
                     return
                }
            }
            
        }

        // If signaling state is stable, and we receive an offer, it's a re-negotiation or a late/duplicate.
        // If we are not expecting an offer (e.g., we sent one), we might need to handle glare.
        // For now, let's assume if we get here, we should process it if we haven't established a connection yet.
        // The key is the `connection.signalingState` before setting remote description.
        // It should be `stable` (initial state) or `haveRemoteOffer` (if a previous offer was received but not answered yet).
        // It should NOT be `haveLocalOffer` (I sent offer, waiting for answer) or `haveLocalPrAnswer` or `haveRemotePrAnswer`.

        if connection.signalingState != .stable && connection.signalingState != .haveRemoteOffer {
             // This check is a bit too simple, need to consider re-negotiation.
             // For initial connection, if I'm the answerer, my state for them should be .stable or .waitingForOffer which maps to .stable PC state.
             logger.logRTC("GM: handleReceivedOffer: Received offer from \(peerId.rawValue), but my SignalingState for them is \(connection.signalingState.rawValue). This might be unexpected. Proceeding cautiously.")
        }
        
        // Update phase: we are now going to answer
        self.updatePlayerConnectionPhase(playerId: peerId, phase: .answering)
        
        Task { // Perform async WebRTC operations
            do {
                // Set remote description (the offer)
//                try await connection.setRemoteDescription(sdp)
//                logger.logRTC("GM: Remote offer from \(peerId) set. Creating answer...")
                
                // Create answer
                self.connectionManager.createAnswer(to: peerId, from: sdp) { [weak self] answeredPeerId, result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let answerSdp):
                        logger.logRTC("GM: Created answer for \(answeredPeerId). Sending...")
                        Task {
                            do {
                                try await self.signalingManager.sendAnswer(from: PlayerId(rawValue: self.preferences.playerId)!, to: answeredPeerId, sdp: answerSdp)
                                logger.logRTC("GM: Successfully sent answer to \(answeredPeerId)")
                                // Now we are waiting for the connection to establish, ICE exchange is likely ongoing
                                // The phase might already be .exchangingNetworkInfo due to local ICE generation
                                // or can be explicitly set.
                                if self.gameState.getPlayer(by: answeredPeerId).connectionPhase != .exchangingNetworkInfo {
                                    self.updatePlayerConnectionPhase(playerId: answeredPeerId, phase: .exchangingNetworkInfo) // Or a more specific "WaitingForConnection"
                                }
                                self.connectionManager.flushPendingIce(for: answeredPeerId)
                                
                                // Clear the offer field in Firestore (optional, but good practice)
                                let offerPath = "offer"
                                let docId = self.signalingManager.documentName(from: answeredPeerId, to: PlayerId(rawValue: self.preferences.playerId)!) // FSM needs public documentName
                                try? await Firestore.firestore().collection("signaling").document(docId).updateData([offerPath: FieldValue.delete()])
                                logger.logRTC("GM: Cleared offer field for \(answeredPeerId) in \(docId)")
                            } catch {
                                logger.log("GM: Error sending answer to \(answeredPeerId): \(error)")
                                self.updatePlayerConnectionPhase(playerId: answeredPeerId, phase: .failed)
                            }
                        }
                    case .failure(let err):
                        logger.log("GM: Failed to create answer for \(answeredPeerId): \(err)")
                        self.updatePlayerConnectionPhase(playerId: answeredPeerId, phase: .failed)
                    }
                }
            } catch {
                logger.log("GM: Error setting remote offer from \(peerId): \(error)")
                self.updatePlayerConnectionPhase(playerId: peerId, phase: .failed)
            }
        }
    }
    
    @MainActor
    func handleReceivedAnswer(from peerId: PlayerId, sdp: RTCSessionDescription) {
        logger.logRTC("GM: Handling received ANSWER from \(peerId.rawValue)")
        
        guard let connection = connectionManager.peerConnections[peerId] else {
            logger.log("GM: Warning: Received answer from \(peerId), but no peer connection exists. THIS SHOULD NOT HAPPEN IF OFFER WAS SENT.")
            // This path indicates a logic error, as an offerer should always have a PC.
            // Potentially the PC was closed prematurely or never properly established on the offerer's side.
            self.updatePlayerConnectionPhase(playerId: peerId, phase: .failed)
            return
        }

        // CRITICAL: Only process answer if we are expecting one
        if connection.signalingState == .haveLocalOffer {
            logger.logRTC("GM: SignalingState is haveLocalOffer for \(peerId), proceeding to set remote answer.")
            self.updatePlayerConnectionPhase(playerId: peerId, phase: .exchangingNetworkInfo) // Or .connecting

            Task {
                do {
                    try await connection.setRemoteDescription(sdp) // This is an async RTC method
                    logger.logRTC("GM: Remote answer from \(peerId) set successfully.")
                    self.connectionManager.flushPendingIce(for: peerId)

                    // Clear the answer field in Firestore
                    let answerPath = "answer"
                    // The document is named by the ANSWERER_to_OFFERER
                    let docId = self.signalingManager.documentName(from: peerId, to: PlayerId(rawValue: self.preferences.playerId)!)
                    try? await Firestore.firestore().collection("signaling").document(docId).updateData([answerPath: FieldValue.delete()])
                    logger.logRTC("GM: Cleared answer field for \(peerId) in \(docId)")

                } catch {
                    logger.log("GM: Failed to set remote answer from \(peerId): \(error.localizedDescription)")
                    self.updatePlayerConnectionPhase(playerId: peerId, phase: .failed)
                }
            }
        } else {
            logger.logRTC("GM: Received answer from \(peerId), but SignalingState is \(connection.signalingState.rawValue) (expected haveLocalOffer). Ignoring duplicate/late answer.")
            // If already stable, and connection is good, no action needed.
            // If some other state, it might indicate an issue, but processing answer now is wrong.
        }
    }

    
    @MainActor
    func handleReceivedRemoteIceCandidate(from peerId: PlayerId, candidate: RTCIceCandidate) {
        logger.logRTC("GM: Handling received ICE candidate from \(peerId.rawValue).")
        // Phase should ideally already be .exchangingNetworkInfo or similar
        let player = self.gameState.getPlayer(by: peerId)
        if ![.exchangingNetworkInfo, .connecting, .connected].contains(player.connectionPhase) {
            logger.logRTC("GM: Updating phase to .exchangingNetworkInfo for \(peerId) upon receiving ICE candidate.")
            self.updatePlayerConnectionPhase(playerId: peerId, phase: .exchangingNetworkInfo)
        }
        
        P2PConnectionManager.shared.addIceCandidate(candidate, for: peerId) { error in
            if let error = error {
                logger.log("GM: Error adding received ICE candidate from \(peerId): \(error)")
                // Potentially update phase to .failed if adding critical candidates fails,
                // but WebRTC might recover or already be in a failed ICE state.
            }
        }
    }
    
    @MainActor
    private func handlePeerPresenceChange(peerId: PlayerId, isOnline: Bool) {
        logger.logRTC("GM: Handling presence change for \(peerId.rawValue). Online: \(isOnline)")
        
        let player = gameState.getPlayer(by: peerId)
        player.firebasePresenceOnline = isOnline
        
        if isOnline {
            // Peer came online or is confirmed online.
            // Only attempt connection if currently idle, failed, or disconnected from P2P.
            let currentPhase = player.connectionPhase
            if currentPhase == .idle || currentPhase == .failed || currentPhase == .disconnected {
                logger.logRTC("GM: Peer \(peerId.rawValue) is online and in phase '\(currentPhase.rawValue)'. Attempting P2P connection.")
                attemptP2PConnection(with: peerId)
            } else {
                logger.logRTC("GM: Peer \(peerId.rawValue) is online, P2P phase '\(currentPhase.rawValue)' indicates attempt in progress/established. No new action.")
            }
        } else {
            // Peer went offline.
            logger.logRTC("GM: Peer \(peerId.rawValue) went offline.")
            // Update connection status
            if player.isP2PConnected ||
               [.initiating, .offering, .waitingForAnswer, .answering, .waitingForOffer, .exchangingNetworkInfo, .connecting].contains(player.connectionPhase) {
                updatePlayerConnectionPhase(playerId: peerId, phase: .disconnected) // Sets phase
            } else {
                 // If it wasn't even WebRTC connected, ensure its phase reflects it's gone
                 updatePlayerConnectionPhase(playerId: peerId, phase: .idle) // Or a new "PeerOffline" phase
            }
            
            // Clear any related signaling data for this peer if appropriate.
            connectionManager.closeConnection(for: peerId)
        }
        
        displayPlayers()
    }

    // New function to encapsulate the logic for a single peer connection attempt
    @MainActor
    private func attemptP2PConnection(with peerId: PlayerId) {
        let localPlayerId = PlayerId(rawValue: preferences.playerId)!

        // (This is the core logic from your setupSignaling loop, refactored for a single peer)
        logger.logRTC("GM: Attempting P2P with \(peerId.rawValue)")

        var iShouldOffer = false
        switch localPlayerId {
        case .dd: if peerId == .gg { iShouldOffer = true }
        case .gg: if peerId == .toto { iShouldOffer = true }
        case .toto: if peerId == .dd { iShouldOffer = true }
        }

        self.updatePlayerConnectionPhase(playerId: peerId, phase: .initiating)
        // Note: We assume peer is online because handlePeerPresenceChange(isOnline: true) called this.

        if iShouldOffer {
            logger.debug("\(localPlayerId.rawValue) is designated offerer to \(peerId.rawValue). Creating an offer...")
            self.updatePlayerConnectionPhase(playerId: peerId, phase: .offering)

            // Check if an offer ALREADY exists (from setupSignaling optimization)
            // This check becomes more important if this function can be called multiple times rapidly.
            Task {
                let myOfferToThemDocRef = Firestore.firestore().collection("signaling").document("\(localPlayerId.rawValue)_to_\(peerId.rawValue)")
                let myOfferSnapshot = try? await myOfferToThemDocRef.getDocument()
                if let existingOfferData = myOfferSnapshot?.data(), existingOfferData["offer"] != nil {
                     logger.logRTC("Signaling: Offer from \(localPlayerId.rawValue) to \(peerId.rawValue) already exists during attemptP2P. Assuming it's being processed.")
                     if self.gameState.getPlayer(by: peerId).connectionPhase == .offering { // If still in offering, update
                         self.updatePlayerConnectionPhase(playerId: peerId, phase: .waitingForAnswer)
                     }
                     return // Don't re-offer if one is pending
                }

                connectionManager.createOffer(to: peerId) { [weak self] _, result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let sdp):
                        Task {
                            do {
                                try await self.signalingManager.sendOffer(from: localPlayerId, to: peerId, sdp: sdp)
                                self.updatePlayerConnectionPhase(playerId: peerId, phase: .waitingForAnswer)
                                self.connectionManager.flushPendingIce(for: peerId)
                            } catch {
                                self.updatePlayerConnectionPhase(playerId: peerId, phase: .failed)
                            }
                        }
                    case .failure:
                        self.updatePlayerConnectionPhase(playerId: peerId, phase: .failed)
                    }
                }
            }
        } else {
            logger.debug("\(localPlayerId.rawValue) is designated answerer for \(peerId.rawValue). Will wait for offer via listener.")
            self.updatePlayerConnectionPhase(playerId: peerId, phase: .waitingForOffer)
            // Listener (onOfferReceived) will handle it.
        }
    }
}
