//
//  Action.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Defines actions that can be taken in the game.

import Foundation

struct GameAction: Codable {
    enum ActionType: String, Codable {
        case playCard
        case sendDeck
        case discard
        case choseBet
        case choseTrump
        case sendState
        
        var associatedPhases: [GamePhase] {
            switch self {
            case .playCard: return [.playingTricks]
            case .sendDeck: return [.waitingForDeck]
            case .discard: return [.choosingTrump, .waitingForTrump, .bidding, .discard]
            case .choseBet: return [.choosingTrump, .waitingForTrump, .bidding, .discard]
            case .choseTrump: return [.choosingTrump, .waitingForTrump, .bidding, .discard]
            default: return []
            }
        }
    }
    let playerId: PlayerId
    let type: ActionType
    let payload: Data
    let timestamp: TimeInterval
}

// Example of creating a playCard action
extension GameAction {
    static func playCardAction(playerId: PlayerId, card: Card) -> GameAction {
        let payloadData = try! JSONEncoder().encode(card)
        return GameAction(
            playerId: playerId,
            type: .playCard,
            payload: payloadData,
            timestamp: Date().timeIntervalSince1970
        )
    }
}
