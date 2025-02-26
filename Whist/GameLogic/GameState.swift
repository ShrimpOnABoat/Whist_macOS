//
//  GameState.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Represents the overall game state.

import Foundation
import SwiftUI

class GameState: ObservableObject, Codable {
    @Published var round: Int = 0 // 1 is the first round, 12 is the last (12th) one
    @Published var deck: [Card] = []
    var newDeck: [Card] = [] // Used to store the deck from the dealer
    @Published var trumpCards: [Card] = [Card(suit: .clubs, rank: .two), Card(suit: .spades, rank: .two), Card(suit: .diamonds, rank: .two), Card(suit: .hearts, rank: .two)]
    @Published var table: [Card] = [] // Must be [] after each trick grab. It follows the same order as in playOrder
    @Published var lastTrick: [PlayerId: Card] = [:] {
        didSet {
            logWithTimestamp("Last trick updated: \(String(describing: lastTrick))")
        }
    }
    @Published var lastTrickCardStates: [PlayerId: CardState] = [:]
    @Published var players: [Player] = []
    @Published var trumpSuit: Suit? = nil {
        didSet {
            logWithTimestamp("Trump suit changed to: \(String(describing: trumpSuit))")
        }
    } // When the trump card is defined, the first card of the deck or twos is returned and trumpSuit is defined
    @Published var playOrder: [PlayerId] = [] // should be reset after each trick grab
    @Published var dealer: PlayerId? = nil
    @Published var currentPhase: GamePhase = .waitingForPlayers
    var tricksGrabbed: [Bool] = []
    var currentTrick: Int = 0


    // MARK: - Codable Conformance
    enum CodingKeys: String, CodingKey {
        case round
        case deck
        case table
        case lastTrick
        case players
        case trumpSuit
        case playOrder
        case dealer
        case currentPhase
        // Include other properties here
    }
    
    // Custom initializer
    init(round: Int = 0, deck: [Card] = [], trumpCards: [Card] = [], table: [Card] = [], players: [Player] = [], trumpSuit: Suit? = nil, playOrder: [PlayerId] = [], dealer: PlayerId? = nil) {
        self.round = round
        self.deck = deck
        self.table = table
        self.lastTrick = lastTrick
        self.players = players
        self.trumpSuit = trumpSuit
        self.playOrder = playOrder
        self.dealer = dealer
        self.createDefaultPlayers()
    }
    
    // Decodable
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        round = try container.decode(Int.self, forKey: .round)
        deck = try container.decode([Card].self, forKey: .deck)
        table = try container.decode([Card].self, forKey: .table)
        lastTrick = try container.decode([PlayerId: Card].self, forKey: .lastTrick)
        players = try container.decode([Player].self, forKey: .players)
        trumpSuit = try container.decodeIfPresent(Suit.self, forKey: .trumpSuit)
        playOrder = try container.decode([PlayerId].self, forKey: .playOrder)
        dealer = try container.decodeIfPresent(PlayerId.self, forKey: .dealer)
        currentPhase = try container.decode(GamePhase.self, forKey: .currentPhase)
        if players.isEmpty { self.createDefaultPlayers() }
    }
    
    // Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(round, forKey: .round)
        try container.encode(deck, forKey: .deck)
        try container.encode(table, forKey: .table)
        try container.encode(lastTrick, forKey: .lastTrick)
        try container.encode(players, forKey: .players)
        try container.encodeIfPresent(trumpSuit, forKey: .trumpSuit)
        try container.encode(playOrder, forKey: .playOrder)
        try container.encodeIfPresent(dealer, forKey: .dealer)
        try container.encode(currentPhase, forKey: .currentPhase)
        // Encode other properties as needed
    }
    
    // MARK: - Player Creation
    private func createDefaultPlayers() {
        let allPossiblePlayers: [PlayerId] = [.dd, .gg, .toto]

        for playerID in allPossiblePlayers {
            // Assign placeholder images for players based on their IDs
            let placeholderImage: Image
            switch playerID {
            case .dd:
                placeholderImage = Image(systemName: "figure.pool.swim.circle.fill")
            case .gg:
                placeholderImage = Image(systemName: "safari.fill")
            case .toto:
                placeholderImage = Image(systemName: "figure.run.treadmill.circle.fill")
            }

            // Add the player to the game state
            let newPlayer = Player(id: playerID, username: playerID.rawValue, image: placeholderImage)
            newPlayer.isConnected = false
            players.append(newPlayer)
        }
    }

    // MARK: - Helper Methods
    
    // Get cards in a player's hand
    func getPlayerHand(playerId: PlayerId) -> [Card] {
        let player = getPlayer(by: playerId)
        return player.hand
    }
    
    // Method to update player references
    func updatePlayerReferences(for localPlayerId: PlayerId) {
        // Find the index of the local player in the playOrder
        guard let localIndex = playOrder.firstIndex(of: localPlayerId) else {
            fatalError("Error: Local player ID \(localPlayerId.rawValue) not found in playOrder")
        }
        
        // Map tablePosition for each player
        for (index, playerId) in playOrder.enumerated() {
            if let player = players.first(where: { $0.id == playerId }) {
                if index == localIndex {
                    player.tablePosition = .local
                } else if index == (localIndex + 1) % playOrder.count {
                    player.tablePosition = .left
                } else if index == (localIndex + playOrder.count - 1) % playOrder.count {
                    player.tablePosition = .right
                }
            }
        }
    }
}

extension GameState {
    static var preview: GameState {
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()
        return gameManager.gameState
    }
}

extension GameState {
    func getPlayer(by id: PlayerId) -> Player {
        guard let player = players.first(where: { $0.id == id }) else {
            fatalError("Error: Player with ID \(id.rawValue) not found.")
        }
        return player
    }
}

extension GameState {
    func moveCardPreview(from source: inout [Card], to destination: inout [Card], card: Card) {
        // Ensure the card exists in the source array
        guard let cardIndex = source.firstIndex(of: card) else {
            fatalError("Card \(card) not found in \(source)")
        }

        // Remove the card from the source
        let cardToMove = source.remove(at: cardIndex)

        // Add the card to the destination
        destination.append(cardToMove)
    }
}

extension GameState {
    var localPlayer: Player? {
        players.first(where: { $0.tablePosition == .local })
    }
    
    var leftPlayer: Player? {
        players.first(where: { $0.tablePosition == .left })
    }
    
    var rightPlayer: Player? {
        players.first(where: { $0.tablePosition == .right })
    }
    
    var lastPlayer: Player? {
        players.first(where: { $0.place == 3 })
    }
    
    var allPlayersConnected: Bool {
        players.allSatisfy(\.isConnected)
    }
}

extension GameState {
    func logWithTimestamp(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        print("[\(timestamp)] \(message)")
    }

}
