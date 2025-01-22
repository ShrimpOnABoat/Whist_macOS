//
//  GM+StateMachine.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-09.
//

import SwiftUI

enum GamePhase {
    case waitingToStart         // Before the game starts, waiting for all players to connect
    case setupGame              // Setup the game for the evening!
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
}

extension GameManager {
    
//     MARK: Transition

    func transition(to newPhase: GamePhase) {
        print("Transitioning from \(currentPhase) to \(newPhase)")
        currentPhase = newPhase
        handleStateTransition()
    }
    
    // MARK: setPlayerState
    
    func setPlayerState(to newState: PlayerState) {
        if gameState.localPlayer?.state != newState {
            gameState.localPlayer?.state = newState
            sendStateToPlayers()
            persistence.saveGameState(gameState)
            print("My new state is \(gameState.localPlayer?.state ?? .idle)")
        }
    }

    // MARK: handleStateTransition

    private func handleStateTransition() {
        switch currentPhase {
        case .waitingToStart:
            setPlayerState(to: .idle)
            break
            
        case .setupGame:
            setPlayerState(to: .idle)
            setupGame()
            transition(to: .newGame)
            
        case .newGame:
            setPlayerState(to: .idle)
            newGame()
            transition(to: .setupNewRound)
            
        case .setupNewRound:
            setPlayerState(to: .idle)
            newGameRound()
            if connectionManager?.localPlayerID == gameState.dealer {
                if !isDeckReady {
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
            isDeckReady = false
            
        case .waitingForDeck:
            setPlayerState(to: .idle)
            // remove cards from tricks, hands and table and bring them back to the deck
            gatherCards() {
                // in case the deck was sent earlier
                self.processPendingActionsForCurrentPhase()
                
                // otherwise nothing to do but wait
                if !self.isDeckReady { print("Waiting for deck") }
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
                        print("My place is \(localPlayer.place)")
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
            if isDealer {
                gatherCards {
                    self.shuffleCards() {
                        self.persistence.saveGameState(self.gameState)
                        self.sendDeckToPlayers()
                        
                        // 3) Call dealCards, then call our afterDealing function
                        self.dealCards {
                            afterDealing()
                        }
                    }
                }
            } else {
                // 4) Same dealCards call, same completion logic
                self.shuffleCards(animationOnly: true) {
                    self.dealCards {
                        afterDealing()
                    }
                }
            }

        case .choosingTrump:
            setPlayerState(to: .choosingTrump)

            chooseTrump() {
                if self.isAIPlaying {
                    self.AIChooseTrumpSuit()
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
                AIdiscard()
            }
            
        case .bidding:
            if gameState.round < 4 {
                if isLocalPlayerTurnToBet() {
                    print("local player must bet < 4")
                    setPlayerState(to: .bidding)
                    showOptions = true
                } else if allPlayersBet() {
                    transition(to: .showCard)
                } else {
                    setPlayerState(to: .waiting)
                }
            } else { // round > 3
                if allPlayersBet() {
                    print("All players have bet")
                    if lastPlayerDiscarded() {
                        transition(to: .playingTricks)
                    } else {
                        setPlayerState(to: .waiting)
                    }
                } else {
                    print("Some players have not bet")
                    showOptions = true
                    setPlayerState(to: .bidding)
                    print("local player must bet > 3")
                }
            }
            
        case .showCard:
            setPlayerState(to: .idle)
            let localPlayer = gameState.getPlayer(by: gameState.localPlayer!.id)
            for i in localPlayer.hand.indices {
                localPlayer.hand[i].isFaceDown = false
            }

            transition(to: .playingTricks)
            
        case .playingTricks:
            showOptions = false // Hide the options view
            let allPlayersAreTied: Bool = gameState.players.map { $0.scores.last ?? 0 }.allSatisfy { $0 == gameState.players.first?.scores.last ?? 0 }
            if gameState.round > 3 && !allPlayersAreTied {
                gameState.trumpCards.last?.isFaceDown = false // show the trump card to the first player
            }
            
            // In case someone already played a card
            processPendingActionsForCurrentPhase()


            if isLocalPlayerTurnToPlay() {
                setPlayerState(to: .playing)
                setPlayableCards()
                if isAIPlaying {
                    AIPlayCard()
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
            print("Assigning trick")
            setPlayerState(to: .idle)
            assignTrick() {
                print("Trick assigned")
                // check if last trick
                if self.isLastTrick() {
                    self.transition(to: .scoring)
                } else {
                    self.transition(to: .playingTricks)
                }
            }
            
            
        case .scoring:
            // Compute scores
            setPlayerState(to: .idle)
            computeScores()
            
            // update positions
            updatePlayersPositions()
            
            // if last round, transition to gameOver
            if gameState.round == 12 {
                transition(to: .gameOver)
            } else { // proceed to the next round
                transition(to: .setupNewRound)
            }
            
        case .gameOver:
            setPlayerState(to: .idle)
            // Show final results, store the score, transition to .newGame ...
            persistence.clearSavedGameState()
            
            break
        }
    }
    
    // MARK: checkAndAdvanceStateIfNeeded

    // Call this after actions come in or after dealing
    // to see if conditions are met to move to next phase
    func checkAndAdvanceStateIfNeeded() {
        print("checkAndAdvanceStateIfNeeded: \(currentPhase)")
        switch currentPhase {
        case .waitingToStart:
            if gameState.players.count == 3 && gameState.players.allSatisfy({ $0.connected }) {
                transition(to: .setupGame)
            }
            break
            
        case .renderingDeck, .waitingForDeck:
            if isDeckReady {
                transition(to: .dealingCards)
            }

        case .dealingCards:
            // This state is handled in handleStateTransition
            print("Dealing cards")
            break

        case .choosingTrump:
            // If trump chosen, I chose a bid
            if gameState.trumpSuit != nil {
                transition(to: .bidding)
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
            // check if last trick
            if self.isLastTrick() {
                self.transition(to: .scoring)
            } else {
                self.transition(to: .playingTricks)
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
    
    func isLocalPlayerTurnToBet() -> Bool {
        guard let localPlayerID = connectionManager?.localPlayerID else {
            print("Error: Local player ID not found.")
            return false
        }

        if gameState.round < 4 {
            guard let playerIndex = gameState.playOrder.firstIndex(of: localPlayerID) else {
                print("Error: Local player not found in play order.")
                return false
            }
            
            // Check if all previous players in play order have made their bets
            for index in 0..<playerIndex {
                let previousPlayerID = gameState.playOrder[index]
                guard let previousPlayer = gameState.players.first(where: { $0.id == previousPlayerID }) else {
                    print("Error: Player \(previousPlayerID) not found.")
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
        if gameState.round < 4 { return true }
        let allHandsSameCount = gameState.players.allSatisfy { $0.hand.count == max(1, gameState.round - 2)}
        return allHandsSameCount
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
            print("It's my turn to play")
            return true
        } else {
            print("Not my turn to play yet")
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
                print("Error: Missing announced or made tricks for player \(player.username)")
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
            
            print("Player \(player.username): Announced \(announced), Made \(made), Round Score \(roundScore), Total Score \(totalScore)")
        }
    }
    
    func isActionValidInCurrentPhase(_ actionType: GameAction.ActionType) -> Bool {
        return (actionType.associatedPhases.contains(currentPhase) || actionType.associatedPhases == [])
    }
    
    func processPendingActionsForCurrentPhase() {
        print("Pending actions count: \(pendingActions.count)")
        
        // Iterate through the actions in pendingActions
        var processedIndices: [Int] = []
        
        for (index, action) in pendingActions.enumerated() {
            if isActionValidInCurrentPhase(action.type) {
                self.processAction(action)
                processedIndices.append(index)
            }
        }
        
        // Remove processed actions from pendingActions
        pendingActions = pendingActions.enumerated().filter { !processedIndices.contains($0.offset) }.map { $0.element }
    }
}
