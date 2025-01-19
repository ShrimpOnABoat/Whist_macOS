//
//  GameManager.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Core controller managing the game flow and state.

import Foundation
import Combine
import CryptoKit
import SwiftUI

enum PlayerId: String, Codable, CaseIterable {
    case dd = "dd"
    case gg = "gg"
    case toto = "toto"
}

class GameManager: ObservableObject, ConnectionManagerDelegate {
    @Published var gameState: GameState = GameState()
    @Published var currentPhase: GamePhase = .waitingToStart
    @Published var showOptions: Bool = false
    @Published var showTrumps: Bool = false
    @Published var showTopDeckCardFaceUp = false
    @Published var movingCards: [MovingCard] = []
    private var timerCancellable: AnyCancellable?
    var isDeckReady: Bool = false
    var pendingActions: [GameAction] = []
    var activeAnimations = 0
    var onBatchAnimationsCompleted: [(() -> Void)?] = []
    var animationQueue: [(Int, () -> Void)] = []
    // Dictionary to store each card's state
    @Published var cardStates: [String: CardState] = [:]
    @Published var isShuffling: Bool = false
    var shuffleCallback: ((_ deck: [Card], _ completion: @escaping () -> Void) -> Void)?
    // Injected dependencies
    var connectionManager: ConnectionManager?
    let soundManager = SoundManager()

    static let SM = ScoresManager.shared
    
    var cancellables = Set<AnyCancellable>()
    var isGameSetup: Bool = false
    
    init() {
    }
    
    // MARK: - Game State Initialization
    
    func setupGame() {
        print("--> SetupGame()")
        let totalPlayers = gameState.players.count
        let connectedPlayers = gameState.players.filter { $0.connected }.count
        print("Total players created: \(totalPlayers), Players connected: \(connectedPlayers)")
        
        // Check if the game is already set up
        guard !isGameSetup else {
            print("Game is already set up.")
            return
        }
        
        // 1. Collect and sort player IDs
        let playerIDs = gameState.players.map { $0.id }.sorted(by: { $0.rawValue < $1.rawValue })
        
        // 2. Create a combined string
        let combinedString = playerIDs.map { $0.rawValue }.joined(separator: ",")
        
        // 3. Generate a seed from the combined string
        let seed = generateSeed(from: combinedString)
        
        // 4. Initialize the random number generator
        var generator = SeededGenerator(seed: seed)
        
        // 5. Shuffle the player order
        var shuffledPlayerIDs = playerIDs
        shuffledPlayerIDs.shuffle(using: &generator)
        
        // 6. Update the game state
        gameState.playOrder = shuffledPlayerIDs
        gameState.dealer = gameState.playOrder.first
        print("Dealer is \(String(describing: gameState.dealer))")
        
        // Set the previous loser's monthlyLosses
        if let loser = GameManager.SM.findLoser(),
           let loserIndex = gameState.players.firstIndex(where: { $0.username == loser.playerId }) {
            gameState.players[loserIndex].monthlyLosses = loser.losingMonths
            print("Updated \(loser.playerId)'s monthlyLosses to \(loser.losingMonths)")
        } else {
            if let loser = GameManager.SM.findLoser() {
                print("Loser \(loser.playerId) not found in players.")
            } else {
                print("No loser found.")
            }
        }
        
        // Identify localPlayer, leftPlayer, and rightPlayer
        if let localPlayerID = connectionManager?.localPlayerID {
            gameState.updatePlayerReferences(for: localPlayerID)
        } else {
            fatalError("Error: Unable to determine main player or neighbors.")
        }
        
        if let localPlayer = gameState.localPlayer, let leftPlayer = gameState.leftPlayer, let rightPlayer = gameState.rightPlayer {
            print("Main Player: \(localPlayer.username), Left Player: \(leftPlayer.username), Right Player: \(rightPlayer.username)")
        } else {
            fatalError("Players could not be assigned correctly.")
        }

        isGameSetup = true

        // Create the cards
        initializeCards()
        
        
        // Proceed with first game of the session
//        newGame()
    }
    
    func generateSeed(from string: String) -> UInt64 {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        // Extract the first 8 bytes to create a UInt64 seed
        let seed = Data(hash.prefix(8)).withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            return ptr.load(as: UInt64.self)
        }
        return seed
    }
    
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        
        init(seed: UInt64) {
            self.state = seed
        }
        
        mutating func next() -> UInt64 {
            self.state ^= self.state >> 12
            self.state ^= self.state << 25
            self.state ^= self.state >> 27
            return self.state &* 2685821657736338717
        }
    }
    
    // MARK: - Game Logic Functions
    
    func newGame() {
        gameState.round = 0
    }
    
    func newGameRound() {
        if let message = gameState.localPlayer?.id.rawValue.uppercased() {
            let padding = 3 // Padding around the message inside the box
            let lineLength = message.count + padding * 2
            let borderLine = String(repeating: "*", count: lineLength)
            let formattedMessage = "** \(message) **"
            
            print(borderLine)
            print(formattedMessage)
            print(borderLine)
        }

        gameState.round += 1
        gameState.trumpSuit = nil
        
        // Move to the next dealer in playOrder
        guard let dealer = gameState.dealer,
              let currentIndex = gameState.playOrder.firstIndex(of: dealer) else {
            fatalError("Error: Dealer is not set or not found in play order.")
        }
        let nextIndex = (currentIndex + 1) % gameState.playOrder.count
        // TODO: Add withAnimation?
        gameState.dealer = gameState.playOrder[nextIndex]
        print("Dealer is now \(gameState.dealer!.rawValue).")
        
        // Set the first player to play
        updatePlayerPlayOrder(startingWith: .dealer(gameState.dealer!))

        // Update the players' positions
        if gameState.round > 1 {
            updatePlayersPositions()
        }
    }
    
    func updatePlayerPlayOrder(startingWith condition: StartingCondition) {
        /// Usage:
        /// updatePlayerPlayOrder(startingWith: .winner(.gg))
        /// updatePlayerPlayOrder(startingWith: .dealer(.dd))
        
        let startingPlayerId: PlayerId?
        
        switch condition {
        case .winner(let winnerId):
            startingPlayerId = winnerId
        case .dealer(let dealerId):
            if let dealerIndex = gameState.playOrder.firstIndex(of: dealerId) {
                let nextIndex = (dealerIndex + 1) % gameState.playOrder.count
                startingPlayerId = gameState.playOrder[nextIndex]
            } else {
                startingPlayerId = nil
            }
        }
        
        guard let startingPlayerId = startingPlayerId,
              let startingIndex = gameState.playOrder.firstIndex(of: startingPlayerId) else {
            fatalError("Error: Starting player not found.")
        }
        
        let reorderedPlayOrder = gameState.playOrder[startingIndex...] + gameState.playOrder[..<startingIndex]
        gameState.playOrder = Array(reorderedPlayOrder)
        print("New players order: \(gameState.playOrder)")
    }
    
    // Enum for distinguishing conditions
    enum StartingCondition {
        case winner(PlayerId)
        case dealer(PlayerId)
    }
    
    // MARK: - Game Utility Functions
    
    func updatePlayersPositions() {
        gameState.players.forEach { player in
            player.place = determinePosition(for: player.username)
        }
    }

    private func determinePosition(for username: String) -> Int {
        /// returns 1 if the player has the highest score, even if there's a tie
        /// returns 2 for the second player
        /// returns 3 for the last player

        // TODO: check that this function works as intended
        guard let player = gameState.players.first(where: { $0.username == username }) else {
            return 1 // Default to 1 if player is not found
        }
        
        let currentRound = gameState.round
        let currentScores = gameState.players.map { $0.scores.last ?? 0 }
        let highestScore = currentScores.max() ?? 0
        let lowestScore = currentScores.min() ?? 0

        // Step 1: Player has the highest score
        if player.scores.last == highestScore {
            return 1
        }

        // Step 2: Player has the lowest score
        if player.scores.last == lowestScore {
            let sortedByScore = gameState.players.sorted {
                ($0.scores.last ?? 0) < ($1.scores.last ?? 0)
            }

            let playersWithLowestScore = sortedByScore.filter {
                $0.scores.last == lowestScore
            }

            if playersWithLowestScore.count > 1 {
                // Break tie based on historical scores
                let otherPlayer = playersWithLowestScore.first { $0.username != player.username }

                for round in stride(from: currentRound - 1, through: 0, by: -1) {
                    let playerScore = player.scores[safe: round] ?? Int.min
                    let otherPlayerScore = otherPlayer?.scores[safe: round] ?? Int.min

                    if playerScore != otherPlayerScore {
                        if playerScore < otherPlayerScore {
                            return 3
                        } else {
                            return 2
                        }
                    }
                }

                // Fallback to dealer-based play order
                if let dealer = gameState.dealer,
                   let dealerIndex = gameState.playOrder.firstIndex(of: dealer),
                   let usernameIndex = gameState.playOrder.firstIndex(of: PlayerId(rawValue: username)!) {
                    // Calculate the index of the player to the left of the dealer
                    let leftOfDealerIndex = (dealerIndex + 1) % gameState.playOrder.count

                    // If the current player is the dealer
                    if usernameIndex == dealerIndex {
                        return 3 // Dealer gets rank 3
                    }

                    // If the other player is the dealer
                    if otherPlayer?.id == gameState.dealer {
                        return 2
                    }

                    // If the current player is the first player to the left of the dealer
                    if usernameIndex == leftOfDealerIndex {
                        return 3 // Real last place
                    } else {
                        return 2
                    }
                }
            } else {
                return 3
            }
        }

        // Step 3: Player is neither the highest nor the lowest
        return 2
    }
    
    func allScoresEqual() -> Bool {
        guard let firstScore = gameState.players.first?.scores.last else {
            return true
        }
        return gameState.players.allSatisfy { $0.scores.last == firstScore }
    }
    
    func updateGameStateWithBet(from playerId: PlayerId, with bet: Int) {
        // Check if bet legal
        if !(bet > -1 && bet <= max(gameState.round - 2, 1)) {
            fatalError("Received a illegal bet from \(playerId) with \(bet).")
        }
        
        // Set the player's bet
        let player = gameState.getPlayer(by: playerId)
        if player.announcedTricks.count < gameState.round {
            player.announcedTricks.append(bet)
            player.madeTricks.append(0)
        } else {
            player.announcedTricks[gameState.round - 1] = bet
        }
        print("Player \(playerId) announced tricks: \(player.announcedTricks)")
        checkAndAdvanceStateIfNeeded()
    }
    
    func updateGameStateWithTrump(from playerId: PlayerId, with card: Card) {
        // move the card on top of the trump deck
        guard let index = gameState.trumpCards.firstIndex(of: card) else {
            print("Card \(card) not found in trumpCards.")
            return
        }

        let removedCard = gameState.trumpCards.remove(at: index)

        // Put the card face up if second player
        if gameState.localPlayer?.place == 2 {
            removedCard.isFaceDown = false
        }
        
        gameState.trumpCards.append(removedCard)
        
        // Set the trump suit
        gameState.trumpSuit = card.suit
        
        checkAndAdvanceStateIfNeeded()
    }
    
    func updateGameStateWithDiscardedCards(from playerId: PlayerId, with cards: [Card], completion: @escaping () -> Void) {
        // Validate the player
        let player = gameState.getPlayer(by: playerId)
        
        beginBatchMove(totalCards: cards.count) { completion() }

        // Ensure the cards are part of the player's hand
        for card in cards {
            guard player.hand.firstIndex(of: card) != nil else {
                print("Error: Card \(card) is not in \(playerId)'s hand.")
                return
            }
            switch player.tablePosition {
                case .left:
                moveCard(card, from: .leftPlayer, to: .deck)
            case .right:
                moveCard(card, from: .rightPlayer, to: .deck)
            default:
                break
            }
        }
        checkAndAdvanceStateIfNeeded()
    }
    
    func updatePlayerWithState(from playerId: PlayerId, with state: PlayerState) {
        let player = gameState.getPlayer(by: playerId)
        player.state = state
        print("\(playerId) updated their state to \(state).")
    }
    
    // MARK: Choose bet
    func choseBet(bet: Int) {
        // Ensure the local player is defined
        guard let localPlayer = gameState.localPlayer else {
            fatalError("Error: Local player is not defined.")
        }
        
        if gameState.round < 4 {
            showOptions = false
            print("the optionsView should disappear now.")
        }
        
        if localPlayer.announcedTricks.count == gameState.round {
            // player updates his current bet
            localPlayer.announcedTricks[localPlayer.announcedTricks.count-1] = bet
        } else {
            // first bet for this round
            localPlayer.announcedTricks.append(bet)
            localPlayer.madeTricks.append(0)
        }
        
        // Notify other players about the action
        sendBetToPlayers(bet)
        checkAndAdvanceStateIfNeeded()
    }

}
