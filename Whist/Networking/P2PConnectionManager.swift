//
//  P2PConnectionManager.swift
//  Whist
//
//  Created by Tony Buffard on 2025-04-19.
//

import Foundation
import WebRTC

class P2PConnectionManager: NSObject {
    static let shared = P2PConnectionManager()

    private var dataChannels:    [PlayerId: RTCDataChannel]   = [:]
    private var remoteCandidates: [PlayerId: [RTCIceCandidate]] = [:]
    private var pendingIceCandidates: [PlayerId: [RTCIceCandidate]] = [:]

    var peerConnections: [PlayerId: RTCPeerConnection] = [:]
    var onMessageReceived: ((PlayerId, String) -> Void)?
    var onConnectionEstablished: ((PlayerId) -> Void)?
    var onIceCandidateGenerated: ((PlayerId, RTCIceCandidate) -> Void)?
    var onError: ((PlayerId, Error) -> Void)?

    private let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
    }()

    private lazy var config: RTCConfiguration = {
        let config = RTCConfiguration()
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]
        config.sdpSemantics = .unifiedPlan
        config.iceTransportPolicy = .all
        return config
    }()

    private let constraints = RTCMediaConstraints(
        mandatoryConstraints: nil,
        optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
    )

    /// Creates or returns an existing RTCPeerConnection for the given peerId,
    /// sets this class as its delegate, and initializes a data channel.
    func makePeerConnection(for peerId: PlayerId) -> RTCPeerConnection {
        if let pc = peerConnections[peerId] {
            return pc
        }
        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            logger.fatalErrorAndLog("P2PConnectionManager: failed to create RTCPeerConnection")
        }
        peerConnections[peerId] = pc
        // Create a data channel for messaging
        let dataChannelConfig = RTCDataChannelConfiguration()
        dataChannelConfig.isOrdered = true
        if let channel = pc.dataChannel(forLabel: peerId.rawValue, configuration: dataChannelConfig) {
            dataChannels[peerId] = channel
            channel.delegate = self
        }
        return pc
    }

    private override init() {
        super.init()
    }

    deinit { cleanup() }

    func cleanup() {
        dataChannels.values.forEach { $0.close() }
        peerConnections.values.forEach { $0.close() }
        dataChannels.removeAll()
        peerConnections.removeAll()
        remoteCandidates.removeAll()
    }

    func createOffer(to peerId: PlayerId, completion: @escaping (PlayerId, Result<RTCSessionDescription, Error>) -> Void) {
        let connection = makePeerConnection(for: peerId)

        connection.offer(for: constraints) { [weak self] (sdp: RTCSessionDescription?, error: Error?) in
            guard self != nil else { return }

            if let error = error {
                completion(peerId, .failure(error))
                return
            }

            guard let sdp = sdp else {
                completion(peerId, .failure(NSError(domain: "P2PConnectionManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to create offer"])))
                return
            }

            connection.setLocalDescription(sdp) { (error: Error?) in
                if let error = error {
                    completion(peerId, .failure(error))
                    return
                }
                completion(peerId, .success(sdp))
            }
        }
    }

    func createAnswer(to peerId: PlayerId, from remoteSDP: RTCSessionDescription, completion: @escaping (PlayerId, Result<RTCSessionDescription, Error>) -> Void) {
        let connection = makePeerConnection(for: peerId)

        connection.setRemoteDescription(remoteSDP) { [weak self] (error: Error?) in
            guard let self = self else { return }

            if let error = error {
                completion(peerId, .failure(error))
                return
            }

            connection.answer(for: self.constraints) { (sdp: RTCSessionDescription?, error: Error?) in
                if let error = error {
                    completion(peerId, .failure(error))
                    return
                }

                guard let sdp = sdp else {
                    completion(peerId, .failure(NSError(domain: "P2PConnectionManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to create answer"])))
                    return
                }

                connection.setLocalDescription(sdp) { (error: Error?) in
                    if let error = error {
                        completion(peerId, .failure(error))
                        return
                    }
                    completion(peerId, .success(sdp))
                }
            }
        }
    }

    func setRemoteDescription(for peerId: PlayerId, _ sdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        let pc = peerConnections[peerId] ?? makePeerConnection(for: peerId)
        
        pc.setRemoteDescription(sdp) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                completion(error)
                return
            }
            
            // Apply any stored remote candidates once remote description is set
            for candidate in self.remoteCandidates[peerId] ?? [] {
                pc.add(candidate) { error in
                    if let error = error {
                        logger.log("Error adding stored ICE candidate: \(error)")
                    }
                }
            }
            self.remoteCandidates[peerId] = []
            completion(nil)
        }
    }

    func addIceCandidate(_ candidate: RTCIceCandidate, for peerId: PlayerId, completion: ((Error?) -> Void)? = nil) {
        guard let pc = peerConnections[peerId] else {
             logger.log("addIceCandidate: No peer connection found for \(peerId). Storing candidate.")
             pendingIceCandidates[peerId, default: []].append(candidate) // Store candidate if PC doesn't exist yet
             completion?(nil)
             return
        }

        // Check remote description state before adding candidate
        if pc.remoteDescription != nil {
            pc.add(candidate) { error in
                completion?(error)
                if let error = error {
                    logger.log("Error adding ICE candidate for \(peerId): \(error)")
                } else {
                     logger.log("Successfully added ICE candidate for \(peerId)")
                }
            }
        } else {
             logger.log("addIceCandidate: Remote description not set yet for \(peerId). Storing candidate.")
            pendingIceCandidates[peerId, default: []].append(candidate) // Store candidate if remote description isn't set
            completion?(nil)
        }
    }
    
    func flushPendingIce(for peerId: PlayerId) {
        guard let pending = pendingIceCandidates[peerId] else { return }
        for candidate in pending {
            onIceCandidateGenerated?(peerId, candidate)
        }
        pendingIceCandidates[peerId] = []
    }

    func sendMessage(_ message: String) -> Bool {
        let buffer = RTCDataBuffer(data: message.data(using: .utf8)!, isBinary: false)
        var allSent = true
        for (peerId, channel) in dataChannels {
            if channel.readyState == .open {
                let sent = channel.sendData(buffer)
                if !sent {
                    logger.log("Failed to send message to \(peerId)")
                    allSent = false
                }
            } else {
                logger.log("Data channel to \(peerId) not open")
                allSent = false
            }
        }
        return allSent
    }
}

extension P2PConnectionManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        logger.log("Signaling state changed: \(stateChanged.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        logger.log("Stream added")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        logger.log("Stream removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        logger.log("Negotiation needed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        logger.log("ICE connection state changed: \(newState.rawValue)")
        
        switch newState {
        case .connected, .completed:
            logger.log("ICE connected")
        case .failed, .disconnected, .closed:
            logger.log("ICE connection failed or closed")
            let error = NSError(domain: "P2PConnectionManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "ICE connection failed with state: \(newState.rawValue)"])
            if let peerId = peerConnections.first(where: { $0.value == peerConnection })?.key {
                onError?(peerId, error)
            }
        default:
            break
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        logger.log("ICE gathering state changed: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        logger.log(" P2P Delegate: peerConnection(_:didGenerate:) called.")
        logger.log(" P2P Delegate: Candidate SDP: \(candidate.sdp)")
        
        guard let peerId = peerConnections.first(where: { $0.value == peerConnection })?.key else {
             logger.log(" P2P Delegate: ERROR - Could not find peerId for this peerConnection.")
            return
        }
         logger.log(" P2P Delegate: Found peerId: \(peerId.rawValue)")

        if onIceCandidateGenerated != nil {
             logger.log(" P2P Delegate: onIceCandidateGenerated callback IS set. Calling it now for \(peerId.rawValue).")
            onIceCandidateGenerated?(peerId, candidate)
        } else {
             logger.log(" P2P Delegate: ERROR - onIceCandidateGenerated callback is NIL.")
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        logger.log("ICE candidates removed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        logger.log("Data channel opened with label: \(dataChannel.label)")
        dataChannel.delegate = self
        // Update the dedicated data channel for the corresponding peerId
        if let peerId = peerConnections.first(where: { $0.value == peerConnection })?.key {
            dataChannels[peerId] = dataChannel
            onConnectionEstablished?(peerId)
        }
    }
}

extension P2PConnectionManager: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        logger.log("Data channel state changed to: \(dataChannel.readyState.rawValue)")

        switch dataChannel.readyState {
        case .open:
            logger.log("Data channel is open and ready to use")
            if let peerId = dataChannels.first(where: { $0.value == dataChannel })?.key {
                onConnectionEstablished?(peerId)
            }
        case .closed:
            logger.log("Data channel closed")
        case .connecting:
            logger.log("Data channel connecting")
        case .closing:
            logger.log("Data channel closing")
        @unknown default:
            logger.log("Unknown data channel state: \(dataChannel.readyState.rawValue)")
        }
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if !buffer.isBinary, let message = String(data: buffer.data, encoding: .utf8),
           let peerId = dataChannels.first(where: { $0.value == dataChannel })?.key {
            logger.log("Received message from \(peerId): \(message)")
            onMessageReceived?(peerId, message)
        } else if buffer.isBinary {
            logger.log("Received binary data of size: \(buffer.data.count) bytes")
        } else {
            logger.log("Received data could not be decoded as UTF-8 text")
        }
    }
}
