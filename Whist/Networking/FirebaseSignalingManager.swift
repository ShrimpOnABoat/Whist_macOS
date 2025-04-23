//
//  FirebaseSignalingManager.swift
//  Whist
//
//  Created by Tony Buffard on 2025-04-19.
//

// FirebaseSignalingManager.swift
// Manages the WebRTC signaling layer using Firebase Firestore

import Foundation
import FirebaseFirestore
import WebRTC

class FirebaseSignalingManager {
    static let shared = FirebaseSignalingManager()

    private var listenerRegistrations: [ListenerRegistration] = []
    private let db = Firestore.firestore()

    private func documentName(from: PlayerId, to: PlayerId) -> String {
        return "\(from.rawValue)_to_\(to.rawValue)"
    }

    func sendOffer(from senderId: PlayerId, to receiverId: PlayerId, sdp: RTCSessionDescription) async throws {
        let docId = documentName(from: senderId, to: receiverId)
        let offerData: [String: Any] = [
            "offer": sdp.sdp
        ]
        logger.log("Firebase [\(docId)]: Sending offer")
        try await db.collection("signaling").document(docId).setData(offerData, merge: true)
    }

    func sendAnswer(from senderId: PlayerId, to receiverId: PlayerId, sdp: RTCSessionDescription) async throws {
        let docId = documentName(from: senderId, to: receiverId)
        let answerData: [String: Any] = [
            "answer": sdp.sdp
        ]
        logger.log("Firebase [\(docId)]: Sending answer")
        try await db.collection("signaling").document(docId).setData(answerData, merge: true)
    }

    func sendIceCandidate(from senderId: PlayerId, to receiverId: PlayerId, candidate: RTCIceCandidate) async throws {
        let docId = documentName(from: senderId, to: receiverId)
        let candidateDict: [String: String] = [
            "sdp": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": String(candidate.sdpMLineIndex)
        ]
        guard let candidateData = try? JSONEncoder().encode(candidateDict),
              let candidateString = String(data: candidateData, encoding: .utf8) else {
            logger.log("Error encoding ICE candidate to JSON string")
            throw NSError(domain: "FirebaseSignalingManager", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Failed to encode ICE candidate"])
        }

        let candidateDataForFirestore: [String: Any] = [
            "iceCandidates": FieldValue.arrayUnion([candidateString])
        ]
        logger.log("Firebase [\(docId)]: Sending ICE candidate")
        try await db.collection("signaling").document(docId).updateData(candidateDataForFirestore)
    }

    private func extractIds(from docId: String) -> (from: PlayerId, to: PlayerId)? {
        let parts = docId.split(separator: "_to_")
        guard parts.count == 2,
              let fromId = PlayerId(rawValue: String(parts[0])),
              let toId = PlayerId(rawValue: String(parts[1])) else {
            return nil
        }
        return (from: fromId, to: toId)
    }
    
    func setupFirebaseListeners(localPlayerId: PlayerId) {
        logger.log(" Firebase Listeners: Setting up for \(localPlayerId.rawValue)")
        
        // Ensure we don't add duplicate listeners if called multiple times
        listenerRegistrations.forEach { $0.remove() }
        listenerRegistrations.removeAll()
        
        // Listen for Offers sent TO me
        let offerListener = listenForOffer(for: localPlayerId) { [weak self] (fromId, sdp) in
            guard let self = self else { return }
            logger.log(" GM Listener: Received OFFER from \(fromId.rawValue).")
            let remoteSdp = RTCSessionDescription(type: .offer, sdp: sdp)
            let connection = P2PConnectionManager.shared.makePeerConnection(for: fromId) // Ensure PC exists
            
            connection.setRemoteDescription(remoteSdp) { error in
                if let error = error {
                    logger.log(" P2P: Error setting remote offer from \(fromId.rawValue): \(error)")
                    return
                }
                logger.log(" P2P: Remote offer set from \(fromId.rawValue). Creating answer...")
                
                P2PConnectionManager.shared.createAnswer(to: fromId, from: remoteSdp) { _, result in
                    // Use weak self again inside async task if needed
                    switch result {
                    case .success(let answerSdp):
                        logger.log(" P2P: Created answer for \(fromId.rawValue). Sending...")
                        Task {
                            do {
                                try await self.sendAnswer(from: localPlayerId, to: fromId, sdp: answerSdp)
                                logger.log(" Firebase: Successfully sent answer to \(fromId.rawValue)")
                                P2PConnectionManager.shared.flushPendingIce(for: fromId)
                                // Optional: Clear the processed offer field
                                let offerPath = "offer"
                                let docId = self.documentName(from: fromId, to: localPlayerId)
                                try? await Firestore.firestore().collection("signaling").document(docId).updateData([offerPath: FieldValue.delete()])
                                logger.log(" Firebase: Cleared offer field in \(docId)")
                            } catch {
                                logger.log(" Firebase: Error sending answer to \(fromId.rawValue): \(error)")
                            }
                        }
                    case .failure(let err):
                        logger.log(" P2P: Failed to create answer for \(fromId.rawValue): \(err)")
                    }
                }
            }
        }
        listenerRegistrations.append(offerListener)
        
        // Listen for Answers sent TO me
        let answerListener = listenForAnswer(for: localPlayerId) { [weak self] (fromId, sdp) in
            guard let self = self else { return }
            logger.log(" GM Listener: Received ANSWER from \(fromId.rawValue).")
            let remoteSdp = RTCSessionDescription(type: .answer, sdp: sdp)
            
            guard let connection = P2PConnectionManager.shared.peerConnections[fromId] else {
                logger.log(" Warning: Received answer from \(fromId.rawValue), but no peer connection exists.")
                return
            }
            
            connection.setRemoteDescription(remoteSdp) { error in
                // Use weak self again inside async task if needed
                if let error = error {
                    logger.log(" P2P: Failed to set remote answer from \(fromId.rawValue): \(error)")
                } else {
                    logger.log(" P2P: Remote answer set from \(fromId.rawValue).")
                    P2PConnectionManager.shared.flushPendingIce(for: fromId) // Important after setting answer
                    // Optional: Clear the processed answer field
                    let answerPath = "answer"
                    let docId = self.documentName(from: fromId, to: localPlayerId)
                    Task {
                        try? await Firestore.firestore().collection("signaling").document(docId).updateData([answerPath: FieldValue.delete()])
                        logger.log(" Firebase: Cleared answer field in \(docId)")
                    }
                }
            }
        }
        listenerRegistrations.append(answerListener)
        
        // Listen for ICE Candidates sent TO me
        let candidateListener = listenForIceCandidates(for: localPlayerId) { [weak self] (fromId, candidate) in
            guard let self = self else { return }
            logger.log(" GM Listener: Received ICE candidate from \(fromId.rawValue). Attempting to add...")
            P2PConnectionManager.shared.addIceCandidate(candidate, for: fromId) { error in
                if let error = error {
                    logger.log(" P2P: Error adding received ICE candidate from \(fromId.rawValue): \(error)")
                }
            }
        }
        listenerRegistrations.append(candidateListener)

        logger.log(" Firebase Listeners: Setup complete for \(localPlayerId.rawValue)")
    }

    func listenForOffer(for localPlayerId: PlayerId, handler: @escaping (_ fromId: PlayerId, _ sdp: String) -> Void) -> ListenerRegistration {
        return db.collection("signaling")
            .addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    logger.log("Error fetching signaling collection: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                snapshot.documentChanges.forEach { diff in
                    if diff.type == .added || diff.type == .modified {
                        let docId = diff.document.documentID
                        if let ids = self.extractIds(from: docId), ids.to == localPlayerId {
                            if let offerSdp = diff.document.data()["offer"] as? String {
                                logger.log("Firebase [\(docId)]: Received offer for \(localPlayerId.rawValue)")
                                handler(ids.from, offerSdp)
                            }
                        }
                    }
                }
            }
    }

    func listenForAnswer(for localPlayerId: PlayerId, handler: @escaping (_ fromId: PlayerId, _ sdp: String) -> Void) -> ListenerRegistration {
        logger.log(" FSM listenForAnswer: Registering listener for \(localPlayerId.rawValue)")
        return db.collection("signaling")
            .addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    logger.log(" FSM listenForAnswer [\(localPlayerId.rawValue)]: Error fetching snapshot: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                logger.log(" FSM listenForAnswer [\(localPlayerId.rawValue)]: Received snapshot with \(snapshot.documentChanges.count) changes.")

                snapshot.documentChanges.forEach { diff in
                    let docId = diff.document.documentID
                    let changeType: String
                    switch diff.type {
                        case .added: changeType = "Added"
                        case .modified: changeType = "Modified"
                        case .removed: changeType = "Removed"
                    }
                    logger.log(" FSM listenForAnswer [\(localPlayerId.rawValue)]: Processing change type '\(changeType)' for doc '\(docId)'")

                    guard diff.type == .added || diff.type == .modified else {
                        return
                    }

                    guard let ids = self.extractIds(from: docId) else {
                        logger.log(" FSM listenForAnswer [\(localPlayerId.rawValue)]: Could not extract IDs from doc '\(docId)'")
                        return
                    }

                    logger.log(" FSM listenForAnswer [\(localPlayerId.rawValue)]: Extracted IDs for '\(docId)': from=\(ids.from.rawValue), to=\(ids.to.rawValue)")

                    guard ids.to == localPlayerId else {
                        logger.log(" FSM listenForAnswer [\(localPlayerId.rawValue)]: Skipping doc '\(docId)' (intended for \(ids.to.rawValue))")
                        return
                    }

                    logger.log(" FSM listenForAnswer [\(localPlayerId.rawValue)]: Doc '\(docId)' IS relevant.")

                    if let answerSdp = diff.document.data()["answer"] as? String {
                        logger.log(" FSM listenForAnswer [\(localPlayerId.rawValue)]: FOUND 'answer' field in '\(docId)'. Calling handler.")
                        handler(ids.from, answerSdp)
                    } else {
                        logger.log(" FSM listenForAnswer [\(localPlayerId.rawValue)]: Did NOT find 'answer' field in '\(docId)'. Data: \(diff.document.data())")
                    }
                }
                logger.log(" FSM listenForAnswer [\(localPlayerId.rawValue)]: Finished processing snapshot changes.")
            }
    }

    /// Listen for ICE candidates sent TO the specified localPlayerId.
    func listenForIceCandidates(for localPlayerId: PlayerId, handler: @escaping (_ fromId: PlayerId, _ candidate: RTCIceCandidate) -> Void) -> ListenerRegistration {
        // Keep track of processed candidate strings PER DOCUMENT ID to avoid duplicates
        var processedCandidatesByDocId = [String: Set<String>]()

        return db.collection("signaling")
            .addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    logger.log("Error fetching signaling collection: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                snapshot.documentChanges.forEach { diff in
                    if diff.type == .added || diff.type == .modified {
                        let docId = diff.document.documentID

                        if let ids = self.extractIds(from: docId), ids.to == localPlayerId {
                            guard let candidateStrings = diff.document.data()["iceCandidates"] as? [String] else {
                                return // No candidates field or wrong type
                            }

                            // Ensure the set exists for this docId *before* the loop
                            if processedCandidatesByDocId[docId] == nil {
                                processedCandidatesByDocId[docId] = Set<String>()
                            }

                            let senderId = ids.from
                            logger.log("Firebase [\(docId)]: Processing \(candidateStrings.count) candidates for \(localPlayerId.rawValue)")

                            for candidateString in candidateStrings {
                                // Safely check if candidate was already processed for this document
                                if processedCandidatesByDocId[docId]?.contains(candidateString) == false {
                                    if let candidateData = candidateString.data(using: .utf8),
                                       let json = try? JSONDecoder().decode([String: String].self, from: candidateData),
                                       let sdp = json["sdp"],
                                       let sdpMid = json["sdpMid"],
                                       let idxStr = json["sdpMLineIndex"],
                                       let idx = Int32(idxStr) {
                                        let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: idx, sdpMid: sdpMid)
                                        logger.log("Firebase [\(docId)]: Decoded ICE candidate from \(senderId.rawValue)")
                                        handler(senderId, candidate)
                                        // Safely insert the processed candidate string
                                        processedCandidatesByDocId[docId]?.insert(candidateString)
                                    } else {
                                        logger.log("Error decoding ICE candidate JSON string from \(senderId) in doc \(docId): \(candidateString)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }

    func clearSignalingData(for playerId: String) async throws {
        let signalingRef = db.collection("signaling")
        let batch = db.batch()
        var docsToDeleteCount = 0

        let outgoingQuery = signalingRef.whereField(FieldPath.documentID(), isGreaterThanOrEqualTo: "\(playerId)_to_").whereField(FieldPath.documentID(), isLessThan: "\(playerId)_to_\u{f8ff}")

        do {
            let outgoingDocs = try await outgoingQuery.getDocuments()
            for document in outgoingDocs.documents {
                batch.deleteDocument(document.reference)
                docsToDeleteCount += 1
                logger.log("Firebase: Queued deletion for outgoing doc: \(document.documentID)")
            }

            if docsToDeleteCount > 0 {
                logger.log("Firebase: Committing batch delete for \(docsToDeleteCount) signaling documents related to \(playerId).")
                try await batch.commit()
                logger.log("Firebase: Successfully cleared signaling data for \(playerId).")
            } else {
                logger.log("Firebase: No signaling documents found to clear for \(playerId).")
            }
        } catch {
            logger.log("Firebase: Error clearing signaling data for \(playerId): \(error.localizedDescription)")
            throw error
        }
    }

    deinit {
        listenerRegistrations.forEach { $0.remove() }
    }
}
