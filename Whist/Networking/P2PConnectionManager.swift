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

    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var remoteCandidates: [RTCIceCandidate] = []

    var onMessageReceived: ((String) -> Void)?
    var onConnectionEstablished: (() -> Void)?
    var onIceCandidateGenerated: ((RTCIceCandidate) -> Void)?
    var onError: ((Error) -> Void)?

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

    private override init() {
        super.init()
    }

    deinit {
        cleanup()
    }

    func cleanup() {
        dataChannel?.close()
        dataChannel = nil
        peerConnection?.close()
        peerConnection = nil
        remoteCandidates.removeAll()
    }

    func createOffer(completion: @escaping (Result<RTCSessionDescription, Error>) -> Void) {
        let connection = setupPeerConnection()
        peerConnection = connection

        connection.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let sdp = sdp else {
                completion(.failure(NSError(domain: "P2PConnectionManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to create offer"])))
                return
            }
            
            connection.setLocalDescription(sdp) { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(sdp))
            }
        }
    }

    func createAnswer(from remoteSDP: RTCSessionDescription, completion: @escaping (Result<RTCSessionDescription, Error>) -> Void) {
        let connection = setupPeerConnection()
        peerConnection = connection

        connection.setRemoteDescription(remoteSDP) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            connection.answer(for: self.constraints) { sdp, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let sdp = sdp else {
                    completion(.failure(NSError(domain: "P2PConnectionManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to create answer"])))
                    return
                }
                
                connection.setLocalDescription(sdp) { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    completion(.success(sdp))
                }
            }
        }
    }

    func setRemoteDescription(_ sdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        guard let pc = peerConnection else {
            completion(NSError(domain: "P2PConnectionManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No peer connection established"]))
            return
        }
        
        pc.setRemoteDescription(sdp) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                completion(error)
                return
            }
            
            // Apply any stored remote candidates once remote description is set
            for candidate in self.remoteCandidates {
                pc.add(candidate) { error in
                    if let error = error {
                        logger.log("Error adding stored ICE candidate: \(error)")
                    }
                }
            }
            self.remoteCandidates.removeAll()
            completion(nil)
        }
    }

    func addIceCandidate(_ candidate: RTCIceCandidate, completion: ((Error?) -> Void)? = nil) {
        if let pc = peerConnection, pc.remoteDescription != nil {
            pc.add(candidate) { error in
                completion?(error)
                if let error = error {
                    logger.log("Error adding ICE candidate: \(error)")
                }
            }
        } else {
            remoteCandidates.append(candidate)
            completion?(nil)
        }
    }

    private func setupPeerConnection() -> RTCPeerConnection {
    guard let connection = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
        logger.fatalErrorAndLog("P2PConnectionManager: Failed to create RTCPeerConnection")
    }
    
    // Configure data channel
    let dataChannelConfig = RTCDataChannelConfiguration()
    dataChannelConfig.isOrdered = true
    
    if let channel = connection.dataChannel(forLabel: "data", configuration: dataChannelConfig) {
        channel.delegate = self
        dataChannel = channel
    }
    
    return connection
    }

    func sendMessage(_ message: String) -> Bool {
        guard let channel = dataChannel, channel.readyState == .open else {
            logger.log("Cannot send message: data channel not open")
            return false
        }
        
        guard let data = message.data(using: .utf8) else {
            logger.log("Failed to convert message to data")
            return false
        }
        
        let buffer = RTCDataBuffer(data: data, isBinary: false)
        return channel.sendData(buffer)
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
            onError?(error)
        default:
            break
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        logger.log("ICE gathering state changed: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        logger.log("New ICE candidate: \(candidate.sdp)")
        onIceCandidateGenerated?(candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        logger.log("ICE candidates removed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        logger.log("Data channel opened with label: \(dataChannel.label)")
        dataChannel.delegate = self
        self.dataChannel = dataChannel
        onConnectionEstablished?()
    }
}

extension P2PConnectionManager: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        logger.log("Data channel state changed to: \(dataChannel.readyState.rawValue)")
        
        switch dataChannel.readyState {
        case .open:
            logger.log("Data channel is open and ready to use")
            onConnectionEstablished?()
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
        if !buffer.isBinary, let message = String(data: buffer.data, encoding: .utf8) {
            logger.log("Received message: \(message)")
            onMessageReceived?(message)
        } else if buffer.isBinary {
            logger.log("Received binary data of size: \(buffer.data.count) bytes")
        } else {
            logger.log("Received data could not be decoded as UTF-8 text")
        }
    }
}
