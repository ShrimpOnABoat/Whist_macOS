//
//  Extensions.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Useful extensions to standard types.

import Foundation

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension String {
    /// Returns the first character of the string as a String.
    /// If the string is empty, returns an empty string.
    func firstInitial() -> String {
        return self.first.map { String($0) } ?? ""
    }
    
    /// Returns the initials from the string.
    /// For example, "Tony Buffard" returns "TB".
    func initials() -> String {
        let words = self.split(separator: " ")
        let initials = words.compactMap { $0.first }.map { String($0) }
        return initials.joined()
    }
}

extension Bool {
    static func random(probability: Double) -> Bool {
        guard (0...1).contains(probability) else { return false }
        return Double.random(in: 0...1) < probability
    }
}
