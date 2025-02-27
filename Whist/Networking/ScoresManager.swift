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
    let playerId: PlayerId
    let losingMonths: Int
}

enum ScoresManagerError: Error {
    case directoryCreationFailed
    case encodingFailed
    case decodingFailed
    case fileWriteFailed
    case fileReadFailed
    case cloudKitError(Error)
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
    
    private func ensureDirectoryExists() throws {
#if TEST_MODE
        if !fileManager.fileExists(atPath: scoresDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: scoresDirectoryURL, withIntermediateDirectories: true)
            } catch {
                throw ScoresManagerError.directoryCreationFailed
            }
        }
#endif
    }
    
    // MARK: Save Scores
    func saveScores(_ scores: [GameScore]) throws {
        #if TEST_MODE
        do {
            try ensureDirectoryExists()
            
            let encoder = JSONEncoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            // Set the encoder to use the custom formatter and produce human-readable JSON.
            encoder.dateEncodingStrategy = .formatted(formatter)
            encoder.outputFormatting = [.prettyPrinted]
            
            let data = try encoder.encode(scores)
            try data.write(to: scoresFileURL)
            print("Scores saved locally in TEST_MODE!")
        } catch ScoresManagerError.directoryCreationFailed {
            throw ScoresManagerError.directoryCreationFailed
        } catch EncodingError.invalidValue(_, _) {
            throw ScoresManagerError.encodingFailed
        } catch {
            throw ScoresManagerError.fileWriteFailed
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
            
            let semaphore = DispatchSemaphore(value: 0)
            var saveError: Error?
            
            CKContainer.default().privateCloudDatabase.save(record) { _, error in
                saveError = error
                semaphore.signal()
            }
            
            semaphore.wait()
            
            // Check if an error occurred during save
            if let error = saveError {
                throw ScoresManagerError.cloudKitError(error)
            }
            
        } catch {
            throw ScoresManagerError.encodingFailed
        }
#endif
    }
    
    // MARK: Save Score
    func saveScore(_ score: GameScore) {
        var scores = loadScoresSafely()
        scores.append(score)
        do {
            try saveScores(scores)
        } catch {
            logWithTimestamp("Error saving scores: \(error)")
        }
    }
    
    // MARK: Load Scores
    // Add a non-throwing convenience method
    func loadScoresSafely(for year: Int = Calendar.current.component(.year, from: Date())) -> [GameScore] {
        do {
            return try loadScores(for: year)
        } catch {
            logWithTimestamp("Error loading scores: \(error)")
            return []
        }
    }
    
    // Helper function for logging
    private func logWithTimestamp(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        print("[\(timestamp)] \(message)")
    }
    
    func loadScores(for year: Int = Calendar.current.component(.year, from: Date())) throws -> [GameScore] {
        #if TEST_MODE
        do {
            try ensureDirectoryExists()
            
            let data = try Data(contentsOf: scoresDirectoryURL.appendingPathComponent("scores_\(year).json"))
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
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Date string does not match expected formats"
                )
            }
            
            return try decoder.decode([GameScore].self, from: data)
        } catch {
            if !FileManager.default.fileExists(atPath: scoresFileURL.path) {
                return []
            }
            throw ScoresManagerError.decodingFailed
        }
        #else
        var scores: [GameScore] = []
        let query = CKQuery(recordType: "GameScores", predicate: NSPredicate(value: true))
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?
        
        CKContainer.default().privateCloudDatabase.fetch(
            withQuery: query,
            inZoneWith: nil,
            desiredKeys: nil,
            resultsLimit: CKQueryOperation.maximumResults
        ) { result in
            switch result {
            case .failure(let error):
                loadError = error
            case .success(let fetchResult):
                // Each matchResult is a tuple: (CKRecord.ID, Result<CKRecord, Error>)
                // We need to extract the CKRecord from the Result.
                let records = fetchResult.matchResults.compactMap { try? $0.1.get() }
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
                            loadError = ScoresManagerError.decodingFailed
                        }
                    }
                }
            }
            semaphore.signal()
        }
        semaphore.wait()
        
        if let error = loadError {
            throw ScoresManagerError.cloudKitError(error)
        }
        return scores
        #endif
    }
    
    // MARK: Find Loser
    func findLoser() -> Loser? {
        let scores = loadScoresSafely(for: currentYear)
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
        var loserName: String?
        var previousMonth = currentMonth - 1
        
        while previousMonth > 0 {
            let games = getGamesForMonth(previousMonth)
            if games.isEmpty {
                previousMonth -= 1
                continue
            }
            
            let points = calculatePlayerPoints(games)
            let loser = findLoserInMonth(points)
            
            if loserName == nil {
                loserName = loser
            }
            
            if loserName == loser {
                losingMonths += 1
                previousMonth -= 1
            } else {
                break
            }
        }
        
        guard let loser = loserName else { return nil }
        guard let loserId = namePlayerIdAssociation[loser] else { return nil }
        
        
        return Loser(playerId: loserId, losingMonths: losingMonths)
    }
}

