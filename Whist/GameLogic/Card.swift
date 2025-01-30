//
//  Card.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Defines the card model.

// Card.swift
import Foundation
import SwiftUI

enum Suit: String, Codable, CaseIterable {
    case hearts, diamonds, clubs, spades
}

enum Rank: String, Codable, CaseIterable {
    case two = "2"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "10"
    case jack = "jack"
    case queen = "queen"
    case king = "king"
    case ace = "ace"

    // Define the precedence of ranks using a computed property
    var precedence: Int {
        switch self {
        case .two: return 1
        case .seven: return 2
        case .eight: return 3
        case .nine: return 4
        case .ten: return 5
        case .jack: return 6
        case .queen: return 7
        case .king: return 8
        case .ace: return 9
        }
    }
}

class Card: Identifiable, ObservableObject, Codable, Equatable {
    let id: String
    var suit: Suit
    var rank: Rank
    @Published var isFaceDown: Bool = true
    @Published var isPlayable: Bool = false
    @Published var rotation: Double = 0
    @Published var offset: CGFloat = CGFloat.random(in: -10...10)
    @Published var scale: CGFloat = 1.0
    @Published var isPlaceholder: Bool = false
    @Published var isLastTrick: Bool = false
    // New properties for random values
    var randomOffset: CGPoint = CGPoint(x: CGFloat.random(in: -10...10), y: CGFloat.random(in: -10...10))
    var randomAngle: CGFloat = CGFloat.random(in: -10...10) + CGFloat([-180, 0, 180].randomElement() ?? 0)
    
    // Initializer
    init(suit: Suit, rank: Rank, isPlaceholder: Bool = false, isLastTrick: Bool = false) {
        self.suit = suit
        self.rank = rank
        self.isPlaceholder = isPlaceholder
        self.isLastTrick = isLastTrick
        self.id = "\(suit.rawValue)_\(rank.rawValue)" + (isPlaceholder ? "_placeholder" : "") + (isLastTrick ? "_lastTrick" : "")
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, suit, rank
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        suit = try container.decode(Suit.self, forKey: .suit)
        rank = try container.decode(Rank.self, forKey: .rank)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(suit, forKey: .suit)
        try container.encode(rank, forKey: .rank)
    }

    // Equatable conformance
    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Card {
    static var mock: Card {
        let card = Card(suit: .hearts, rank: .queen) // Create a mutable card instance
        return card                                // Return the fully initialized card
    }
}

extension Card: CustomStringConvertible {
    var description: String {
        return "\(rank.rawValue) of \(suit.rawValue)"
    }
}
