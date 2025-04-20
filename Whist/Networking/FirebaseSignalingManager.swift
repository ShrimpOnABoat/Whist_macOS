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

    private let db = Firestore.firestore()

    struct SignalDocument: Codable {
        var status: String = "waiting"
        var offer: String?
        var answer: String?
        var iceCandidates: [String] = []
    }

    func updateStatus(for playerId: String, status: String) async throws {
        try await db.collection("signaling").document(playerId).setData(["status": status], merge: true)
    }

    func sendOffer(to playerId: String, sdp: RTCSessionDescription) async throws {
        try await db.collection("signaling").document(playerId).setData(["offer": sdp.sdp], merge: true)
    }

    func sendAnswer(to playerId: String, sdp: RTCSessionDescription) async throws {
        try await db.collection("signaling").document(playerId).setData(["answer": sdp.sdp], merge: true)
    }

    func sendIceCandidate(to playerId: String, candidate: RTCIceCandidate) async throws {
        let candidateDict: [String: String] = [
            "sdp": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": String(candidate.sdpMLineIndex)
        ]
        let candidateData = try JSONSerialization.data(withJSONObject: candidateDict)
        let candidateString = candidateData.base64EncodedString()
        let ref = db.collection("signaling").document(playerId)
        try await ref.updateData([
            "iceCandidates": FieldValue.arrayUnion([candidateString])
        ])
    }

    func listenForOffer(from playerId: String, handler: @escaping (String?) -> Void) -> ListenerRegistration {
        return db.collection("signaling").document(playerId).addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data() else {
                handler(nil)
                return
            }
            handler(data["offer"] as? String)
        }
    }

    func listenForAnswer(from playerId: String, handler: @escaping (String?) -> Void) -> ListenerRegistration {
        return db.collection("signaling").document(playerId).addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data() else {
                handler(nil)
                return
            }
            handler(data["answer"] as? String)
        }
    }

    func listenForIceCandidates(from playerId: String, onCandidate: @escaping (RTCIceCandidate) -> Void) -> ListenerRegistration {
        return db.collection("signaling").document(playerId).addSnapshotListener { snapshot, error in
            guard
                let data = snapshot?.data(),
                let encodedCandidates = data["iceCandidates"] as? [String]
            else { return }

            for base64 in encodedCandidates {
                if let decoded = Data(base64Encoded: base64),
                   let json = try? JSONSerialization.jsonObject(with: decoded) as? [String: String],
                   let sdp = json["sdp"],
                   let sdpMid = json["sdpMid"],
                   let sdpMLineIndexStr = json["sdpMLineIndex"],
                   let sdpMLineIndex = Int32(sdpMLineIndexStr) {
                    let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                    onCandidate(candidate)
                }
            }
        }
    }

    func clearSignalingData(for playerId: String) async throws {
        try await db.collection("signaling").document(playerId).delete()
    }
}
