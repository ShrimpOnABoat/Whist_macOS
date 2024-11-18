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
    case dealingCards           // Dealing cards to players
    case choosingTrump          // Local player choose a trump suit
    case waitingForTrump        // Waiting for a player to pick trump
    case bidding                // Players bid how many tricks they will take
    case discard                // Discard one or two cards
    case showCard               // Show card face up in first 3 rounds
    case playingTricks          // Active trick-playing phase
    case grabTrick              // One player takes the trick
    case scoring                // Calculating scores for the round
    case gameOver               // Game has ended
}

extension GameManager {
    
//     MARK: State Machine

    func transition(to newPhase: GamePhase) {
        print("Transitioning from \(currentPhase) to \(newPhase)")
        currentPhase = newPhase
        handleStateTransition()
    }

    // This function decides what to do upon entering a new phase
    private func handleStateTransition() {
        switch currentPhase {
        case .waitingToStart:
            // Already in initial state, just sitting tight until everyone connects
            break
            
        case .setupGame:
            setupGame()
            transition(to: .newGame)
            
        case .newGame:
            newGame()
            transition(to: .setupNewRound)
            
        case .setupNewRound:
            newGameRound()
            if connectionManager?.localPlayerID == gameState.dealer {
                transition(to: .dealingCards)
            } else {
                transition(to: .waitingForDeck)
            }
            
        case .waitingForDeck:
            // remove cards from tricks, hands and table and bring them back to the deck
            gatherCards()
            
            // in case the deck was sent earlier
            self.processPendingActionsForCurrentPhase()

            // otherwise nothing to do but wait
            if !isDeckReady { print("Waiting for deck") }
            
        case .dealingCards:
            if connectionManager?.localPlayerID == gameState.dealer {
                gatherCards()
                shuffleCards()
                sendDeckToPlayers()
            }
            
            dealCards {
                self.showCards()
                
                // After dealing, decide what’s next:
                if self.gameState.round < 4 { // Rounds with 1 card
                    if self.isLocalPlayerTurnToBet() {
                        self.transition(to: .bidding)
                    } else {
                        self.transition(to: .bidding)
                    }
                } else { // rounds with more than one card
                    if let localPlayer = self.gameState.localPlayer {
                        switch localPlayer.place {
                        case 1:
                            self.transition(to: .bidding)
                        case 2:
                            self.transition(to: .waitingForTrump)
                        case 3:
                            self.transition(to: .choosingTrump)
                        default:
                            fatalError("Unknown place \(localPlayer.place)")
                        }
                    }
                }
            }
            
        case .choosingTrump:
            // Prompt the relevant player to choose a trump suit
            // When that choice is done (via handleReceivedAction), move to .waitingForTrump
            showTrumps = true
            for index in gameState.trumpCards.indices {
                gameState.trumpCards[index].isFaceDown = false
            }
            checkAndAdvanceStateIfNeeded()
            
        case .waitingForTrump:
            // Once a trump suit is chosen and confirmed:
            if (gameState.trumpSuit == nil) && (gameState.localPlayer?.place == 2) {
                transition(to: .discard) // In case local player is second
            }
            
        case .discard:
            showDiscard = true
            
        case .bidding:
            // Either waiting until I can bid or until everybody did:
            if isLocalPlayerTurnToBet() {
                print("local player must bet")
                showOptions = true
            } else {
                if allPlayersBet() {
                    // Show card if round < 4
                    if gameState.round < 4 {
                        transition(to: .showCard)
                    }
                    print("All players have bet")
                    transition(to: .playingTricks)
                }
                // Still waiting for local player's turn to bet.
            }
            
        case .showCard:
            let localPlayer = gameState.getPlayer(by: gameState.localPlayer!.id)
            for i in localPlayer.hand.indices {
                localPlayer.hand[i].isFaceDown = false
            }
            transition(to: .playingTricks)
            
        case .playingTricks:
            // Normal gameplay

            if isLocalPlayerTurnToPlay() {
                setPlayableCards()
            } else if allPlayersPlayed() {
                transition(to: .grabTrick)
            }
            
        case .grabTrick:
            // Wait a few seconds and grab trick automatically
            // and set the last trick
            // and refresh playOrder
            assignTrick() {
                // check if last trick
                if self.isLastTrick() {
                    self.transition(to: .scoring)
                } else {
                    self.transition(to: .playingTricks)
                }
            }
            
            
        case .scoring:
            // Compute scores
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
            // Show final results, store the score, transition to .newGame ...
            
            break
        }
    }

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
            
        case .waitingForDeck:
            print("checkAndAdvanceStateIfNeeded: check if deck ready")
            if isDeckReady {
                isDeckReady = false
                print("checkAndAdvanceStateIfNeeded: it is!")
                transition(to: .dealingCards)
            }
            break

        case .dealingCards:
            // This state is handled in handleStateTransition
            print("Dealing cards")
            break

        case .choosingTrump:
            // If trump chosen, I chose a bid
            if gameState.trumpSuit != nil {
                transition(to: .bidding)
            }
            break

        case .waitingForTrump:
            // If trump confirmed:
            // transition(to: .bidding)
            break

        case .bidding:
            // Either waiting until I can bid or until everybody did:
            if allPlayersBet() {
                if gameState.round < 4 {
                    transition(to: .showCard)
                } else {
                    transition(to: .playingTricks)
                }
            } else {
                transition(to: .bidding)
            }
            break
            
        case .showCard:
            print("showCard: not supposed to happen!")
            break
            
        case .playingTricks:

            if allPlayersPlayed() {
                transition(to: .grabTrick)
            } else {
                transition(to: .playingTricks)
            }
            break

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
    
    func allPlayersBet() -> Bool {
        return gameState.players.allSatisfy { $0.announcedTricks.count == gameState.round }
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
        let maxTricks = max(gameState.round - 1, 1)
        
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
