//
//  GM+StateMachine.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-09.
//

import SwiftUI

enum GamePhase: Encodable, Decodable {
    case waitingForPlayers      // Before the game starts, waiting for all players to connect
    case exchangingSeed         // Ensuring seed is distributed before setup
    case setupGame              // Setup the game for the evening!
    case waitingToStart         // Display a "New game" button and the last game's winner
    case newGame                // Setup a new game
    case setupNewRound          // setup the new round
    case waitingForDeck         // Waiting for the dealer to shuffle the deck
    case renderingDeck          // Make sure the cards' cardState are initialized before dealing
    case dealingCards           // Dealing cards to players
    case choosingTrump          // Local player choose a trump suit
    case waitingForTrump        // Waiting for a player to pick trump
    case bidding                // Players bid how many tricks they will take. Stays on screen while the others still decide so that the player can change his mind.
    case discard                // Discard one or two cards
    case showCard               // Show card face up in first 3 rounds
    case playingTricks          // Active trick-playing phase
    case grabTrick              // One player takes the trick
    case scoring                // Calculating scores for the round
    case gameOver               // Game has ended
    
    var isPlayingPhase: Bool {
        switch self {
        case .showCard, .playingTricks, .grabTrick:
            return true
        default:
            return false
        }
    }
}

extension GameManager {
    
//     MARK: Transition
    
    func transition(to newPhase: GamePhase) {
        let multiplePhases: Set<GamePhase> = [.bidding, .playingTricks]
        if gameState.currentPhase == newPhase && !multiplePhases.contains(newPhase) {
            return
        }
        
        logWithTimestamp("Transitioning from \(gameState.currentPhase) to \(newPhase)")
        gameState.currentPhase = newPhase
        handleStateTransition()
    }
    
    // MARK: setPlayerState
    
    func setPlayerState(to newState: PlayerState) {
        if gameState.localPlayer?.state != newState {
            gameState.localPlayer?.state = newState
            sendStateToPlayers()
            persistence.saveGameState(gameState)
        }
    }

    // MARK: handleStateTransition

    private func handleStateTransition() {
        if processPendingActionsForCurrentPhase() { return }
        
        switch gameState.currentPhase {
        case .waitingForPlayers:
            setPlayerState(to: .idle)
            
        case .exchangingSeed:
            if gameState.localPlayer?.id == .toto {
                generateAndSendSeed()
            } else {
                logWithTimestamp("Waiting for seed from Toto...")
            }
            
        case .setupGame:
            setPlayerState(to: .idle)
            setupGame()
            transition(to: .waitingToStart)
            
        case .waitingToStart:
            setPlayerState(to: .startNewGame)
            
        case .newGame:
            setPlayerState(to: .idle)
            newGame()
            transition(to: .setupNewRound)
            
        case .setupNewRound:
            setPlayerState(to: .idle)
            newGameRound()
            if connectionManager?.localPlayerID == gameState.dealer {
                if !isDeckReady {
                    logWithTimestamp("isDeckReady: \(isDeckReady)")
                    transition(to: .renderingDeck)
                } else {
                    transition(to: .dealingCards)
                }
            } else {
                transition(to: .waitingForDeck)
            }
            
        case .renderingDeck:
            setPlayerState(to: .idle)
            // Mark that the deck is NOT measured yet
//            isDeckReady = false
            
        case .waitingForDeck:
            setPlayerState(to: .idle)
            // remove cards from tricks, hands and table and bring them back to the deck
            waitForAnimationsToFinish {
                self.gatherCards() {
                    // in case the deck was sent earlier
//                    self.processPendingActionsForCurrentPhase()
                    
                    // otherwise nothing to do but wait
                    if !self.isDeckReady { self.logWithTimestamp("Waiting for deck") }
                }
            }
            
        case .dealingCards:
            setPlayerState(to: .idle)
            let isDealer = (connectionManager?.localPlayerID == gameState.dealer)

            // 1) Define a function/closure that contains everything you do *after* dealCards finishes.
            func afterDealing() {
                persistence.saveGameState(gameState)
                // After dealing, decide what’s next:
                if gameState.round < 4 {
                    transition(to: .bidding)
                } else {
                    if let localPlayer = gameState.localPlayer {
                        logWithTimestamp("My place is \(localPlayer.place)")
                        switch localPlayer.place {
                        case 1: transition(to: .bidding)
                        case 2: transition(to: .waitingForTrump)
                        case 3: transition(to: .choosingTrump)
                        default: fatalError("Unknown place \(localPlayer.place)")
                        }
                    }
                }
            }

            // 2) Now branch out whether we do gatherCards + shuffle or not:
            waitForAnimationsToFinish {
                if isDealer {
                    self.gatherCards {
                        self.shuffleCards() {
                            self.persistence.saveGameState(self.gameState)
                            self.sendDeckToPlayers()
                            
                            // 3) Call dealCards, then call our afterDealing function
                            self.waitForAnimationsToFinish {
                                self.dealCards {
                                    afterDealing()
                                }
                            }
                        }
                    }
                } else {
                    // 4) Same dealCards call, same completion logic
                    self.shuffleCards(animationOnly: true) {
                        self.waitForAnimationsToFinish {
                            self.dealCards {
                                afterDealing()
                            }
                        }
                    }
                }
            }

        case .choosingTrump:
            setPlayerState(to: .choosingTrump)
            
            waitForAnimationsToFinish {
                self.chooseTrump() {
                    if self.isAIPlaying {
                        self.waitForAnimationsToFinish {
                            self.AIChooseTrumpSuit() {
                                self.transition(to: .bidding)
                            }
                        }
                    }
                }
            }
            
        case .waitingForTrump:
            setPlayerState(to: .waiting)

            // Once a trump suit is chosen and confirmed:
            if (gameState.trumpSuit != nil) && (gameState.localPlayer?.place == 2) {
                transition(to: .discard) // In case local player is second
            }
            
        case .discard:
            setPlayerState(to: .discarding)
            if isAIPlaying {
                waitForAnimationsToFinish {
                    self.AIdiscard() {
                        if let place = self.gameState.localPlayer?.place {
                            if place == 2 {
                                self.transition(to: .bidding)
                            } else {
                                self.transition(to: .playingTricks)
                            }
                        }
                    }
                }
            }
            
        case .bidding:
            if gameState.round < 4 {
                if isLocalPlayerTurnToBet() {
                    logWithTimestamp("local player must bet < 4")
                    setPlayerState(to: .bidding)
                    showOptions = true
                } else if allPlayersBet() {
                    transition(to: .showCard)
                } else {
                    setPlayerState(to: .waiting)
                }
            } else { // round > 3
                if allPlayersBet() {
                    logWithTimestamp("All players have bet")
                    if lastPlayerDiscarded() {
                        transition(to: .playingTricks)
                    } else {
                        if gameState.localPlayer?.place == 3 {
                            transition(to: .discard)
                        } else {
                            setPlayerState(to: .waiting)
                        }
                    }
                } else {
                    logWithTimestamp("Some players have not bet")
                    showOptions = true
                    setPlayerState(to: .bidding)
                    logWithTimestamp("local player must bet > 3")
                }
            }
            
        case .showCard:
            setPlayerState(to: .idle)
            if let localPlayer = gameState.localPlayer {
                for i in localPlayer.hand.indices {
                    localPlayer.hand[i].isFaceDown = false
                }
            }

            transition(to: .playingTricks)
            
        case .playingTricks:
            showOptions = false // Hide the options view
            let allPlayersAreTied: Bool = gameState.players.map { $0.scores.last ?? 0 }.allSatisfy { $0 == gameState.players.first?.scores.last ?? 0 }
            if gameState.round > 3 && !allPlayersAreTied {
                gameState.trumpCards.last?.isFaceDown = false // show the trump card to the first player
            }
            
            // In case someone already played a card
//            processPendingActionsForCurrentPhase()


            if isLocalPlayerTurnToPlay() {
                setPlayerState(to: .playing)
                setPlayableCards()
                if isAIPlaying {
                    waitForAnimationsToFinish {
                        self.AIPlayCard() {
                            if self.allPlayersPlayed() {
                                self.transition(to: .grabTrick)
                            } else {
                                self.setPlayerState(to: .waiting)
                            }
                        }
                    }
                }
            } else if allPlayersPlayed() {
                transition(to: .grabTrick)
            } else {
                setPlayerState(to: .waiting)
            }
            
        case .grabTrick:
            // Wait a few seconds and grab trick automatically
            // and set the last trick
            // and refresh playOrder
            logWithTimestamp("Assigning trick")
            setPlayerState(to: .idle)
            waitForAnimationsToFinish {
                self.assignTrick() {
                    self.gameState.currentTrick += 1
                    self.logWithTimestamp("Trick assigned, current trick is now \(self.gameState.currentTrick)")
                    // check if last trick
                    if self.isLastTrick() {
                        self.transition(to: .scoring)
                    } else {
                        self.transition(to: .playingTricks)
                    }
                }
            }
            
            
        case .scoring:
            waitForAnimationsToFinish {
                self.gatherCards {
                    // Compute scores
                    self.setPlayerState(to: .idle)
                    self.computeScores()
                    
                    // update positions
                    self.updatePlayersPositions()
                    
                    // if last round, transition to gameOver
                    if self.gameState.round == 12 {
                        self.transition(to: .gameOver)
                    } else { // proceed to the next round
                        self.transition(to: .setupNewRound)
                    }
                }
            }
            
        case .gameOver:
            setPlayerState(to: .idle)
            showConfetti.toggle()
            // Show final results, store the score, transition to .newGame ...
            persistence.clearSavedGameState()
            // save the game
            saveScore() //Sets the winner too
            transition(to: .waitingToStart)
        }
    }
    
    // MARK: checkAndAdvanceStateIfNeeded

    // Call this after actions come in or after dealing
    // to see if conditions are met to move to next phase
    func checkAndAdvanceStateIfNeeded() {
        // TODO: Add a .pause phase for when a player disconnects?
        
        logWithTimestamp("checkAndAdvanceStateIfNeeded: \(gameState.currentPhase)")
        switch gameState.currentPhase {
        case .waitingForPlayers:
            if gameState.allPlayersConnected {
                logWithTimestamp("All players connected! Moving to .exchangingSeed")
                transition(to: .exchangingSeed)
            }
            
        case .exchangingSeed:
            if gameState.playOrder.isEmpty {
                logWithTimestamp("Seed not received yet. Waiting in .exchangingSeed...")
            } else {
                logWithTimestamp("Seed received by all players! Moving to .setupGame")
                transition(to: .setupGame)
            }
            
        case .renderingDeck:
            if isDeckReady {
                transition(to: .dealingCards)
            }
            
        case .waitingForDeck:
            if isDeckReceived {
                transition(to: .dealingCards)
            } else {
                logWithTimestamp("Still waiting for the deck...")
            }

        case .dealingCards:
            // This state is handled in handleStateTransition
            logWithTimestamp("Dealing cards")

        case .choosingTrump:
            // If trump chosen, I chose a bid
            if gameState.trumpSuit != nil {
                transition(to: .bidding)
            } else {
                transition(to: .choosingTrump)
            }

        case .waitingForTrump:
            // If trump chosen, I chose a bid
            if gameState.trumpSuit != nil {
                transition(to: .discard)
            }
            
        case .discard:
            let numberOfCardsToDiscard = (gameState.localPlayer?.hand.count ?? 0) - max(1, gameState.round - 2)
            if numberOfCardsToDiscard > 0 {
                return
            } else if gameState.localPlayer?.place == 2 {
                transition(to: .bidding)
            } else {
                transition(to: .playingTricks)
            }

        case .bidding:
            if allPlayersBet() {
                showOptions = false
                if gameState.round < 4 {
                    transition(to: .showCard)
                } else if gameState.localPlayer?.place == 3 {
                    transition(to: .discard)
                } else if lastPlayerDiscarded() {
                    transition(to: .playingTricks)
                } else {
                    transition(to: .bidding)
                }
            } else {
                transition(to: .bidding)
            }
            
        case .showCard:
            gameState.trumpCards.last?.isFaceDown = false
            transition(to: .playingTricks)
            
        case .playingTricks:
            if allPlayersPlayed() {
                transition(to: .grabTrick)
            } else {
                transition(to: .playingTricks)
            }
            break
            
        case .grabTrick:
            if gameState.table.isEmpty && !allPlayersPlayed() {
                // check if last trick
                if isLastTrick() {
                    transition(to: .scoring)
                } else {
                    transition(to: .playingTricks)
                }
            } else {
                transition(to: .grabTrick)
            }

        case .scoring:
            // After scoring logic:
            // Either start new round: transition(to: .dealingCards)
            // Or end game: transition(to: .gameOver)
            break

        default:
            break
        }
    }
    
    // MARK: - Utilities

    func startNewGame() {
        logWithTimestamp("Starting new game")
        transition(to: .newGame)
    }
    
    func isLocalPlayerTurnToBet() -> Bool {
        guard let localPlayerID = connectionManager?.localPlayerID else {
            logWithTimestamp("Error: Local player ID not found.")
            return false
        }

        if gameState.round < 4 {
            guard let playerIndex = gameState.playOrder.firstIndex(of: localPlayerID) else {
                logWithTimestamp("Error: Local player not found in play order.")
                return false
            }
            
            // Check if all previous players in play order have made their bets
            for index in 0..<playerIndex {
                let previousPlayerID = gameState.playOrder[index]
                guard let previousPlayer = gameState.players.first(where: { $0.id == previousPlayerID }) else {
                    logWithTimestamp("Error: Player \(previousPlayerID) not found.")
                    return false
                }
                
                if previousPlayer.announcedTricks.count < gameState.round {
                    // A previous player hasn't made their bet yet
                    return false
                }
            }
            
            // Check if the player already bet
            if gameState.localPlayer!.announcedTricks.count >= gameState.round {
                return false
            }
            
            // If all checks pass, it's local player's turn to bet
            return true
        }
        else {
            return true
        }
    }
    
    func allPlayersBet() -> Bool {
        return gameState.players.allSatisfy { $0.announcedTricks.count == gameState.round }
    }
    
    func lastPlayerDiscarded() -> Bool {
        if gameState.round < 4 || allScoresEqual() { return true }
        if let lastPlayer = gameState.lastPlayer {
            logWithTimestamp("Last player \(lastPlayer.id) hasDiscarded: \(lastPlayer.hasDiscarded)")
            return lastPlayer.hasDiscarded
        } else {
            logWithTimestamp("lastPlayerDiscarded: No last player found.")
            return false
        }
    }
    
    func isLocalPlayerTurnToPlay() -> Bool {
        guard let localPlayerID = connectionManager?.localPlayerID else {
            fatalError("Error: Local player ID not found.")
        }

        guard let playerIndex = gameState.playOrder.firstIndex(of: localPlayerID) else {
            fatalError("Error: Local player not found in play order.")
        }

        // Check if it's the local player's turn to play
        if gameState.table.count == playerIndex {
            logWithTimestamp("It's my turn to play")
            return true
        } else {
            logWithTimestamp("Not my turn to play yet")
            return false
        }
    }
    func allPlayersPlayed() -> Bool {
        return gameState.table.count == gameState.players.count
    }

    func isLastTrick() -> Bool {
        // Check if all players' hands are empty
        let allHandsEmpty = gameState.players.allSatisfy { $0.hand.isEmpty }
        if allHandsEmpty {
            return true
        }

        return false
    }
    
    func computeScores() {
        // Determine the maximum possible tricks for this round
        let maxTricks = max(gameState.round - 2, 1)
        
        for player in gameState.players {
            guard gameState.round > 0 else { return }
            let roundIndex = gameState.round - 1
            
            // Ensure the player has announced and made tricks for this round
            guard player.announcedTricks.indices.contains(roundIndex),
                  player.madeTricks.indices.contains(roundIndex) else {
                logWithTimestamp("Error: Missing announced or made tricks for player \(player.username)")
                continue
            }
            
            let announced = player.announcedTricks[roundIndex]
            let made = player.madeTricks[roundIndex]
            var roundScore = 0
            
            if announced == made {
                // Player matched their announced tricks
                if announced == maxTricks {
                    // Announced maximum tricks
                    roundScore = 10 + 10 * made
                } else {
                    // Standard scoring
                    roundScore = 10 + 5 * made
                }
            } else {
                // Player missed their announced tricks
                roundScore = -5 * abs(made - announced)
            }
            
            // Add the round score to the player's total score
            let totalScore = (player.scores.last ?? 0) + roundScore
            player.scores.append(totalScore)
            
            
            
            logWithTimestamp("Player \(player.username): Announced \(announced), Made \(made), Round Score \(roundScore), Total Score \(totalScore)")
        }
        
        // Add bonus for the highest bidder in the last round (round 12)
        if gameState.round == 12 {
            // Calculate each player's total announced tricks (across all rounds)
            let playersAnnouncedTotals = gameState.players.map { player in
                (player: player, total: player.announcedTricks.reduce(0, +))
            }
            let maxAnnounced = playersAnnouncedTotals.map { $0.total }.max() ?? 0
            
            // Identify all players who reached the maximum
            let topPlayers = playersAnnouncedTotals.filter { $0.total == maxAnnounced }
            if topPlayers.count == 1 {
                let bonusWinner = topPlayers.first!.player
                // Add 15 bonus points to the bonus winner's last score
                bonusWinner.scores[bonusWinner.scores.count - 1] += 15
                logWithTimestamp("Bonus added for highest bidder \(bonusWinner.username): +15 points")
            } else {
                logWithTimestamp("No bonus added due to tie among highest bidders.")
            }
        }
        self.playersScoresUpdated.toggle()
    }
    
    func isActionValidInCurrentPhase(_ actionType: GameAction.ActionType) -> Bool {
        return (actionType.associatedPhases.contains(gameState.currentPhase) || actionType.associatedPhases == [])
    }
    
    func processPendingActionsForCurrentPhase(checkState: Bool = true) -> Bool {
        guard pendingActions.isEmpty == false else { return false }
        
        logWithTimestamp("Pending actions count: \(pendingActions.count)")
        logWithTimestamp("checkState: \(checkState)")
        var atLeastOneActionProcessed = false
        
        let remainingActions = pendingActions
        pendingActions.removeAll()

        for action in remainingActions {
            if isActionValidInCurrentPhase(action.type) {
                logWithTimestamp("Action \(action.type) is valid in current phase, processing it")
                processAction(action)
                atLeastOneActionProcessed = true
            } else {
                logWithTimestamp("Action \(action.type) is NOT valid in current phase (\(gameState.currentPhase)), skipping it")
                pendingActions.append(action)  // Re-add invalid actions
            }
        }

        if atLeastOneActionProcessed && checkState {
            logWithTimestamp("processPendingActionsForCurrentPhase: Checking state after processing actions...")
            checkAndAdvanceStateIfNeeded()
        }
        
        // Remove processed actions from pendingActions
        logWithTimestamp("Pending actions left: \(pendingActions.count)")
        
        return atLeastOneActionProcessed
    }
}
