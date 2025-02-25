//
//  Player.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Represents a player's state and actions.

import Foundation
import SwiftUI

enum TablePosition: String, Codable {
    case local
    case left
    case right
}

enum PlayerState: String, Codable {
    case idle
    case startNewGame
    case choosingTrump
    case bidding
    case discarding
    case playing
    case waiting
    
    var message: String {
        switch self {
        case .idle: return "Idle"
        case .startNewGame: return "Starting New Game"
        case .choosingTrump: return "Choosing Trump"
        case .bidding: return "Bidding"
        case .discarding: return "Discarding"
        case .playing: return "Playing"
        case .waiting: return "Waiting"
        }
    }
}

class Player: Identifiable, ObservableObject, Codable {
    
    // Use PlayerId enum for the player's unique identifier
    let id: PlayerId
    
    // Player properties
    @Published var username: String
    @Published var scores: [Int] = []
    @Published var announcedTricks: [Int] = []
    @Published var madeTricks: [Int] = []
    @Published var monthlyLosses: Int = 0
    @Published var bonusCards: Int = 0
    @Published var isConnected: Bool = false
    @Published var place: Int = -1
    @Published var hand: [Card] = []
    @Published var trickCards: [Card] = []
    @Published var tablePosition: TablePosition? //= .local
    @Published var state: PlayerState = .idle
    var hasDiscarded: Bool = false
    
    // Image is not codable; handle separately if needed
    @Published var image: Image?
    
    init(id: PlayerId, username: String? = "", image: Image? = nil) {
        self.id = id
        self.username = username ?? id.rawValue
        self.image = image
    }
    
    // MARK: - Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case scores
        case announcedTricks
        case madeTricks
        case monthlyLosses
        case bonusCards
        case connected
        case state
        case hand
        case trickCards
        case hasDiscarded
        // Exclude 'image' as it cannot be directly serialized
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all codable properties
        id = try container.decode(PlayerId.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        scores = try container.decode([Int].self, forKey: .scores)
        announcedTricks = try container.decode([Int].self, forKey: .announcedTricks)
        madeTricks = try container.decode([Int].self, forKey: .madeTricks)
        monthlyLosses = try container.decode(Int.self, forKey: .monthlyLosses)
        bonusCards = try container.decode(Int.self, forKey: .bonusCards)
        isConnected = try container.decode(Bool.self, forKey: .connected)
        hand = try container.decode([Card].self, forKey: .hand)
        trickCards = try container.decode([Card].self, forKey: .trickCards)
        state = try container.decode(PlayerState.self, forKey: .state)
        hasDiscarded = try container.decode(Bool.self, forKey: .hasDiscarded)
        
        // 'image' remains nil upon decoding; handle image loading separately if needed
        image = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode all codable properties
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(scores, forKey: .scores)
        try container.encode(announcedTricks, forKey: .announcedTricks)
        try container.encode(madeTricks, forKey: .madeTricks)
        try container.encode(monthlyLosses, forKey: .monthlyLosses)
        try container.encode(bonusCards, forKey: .bonusCards)
        try container.encode(isConnected, forKey: .connected)
        try container.encode(hand, forKey: .hand)
        try container.encode(trickCards, forKey: .trickCards)
        try container.encode(state, forKey: .state)
        try container.encode(hasDiscarded, forKey: .hasDiscarded)
        
        // 'image' is not encoded
    }
}

extension Player: CustomStringConvertible {
    var description: String {
        return username
    }
}
