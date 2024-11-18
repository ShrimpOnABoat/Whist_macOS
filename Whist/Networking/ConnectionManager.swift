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

struct PeerConnection {
    let connection: NWConnection
    var playerID: PlayerId?
    var isServer: Bool = false
    var incomingData: Data = Data() // New buffer for accumulating data
}

class ConnectionManager: NSObject, ObservableObject {
    weak var gameManager: GameManager?
    
#if !TEST_MODE
    @Published var match: GKMatch?
#endif
    
#if TEST_MODE
    @Published var localPlayerID: PlayerId = .dd
    private var connectedPeers: [PeerConnection] = []
//    {
//        didSet {
//            print("connectedPeers changed: \(connectedPeers.map { $0.playerID?.rawValue ?? "nil" })")
//        }
//    }
    private var listener: NWListener?
    private var isServer: Bool = false
#endif
    
    override init() {
        super.init()
        
#if TEST_MODE
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminateNotification), name: NSApplication.willTerminateNotification, object: nil)
#endif
    }
    
#if TEST_MODE
    @objc private func applicationWillTerminateNotification() {
        applicationWillTerminate()
    }
#endif
    
    // MARK: - Test Mode Networking (Sockets)
    
#if TEST_MODE
    func setLocalPlayerID(_ playerID: PlayerId) {
        self.localPlayerID = playerID

        let message = playerID.rawValue.uppercased()
        let padding = 3 // Padding around the message inside the box
        let lineLength = message.count + padding * 2
        let borderLine = String(repeating: "*", count: lineLength)
        let formattedMessage = "** \(message) **"
        
        print(borderLine)
        print(formattedMessage)
        print(borderLine)
//            func logImportantMessage(_ message: String) {
//                let padding = 3 // Padding around the message inside the box
//                let lineLength = message.count + padding * 2
//                let borderLine = String(repeating: "*", count: lineLength)
//                let formattedMessage = "** \(message) **"
//                
//                print(borderLine)
//                print(formattedMessage)
//                print(borderLine)
//            }
        
//        initializePlayers()
        startListening()
        print("setLocalPlayerID called. isServer: \(isServer)")
    }
    
    private func startListening() {
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: 12345)
        } catch {
            print("Failed to create listener: \(error)")
            return
        }
        
        listener?.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .setup:
                print("Listener state: setup")
            case .waiting(let error):
                print("Listener state: waiting with error: \(error)")
            case .ready:
                self?.isServer = true
                print("Listener ready on port \(self?.listener?.port?.debugDescription ?? "unknown")")
                print("This instance is acting as the server.")
            case .failed(let error):
                print("Listener failed with error: \(error)")
                self?.listener?.cancel()
                if case .posix(let posixErrorCode) = error, posixErrorCode == .EADDRINUSE {
                    print("Port 12345 is already in use. This instance will act as a client.")
                    self?.isServer = false
                    self?.connectToServer()
                } else {
                    print("Unexpected error: \(error)")
                }
            case .cancelled:
                print("Listener state: cancelled")
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            print("Received new connection from \(connection.endpoint)")
            self?.acceptConnection(connection)
        }
        
        listener?.start(queue: .main)
        print("isServer after error handling: \(isServer)")
    }
    
    private func acceptConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                print("Connection ready from \(connection.endpoint)")
                self?.receive(on: connection)
                self?.addConnection(connection)
                // Send our presence to the new client
                self?.sendPlayerConnectedMessage(to: [connection])
            case .failed(let error):
                print("Connection failed with error: \(error)")
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
                print("Connected to server")
                self?.receive(on: connection)
                self?.addConnection(connection, isServer: true)
                // Send our presence to the server
                self?.sendPlayerConnectedMessage(to: [connection])
            case .failed(let error):
                print("Failed to connect to server: \(error)")
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
    
    private func addConnection(_ connection: NWConnection, isServer: Bool = false) {
        if let index = connectedPeers.firstIndex(where: { $0.connection === connection }) {
            print("Updating existing connection: \(connection.endpoint)")
            var peer = connectedPeers[index]
            peer.incomingData = Data() // Reset incoming data buffer
            connectedPeers[index] = peer
        } else {
            let newPeer = PeerConnection(connection: connection, playerID: nil, isServer: isServer)
            connectedPeers.append(newPeer)
        }
        print("Updated connectedPeers: \(connectedPeers.map { $0.playerID?.rawValue ?? "nil" })")
    }
//    private func addConnection(_ connection: NWConnection) {
//        let peerConnection = PeerConnection(connection: connection, playerID: nil)
//        connectedPeers.append(peerConnection)
//        print("Added connection from \(connection.endpoint)")
////        gameManager?.syncPlayersFromConnections(connectedPeers)
//    }
    
    private func removeConnection(_ connection: NWConnection) {
        if let index = connectedPeers.firstIndex(where: { $0.connection === connection }) {
            let playerID = connectedPeers[index].playerID
            print("Removing connection from \(connection.endpoint), playerID: \(playerID?.rawValue ?? "Undefined")")
            connectedPeers.remove(at: index)
            gameManager?.syncPlayersFromConnections(connectedPeers) // Update the players once the connection is removed
        } else {
            print("Connection from \(connection.endpoint) not found in connectedPeers")
        }
    }
    
    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleReceivedData(data, from: connection)
            }
            if isComplete {
                print("Connection with \(connection.endpoint) is complete")
                self?.removeConnection(connection)
                connection.cancel()
            } else if let error = error {
                print("Receive error from \(connection.endpoint): \(error)")
                self?.removeConnection(connection)
                connection.cancel()
            } else {
                self?.receive(on: connection)
            }
        }
    }
    
    private func handleReceivedData(_ data: Data, from connection: NWConnection) {
        guard let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) else {
            print("Connection not found in connectedPeers")
            return
        }
        
        // Accumulate incoming data
        connectedPeers[peerIndex].incomingData.append(data)
        
        // Process any complete messages
        processIncomingData(for: connection)
    }
    
    private func processIncomingData(for connection: NWConnection) {
        guard let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) else {
            print("Connection not found in connectedPeers")
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
                print("Received message of type \(message.type.rawValue) from \(connection.endpoint)")
                handleTestModeMessage(message, from: connection)
            } catch {
                // If decoding as TestModeMessage fails, try decoding as GameAction
                do {
                    let action = try JSONDecoder().decode(GameAction.self, from: messageData)
                    print("Received custom action of type \(action.type) from \(action.playerId.rawValue)")
                    if isServer {
                        // Relay action only to the other player
                        let sourcePlayerId = action.playerId

                        // Find the connection associated with the "other player" (not the source)
                        if let otherPlayerConnection = connectedPeers.first(where: { $0.playerID != sourcePlayerId && $0.playerID != localPlayerID }) {
                            // Relay the action to the other player
                            sendData(messageData, to: otherPlayerConnection.connection)
                            print("Relayed action \(action.type) from \(sourcePlayerId.rawValue) to \(otherPlayerConnection.playerID?.rawValue ?? "unknown")")
                        } else {
                            print("Error: Could not find connection for the other player.")
                        }
                    }
                    gameManager?.handleReceivedAction(action)
                } catch {
                    print("Failed to decode incoming data as TestModeMessage or GameAction: \(error)")
                    if let rawMessage = String(data: messageData, encoding: .utf8) {
                        print("Raw message: \(rawMessage)")
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
                            print("Broadcast send error: \(error)")
                        }
                    })
                }
            }
        } else {
            print("Failed to encode message for broadcasting")
        }
    }
    
    private func handleTestModeMessage(_ message: TestModeMessage, from connection: NWConnection) {
        switch message.type {
        case .playerConnected:
            print("handleTestModeMessage: playerConnected")
            if isServer {
                // Server logic remains unchanged
                if let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) {
                    var peer = connectedPeers[peerIndex]
                    peer.playerID = message.playerID
                    connectedPeers[peerIndex] = peer
                    
                    print("Server assigned playerID \(message.playerID.rawValue) to \(connection.endpoint)")

                    broadcastPlayerList()

                    // Notify the UI about the updated list
                    gameManager?.syncPlayersFromConnections(connectedPeers)
                } else {
                    print("The connection wasn't found in connectedPeers")
                }
            } else {
                // Client logic
                if let peerIndex = connectedPeers.firstIndex(where: { $0.connection === connection }) {
                    // Check if this is the server's playerID
                    var peer = connectedPeers[peerIndex]
                    if connection === connectedPeers.first(where: { $0.isServer })?.connection && peer.playerID == nil {
                        print("Client updated server's playerID to \(message.playerID.rawValue)")
                        peer.playerID = message.playerID
                        peer.isServer = true
                        connectedPeers[peerIndex] = peer
                    } else {
                        if connectedPeers.firstIndex(where: { $0.playerID == message.playerID}) == nil {
                            // It's the other client's connection, add it
                            let newPeer = PeerConnection(connection: connection, playerID: message.playerID, isServer: false)
                            connectedPeers.append(newPeer)
                            print("Client added a new peer with ID \(message.playerID.rawValue)")
                        }
                    }
                }
            }
            // Notify the UI about the updated list
            gameManager?.syncPlayersFromConnections(connectedPeers)

        case .playerDisconnected:
            print("Player disconnected: \(message.playerID.rawValue)")
            // When a player disconnects, `removeConnection` will be called, removing them from connectedPeers.
            // After removal, just re-initializePlayers.
            if !isServer {
                if let peerIndex = connectedPeers.firstIndex(where: { $0.playerID == message.playerID }) {
                    connectedPeers.remove(at: peerIndex)
                }
            }
            gameManager?.syncPlayersFromConnections(connectedPeers)

            if isServer {
                print("Broadcasting playerDisconnected message for \(message.playerID) to other clients")
                broadcastMessage(message, excluding: connection)
            }
        }
    }
        
    func applicationWillTerminate() {
        let message = TestModeMessage(type: .playerDisconnected, playerID: self.localPlayerID)
        if let data = try? JSONEncoder().encode(message) {
            if isServer {
                // Broadcast to all connected clients
                broadcastMessage(message)
            } else {
                // Send to server
                sendData(data)
            }
        }
    }
#endif
    
    // MARK: - Data Transmission
    
    func sendData(_ data: Data, to connection: NWConnection? = nil) {
    #if TEST_MODE
        var dataWithDelimiter = data
        dataWithDelimiter.append("\n".data(using: .utf8)!)
        print("sendData: \(connectedPeers.count) connected")

        // Check if a specific connection is provided
        if let connection = connection {
            // Send data to the specific player
            if let peer = connectedPeers.first(where: { $0.connection.endpoint == connection.endpoint }) {
                print("Sending \(data) to \(peer.connection.endpoint)")
                peer.connection.send(content: dataWithDelimiter, completion: .contentProcessed { error in
                    if let error = error {
                        print("Send error: \(error)")
                    }
                })
            } else {
                print("Error: No peer found with connection \(connection.endpoint)")
            }
        } else {
            // Broadcast data to all connected peers if server
            if isServer {
                for peer in connectedPeers {
                    if peer.playerID != localPlayerID {
                        print("Broadcasting \(data) to \(peer.playerID?.rawValue ?? "unknown")")
                        peer.connection.send(content: dataWithDelimiter, completion: .contentProcessed { error in
                            if let error = error {
                                print("Broadcast send error: \(error)")
                            }
                        })
                    }
                }
            } else {
                // A client sends only to the server
                if let serverPeer = connectedPeers.first(where: { $0.isServer }) {
                    print("Client sending \(data) to server at \(serverPeer.connection.endpoint)")
                    serverPeer.connection.send(content: dataWithDelimiter, completion: .contentProcessed { error in
                        if let error = error {
                            print("Send error: \(error)")
                        }
                    })
                } else {
                    print("Error: No server connection found")
                }
            }
        }
    #else
        // Existing GameKit code...
    #endif
    }
    
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
        let message = TestModeMessage(type: .playerConnected, playerID: self.localPlayerID)
        if var data = try? JSONEncoder().encode(message) {
            data.append("\n".data(using: .utf8)!) // Append newline delimiter
            if let connections = connections {
                for connection in connections {
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error = error {
                            print("Send error: \(error)")
                        }
                    })
                }
            } else {
                for peer in connectedPeers {
                    peer.connection.send(content: data, completion: .contentProcessed { error in
                        if let error = error {
                            print("Send error: \(error)")
                        }
                    })
                }
            }
        }
    }
#endif
    
    // MARK: - GameKit Networking
    
#if !TEST_MODE
    // Existing GameKit methods...
#endif
    
    func connectionStatus(for player: Player) -> String {
#if TEST_MODE
        if player.id == self.localPlayerID {
            return "Connected (You)"
        } else if connectedPeers.contains(where: { $0.playerID == player.id }) {
            return "Connected"
        } else {
            return "Disconnected"
        }
#else
        // Existing GameKit implementation...
#endif
    }
}

protocol ConnectionManagerDelegate: AnyObject {
    func handleReceivedAction(_ action: GameAction)
}
