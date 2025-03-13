// ConnectionManager.swift
// Whist
//
// Created by Tony Buffard on 2024-11-18.
// Manages data transmission between players.

import Foundation
import SwiftUI

#if TEST_MODE
import Network
#else
import GameKit
#endif

enum TestModeMessageType: String, Codable {
    case playerConnected
    case playerDisconnected
}

struct TestModeMessage: Codable {
    let type: TestModeMessageType
    let playerID: PlayerId
}

#if TEST_MODE
struct PeerConnection {
    let connection: NWConnection
    var playerID: PlayerId?
    var isServer: Bool = false
    var incomingData: Data = Data() // New buffer for accumulating data
}
#endif

class ConnectionManager: NSObject, ObservableObject {
    weak var gameManager: GameManager?
    @Published private(set) var localPlayerID: PlayerId?
    
#if !TEST_MODE
    @Published var match: GKMatch?
#else
//    @Published var localPlayerID: PlayerId = .dd
    private var connectedPeers: [PeerConnection] = []
    private var listener: NWListener?
    private var isServer: Bool = false
#endif
    
    override init() {
        super.init()
        
#if TEST_MODE
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillTerminateNotification),
                                               name: NSApplication.willTerminateNotification,
                                               object: nil)
#endif
    }
    
#if TEST_MODE
    @objc private func applicationWillTerminateNotification() {
        applicationWillTerminate()
    }
#endif
    
    // MARK: - Test Mode Networking (Sockets)

    func setLocalPlayerID(_ playerID: PlayerId) {
        self.localPlayerID = playerID

#if TEST_MODE
        let message = playerID.rawValue.uppercased()
        let padding = 3 // Padding around the message inside the box
        let lineLength = message.count + padding * 2
        let borderLine = String(repeating: "*", count: lineLength)
        let formattedMessage = "** \(message) **"
        
        logger.log(borderLine)
        logger.log(formattedMessage)
        logger.log(borderLine)

        startListening()
        logger.log("setLocalPlayerID called. isServer: \(isServer)")
        #else
        logger.log("Local player ID set to: \(playerID.rawValue)")
#endif
    }
    

#if TEST_MODE
    private func startListening() {
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: 12345)
        } catch {
            logger.log("Failed to create listener: \(error)")
            return
        }
        
        listener?.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .setup:
                self?.logger.log("Listener state: setup")
            case .waiting(let error):
                self?.logger.log("Listener state: waiting with error: \(error)")
            case .ready:
                self?.isServer = true
                self?.logger.log("Listener ready on port \(self?.listener?.port?.debugDescription ?? "unknown")")
                self?.logger.log("This instance is acting as the server.")
            case .failed(let error):
                self?.logger.log("Listener failed with error: \(error)")
                self?.listener?.cancel()
                if case .posix(let posixErrorCode) = error, posixErrorCode == .EADDRINUSE {
                    self?.logger.log("Port 12345 is already in use. This instance will act as a client.")
                    self?.isServer = false
                    self?.connectToServer()
                } else {
                    self?.logger.log("Unexpected error: \(error)")
                }
            case .cancelled:
                self?.logger.log("Listener state: cancelled")
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.logger.log("Received new connection from \(connection.endpoint)")
            self?.acceptConnection(connection)
        }
        
        listener?.start(queue: .main)
        logger.log("isServer after error handling: \(isServer)")
    }
    
    private func acceptConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                self?.logger.log("Connection ready from \(connection.endpoint)")
                self?.receive(on: connection)
                self?.addConnection(connection)
                // Send our presence to the new client
                self?.sendPlayerConnectedMessage(to: [connection])
            case .failed(let error):
                self?.logger.log("Connection failed with error: \(error)")
                self?.removeConnection(connection)
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
    
    private func connectToServer() {
        let connection = NWConnection(host: .ipv4(IPv4Address.loopback), port: 12345, using: .tcp)
        connection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                self?.logger.log("Connected to server")
                self?.receive(on: connection)
                self?.addConnection(connection, isServer: true)
                // Send our presence to the server
                self?.sendPlayerConnectedMessage(to: [connection])
            case .failed(let error):
                self?.logger.log("Failed to connect to server: \(error)")
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
    
    private func addConnection(_ connection: NWConnection, isServer: Bool = false) {
        if let index = connectedPeers.firstIndex(where: { $0.connection === connection }) {
            logger.log("Updating existing connection: \(connection.endpoint)")
            var peer = connectedPeers[index]
            peer.incomingData = Data() // Reset incoming data buffer
            connectedPeers[index] = peer
        } else {
            let newPeer = PeerConnection(connection: connection, playerID: nil, isServer: isServer)
            connectedPeers.append(newPeer)
        }
        logger.log("Updated connectedPeers: \(connectedPeers.map { $0.playerID?.rawValue ?? "nil" })")
    }
//    private func addConnection(_ connection: NWConnection) {
//        let peerConnection = PeerConnection(connection: connection, playerID: nil)
//        connectedPeers.append(peerConnection)
//        logger.log("Added connection from \(connection.endpoint)")
////        gameManager?.syncPlayersFromConnections(connectedPeers)
//    }
    
    private func removeConnection(_ connection: NWConnection) {
        if let index = connectedPeers.firstIndex(where: { $0.connection === connection }) {
            let playerID = connectedPeers[index].playerID
            logger.log("Removing connection from \(connection.endpoint), playerID: \(playerID?.rawValue ?? "Undefined")")
            connectedPeers.remove(at: index)
            gameManager?.syncPlayersFromConnections(connectedPeers) // Update the players once the connection is removed
        } else {
            logger.log("Connection from \(connection.endpoint) not found in connectedPeers")
        }
    }
    
    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleReceivedData(data, from: connection)
            }
            if isComplete {
                self?.logger.log("Connection with \(connection.endpoint) is complete")
                self?.removeConnection(connection)
                connection.cancel()
            } else if let error = error {
                self?.logger.log("Receive error from \(connection.endpoint): \(error)")
                self?.removeConnection(connection)
                connection.cancel()
            } else {
                self?.receive(on: connection)
            }
        }
    }
    
    private func handleReceivedData(_ data: Data, from connection: NWConnection) {
        guard let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) else {
            logger.log("Connection not found in connectedPeers")
            return
        }
        
        // Accumulate incoming data
        connectedPeers[peerIndex].incomingData.append(data)
        
        // Process any complete messages
        processIncomingData(for: connection)
    }
    
    private func processIncomingData(for connection: NWConnection) {
        guard let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) else {
            logger.log("Connection not found in connectedPeers")
            return
        }
        
        var peer = connectedPeers[peerIndex]
        let delimiter = "\n".data(using: .utf8)!
        
        while let range = peer.incomingData.range(of: delimiter) {
            let messageData = peer.incomingData.subdata(in: 0..<range.lowerBound)
            peer.incomingData.removeSubrange(0..<range.upperBound)
            
            do {
                // Attempt to decode as TestModeMessage
                let message = try JSONDecoder().decode(TestModeMessage.self, from: messageData)
//                logger.log("Received message of type \(message.type.rawValue) from \(connection.endpoint)")
                handleTestModeMessage(message, from: connection)
            } catch {
                // If decoding as TestModeMessage fails, try decoding as GameAction
                do {
                    let action = try JSONDecoder().decode(GameAction.self, from: messageData)
//                    logger.log("Received custom action of type \(action.type) from \(action.playerId.rawValue)")
                    if isServer {
                        // Relay action only to the other player
                        let sourcePlayerId = action.playerId

                        // Find the connection associated with the "other player" (not the source)
                        if let otherPlayerConnection = connectedPeers.first(where: { $0.playerID != sourcePlayerId && $0.playerID != localPlayerID }) {
                            // Relay the action to the other player
                            sendData(messageData, to: otherPlayerConnection.connection)
//                            logger.log("Relayed action \(action.type) from \(sourcePlayerId.rawValue) to \(otherPlayerConnection.playerID?.rawValue ?? "unknown")")
                        } else {
                            logger.log("Error: Could not find connection for the other player.")
                        }
                    }
                    gameManager?.handleReceivedAction(action)
                } catch {
                    logger.log("Failed to decode incoming data as TestModeMessage or GameAction: \(error)")
                    if let rawMessage = String(data: messageData, encoding: .utf8) {
                        logger.log("Raw message: \(rawMessage)")
                    }
                }
            }
        }
        
        // Update the peer's data in the array
        connectedPeers[peerIndex].incomingData = peer.incomingData
    }
    
    private func broadcastMessage(_ message: TestModeMessage, excluding excludedConnection: NWConnection? = nil) {
        if var data = try? JSONEncoder().encode(message) {
            data.append("\n".data(using: .utf8)!) // Append newline delimiter
            for peer in connectedPeers {
                if peer.connection !== excludedConnection {
                    peer.connection.send(content: data, completion: .contentProcessed { error in
                        if let error = error {
                            logger.log("Broadcast send error: \(error)")
                        }
                    })
                }
            }
        } else {
            logger.log("Failed to encode message for broadcasting")
        }
    }
    
    private func handleTestModeMessage(_ message: TestModeMessage, from connection: NWConnection) {
        switch message.type {
        case .playerConnected:
            logger.log("handleTestModeMessage: playerConnected")
            if isServer {
                // Server logic remains unchanged
                if let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) {
                    var peer = connectedPeers[peerIndex]
                    peer.playerID = message.playerID
                    connectedPeers[peerIndex] = peer
                    
                    logger.log("Server assigned playerID \(message.playerID.rawValue) to \(connection.endpoint)")

                    broadcastPlayerList()

                    // Notify the UI about the updated list
                    gameManager?.syncPlayersFromConnections(connectedPeers)
                } else {
                    logger.log("The connection wasn't found in connectedPeers")
                }
            } else {
                // Client logic
                if let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) {
                    // Check if this is the server's playerID
                    var peer = connectedPeers[peerIndex]
                    if connection === connectedPeers.first(where: { $0.isServer })?.connection && peer.playerID == nil {
                        logger.log("Client updated server's playerID to \(message.playerID.rawValue)")
                        peer.playerID = message.playerID
                        peer.isServer = true
                        connectedPeers[peerIndex] = peer
                    } else {
                        if connectedPeers.firstIndex(where: { $0.playerID == message.playerID}) == nil {
                            // It's the other client's connection, add it
                            let newPeer = PeerConnection(connection: connection, playerID: message.playerID, isServer: false)
                            connectedPeers.append(newPeer)
                            logger.log("Client added a new peer with ID \(message.playerID.rawValue)")
                        }
                    }
                }
            }
            // Notify the UI about the updated list
            gameManager?.syncPlayersFromConnections(connectedPeers)

        case .playerDisconnected:
            logger.log("Player disconnected: \(message.playerID.rawValue)")
            // When a player disconnects, `removeConnection` will be called, removing them from connectedPeers.
            // After removal, just re-initializePlayers.
            if !isServer {
                if let peerIndex = connectedPeers.firstIndex(where: { $0.playerID == message.playerID }) {
                    connectedPeers.remove(at: peerIndex)
                }
            }
            gameManager?.syncPlayersFromConnections(connectedPeers)

            if isServer {
                logger.log("Broadcasting playerDisconnected message for \(message.playerID) to other clients")
                broadcastMessage(message, excluding: connection)
            }
        }
    }
        
    func applicationWillTerminate() {
        if let localPlayerID = self.localPlayerID {
            let message = TestModeMessage(type: .playerDisconnected, playerID: localPlayerID)
            if let data = try? JSONEncoder().encode(message) {
                if isServer {
                    // Broadcast to all connected clients
                    broadcastMessage(message)
                } else {
                    // Send to server
                    sendData(data)
                }
            }
        } else {
            logger.log( "applicationWillTerminate: Local player ID not found.")
        }
    }
#endif
    
    // MARK: - Data Transmission
    
#if TEST_MODE
    func sendData(_ data: Data, to connection: NWConnection? = nil) {
        var dataWithDelimiter = data
        dataWithDelimiter.append("\n".data(using: .utf8)!)
        
        // Check if a specific connection is provided
        if let connection = connection {
            // Send data to the specific player
            if let peer = connectedPeers.first(where: { $0.connection.endpoint == connection.endpoint }) {
                peer.connection.send(content: dataWithDelimiter, completion: .contentProcessed { error in
                    if let error = error {
                        logger.log("Send error: \(error)")
                    }
                })
            } else {
                logger.log("Error: No peer found with connection \(connection.endpoint)")
            }
        } else {
            // Broadcast data to all connected peers if server
            if isServer {
                for peer in connectedPeers {
                    if peer.playerID != localPlayerID {
                        peer.connection.send(content: dataWithDelimiter, completion: .contentProcessed { error in
                            if let error = error {
                                logger.log("Broadcast send error: \(error)")
                            }
                        })
                    }
                }
            } else {
                // A client sends only to the server
                if let serverPeer = connectedPeers.first(where: { $0.isServer }) {
                    serverPeer.connection.send(content: dataWithDelimiter, completion: .contentProcessed { error in
                        if let error = error {
                            logger.log("Send error: \(error)")
                        }
                    })
                } else {
                    logger.log("Error: No server connection found")
                }
            }
        }
    }
    #else
    func sendData(_ data: Data) {
        // GameKit implementation: send data to all players reliably.
        guard let match = self.match else {
            logger.log("No active GameKit match to send data.")
            return
        }
        do {
            try match.sendData(toAllPlayers: data, with: .reliable)
            logger.log("Data sent via GameKit.")
        } catch {
            logger.log("Error sending data via GameKit: \(error)")
        }
    }
#endif
    
    // MARK: - GameKit Match Configuration (Non‑TEST_MODE)
#if !TEST_MODE
    /// Call this method from your GameKitManager once a match is found.
    // In ConnectionManager.swift

    func configureMatch(_ match: GKMatch) {
        self.match = match
        
        // Track how many players we've processed
        var playersProcessed = 0
        let totalPlayers = match.players.count
        
        logger.log("Configuring match with \(totalPlayers) remote players")
        
        // If there are no remote players, mark the connection as complete
        if totalPlayers == 0 {
            logger.log("No remote players to configure, match is complete")
            return
        }

        // Loop over remote players and assign playerIDs using the association dictionary.
        for player in match.players {
            let assignedId = GCPlayerIdAssociation[player.displayName, default: .dd]
            let username = player.displayName
            logger.log("Processing player: \(username) as \(assignedId.rawValue)")
            
            // Load the player's photo asynchronously
            player.loadPhoto(for: .normal) { [weak self] image, error in
                guard let self = self else { return }
                
                // Update player regardless of whether photo loaded or not
                DispatchQueue.main.async {
                    if let error = error {
                        logger.log("Error loading photo for \(username): \(error)")
                    }
                    
                    // Update the player with whatever image we got (nil is fine)
                    self.gameManager?.updatePlayer(assignedId, name: username, image: image)
                    
                    // Track processed players
                    playersProcessed += 1
                    logger.log("Processed \(playersProcessed)/\(totalPlayers) players")
                    
                    // When all players are processed, check and advance game state
                    if playersProcessed == totalPlayers {
                        logger.log("All players processed, advancing game state")
                        self.gameManager?.checkAndAdvanceStateIfNeeded()
                    }
                }
            }
        }

        logger.log("GameKit match configured with players: \(match.players.map { $0.displayName })")
    }
    
    func handleReceivedGameKitData(_ data: Data, from player: GKPlayer) {
        logger.log("Received some data from \(player.displayName)")
        // Attempt to decode a GameAction (or other message) from the received data
        do {
            let action = try JSONDecoder().decode(GameAction.self, from: data)
            DispatchQueue.main.async {
                logger.log("Received action \(action.type) from \(player.displayName)")
                self.gameManager?.handleReceivedAction(action)
            }
        } catch {
            logger.log("Failed to decode GameAction from GameKit data: \(error)")
        }
    }

    func handleMatchFailure(error: Error?) {
        logger.log("Match failed with error: \(error?.localizedDescription ?? "Unknown error")")
        
        // Handle any cleanup or UI updates needed
        self.match = nil
    }

    func updatePlayerConnectionStatus(playerID: PlayerId, isConnected: Bool) {
        logger.log("Player \(playerID.rawValue) disconnected")
        // Update player connection status in game manager
        gameManager?.updatePlayerConnectionStatus(playerID: playerID, isConnected: isConnected)
    }

#endif

#if TEST_MODE
    private func broadcastPlayerList() {
        // For each connected player, send a playerConnected message
        for peer in connectedPeers {
            if let playerID = peer.playerID {
                let message = TestModeMessage(type: .playerConnected, playerID: playerID)
                broadcastMessage(message)
            }
        }
    }
    
    private func sendPlayerConnectedMessage(to connections: [NWConnection]? = nil) {
        if let localPlayerID = self.localPlayerID {
            let message = TestModeMessage(type: .playerConnected, playerID: localPlayerID)
            if var data = try? JSONEncoder().encode(message) {
                data.append("\n".data(using: .utf8)!) // Append newline delimiter
                if let connections = connections {
                    for connection in connections {
                        connection.send(content: data, completion: .contentProcessed { error in
                            if let error = error {
                                logger.log("Send error: \(error)")
                            }
                        })
                    }
                } else {
                    for peer in connectedPeers {
                        peer.connection.send(content: data, completion: .contentProcessed { error in
                            if let error = error {
                                logger.log("Send error: \(error)")
                            }
                        })
                    }
                }
            }
        } else {
            logger.log("sendPlayerConnectedMessage called, but localPlayerID is nil")
        }
    }
#endif
}

protocol ConnectionManagerDelegate: AnyObject {
    func handleReceivedAction(_ action: GameAction)
}
