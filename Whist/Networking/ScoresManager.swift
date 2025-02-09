//
//  ScoresManager.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-22.
//

import Foundation
import CloudKit

struct GameScore: Codable, Identifiable {
    let id = UUID() // Unique ID for each game
    let date: Date
    let ggScore: Int
    let ddScore: Int
    let totoScore: Int
    let ggPosition: Int?
    let ddPosition: Int?
    let totoPosition: Int?
    let ggConsecutiveWins: Int?
    let ddConsecutiveWins: Int?
    let totoConsecutiveWins: Int?
    
    enum CodingKeys: String, CodingKey {
        case date
        case ggScore = "gg_score"
        case ddScore = "dd_score"
        case totoScore = "toto_score"
        case ggPosition = "gg_position"
        case ddPosition = "dd_position"
        case totoPosition = "toto_position"
        case ggConsecutiveWins = "gg_consecutive_wins"
        case ddConsecutiveWins = "dd_consecutive_wins"
        case totoConsecutiveWins = "toto_consecutive_wins"
    }
}

extension GameScore {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode properties in the desired order:
        try container.encode(date, forKey: .date)
        try container.encode(ggScore, forKey: .ggScore)
        try container.encode(ddScore, forKey: .ddScore)
        try container.encode(totoScore, forKey: .totoScore)
        try container.encode(ggPosition, forKey: .ggPosition)
        try container.encode(ddPosition, forKey: .ddPosition)
        try container.encode(totoPosition, forKey: .totoPosition)
        try container.encode(ggConsecutiveWins, forKey: .ggConsecutiveWins)
        try container.encode(ddConsecutiveWins, forKey: .ddConsecutiveWins)
        try container.encode(totoConsecutiveWins, forKey: .totoConsecutiveWins)
    }
}

struct Loser {
    let playerId: String
    let losingMonths: Int
}

class ScoresManager {
    static let shared = ScoresManager()
    
    private let fileManager = FileManager.default
    private var scoresDirectoryURL: URL {
        #if TEST_MODE
        // /Users/tonybuffard/Library/Containers/com.Tony.Whist/Data/Documents
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectory.appendingPathComponent("scores/")
        #else
        fatalError("Use CloudKit in release mode")
        #endif
    }
    private var scoresFileURL: URL {
        #if TEST_MODE
        return scoresDirectoryURL.appendingPathComponent("scores_\(currentYear).json")
        #else
        fatalError("Use CloudKit in release mode")
        #endif
    }
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    // MARK: Save Scores
    func saveScores(_ scores: [GameScore]) {
        #if TEST_MODE
        do {
            let encoder = JSONEncoder()
            
            // Configure the date formatter for the desired ISO 8601 format with timezone offset.
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            // Set the encoder to use the custom formatter and produce human-readable JSON.
            encoder.dateEncodingStrategy = .formatted(formatter)
            encoder.outputFormatting = [.prettyPrinted]
            
            let data = try encoder.encode(scores)
            try data.write(to: scoresFileURL)
            print("Scores saved locally in TEST_MODE!")
        } catch {
            print("Error saving scores: \(error)")
        }
        #else
        let record = CKRecord(recordType: "GameScores")
        do {
            let encoder = JSONEncoder()
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            encoder.dateEncodingStrategy = .formatted(formatter)
            encoder.outputFormatting = [.prettyPrinted]
            
            let data = try encoder.encode(scores)
            record["scores"] = data as CKRecordValue
            CKContainer.default().privateCloudDatabase.save(record) { _, error in
                if let error = error {
                    print("Error saving scores to CloudKit: \(error)")
                } else {
                    print("Scores saved to CloudKit!")
                }
            }
        } catch {
            print("Error encoding scores for CloudKit: \(error)")
        }
        #endif
    }
    
    // MARK: Save Score
    func saveScore(_ score: GameScore) {
        var scores = loadScores()
        scores.append(score)
        saveScores(scores)
    }
    
    // MARK: Load Scores
    func loadScores(for year: Int = Calendar.current.component(.year, from: Date())) -> [GameScore] {
        #if TEST_MODE
        do {
            let decoder = JSONDecoder()
            
            // Custom date decoding strategy to handle different formats
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let alternateFormatter = DateFormatter()
                alternateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                } else if let date = alternateFormatter.date(from: dateString) {
                    return date
                } else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Date string does not match expected formats"
                    )
                }
            }

            let data = try Data(contentsOf: scoresDirectoryURL.appendingPathComponent("scores_\(year).json"))
            return try decoder.decode([GameScore].self, from: data)
        } catch {
            print("Error loading scores: \(error)")
            return []
        }
        #else
        var scores: [GameScore] = []
        let query = CKQuery(recordType: "GameScores", predicate: NSPredicate(value: true))
        let semaphore = DispatchSemaphore(value: 0)
        CKContainer.default().privateCloudDatabase.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("Error loading scores from CloudKit: \(error)")
            } else if let records = records {
                for record in records {
                    if let data = record["scores"] as? Data {
                        do {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .custom { decoder in
                                let container = try decoder.singleValueContainer()
                                let dateString = try container.decode(String.self)
                                
                                let iso8601Formatter = ISO8601DateFormatter()
                                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                
                                let alternateFormatter = DateFormatter()
                                alternateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                                
                                if let date = iso8601Formatter.date(from: dateString) {
                                    return date
                                } else if let date = alternateFormatter.date(from: dateString) {
                                    return date
                                } else {
                                    throw DecodingError.dataCorruptedError(
                                        in: container,
                                        debugDescription: "Date string does not match expected formats"
                                    )
                                }
                            }
                            
                            let decodedScores = try decoder.decode([GameScore].self, from: data)
                            scores.append(contentsOf: decodedScores)
                        } catch {
                            print("Error decoding scores: \(error)")
                        }
                    }
                }
            }
            semaphore.signal()
        }
        semaphore.wait()
        return scores
        #endif
    }
    
    // MARK: Find Loser
    func findLoser() -> Loser? {
        let scores = loadScores(for: currentYear)
        guard !scores.isEmpty else { return nil }
        
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        let calculatePlayerPoints: ([GameScore]) -> [String: Int] = { games in
            var points: [String: Int] = ["gg": 0, "dd": 0, "toto": 0]
            for game in games {
                let sortedScores = [
                    ("gg", game.ggScore),
                    ("dd", game.ddScore),
                    ("toto", game.totoScore)
                ].sorted(by: { $0.1 > $1.1 })
                
                if sortedScores[0].1 > sortedScores[1].1 {
                    points[sortedScores[0].0, default: 0] += 2
                }
                if sortedScores[1].1 > sortedScores[2].1 {
                    points[sortedScores[1].0, default: 0] += 1
                }
            }
            return points
        }
        
        let getGamesForMonth: (Int) -> [GameScore] = { month in
            return scores.filter {
                let gameMonth = Calendar.current.component(.month, from: $0.date)
                return gameMonth == month
            }
        }
        
        let findLoserInMonth: ([String: Int]) -> String? = { points in
            let sortedPoints = points.sorted { $0.value < $1.value }
            if sortedPoints.count > 1 && sortedPoints[0].value != sortedPoints[1].value {
                return sortedPoints[0].key
            }
            return nil
        }
        
        var losingMonths = 0
        var loserId: String?
        var previousMonth = currentMonth - 1
        
        while previousMonth > 0 {
            let games = getGamesForMonth(previousMonth)
            if games.isEmpty {
                previousMonth -= 1
                continue
            }
            
            let points = calculatePlayerPoints(games)
            let loser = findLoserInMonth(points)
            
            if loserId == nil {
                loserId = loser
            }
            
            if loserId == loser {
                losingMonths += 1
                previousMonth -= 1
            } else {
                break
            }
        }
        
        guard let loser = loserId else { return nil }
        return Loser(playerId: loser, losingMonths: losingMonths)
    }
}
