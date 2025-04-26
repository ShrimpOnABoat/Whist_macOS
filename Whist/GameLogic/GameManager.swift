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
import CloudKit
import WebRTC
import FirebaseFirestore

enum PlayerId: String, Codable, CaseIterable {
    case dd = "dd"
    case gg = "gg"
    case toto = "toto"
}

@MainActor
class GameManager: ObservableObject {
    @Published var gameState: GameState = GameState()
    @Published var showOptions: Bool = false
    @Published var showTrumps: Bool = false
    @Published var showLastTrick: Bool = false
    @Published var movingCards: [MovingCard] = []
    @Published var hoveredSuit: Suit? = nil
    private var timerCancellable: AnyCancellable?
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
    // MARK: - WebRTC Signaling Dependencies
    let connectionManager: P2PConnectionManager
    private let signalingManager: FirebaseSignalingManager
    private var networkingStarted: Bool = false
    private let preferences: Preferences
    let soundManager = SoundManager()
    static let SM = ScoresManager.shared
    var persistence: GamePersistence = GamePersistence() // No longer needs playerID
    
    var cancellables = Set<AnyCancellable>()
    var isGameSetup: Bool = false
    @Published var autoPilot: Bool = false
    
    var lastGameWinner: PlayerId?
    var showConfetti: Bool = false
    @Published var showWindSwirl: Bool = false
    @Published var showFailureEffect: Bool = false
    @Published var cameraShakeOffset: CGSize = .zero
    @Published var showImpactEffect: Bool = false
    @Published var showSubtleFailureEffect: Bool = false
    @Published var effectPosition: CGPoint = .zero
    
    @Published var dealerPosition: CGPoint = .zero
    @Published var playersScoresUpdated: Bool = false
    
    var logCounter: Int = 0

    // MARK: - Slowpoke Timer Properties
    var slowpokeTimer: DispatchSourceTimer?
    #if DEBUG
    let slowpokeDelay: TimeInterval = 5 // Delay in seconds before sending slowpoke
    #else
    let slowpokeDelay: TimeInterval = 60 // Delay in seconds before sending slowpoke
    #endif
    var amSlowPoke: Bool = false
    @Published var isSlowPoke: [PlayerId: Bool] = [:]
    @Published var amHonked: Bool = false
    
    /// Dependency‐injecting initializer
    init(connectionManager: P2PConnectionManager,
         signalingManager: FirebaseSignalingManager,
         preferences: Preferences) {
        self.connectionManager = connectionManager
        self.signalingManager = signalingManager
        self.preferences = preferences
    }
    
    // MARK: - Game State Initialization
    
    func updateLocalPlayer(_ playerId: PlayerId, name: String, image: Image) {
        guard let playerIndex = gameState.players.firstIndex(where: { $0.id == playerId }) else {
            logger.log("Error: Player with ID \(playerId) not found in gameState during update.")
            return
        }
        
        let player = gameState.players[playerIndex]
        player.username = name
        player.image = image
        player.isConnected = true
        player.tablePosition = .local // Assume local initially, updatePlayerReferences will adjust
        
        logger.log("Player \(playerId) updated successfully with name: \(name)")
        
        // Log connected players
        let connectedUsernames = gameState.players.filter { $0.isConnected }.map { $0.username }
        logger.log("Players connected: \(connectedUsernames.joined(separator: ", "))")
        displayPlayers() // Log detailed player status
        
        if !gameState.playOrder.isEmpty {
            gameState.updatePlayerReferences()
        }
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
        gameState.dealer = gameState.playOrder.first
        logger.log("Dealer is \(String(describing: gameState.dealer))")

        // Set the previous loser's monthlyLosses
        Task {
            if let loser = await GameManager.SM.findLoser() {
                // Since GameManager is @MainActor, DispatchQueue.main.async might be redundant,
                // but it's safe to keep for explicit main thread updates.
                DispatchQueue.main.async {
                    let loserPlayer = self.gameState.getPlayer(by: loser.playerId)
                    loserPlayer.monthlyLosses = loser.losingMonths
                    logger.log("Updated \(loser.playerId)'s monthlyLosses to \(loser.losingMonths)")
                }
            } else {
                 // Ensure logging happens on the main thread if needed for UI consistency
                 DispatchQueue.main.async {
                    logger.log("No loser identified or loser had 0 losing months.")
                 }
            }
        }
        // Identify localPlayer, leftPlayer, and rightPlayer
        gameState.updatePlayerReferences()
        
        if let localPlayer = gameState.localPlayer, let leftPlayer = gameState.leftPlayer, let rightPlayer = gameState.rightPlayer {
            logger.log("Main Player: \(localPlayer.username), Left Player: \(leftPlayer.username), Right Player: \(rightPlayer.username)")
        } else {
            logger.fatalErrorAndLog("Players could not be assigned correctly.")
        }
        
        isGameSetup = true
        
        // Create the cards
        initializeCards()
        
        // Refresh the UI if necessary
        objectWillChange.send()
    }
    
    func setPersistencePlayerID(with playerId: PlayerId) {
        logger.log("SetPersistencePlayerID called, but GamePersistence now uses shared CloudKit state. PlayerID \(playerId) noted if needed for logic elsewhere.")
    }
    
    func setAndSendPlayOrder() { // Only if local player is toto
        gameState.playOrder = [.gg, .dd, .toto].shuffled()
        logger.log("Sending playOrder to other players!")
        sendPlayOrderToPlayers(gameState.playOrder)
        checkAndAdvanceStateIfNeeded()
    }
    
    // MARK: Connection/Deconnection
    
    func updatePlayerConnectionStatus(playerId: PlayerId, isConnected: Bool) {
        // Find the player by ID
        guard let index = gameState.players.firstIndex(where: { $0.id == playerId }) else {
            logger.log("Could not find player \(playerId) to update connection status")
            return
        }
        
        // Update connection status
        if gameState.players[index].isConnected != isConnected {
            self.objectWillChange.send()
            gameState.players[index].isConnected = isConnected
            logger.log("Updated \(playerId) connection status to \(isConnected)")

            // Display current players for debugging
            displayPlayers()
            
            checkAndAdvanceStateIfNeeded() // Might pause the game while the player reconnects
            
        } else {
            logger.log("Player \(playerId) connection status did not change: \(isConnected)")
        }
    }
    
    // MARK: resumeGameState
    
    func saveGameState(_ state: GameState) {
        if ![.waitingForPlayers, .setPlayOrder, .setupGame, .waitingToStart].contains(gameState.currentPhase) && gameState.localPlayer?.id == .toto {
            Task {
                await persistence.saveGameState(state)
            }
        }
    }
    
    func loadGameState(completion: @escaping (GameState?) -> Void) {
        Task {
            let state = await persistence.loadGameState()
            completion(state)
        }
    }
    
    func clearSavedGameState() {
        Task {
            await persistence.clearSavedGameState()
        }
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
        amSlowPoke = false
        isSlowPoke = [:]
        autoPilot = false // Resets the autoPilot
        
#if DEBUG
        if gameState.localPlayer?.id != .toto {
            autoPilot = true
        }
#endif
        
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
        Task {
            saveGameState(gameState)
        }
        logger.log("Player \(playerId) announced tricks: \(player.announcedTricks)")

        // if all players have bet and I'm placed 1, show the trump card if there's no 3-tie OR if local player score >= 2 * second player score
        let shouldRevealTrump = (
            allPlayersBet() &&
            gameState.round > 3 &&
            gameState.playerPlaced(1)?.scores.last != gameState.playerPlaced(3)?.scores.last
        ) || ({ // Use a closure to safely unwrap and compare scores
            guard let localScore = gameState.localPlayer?.scores.last, // Safely get local player's last score
                  let secondPlacePlayer = gameState.playerPlaced(2),   // Safely get player in 2nd place
                  let secondScore = secondPlacePlayer.scores.last else { // Safely get 2nd place player's last score
                return false // If any value is nil, this condition is false
            }
            // Now perform the comparison with unwrapped values
            return localScore >= 2 * secondScore
        })() // Immediately execute the closure

        if shouldRevealTrump {
            gameState.trumpCards.last?.isFaceDown = false
        }

        self.objectWillChange.send() // To force a refresh for the last player
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
        
        Task {
            saveGameState(gameState)
        }
        //        checkAndAdvanceStateIfNeeded()
    }
    
    func updateGameStateWithTrumpCancellation() {
        // Reset trump-related state to cancel the trump choice
        gameState.trumpSuit = nil
        gameState.trumpCards.last?.isFaceDown = true
        showOptions = false
        
        logger.log("Trump choice cancelled by second player.")
        
        transition(to: .choosingTrump)
        Task {
            saveGameState(gameState) // Save the cancelled state
        }
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
        Task {
            saveGameState(gameState)
        }
    }
    
    func updatePlayerWithState(from playerId: PlayerId, with state: PlayerState) {
        let player = gameState.getPlayer(by: playerId)
        player.state = state
        Task {
            saveGameState(gameState)
        }
        isSlowPoke[playerId] = false
        logger.log("\(playerId) updated their state to \(state).")
    }
    
    func showSlowPokeButton(for playerId: PlayerId) {
        isSlowPoke[playerId] = true
    }
    
    func honk() {
        if amSlowPoke {
            amHonked = true
        }
        playSound(named: "pouet")
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
        Task {
            saveGameState(gameState)
        }
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
            Task {
                do {
                    try await ScoresManager.shared.saveScore(newScore)
                    // Log success on the main thread if necessary, though logger should handle it
                    await MainActor.run { // Ensure logging happens on main thread if it interacts with UI state implicitly
                         logger.log("Score saved successfully for game ending \(newScore.date)")
                    }
                } catch {
                     // Handle the error (e.g., display an alert to the user).
                    await MainActor.run {
                         logger.log("Failed to save score: \(error.localizedDescription)")
                         logger.log("Score data that failed to save: \(newScore)")
                    }
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
            
            logger.log("\(isConnected ? "✅": "❌") Player: \(username), PlayerId: \(playerId), TablePosition: \(tablePosition), Connected: \(isConnected)")
        }
    }
    
    // MARK: - Restore Saved Game
    func checkAndRestoreSavedGame() async -> Bool {
        logger.log("Match connected. Checking database for saved game...")
        if let savedState = await persistence.loadGameState() {
            logger.log("Saved game found in db:\n\(savedState)")
            let localPlayerId = self.gameState.localPlayer?.id
//            logger.log("I am player \(localPlayerId?.rawValue ?? "unknown")")
            let playerImages = Dictionary(uniqueKeysWithValues: self.gameState.players.map { ($0.id, $0.image) })
            self.gameState = savedState
            for index in self.gameState.players.indices {
                let playerId = self.gameState.players[index].id
                if let savedImage = playerImages[playerId] {
                    self.gameState.players[index].image = savedImage
                }
            }
            if let localId = localPlayerId,
               let index = self.gameState.players.firstIndex(where: { $0.id == localId }) {
                self.gameState.players[index].tablePosition = .local
            }
            self.configureGameFromLoadedState()
            self.checkAndAdvanceStateIfNeeded()
            self.objectWillChange.send()
//            self.printAllCardsDebugInfo()
            return true
        } else {
            logger.log("No saved game found or error loading. Starting new game...")
            return false
        }
    }

    // MARK: - Game Flow Initialization Helpers

    private func configureGameFromLoadedState() {
        logger.log("Configuring game UI and state from loaded data...")

        // Ensure player references and UI elements reflect the loaded state
        self.gameState.updatePlayerReferences() // Essential
        sortLocalPlayerHand()
        
        // restore states when in these phases:.choosingTrump, .waitingForTrump, .bidding, .discard
        if [.choosingTrump, .waitingForTrump, .bidding, .discard].contains(gameState.currentPhase) {
            // restore gameState.currentPhase
            switch gameState.localPlayer?.state {
            case .choosingTrump:
                gameState.currentPhase = .choosingTrump
                
            case .waiting:
                if gameState.trumpSuit != nil {
                    gameState.currentPhase = .bidding
                } else {
                    gameState.currentPhase = .waitingForTrump
                }
                
            case .bidding:
                gameState.currentPhase = .bidding
                
            case .discarding:
                gameState.currentPhase = .discard
                
            default:
                break
            }
//            logger.log("My current phase is \(gameState.currentPhase)")
            
            // Move trump cards back in their deck
            gameState.table = []
            gameState.trumpCards = [Card(suit: .clubs, rank: .two), Card(suit: .spades, rank: .two), Card(suit: .diamonds, rank: .two), Card(suit: .hearts, rank: .two)]
            for trumpCard in gameState.trumpCards {
                trumpCard.isFaceDown = true
            }
//            logger.log("Cards on table: \(gameState.table)")
//            logger.log("Cards in trump deck: \(gameState.trumpCards)")
            
            // put back trump cards on table for the choosing player
            if gameState.currentPhase == .choosingTrump {
                chooseTrump() {
                    self.hoveredSuit = nil
                }
            }
        }
        
        // Update card visibility based on loaded state
        for player in self.gameState.players {
            if player.tablePosition == .local {
                let shouldRevealCards = self.gameState.round > 3 || self.gameState.currentPhase.isPlayingPhase
                player.hand.indices.forEach { player.hand[$0].isFaceDown = !shouldRevealCards }
            } else {
                 let shouldHideCards = self.gameState.round > 3
                 player.hand.indices.forEach { player.hand[$0].isFaceDown = shouldHideCards }
            }
        }

        // Update trump card visibility (Simplified logic, adjust if needed)
        if self.gameState.trumpSuit != nil {
            let trumpCardShouldBeVisible = gameState.currentPhase.isPlayingPhase || gameState.round < 4 || allScoresEqual()
            if self.gameState.round < 4 || allScoresEqual() {
                 self.gameState.deck.last?.isFaceDown = !trumpCardShouldBeVisible
            } else if let trumpCard = self.gameState.trumpCards.last {
                 trumpCard.isFaceDown = !trumpCardShouldBeVisible
            }
        }

        // Update table card visibility
        if self.gameState.currentPhase.isPlayingPhase {
            self.gameState.table.indices.forEach { self.gameState.table[$0].isFaceDown = false }
        }

        self.updatePlayersPositions() // Ensure places are correct
        self.isDeckReady = true // Assume deck is ready based on loaded state

        logger.log("Game configured from loaded state. Current phase: \(self.gameState.currentPhase). Advancing state machine...")
    }
    
    // MARK: - Signaling Setup
    func startNetworkingIfNeeded() {
        guard !preferences.playerId.isEmpty else {
            print("🚫 Cannot start networking: playerId is empty.")
            return
        }
        
        guard !networkingStarted else {
            return
        }

        Task {
            networkingStarted = true
            await clearSignalingDataIfNeeded()
            setupConnectionManagerCallbacks(localPlayerId: PlayerId(rawValue: preferences.playerId)!)
            signalingManager.setupFirebaseListeners(localPlayerId: PlayerId(rawValue: preferences.playerId)!)
            setupSignaling()
        }
    }
    
    private func clearSignalingDataIfNeeded() async {
        let playerIds = ["dd", "gg", "toto"]

        for playerId in playerIds {
            await withCheckedContinuation { continuation in
                PresenceManager.shared.checkPresence(of: playerId) { isOnline in
                    if let isOnline = isOnline, (!isOnline || playerId == self.gameState.localPlayer?.id.rawValue) {
//                        logger.log("Player \(playerId) is offline or myself. Clearing their signaling data.")
                        Task {
                            do {
                                try await self.signalingManager.clearSignalingData(for: playerId)
                            } catch {
                                logger.log("Error clearing signaling data for \(playerId): \(error.localizedDescription)")
                            }
                            continuation.resume()
                        }
                    } else {
//                        logger.log("Player \(playerId) is \(isOnline == true ? "online" : "unknown"). Skipping cleanup.")
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    private func setupSignaling() {
        guard !preferences.playerId.isEmpty else {
            logger.log("setupSignaling: Cannot setup, playerId is empty.")
            return
        }

        let localPlayerId = PlayerId(rawValue: preferences.playerId)!
        let otherPlayerIds = PlayerId.allCases.filter { $0 != localPlayerId }

        logger.debug("Setting up signaling for \(localPlayerId).")

        Task {
            for peerId in otherPlayerIds {
                let isPeerOnline: Bool = await withCheckedContinuation { continuation in
                    PresenceManager.shared.checkPresence(of: peerId.rawValue) { result in
                        continuation.resume(returning: result ?? false)
                    }
                }

                let docRef = Firestore.firestore().collection("signaling").document("\(peerId.rawValue)_to_\(localPlayerId.rawValue)")
                let docSnapshot = try? await docRef.getDocument()
                let offerText = docSnapshot?.data()?["offer"] as? String

                if isPeerOnline, let offerText = offerText {

                    logger.debug("Found offer from \(peerId). Processing...")

                    let remoteSdp = RTCSessionDescription(type: .offer, sdp: offerText)
                    let connection = connectionManager.makePeerConnection(for: peerId)

                    do {
                        try await connection.setRemoteDescription(remoteSdp)
                    } catch {
                        logger.log("Error setting remote offer for \(peerId): \(error)")
                        return
                    }
                    self.connectionManager.createAnswer(to: peerId, from: remoteSdp) { _, result in
                        switch result {
                        case .success(let answerSdp):
                            Task {
                                do {
                                    try await self.signalingManager.sendAnswer(from: localPlayerId, to: peerId, sdp: answerSdp)
                                    logger.debug("Successfully sent answer to \(peerId)")
                                    // Send ICE candidates after answer
                                    self.connectionManager.flushPendingIce(for: peerId)
                                } catch {
                                    logger.debug("Error sending answer to \(peerId): \(error)")
                                }
                            }
                        case .failure(let err):
                            logger.log("Failed to create answer for \(peerId): \(err)")
                        }
                    }
                } else {
                    logger.debug("\(peerId) is offline or has no offer. Creating an offer...")

                    connectionManager.createOffer(to: peerId) { _, result in
                        switch result {
                        case .success(let sdp):
                            Task {
                                do {
                                    try await self.signalingManager.sendOffer(from: localPlayerId, to: peerId, sdp: sdp)
                                    logger.debug("Sent offer to \(peerId)")
                                    // Send ICE candidates after offer
                                    self.connectionManager.flushPendingIce(for: peerId)
                                } catch {
                                    logger.debug("Error sending offer to \(peerId): \(error)")
                                }
                            }
                        case .failure(let error):
                            logger.log("Failed to create offer for \(peerId): \(error)")
                        }
                    }
                }
            }
        }
    }
    
    func decodeAndProcessAction(from peerId: PlayerId, message: String) {
         logger.log("Decoding and processing action from \(peerId)...")
         guard let actionData = message.data(using: .utf8) else {
             logger.log("Failed to convert message string to Data from \(peerId)")
             return
         }

         do {
             let gameAction = try JSONDecoder().decode(GameAction.self, from: actionData)
             logger.log("Successfully decoded action: \(gameAction.type)")
             // Use handleReceivedAction to process or queue the action
             handleReceivedAction(gameAction)
         } catch {
             logger.log("Failed to decode GameAction from \(peerId): \(error.localizedDescription)")
             logger.log("Raw message data: \(message)") // Log the raw message on error
         }
    }

    private func setupConnectionManagerCallbacks(localPlayerId: PlayerId) {
        logger.debug(" GM Setup: Setting up P2PConnectionManager callbacks for \(localPlayerId.rawValue).") // ADD: Log setup

        connectionManager.onIceCandidateGenerated = { [weak self] (peerId, candidate) in
             // ADD: Log callback execution start
             logger.debug(" GM Callback: onIceCandidateGenerated called for peer \(peerId.rawValue).")
             guard let self = self else {
                 logger.debug(" GM Callback: ERROR - self is nil in onIceCandidateGenerated.") // ADD: Log self nil
                 return
             }
             // ADD: Log before starting Task
             logger.debug(" GM Callback: Starting Task to send ICE candidate from \(localPlayerId.rawValue) to \(peerId.rawValue).")
             Task {
                 // ADD: Log inside Task, before calling sendIceCandidate
                 logger.debug(" GM Callback Task: Inside Task. Attempting to send ICE candidate via signalingManager...")
                 do {
                     try await self.signalingManager.sendIceCandidate(from: localPlayerId, to: peerId, candidate: candidate)
                     // ADD: Log success
                     logger.debug(" GM Callback Task: signalingManager.sendIceCandidate successful for \(peerId.rawValue).")
                 } catch {
                      // ADD: Log error from sendIceCandidate
                     logger.log(" GM Callback Task: ERROR calling signalingManager.sendIceCandidate for \(peerId.rawValue): \(error)")
                 }
             }
        }

        connectionManager.onConnectionEstablished = { [weak self] peerId in
             guard let self = self else { return }
             logger.debug("✅ P2P Connection established with \(peerId.rawValue)")
             self.updatePlayerConnectionStatus(playerId: peerId, isConnected: true)
        }

        connectionManager.onMessageReceived = { [weak self] (peerId, message) in
            guard let self = self else { return }
            logger.log("📩 P2P Message received from \(peerId.rawValue)")
            self.decodeAndProcessAction(from: peerId, message: message)
        }

        connectionManager.onError = { [weak self] (peerId, error) in
            guard self != nil else { return }
            logger.log("❌ P2P Error with \(peerId.rawValue): \(error.localizedDescription)")
        }
         logger.log(" GM Setup: Finished setting up P2PConnectionManager callbacks.")// ADD: Log setup finish
    }
}
