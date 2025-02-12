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
        
        logWithTimestamp(borderLine)
        logWithTimestamp(formattedMessage)
        logWithTimestamp(borderLine)

        startListening()
        logWithTimestamp("setLocalPlayerID called. isServer: \(isServer)")
        #else
        logWithTimestamp("Local player ID set to: \(playerID.rawValue)")
#endif
    }
    

#if TEST_MODE
    private func startListening() {
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: 12345)
        } catch {
            logWithTimestamp("Failed to create listener: \(error)")
            return
        }
        
        listener?.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .setup:
                self?.logWithTimestamp("Listener state: setup")
            case .waiting(let error):
                self?.logWithTimestamp("Listener state: waiting with error: \(error)")
            case .ready:
                self?.isServer = true
                self?.logWithTimestamp("Listener ready on port \(self?.listener?.port?.debugDescription ?? "unknown")")
                self?.logWithTimestamp("This instance is acting as the server.")
            case .failed(let error):
                self?.logWithTimestamp("Listener failed with error: \(error)")
                self?.listener?.cancel()
                if case .posix(let posixErrorCode) = error, posixErrorCode == .EADDRINUSE {
                    self?.logWithTimestamp("Port 12345 is already in use. This instance will act as a client.")
                    self?.isServer = false
                    self?.connectToServer()
                } else {
                    self?.logWithTimestamp("Unexpected error: \(error)")
                }
            case .cancelled:
                self?.logWithTimestamp("Listener state: cancelled")
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.logWithTimestamp("Received new connection from \(connection.endpoint)")
            self?.acceptConnection(connection)
        }
        
        listener?.start(queue: .main)
        logWithTimestamp("isServer after error handling: \(isServer)")
    }
    
    private func acceptConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                self?.logWithTimestamp("Connection ready from \(connection.endpoint)")
                self?.receive(on: connection)
                self?.addConnection(connection)
                // Send our presence to the new client
                self?.sendPlayerConnectedMessage(to: [connection])
            case .failed(let error):
                self?.logWithTimestamp("Connection failed with error: \(error)")
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
                self?.logWithTimestamp("Connected to server")
                self?.receive(on: connection)
                self?.addConnection(connection, isServer: true)
                // Send our presence to the server
                self?.sendPlayerConnectedMessage(to: [connection])
            case .failed(let error):
                self?.logWithTimestamp("Failed to connect to server: \(error)")
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
    
    private func addConnection(_ connection: NWConnection, isServer: Bool = false) {
        if let index = connectedPeers.firstIndex(where: { $0.connection === connection }) {
            logWithTimestamp("Updating existing connection: \(connection.endpoint)")
            var peer = connectedPeers[index]
            peer.incomingData = Data() // Reset incoming data buffer
            connectedPeers[index] = peer
        } else {
            let newPeer = PeerConnection(connection: connection, playerID: nil, isServer: isServer)
            connectedPeers.append(newPeer)
        }
        logWithTimestamp("Updated connectedPeers: \(connectedPeers.map { $0.playerID?.rawValue ?? "nil" })")
    }
//    private func addConnection(_ connection: NWConnection) {
//        let peerConnection = PeerConnection(connection: connection, playerID: nil)
//        connectedPeers.append(peerConnection)
//        logWithTimestamp("Added connection from \(connection.endpoint)")
////        gameManager?.syncPlayersFromConnections(connectedPeers)
//    }
    
    private func removeConnection(_ connection: NWConnection) {
        if let index = connectedPeers.firstIndex(where: { $0.connection === connection }) {
            let playerID = connectedPeers[index].playerID
            logWithTimestamp("Removing connection from \(connection.endpoint), playerID: \(playerID?.rawValue ?? "Undefined")")
            connectedPeers.remove(at: index)
            gameManager?.syncPlayersFromConnections(connectedPeers) // Update the players once the connection is removed
        } else {
            logWithTimestamp("Connection from \(connection.endpoint) not found in connectedPeers")
        }
    }
    
    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleReceivedData(data, from: connection)
            }
            if isComplete {
                self?.logWithTimestamp("Connection with \(connection.endpoint) is complete")
                self?.removeConnection(connection)
                connection.cancel()
            } else if let error = error {
                self?.logWithTimestamp("Receive error from \(connection.endpoint): \(error)")
                self?.removeConnection(connection)
                connection.cancel()
            } else {
                self?.receive(on: connection)
            }
        }
    }
    
    private func handleReceivedData(_ data: Data, from connection: NWConnection) {
        guard let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) else {
            logWithTimestamp("Connection not found in connectedPeers")
            return
        }
        
        // Accumulate incoming data
        connectedPeers[peerIndex].incomingData.append(data)
        
        // Process any complete messages
        processIncomingData(for: connection)
    }
    
    private func processIncomingData(for connection: NWConnection) {
        guard let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) else {
            logWithTimestamp("Connection not found in connectedPeers")
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
//                logWithTimestamp("Received message of type \(message.type.rawValue) from \(connection.endpoint)")
                handleTestModeMessage(message, from: connection)
            } catch {
                // If decoding as TestModeMessage fails, try decoding as GameAction
                do {
                    let action = try JSONDecoder().decode(GameAction.self, from: messageData)
//                    logWithTimestamp("Received custom action of type \(action.type) from \(action.playerId.rawValue)")
                    if isServer {
                        // Relay action only to the other player
                        let sourcePlayerId = action.playerId

                        // Find the connection associated with the "other player" (not the source)
                        if let otherPlayerConnection = connectedPeers.first(where: { $0.playerID != sourcePlayerId && $0.playerID != localPlayerID }) {
                            // Relay the action to the other player
                            sendData(messageData, to: otherPlayerConnection.connection)
//                            logWithTimestamp("Relayed action \(action.type) from \(sourcePlayerId.rawValue) to \(otherPlayerConnection.playerID?.rawValue ?? "unknown")")
                        } else {
                            logWithTimestamp("Error: Could not find connection for the other player.")
                        }
                    }
                    gameManager?.handleReceivedAction(action)
                } catch {
                    logWithTimestamp("Failed to decode incoming data as TestModeMessage or GameAction: \(error)")
                    if let rawMessage = String(data: messageData, encoding: .utf8) {
                        logWithTimestamp("Raw message: \(rawMessage)")
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
                            self.logWithTimestamp("Broadcast send error: \(error)")
                        }
                    })
                }
            }
        } else {
            logWithTimestamp("Failed to encode message for broadcasting")
        }
    }
    
    private func handleTestModeMessage(_ message: TestModeMessage, from connection: NWConnection) {
        switch message.type {
        case .playerConnected:
            logWithTimestamp("handleTestModeMessage: playerConnected")
            if isServer {
                // Server logic remains unchanged
                if let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) {
                    var peer = connectedPeers[peerIndex]
                    peer.playerID = message.playerID
                    connectedPeers[peerIndex] = peer
                    
                    logWithTimestamp("Server assigned playerID \(message.playerID.rawValue) to \(connection.endpoint)")

                    broadcastPlayerList()

                    // Notify the UI about the updated list
                    gameManager?.syncPlayersFromConnections(connectedPeers)
                } else {
                    logWithTimestamp("The connection wasn't found in connectedPeers")
                }
            } else {
                // Client logic
                if let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) {
                    // Check if this is the server's playerID
                    var peer = connectedPeers[peerIndex]
                    if connection === connectedPeers.first(where: { $0.isServer })?.connection && peer.playerID == nil {
                        logWithTimestamp("Client updated server's playerID to \(message.playerID.rawValue)")
                        peer.playerID = message.playerID
                        peer.isServer = true
                        connectedPeers[peerIndex] = peer
                    } else {
                        if connectedPeers.firstIndex(where: { $0.playerID == message.playerID}) == nil {
                            // It's the other client's connection, add it
                            let newPeer = PeerConnection(connection: connection, playerID: message.playerID, isServer: false)
                            connectedPeers.append(newPeer)
                            logWithTimestamp("Client added a new peer with ID \(message.playerID.rawValue)")
                        }
                    }
                }
            }
            // Notify the UI about the updated list
            gameManager?.syncPlayersFromConnections(connectedPeers)

        case .playerDisconnected:
            logWithTimestamp("Player disconnected: \(message.playerID.rawValue)")
            // When a player disconnects, `removeConnection` will be called, removing them from connectedPeers.
            // After removal, just re-initializePlayers.
            if !isServer {
                if let peerIndex = connectedPeers.firstIndex(where: { $0.playerID == message.playerID }) {
                    connectedPeers.remove(at: peerIndex)
                }
            }
            gameManager?.syncPlayersFromConnections(connectedPeers)

            if isServer {
                logWithTimestamp("Broadcasting playerDisconnected message for \(message.playerID) to other clients")
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
            logWithTimestamp( "applicationWillTerminate: Local player ID not found.")
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
                        self.logWithTimestamp("Send error: \(error)")
                    }
                })
            } else {
                logWithTimestamp("Error: No peer found with connection \(connection.endpoint)")
            }
        } else {
            // Broadcast data to all connected peers if server
            if isServer {
                for peer in connectedPeers {
                    if peer.playerID != localPlayerID {
                        peer.connection.send(content: dataWithDelimiter, completion: .contentProcessed { error in
                            if let error = error {
                                self.logWithTimestamp("Broadcast send error: \(error)")
                            }
                        })
                    }
                }
            } else {
                // A client sends only to the server
                if let serverPeer = connectedPeers.first(where: { $0.isServer }) {
                    serverPeer.connection.send(content: dataWithDelimiter, completion: .contentProcessed { error in
                        if let error = error {
                            self.logWithTimestamp("Send error: \(error)")
                        }
                    })
                } else {
                    logWithTimestamp("Error: No server connection found")
                }
            }
        }
    }
    #else
    func sendData(_ data: Data) {
        // GameKit implementation: send data to all players reliably.
        guard let match = self.match else {
            logWithTimestamp("No active GameKit match to send data.")
            return
        }
        do {
            try match.sendData(toAllPlayers: data, with: .reliable)
            logWithTimestamp("Data sent via GameKit.")
        } catch {
            logWithTimestamp("Error sending data via GameKit: \(error)")
        }
    }
#endif
    
    // MARK: - GameKit Match Configuration (Non‑TEST_MODE)
#if !TEST_MODE
    /// Call this method from your GameKitManager once a match is found.
    func configureMatch(_ match: GKMatch) {
        self.match = match
        self.match?.delegate = self
        logWithTimestamp("GameKit match configured with players: \(match.players.map { $0.displayName })")
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
                                self.logWithTimestamp("Send error: \(error)")
                            }
                        })
                    }
                } else {
                    for peer in connectedPeers {
                        peer.connection.send(content: data, completion: .contentProcessed { error in
                            if let error = error {
                                self.logWithTimestamp("Send error: \(error)")
                            }
                        })
                    }
                }
            }
        } else {
            logWithTimestamp("sendPlayerConnectedMessage called, but localPlayerID is nil")
        }
    }
#endif
    
    // MARK: - GameKit Networking
    
#if !TEST_MODE
    // Existing GameKit methods...
#endif
    
//    func connectionStatus(for player: Player) -> String {
//#if TEST_MODE
//        if player.id == self.localPlayerID {
//            return "Connected (You)"
//        } else if connectedPeers.contains(where: { $0.playerID == player.id }) {
//            return "Connected"
//        } else {
//            return "Disconnected"
//        }
//#else
//        // Existing GameKit implementation...
//#endif
//    }
//    
    func logWithTimestamp(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        print("[\(timestamp)] \(message)")
    }
}

protocol ConnectionManagerDelegate: AnyObject {
    func handleReceivedAction(_ action: GameAction)
}

#if !TEST_MODE
// MARK: - GKMatchDelegate Implementation

extension ConnectionManager: GKMatchDelegate {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        logWithTimestamp("Received data from \(player.displayName)")
        // Attempt to decode a GameAction (or other message) from the received data.
        do {
            let action = try JSONDecoder().decode(GameAction.self, from: data)
            DispatchQueue.main.async {
                self.gameManager?.handleReceivedAction(action)
            }
        } catch {
            logWithTimestamp("Failed to decode GameAction from GameKit data: \(error)")
        }
    }
    
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        logWithTimestamp("Player \(player.displayName) changed state to \(state.rawValue)")
        // Update your game state or notify the GameManager if needed.
    }
    
    func match(_ match: GKMatch, didFailWithError error: Error?) {
        logWithTimestamp("Match failed with error: \(error?.localizedDescription ?? "Unknown error")")
    }
}
#endif
