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

    // CHANGE: Rename dataChannels to outgoingDataChannels for clarity
    private var outgoingDataChannels: [PlayerId: RTCDataChannel] = [:]
    // ADD: Dictionary to map incoming data channels to their peer ID
    private var incomingDataChannelsMap: [RTCDataChannel: PlayerId] = [:]
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
             // Ensure an outgoing data channel exists if the connection already exists
             if outgoingDataChannels[peerId] == nil, let pc = peerConnections[peerId] {
                 createAndStoreOutgoingDataChannel(for: peerId, on: pc)
             }
            return pc
        }
        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            logger.fatalErrorAndLog("P2PConnectionManager: failed to create RTCPeerConnection")
        }
        peerConnections[peerId] = pc
        // Create and store the outgoing data channel
        createAndStoreOutgoingDataChannel(for: peerId, on: pc)
        return pc
    }

    // ADD: Helper function to create and store the outgoing data channel
    private func createAndStoreOutgoingDataChannel(for peerId: PlayerId, on pc: RTCPeerConnection) {
         let dataChannelConfig = RTCDataChannelConfiguration()
         dataChannelConfig.isOrdered = true
         // Use the peerId (recipient) as the label for the outgoing channel
         if let channel = pc.dataChannel(forLabel: peerId.rawValue, configuration: dataChannelConfig) {
             channel.delegate = self // Also set delegate for outgoing channel state changes
             outgoingDataChannels[peerId] = channel // Store in outgoing map
             logger.debug("Created and stored outgoing data channel labeled '\(peerId.rawValue)' for peer \(peerId.rawValue)")
         } else {
             logger.log("Error: Failed to create outgoing data channel for \(peerId.rawValue)")
         }
    }

    private override init() {
        super.init()
    }

    deinit { cleanup() }

    func cleanup() {
        // Close both outgoing and incoming channels
        outgoingDataChannels.values.forEach { $0.close() }
        incomingDataChannelsMap.keys.forEach { $0.close() } // Close incoming channels
        peerConnections.values.forEach { $0.close() }
        outgoingDataChannels.removeAll()
        incomingDataChannelsMap.removeAll() // Clear incoming map
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

        // Ensure remote description is set before creating answer (moved from original setRemoteDescription logic for clarity)
         connection.setRemoteDescription(remoteSDP) { [weak self] error in
             guard let self = self else { return }
             if let error = error {
                 logger.log("Error setting remote description before creating answer for \(peerId): \(error)")
                 completion(peerId, .failure(error))
                 return
             }

             // Now create the answer
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
                 logger.log("Error setting remote description for \(peerId): \(error)")
                completion(error)
                return
            }
             logger.debug("Successfully set remote description for \(peerId). Type: \(sdp.type.rawValue)")


            // Apply any stored remote candidates once remote description is set
            // Ensure this doesn't conflict with ICE candidate handling elsewhere
            if let candidates = self.remoteCandidates[peerId], !candidates.isEmpty {
                logger.debug("Applying \(candidates.count) stored remote ICE candidates for \(peerId).")
                for candidate in candidates {
                    pc.add(candidate) { error in
                        if let error = error {
                            logger.log("Error adding stored ICE candidate for \(peerId): \(error)")
                        } else {
                            logger.debug("Successfully added stored ICE candidate for \(peerId).")
                        }
                    }
                }
                 self.remoteCandidates.removeValue(forKey: peerId) // Clear applied candidates
            }
            completion(nil)
        }
    }

    func addIceCandidate(_ candidate: RTCIceCandidate, for peerId: PlayerId, completion: ((Error?) -> Void)? = nil) {
        guard let pc = peerConnections[peerId] else {
             logger.debug("addIceCandidate: No peer connection found for \(peerId). Storing candidate.")
             pendingIceCandidates[peerId, default: []].append(candidate) // Store candidate if PC doesn't exist yet
             completion?(nil)
             return
        }

        // Check remote description state before adding candidate
        if pc.remoteDescription != nil {
             logger.debug("addIceCandidate: Remote description exists for \(peerId). Adding candidate immediately.")
            pc.add(candidate) { error in
                completion?(error)
                if let error = error {
                    logger.log("Error adding ICE candidate for \(peerId): \(error)")
                } else {
                     logger.debug("Successfully added ICE candidate for \(peerId)")
                }
            }
        } else {
             logger.debug("addIceCandidate: Remote description not set yet for \(peerId). Storing candidate in remoteCandidates.")
             // Store in remoteCandidates to be applied when setRemoteDescription completes
            remoteCandidates[peerId, default: []].append(candidate)
            completion?(nil)
        }
    }

     func flushPendingIce(for peerId: PlayerId) {
         guard let _ = peerConnections[peerId], let pending = pendingIceCandidates[peerId], !pending.isEmpty else { return }
         logger.debug("Flushing \(pending.count) pending *local* ICE candidates for \(peerId).")
         for candidate in pending {
             // Send pending local candidates via signaling
             onIceCandidateGenerated?(peerId, candidate)
         }
         pendingIceCandidates[peerId]?.removeAll() // Clear
    }

    func sendMessage(_ message: String) -> Bool {
        let buffer = RTCDataBuffer(data: message.data(using: .utf8)!, isBinary: false)
        var allSent = true
        
        for (peerId, channel) in outgoingDataChannels {
            if channel.readyState == .open {
                #if DEBUG
                let delay = Double.random(in: 0.1...0.8) // Simulate 100ms to 800ms delay
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    let sent = channel.sendData(buffer)
                    if !sent {
                        logger.log("Simulated lag: Failed to send message to \(peerId)")
                    } else {
                        logger.debug("Simulated lag: Message sent to \(peerId) after \(Int(delay * 1000))ms")
                    }
                }
                #else
                let sent = channel.sendData(buffer)
                if !sent {
                    logger.log("Failed to send message to \(peerId)")
                    allSent = false
                } else {
                    logger.debug("Message sent to \(peerId) on channel \(channel)")
                }
                #endif
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
        logger.debug("Signaling state changed: \(stateChanged.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        logger.debug("Stream added")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        logger.debug("Stream removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        logger.debug("Negotiation needed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        logger.debug("ICE connection state changed: \(newState.rawValue)")
        
        switch newState {
        case .connected, .completed:
            logger.debug("ICE connected")
        case .failed, .disconnected, .closed:
            logger.debug("ICE connection failed or closed")
            let error = NSError(domain: "P2PConnectionManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "ICE connection failed with state: \(newState.rawValue)"])
            if let peerId = peerConnections.first(where: { $0.value == peerConnection })?.key {
                onError?(peerId, error)
            }
        default:
            break
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        logger.debug("ICE gathering state changed: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        logger.debug(" P2P Delegate: peerConnection(_:didGenerate:) called.")
        logger.debug(" P2P Delegate: Candidate SDP: \(candidate.sdp)")
        
        guard let peerId = peerConnections.first(where: { $0.value == peerConnection })?.key else {
             logger.log(" P2P Delegate: ERROR - Could not find peerId for this peerConnection.")
            return
        }
         logger.debug(" P2P Delegate: Found peerId: \(peerId.rawValue)")

        if onIceCandidateGenerated != nil {
             logger.debug(" P2P Delegate: onIceCandidateGenerated callback IS set. Calling it now for \(peerId.rawValue).")
            onIceCandidateGenerated?(peerId, candidate)
        } else {
             logger.log(" P2P Delegate: ERROR - onIceCandidateGenerated callback is NIL.")
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        logger.debug("ICE candidates removed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        logger.debug("Data channel opened with label: \(dataChannel.label)")
        dataChannel.delegate = self
        // Update the dedicated data channel for the corresponding peerId
        if let peerId = peerConnections.first(where: { $0.value == peerConnection })?.key {
            incomingDataChannelsMap[dataChannel] = peerId
            onConnectionEstablished?(peerId)
        }
        
        for peerConnection in peerConnections {
            logger.debug("🍐 Peer \(peerConnection.key) connected to \(peerConnection.value)")
        }
        for dataChannel in outgoingDataChannels {
            logger.debug("🏁 Peer \(dataChannel.key) connected to \(dataChannel.value)")
        }
    }
}

extension P2PConnectionManager: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        logger.debug("Data channel state changed to: \(dataChannel.readyState.rawValue)")

        switch dataChannel.readyState {
        case .open:
            logger.debug("Data channel is open and ready to use")
            if let peerId = incomingDataChannelsMap[dataChannel] {
                onConnectionEstablished?(peerId)
            } else if let peerId = outgoingDataChannels.first(where: { $0.value === dataChannel })?.key {
                onConnectionEstablished?(peerId)
            }
        case .closed:
            logger.debug("Data channel closed")
        case .connecting:
            logger.debug("Data channel connecting")
        case .closing:
            logger.debug("Data channel closing")
        @unknown default:
            logger.debug("Unknown data channel state: \(dataChannel.readyState.rawValue)")
        }
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if !buffer.isBinary, let message = String(data: buffer.data, encoding: .utf8),
           let peerId = incomingDataChannelsMap[dataChannel] {
            logger.debug("Received message from \(peerId): \(message)")
            onMessageReceived?(peerId, message)
        } else if buffer.isBinary {
            logger.log("Received binary data of size: \(buffer.data.count) bytes")
        } else {
            logger.log("Received data could not be decoded as UTF-8 text")
        }
    }
}
