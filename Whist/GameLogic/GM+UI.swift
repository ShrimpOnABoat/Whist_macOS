//
//  GM+UI.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-30.
//

import Foundation
import SwiftUI

struct CardState: Equatable {
    var position: CGPoint
    var rotation: Double
    var scale: CGFloat
}

// MARK: - CardPlace

enum CardPlace {
    case localPlayer
    case leftPlayer
    case rightPlayer
    case localPlayerTricks
    case leftPlayerTricks
    case rightPlayerTricks
    case table
    case deck
    case trumpDeck
    
//    // Computed properties for rotation and scale based on destination
//    var rotation: Double {
//        switch self {
//        case .player1, .player2:
//            return 0 // No rotation for players' hands
//        case .table:
//            return 90 // Rotate cards on the table by 90 degrees
//        }
//    }
//    
//    var scale: CGFloat {
//        switch self {
//        case .player1, .player2:
//            return 1.0 // Normal size for players' hands
//        case .table:
//            return 0.8 // 20% smaller for table cards
//        }
//    }
}
