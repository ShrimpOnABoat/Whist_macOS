//
//  constants.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Application-wide constants.

import Foundation
import SwiftUI

struct GameConstants {
    // Deck
    static let deckOffset = CGPoint(x: 0.25, y: -0.25)
    static let deckShuffleOffset: CGFloat = 50
    static let deckShuffleAngle: Double = 15
    static let deckShuffleDuration: TimeInterval = 0.9

    // Animation Durations
    static let cardMoveDuration: TimeInterval = 0.5
    static let optionsRandomDuration: TimeInterval = 1
    
    // Background related constants
    static let feltColors: [Color] = [
        Color(red: 34 / 255, green: 139 / 255, blue: 34 / 255), // Classic Green
        Color(red: 0 / 255, green: 0 / 255, blue: 139 / 255),   // Deep Blue
        Color(red: 139 / 255, green: 0 / 255, blue: 0 / 255),   // Wine Red
        Color(red: 75 / 255, green: 0 / 255, blue: 130 / 255),  // Royal Purple
        Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255), // Teal
        Color(red: 54 / 255, green: 69 / 255, blue: 79 / 255),  // Charcoal Gray
        Color(red: 205 / 255, green: 92 / 255, blue: 0 / 255),  // Burnt Orange
        Color(red: 34 / 255, green: 90 / 255, blue: 34 / 255),  // Forest Green
        Color(red: 139 / 255, green: 69 / 255, blue: 19 / 255), // Chocolate Brown
        Color(red: 220 / 255, green: 20 / 255, blue: 60 / 255)  // Crimson Red
    ]
}

// UI-related constants
struct DynamicSize {
    let width: CGFloat
    let height: CGFloat
    let widthProportion: CGFloat
    let heightProportion: CGFloat
    let proportion: CGFloat
    
    init(from geometry: GeometryProxy) {
        self.width = geometry.size.width
        self.height = geometry.size.height
        self.widthProportion = width / 800
        self.heightProportion = height / 600
        self.proportion = min(widthProportion, heightProportion)
    }
    
    // Game Views
    var localPlayerWidth: CGFloat { width * 0.5 } // 25% of total width
    var localPlayerHeight: CGFloat { height * 0.33 } // 58% of total height
    var sidePlayerWidth: CGFloat { width * 0.25 } // 25% of total width
    var sidePlayerHeight: CGFloat { height * 0.58 } // 58% of total height
    
    // Table View
    var tableWidth: CGFloat { width * 0.5 } // 50% of total width
    var tableHeight: CGFloat { height * 0.3 } // 30% of total height
    
    // Scoreboard
    var scoreboardWidth: CGFloat { width * 0.5 }
    var scoreboardHeight: CGFloat { height * 0.25 }
    
    // Cards attributes
    var cardWidth: CGFloat { proportion * 90 }
    var cardHeight: CGFloat { proportion * 135 }
    var cardShadowRadius: CGFloat = 2
    var cardHoverOffset: CGFloat = 20
    

    // Player View
    let fanRadius: CGFloat = 300
    let minCardAngle: CGFloat = 5
    var playerViewHorizontalSpacing: CGFloat { widthProportion * 30 }
    var localPlayerHandWidth: CGFloat { width * 1 }
    var localPlayerHandHeight: CGFloat { height * 0.5 }
    var localPlayerStateWidth: CGFloat { width * 0.25 }
    var localPlayerStateHeight: CGFloat { height * 0.25 }
    var localPlayerInfoWidth: CGFloat { width * 0.25 }
    var localPlayerInfoHeight: CGFloat { height * 0.25 }
    var localPlayerTrickWidth: CGFloat { width * 0.25 }
    var localPlayerTrickHeight: CGFloat { height * 0.25 }
    var playerImageWidth: CGFloat { widthProportion * 50 }
    var playerImageHeight: CGFloat { heightProportion * 50 }
    var otherTrickSpacing: CGFloat { heightProportion * 0 }
    var localTrickSpacing: CGFloat { widthProportion * 5 }
    var trickScale: CGFloat { proportion / 3 }
    
    // Dealer button
    var dealerButtonSize: CGFloat { 30 * proportion }
    var dealerButtonLocalOffset: CGSize { CGSize(width: width * -40, height: height * -30) }
    var dealerButtonSideOffset: CGPoint { CGPoint(x: width * 50, y: height * 20) }
    
    // Betting options
    var optionsVerticalSpacing : CGFloat { 20 * proportion }
    var optionsButtonSize: CGFloat { 40 * proportion }
}
