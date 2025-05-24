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
        player.isConnected = true
        player.tablePosition = .local // Assume local initially, updatePlayerReferences will adjust
        
        logger.log("Player \(playerId) updated successfully with name: \(name)")
        
        // Log connected players
        let connectedUsernames = gameState.players.filter { $0.isConnected }.map { $0.username }
        logger.log("Players connected: \(connectedUsernames.joined(separator: ", "))")
        displayPlayers() // Log detailed player status
        
        if !gameState.playOrder.isEmpty {
            gameState.updatePlayerReferences()
        }
    }
    
    // MARK: Connection/Deconnection
    
    func updatePlayerConnectionStatus(playerId: PlayerId, isConnected: Bool) {
        // Find the player by ID
        guard let index = gameState.players.firstIndex(where: { $0.id == playerId }) else {
            logger.log("Could not find player \(playerId) to update connection status")
            return
        }
        
        // Update connection status
        if gameState.players[index].isConnected != isConnected {
            self.objectWillChange.send()
            gameState.players[index].isConnected = isConnected
            logger.log("Updated \(playerId) connection status to \(isConnected)")
            
            // Display current players for debugging
            displayPlayers()
            
            checkAndAdvanceStateIfNeeded() // Might pause the game while the player reconnects
            
        } else {
            logger.log("Player \(playerId) connection status did not change: \(isConnected)")
        }
    }
    
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
        let playerIds = ["dd", "gg", "toto"]
        
        for playerId in playerIds {
            await withCheckedContinuation { continuation in
                PresenceManager.shared.checkPresence(of: playerId) { isOnline in
                    if let isOnline = isOnline, (!isOnline || playerId == self.gameState.localPlayer?.id.rawValue) {
                        //                        logger.log("Player \(playerId) is offline or myself. Clearing their signaling data.")
                        Task {
                            do {
                                try await self.signalingManager.clearSignalingData(for: playerId)
                            } catch {
                                logger.log("Error clearing signaling data for \(playerId): \(error.localizedDescription)")
                            }
                            continuation.resume()
                        }
                    } else {
                        //                        logger.log("Player \(playerId) is \(isOnline == true ? "online" : "unknown"). Skipping cleanup.")
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    private func setupSignaling() {
        guard !preferences.playerId.isEmpty else {
            logger.log("setupSignaling: Cannot setup, playerId is empty.")
            return
        }
        
        let localPlayerId = PlayerId(rawValue: preferences.playerId)!
        let otherPlayerIds = PlayerId.allCases.filter { $0 != localPlayerId }
        
        logger.debug("Setting up signaling for \(localPlayerId).")
        
        Task {
            for peerId in otherPlayerIds {
                // Before checking presence, set a state
                self.updatePlayerConnectionPhase(playerId: peerId, phase: .initiating)
                
                let isPeerOnline: Bool = await withCheckedContinuation { continuation in
                    PresenceManager.shared.checkPresence(of: peerId.rawValue) { result in
                        continuation.resume(returning: result ?? false)
                    }
                }
                
                let docRef = Firestore.firestore().collection("signaling").document("\(peerId.rawValue)_to_\(localPlayerId.rawValue)")
                let docSnapshot = try? await docRef.getDocument()
                let offerText = docSnapshot?.data()?["offer"] as? String
                
                if isPeerOnline, let offerText = offerText {
                    
                    logger.debug("Found offer from \(peerId). Processing...")
                    
                    let remoteSdp = RTCSessionDescription(type: .offer, sdp: offerText)
                    let connection = connectionManager.makePeerConnection(for: peerId)
                    
                    
                    do {
                        try await connection.setRemoteDescription(remoteSdp)
                    } catch {
                        logger.log("Error setting remote offer for \(peerId): \(error)")
                        return
                    }
                    
                    self.updatePlayerConnectionPhase(playerId: peerId, phase: .answering)
                    
                    self.connectionManager.createAnswer(to: peerId, from: remoteSdp) { _, result in
                        switch result {
                        case .success(let answerSdp):
                            Task {
                                do {
                                    try await self.signalingManager.sendAnswer(from: localPlayerId, to: peerId, sdp: answerSdp)
                                    logger.debug("Successfully sent answer to \(peerId)")
                                    
                                    // Send ICE candidates after answer
                                    self.connectionManager.flushPendingIce(for: peerId)
                                } catch {
                                    logger.debug("Error sending answer to \(peerId): \(error)")
                                }
                            }
                        case .failure(let err):
                            logger.log("Failed to create answer for \(peerId): \(err)")
                        }
                    }
                } else {
                    logger.debug("\(peerId) is offline or has no offer. Creating an offer...")
                    self.updatePlayerConnectionPhase(playerId: peerId, phase: .offering)
                    
                    connectionManager.createOffer(to: peerId) { _, result in
                        switch result {
                        case .success(let sdp):
                            Task {
                                do {
                                    try await self.signalingManager.sendOffer(from: localPlayerId, to: peerId, sdp: sdp)
                                    logger.debug("Sent offer to \(peerId)")
                                    self.updatePlayerConnectionPhase(playerId: peerId, phase: .waitingForAnswer)
                                    // Send ICE candidates after offer
                                    self.connectionManager.flushPendingIce(for: peerId)
                                } catch {
                                    logger.debug("Error sending offer to \(peerId): \(error)")
                                }
                            }
                        case .failure(let error):
                            logger.log("Failed to create offer for \(peerId): \(error)")
                        }
                    }
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
            self.updatePlayerConnectionStatus(playerId: peerId, isConnected: true)
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
            self.updatePlayerConnectionStatus(playerId: peerId, isConnected: false)
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
            guard let self = self else { return }
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
            // self.objectWillChange.send()
        }
    }
    
    // MARK: Handler methods
    @MainActor
    func handleReceivedOffer(from peerId: PlayerId, sdp: RTCSessionDescription) {
        logger.logRTC("GM: Handling received OFFER from \(peerId.rawValue)")
        // Update phase: we are now going to answer
        self.updatePlayerConnectionPhase(playerId: peerId, phase: .answering)

        let connection = connectionManager.makePeerConnection(for: peerId) // Ensure PC exists

        Task { // Perform async WebRTC operations
            do {
                // Set remote description (the offer)
                try await connection.setRemoteDescription(sdp)
                logger.logRTC("GM: Remote offer from \(peerId) set. Creating answer...")

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
            logger.log("GM: Warning: Received answer from \(peerId), but no peer connection exists.")
            self.updatePlayerConnectionPhase(playerId: peerId, phase: .failed) // Or some other error state
            return
        }
        
        // We were waiting for an answer, now we'll process it and ICE exchange should be active
        self.updatePlayerConnectionPhase(playerId: peerId, phase: .exchangingNetworkInfo)

        Task { // Perform async WebRTC operation
            do {
                try await connection.setRemoteDescription(sdp)
                logger.logRTC("GM: Remote answer from \(peerId) set successfully.")
                self.connectionManager.flushPendingIce(for: peerId) // Important after setting answer

                // Clear the answer field in Firestore (optional)
                let answerPath = "answer"
                let docId = self.signalingManager.documentName(from: peerId, to: PlayerId(rawValue: self.preferences.playerId)!) // FSM needs public documentName
                try? await Firestore.firestore().collection("signaling").document(docId).updateData([answerPath: FieldValue.delete()])
                logger.logRTC("GM: Cleared answer field for \(peerId) in \(docId)")
            } catch {
                logger.log("GM: Failed to set remote answer from \(peerId): \(error)")
                self.updatePlayerConnectionPhase(playerId: peerId, phase: .failed)
            }
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
    }}
