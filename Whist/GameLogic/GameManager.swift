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
    @Published var showOptions: Bool = false
    @Published var showTrumps: Bool = false
    @Published var showLastTrick: Bool = false
    @Published var movingCards: [MovingCard] = []
    private var timerCancellable: AnyCancellable?
    var randomSeed: UInt64 = 0
    var isDeckReady: Bool = false
    var isDeckReceived: Bool = false
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
    var persistence: GamePersistence = GamePersistence(playerID: .dd) // default value
    
    var cancellables = Set<AnyCancellable>()
    var isGameSetup: Bool = false
    @Published var autoPilot: Bool = false {
        didSet {
            logger.log("Autopilot is now \(autoPilot ? "on": "off")!")
        }
    }
    
    var lastGameWinner: PlayerId?
    var showConfetti: Bool = false
    @Published var showWindSwirl: Bool = false
    @Published var showFailureEffect: Bool = false
    @Published var cameraShakeOffset: CGSize = .zero
    @Published var showImpactEffect: Bool = false
    @Published var showSubtleFailureEffect: Bool = false
    @Published var effectPosition: CGPoint = .zero // Add this line

    @Published var dealerPosition: CGPoint = .zero
    @Published var playersScoresUpdated: Bool = false
    
    var logCounter: Int = 0

    init() {
//        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
//            do {
//                try GameManager.SM.ensureiCloudFolderExists()
//                logger.log("✅ iCloud Drive folder ensured on initialization.")
//            } catch {
//                logger.log("❌ Error ensuring iCloud Drive folder: \(error)")
//            }
//        }
    }
    
    // MARK: - Game State Initialization
    
    func updatePlayer(_ playerId: PlayerId, isLocal: Bool = false, name: String, image: NSImage?) {
        logger.log("updatePlayer: processing \(playerId)")
        let players = gameState.players
        guard let index = players.firstIndex(where: { $0.id == playerId }) else {
            logger.log("Player with id \(playerId.rawValue) not found.")
            return
        }
        players[index].username = name
        
        if let unwrappedImage = image {
            players[index].image = Image(nsImage: unwrappedImage)
        } else {
            players[index].image = Image(systemName: "person.crop.circle.fill")
        }
        if isLocal {
            players[index].tablePosition = .local
        }
        players[index].isConnected = true // Set for GK
        logger.log("Player \(playerId.rawValue) updated successfully with name: \(name)")
        logger.log("Players connected: \(players.filter { $0.isConnected }.map(\.username).joined(separator: ", "))")
        displayPlayers()
    }

    func setupGame() {
        logger.log("--> SetupGame()")
        let totalPlayers = gameState.players.count
        let connectedPlayers = gameState.players.filter { $0.isConnected }.count
        logger.log("Total players created: \(totalPlayers), Players connected: \(connectedPlayers)")
        
        // Check if the game is already set up
        guard !isGameSetup else {
            logger.log("Game is already set up.")
            return
        }
        
        // Update the game state
        var generator = SeededGenerator(seed: randomSeed)
        gameState.playOrder = [.gg, .dd, .toto]
        gameState.playOrder.shuffle(using: &generator)
        gameState.dealer = gameState.playOrder.first
        logger.log("Dealer is \(String(describing: gameState.dealer))")
        
        // Set the previous loser's monthlyLosses
        GameManager.SM.findLoser { loser in
            DispatchQueue.main.async {
                if let loser = loser {
                    let loserPlayer = self.gameState.getPlayer(by: loser.playerId)
                    loserPlayer.monthlyLosses = loser.losingMonths
                    logger.log("Updated \(loser.playerId)'s monthlyLosses to \(loser.losingMonths)")
                } else {
                    logger.log("No loser identified")
                }
            }
        }
        // Identify localPlayer, leftPlayer, and rightPlayer
        if let localPlayerID = connectionManager?.localPlayerID {
            gameState.updatePlayerReferences(for: localPlayerID)
        } else {
            logger.fatalErrorAndLog("Error: Unable to determine main player or neighbors.")
        }
        
        if let localPlayer = gameState.localPlayer, let leftPlayer = gameState.leftPlayer, let rightPlayer = gameState.rightPlayer {
            logger.log("Main Player: \(localPlayer.username), Left Player: \(leftPlayer.username), Right Player: \(rightPlayer.username)")
        } else {
            logger.fatalErrorAndLog("Players could not be assigned correctly.")
        }

        isGameSetup = true

        // Create the cards
        initializeCards()
}
    
    func setPersistencePlayerID(with playerId: PlayerId) {
        persistence = GamePersistence(playerID: playerId)
//        if playerId != .toto {
//            isAIPlaying = true
//        }
    }
    
    func generateAndSendSeed() { // Only if local player is toto
        randomSeed = UInt64.random(in: 1...UInt64.max)
        logger.log("Sending seed to other players!")
        sendSeedToPlayers(randomSeed)
        checkAndAdvanceStateIfNeeded()
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
    
    // MARK: Connection/Deconnection

    func updatePlayerConnectionStatus(playerID: PlayerId, isConnected: Bool) {
        // Find the player by ID
        guard let index = gameState.players.firstIndex(where: { $0.id == playerID }) else {
            logger.log("Could not find player with ID \(playerID.rawValue) to update connection status")
            return
        }
        
        // Update connection status
        gameState.players[index].isConnected = isConnected
        logger.log("Updated player \(playerID.rawValue) connection status to \(isConnected)")
        
        checkAndAdvanceStateIfNeeded() // Might pause the game while the player reconnects
        
        // Display current players for debugging
        displayPlayers()
    }

    // MARK: resumeGameState
    
    func resumeGameState() {
        guard let savedState = persistence.loadGameState() else {
            newGame()
            return
        }
        gameState = savedState

        // Identify localPlayer, leftPlayer, and rightPlayer
        if let localPlayerID = connectionManager?.localPlayerID {
            gameState.updatePlayerReferences(for: localPlayerID)
        } else {
            logger.fatalErrorAndLog("Error: Unable to determine main player or neighbors.")
        }
        
        for player in gameState.players {
            let isLocalPlayer = (player.tablePosition == .local)

            if isLocalPlayer {
                let shouldRevealCards = gameState.round >= 4 || gameState.currentPhase.isPlayingPhase
                player.hand.indices.forEach { player.hand[$0].isFaceDown = !shouldRevealCards }
            } else {  // left and right players
                let shouldHideCards = gameState.round >= 4
                player.hand.indices.forEach { player.hand[$0].isFaceDown = shouldHideCards }
            }
        }
        
        // Show the trump card
        logger.log("Trump suit: \(String(describing: gameState.trumpSuit ?? nil))")
        if gameState.trumpSuit != nil {
            logger.log("Local player's place: \(gameState.localPlayer?.place ?? -1)")
            logger.log("All scores equal: \(allScoresEqual())")
            if gameState.localPlayer?.place != 1 || gameState.currentPhase.isPlayingPhase || allScoresEqual() { // I can see the trump card
                if gameState.round < 4 || allScoresEqual() {
                    gameState.deck.last?.isFaceDown = false
                } else {
                    gameState.trumpCards.last?.isFaceDown = false
                }
            }
        }
        
        // show the cards on the table
        if gameState.currentPhase.isPlayingPhase {
            gameState.table.indices.forEach { gameState.table[$0].isFaceDown = false }
        }
        
        // Set the players' places
        updatePlayersPositions()
        
        isDeckReady = true
        
        logger.log("Current phase: \(gameState.currentPhase)")
        checkAndAdvanceStateIfNeeded()
        
    }
    
    // MARK: startNewGame
    func startNewGameAction() {
        sendStartNewGameAction()
        startNewGame()
    }
    
    // MARK: - Game Logic Functions
    
    func newGame() {
        gameState.round = 0
        gameState.players.forEach {
            $0.scores.removeAll()
            $0.announcedTricks.removeAll()
            $0.madeTricks.removeAll()
            $0.place = 0
            $0.hand.removeAll()
            $0.trickCards.removeAll()
            $0.state = .idle
        }

        // Move to the next dealer in playOrder so that another player starts the game
        guard let dealer = gameState.dealer,
              let currentIndex = gameState.playOrder.firstIndex(of: dealer) else {
            logger.fatalErrorAndLog("Error: Dealer is not set or not found in play order.")
        }
        let nextIndex = (currentIndex + 1) % gameState.playOrder.count
        gameState.dealer = gameState.playOrder[nextIndex]
        logger.log("Dealer is now \(gameState.dealer!.rawValue).")
    }
    
    func newGameRound() {
        if let message = gameState.localPlayer?.id.rawValue.uppercased() {
            let message2 = message + " / round \(gameState.round + 1)"
            let padding = 3 // Padding around the message inside the box
            let lineLength = message2.count + padding * 2
            let borderLine = String(repeating: "*", count: lineLength)
            let formattedMessage = "** \(message2) **"
            
            logger.log(borderLine)
            logger.log(formattedMessage)
            logger.log(borderLine)
        }

        gameState.round += 1
        gameState.trumpSuit = nil
        gameState.tricksGrabbed = Array(repeating: false, count: max(gameState.round - 2, 1))
        gameState.currentTrick = 0
        gameState.lastTrick.removeAll()
        gameState.lastTrickCardStates.removeAll()
        gameState.players.forEach {
            $0.hasDiscarded = false
        }
        autoPilot = false // Resets the autoPilot

        // Move to the next dealer in playOrder
        guard let dealer = gameState.dealer,
              let currentIndex = gameState.playOrder.firstIndex(of: dealer) else {
            logger.fatalErrorAndLog("Error: Dealer is not set or not found in play order.")
        }
        let nextIndex = (currentIndex + 1) % gameState.playOrder.count
        gameState.dealer = gameState.playOrder[nextIndex]
        logger.log("Dealer is now \(gameState.dealer!.rawValue).")
        
        // Set the first player to play
        updatePlayerPlayOrder(startingWith: .dealer(gameState.dealer!))

        // Update the players' positions
        if gameState.round > 1 {
            updatePlayersPositions()
        }
    }
    
    func updateDealerFrame(playerId: PlayerId, frame: CGRect) {
        dealerPosition = CGPoint(x: frame.midX, y: frame.midY)
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
            logger.fatalErrorAndLog("Error: Starting player not found.")
        }
        
        let reorderedPlayOrder = gameState.playOrder[startingIndex...] + gameState.playOrder[..<startingIndex]
        gameState.playOrder = Array(reorderedPlayOrder)
        logger.log("New players order: \(gameState.playOrder)")
    }
    
    // Enum for distinguishing conditions
    enum StartingCondition {
        case winner(PlayerId)
        case dealer(PlayerId)
    }
    
    // MARK: - Game Utility Functions

    func updatePlayersPositions() {
        gameState.players.forEach { player in
            player.place = determinePosition(for: player.id)
        }
    }

    private func determinePosition(for playerId: PlayerId) -> Int {
        /// returns 1 if the player has the highest score, even if there's a tie
        /// returns 2 for the second player
        /// returns 3 for the last player

        // TODO: check that this function works as intended
        let player = gameState.getPlayer(by: playerId)
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
                   let usernameIndex = gameState.playOrder.firstIndex(of: playerId) {
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
            logger.fatalErrorAndLog("Received a illegal bet from \(playerId) with \(bet).")
        }
        
        // Set the player's bet
        let player = gameState.getPlayer(by: playerId)
        if player.announcedTricks.count < gameState.round {
            player.announcedTricks.append(bet)
            player.madeTricks.append(0)
        } else {
            player.announcedTricks[gameState.round - 1] = bet
        }
        persistence.saveGameState(gameState)
        logger.log("Player \(playerId) announced tricks: \(player.announcedTricks)")
//        checkAndAdvanceStateIfNeeded()
    }
    
    func updateGameStateWithTrump(from playerId: PlayerId, with card: Card) {
        // move the card on top of the trump deck
        guard let index = gameState.trumpCards.firstIndex(of: card) else {
            logger.log("Card \(card) not found in trumpCards.")
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
        
        self.objectWillChange.send() // To force a refresh for the 2nd player
        
        persistence.saveGameState(gameState)
        
//        checkAndAdvanceStateIfNeeded()
    }
    
    func updateGameStateWithTrumpCancellation() {
        // Reset trump-related state to cancel the trump choice
        gameState.trumpSuit = nil
        gameState.trumpCards.last?.isFaceDown = true
        
        logger.log("Trump choice cancelled by second player.")
        
        transition(to: .choosingTrump)
    }
    
    func updateGameStateWithDiscardedCards(from playerId: PlayerId, with cards: [Card], completion: @escaping () -> Void) {
        // Validate the player
        let player = gameState.getPlayer(by: playerId)
 
        // Ensure the cards are part of the player's hand
        for card in cards {
            guard player.hand.firstIndex(of: card) != nil else {
                logger.log("Error: Card \(card) is not in \(playerId)'s hand.")
                return
            }
            
            player.hasDiscarded = true
            
            let origin: CardPlace = player.tablePosition == .left ? .leftPlayer: .rightPlayer
            var destination: CardPlace = .deck
            var message: String = "Player \(player) discarded \(card)"

            if player.place == 2 && gameState.round == 12 {
                if Double(gameState.lastPlayer?.scores[safe: gameState.round - 2] ?? 0) <= 0.5 * Double(player.scores[safe: gameState.round - 2] ?? 0) || gameState.lastPlayer?.monthlyLosses ?? 0 > 0 {
                    switch gameState.lastPlayer?.tablePosition {
                    case .left:
                        destination = .leftPlayer
                        
                    case .right:
                        destination = .rightPlayer
                        
                    case .local:
                        cards.forEach { $0.isFaceDown = false } // show the card if I'm the last player
                        destination = .localPlayer
                        
                    default:
                        destination = .table // Should crash but shouldn't happen
                    }
                    message = "Player \(playerId) gave \(card) to the last, \(destination) player"
                }
            }
            logger.log(message)
            beginBatchMove(totalCards: 1) {
                if destination == .localPlayer {
                    self.sortLocalPlayerHand()
                }
                completion() }
            moveCard(card, from: origin, to: destination)
        }
        persistence.saveGameState(gameState)
    }
    
    func updatePlayerWithState(from playerId: PlayerId, with state: PlayerState) {
        let player = gameState.getPlayer(by: playerId)
        player.state = state
        persistence.saveGameState(gameState)
//        logger.log("\(playerId) updated their state to \(state).")
    }
    
    // MARK: Choose bet
    func choseBet(bet: Int) {
        // Ensure the local player is defined
        guard let localPlayer = gameState.localPlayer else {
            logger.fatalErrorAndLog("Error: Local player is not defined.")
        }
        
        if gameState.round < 4 {
            showOptions = false
            logger.log("the optionsView should disappear now.")
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
        persistence.saveGameState(gameState)
//        checkAndAdvanceStateIfNeeded()
    }
    
    // MARK: Cancel Trump Choice
    
    func cancelTrumpChoice() {
        // Reset trump-related state to cancel the trump choice
        gameState.trumpSuit = nil
        gameState.trumpCards.last?.isFaceDown = true
        
        logger.log("Trump choice cancelled by local player.")
        
        // Notify other players about the cancellation
        sendCancelTrumpChoice()
        
        // Advance the game state as needed
        checkAndAdvanceStateIfNeeded()
    }
    
    // MARK: Save scores
    func saveScore() {
        // Update the game's winner
        lastGameWinner = gameState.players.first { $0.place == 1 }?.id
        
        // Save the score only once
        if gameState.localPlayer?.id == .toto {
            // Retrieve players by their ID using the gameState helper.
            let ggPlayer = gameState.getPlayer(by: .gg)
            let ddPlayer = gameState.getPlayer(by: .dd)
            let totoPlayer = gameState.getPlayer(by: .toto)
            
            // Get the latest score for each player (defaulting to 0 if not available).
            let ggScore = ggPlayer.scores.last ?? 0
            let ddScore = ddPlayer.scores.last ?? 0
            let totoScore = totoPlayer.scores.last ?? 0

            // Create a new GameScore instance with current date, scores, and positions.
            let newScore = GameScore(
                date: Date(),
                ggScore: ggScore,
                ddScore: ddScore,
                totoScore: totoScore,
                ggPosition: ggPlayer.place,
                ddPosition: ddPlayer.place,
                totoPosition: totoPlayer.place,
                ggConsecutiveWins: consecutiveWins(by: .gg),
                ddConsecutiveWins: consecutiveWins(by: .dd),
                totoConsecutiveWins: consecutiveWins(by: .toto)
            )
            
            // Save the updated scores array.
            ScoresManager.shared.saveScore(newScore) { result in
                switch result {
                case .success(let savedRecord):
                    // The GameScore was successfully saved to CloudKit.
                    logger.log("Score saved successfully with recordID: \(savedRecord.recordID)")
                case .failure(let error):
                    // Handle the error (e.g., display an alert to the user).
                    logger.log("Failed to save score: \(error.localizedDescription)")
                    logger.log("Scores to save: \(newScore)")
                }
            }
        }
    }
    
    func consecutiveWins(by playerId: PlayerId) -> Int {
        let player = gameState.getPlayer(by: playerId)
        var count = 0

        for round in 0..<player.announcedTricks.count {
            if player.announcedTricks[round] == player.madeTricks[round] {
                count += 1
            } else {
                break // Stop counting if a round was lost
            }
        }
        
        return count
    }
    
    func displayPlayers() {
        logger.log("🔍 Displaying all players:")

        for player in gameState.players {
            let username = player.username
            let playerId = player.id.rawValue
            let tablePosition = player.tablePosition?.rawValue ?? "unknown"
            let isConnected = player.isConnected

            logger.log("🔹 Player: \(username), PlayerId: \(playerId), TablePosition: \(tablePosition), Connected: \(isConnected)")
        }
    }
}
