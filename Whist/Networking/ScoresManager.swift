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
    
    // 🔹 Custom initializer to provide default values
    init(date: Date, ggScore: Int, ddScore: Int, totoScore: Int,
         ggPosition: Int? = nil, ddPosition: Int? = nil, totoPosition: Int? = nil,
         ggConsecutiveWins: Int? = nil, ddConsecutiveWins: Int? = nil, totoConsecutiveWins: Int? = nil) {
        self.date = date
        self.ggScore = ggScore
        self.ddScore = ddScore
        self.totoScore = totoScore
        self.ggPosition = ggPosition
        self.ddPosition = ddPosition
        self.totoPosition = totoPosition
        self.ggConsecutiveWins = ggConsecutiveWins
        self.ddConsecutiveWins = ddConsecutiveWins
        self.totoConsecutiveWins = totoConsecutiveWins
    }
    
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

extension GameScore {
    /// Converts a GameScore instance into a CKRecord.
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "GameScore")
        record["date"] = date as CKRecordValue
        record["gg_score"] = ggScore as CKRecordValue
        record["dd_score"] = ddScore as CKRecordValue
        record["toto_score"] = totoScore as CKRecordValue
        if let ggPosition = ggPosition {
            record["gg_position"] = ggPosition as CKRecordValue
        }
        if let ddPosition = ddPosition {
            record["dd_position"] = ddPosition as CKRecordValue
        }
        if let totoPosition = totoPosition {
            record["toto_position"] = totoPosition as CKRecordValue
        }
        if let ggConsecutiveWins = ggConsecutiveWins {
            record["gg_consecutive_wins"] = ggConsecutiveWins as CKRecordValue
        }
        if let ddConsecutiveWins = ddConsecutiveWins {
            record["dd_consecutive_wins"] = ddConsecutiveWins as CKRecordValue
        }
        if let totoConsecutiveWins = totoConsecutiveWins {
            record["toto_consecutive_wins"] = totoConsecutiveWins as CKRecordValue
        }
        return record
    }
    
    /// Initializes a GameScore instance from a CKRecord.
    init?(record: CKRecord) {
        guard let date = record["date"] as? Date,
              let ggScore = record["gg_score"] as? Int,
              let ddScore = record["dd_score"] as? Int,
              let totoScore = record["toto_score"] as? Int else {
            return nil
        }
        
        self.date = date
        self.ggScore = ggScore
        self.ddScore = ddScore
        self.totoScore = totoScore
        self.ggPosition = record["gg_position"] as? Int
        self.ddPosition = record["dd_position"] as? Int
        self.totoPosition = record["toto_position"] as? Int
        self.ggConsecutiveWins = record["gg_consecutive_wins"] as? Int
        self.ddConsecutiveWins = record["dd_consecutive_wins"] as? Int
        self.totoConsecutiveWins = record["toto_consecutive_wins"] as? Int
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
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    // MARK: - Initializer
    init() {
    }
    
    // MARK: Save Scores
    func saveScores(_ scores: [GameScore]) throws {
        let fileManager = FileManager.default
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.Tony.Whist")?
            .appendingPathComponent("Documents")
            .appendingPathComponent("scores_\(currentYear).json") else {
            logger.log("❌ iCloud Drive is not available")
            throw ScoresManagerError.fileWriteFailed
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            encoder.dateEncodingStrategy = .formatted(formatter)
            
            let data = try encoder.encode(scores)
            try data.write(to: iCloudURL, options: .atomic)
            logger.log("✅ Scores for \(currentYear) saved to iCloud Drive at \(iCloudURL.path)")
        } catch {
            logger.log("❌ Error saving to iCloud Drive: \(error.localizedDescription)")
            throw ScoresManagerError.fileWriteFailed
        }
    }
    
    // MARK: Save Score
    
    /// Saves a GameScore to CloudKit.
    func saveScore(_ gameScore: GameScore, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        // Convert GameScore to CKRecord.
        let record = gameScore.toCKRecord()
        
        // Get the default public CloudKit database.
        let container = CKContainer(identifier: "iCloud.com.Tony.WhistTest")
        let publicDatabase = container.publicCloudDatabase
        
        // Save the record in CloudKit.
        publicDatabase.save(record) { savedRecord, error in
            // Make sure UI updates happen on the main thread.
            DispatchQueue.main.async {
                if let error = error {
                    print("Error saving GameScore: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    print("Successfully saved GameScore with recordID: \(savedRecord.recordID)")
                    completion(.success(savedRecord))
                }
            }
        }
    }
    
    // MARK: Load Scores
    // Add a non-throwing convenience method
    func loadScoresSafely(for year: Int = Calendar.current.component(.year, from: Date()),
                          completion: @escaping ([GameScore]) -> Void) {
        loadScores(for: year) { result in
            switch result {
            case .success(let scores):
                completion(scores)
            case .failure(let error):
                logger.log("Error loading scores: \(error)")
                completion([])
            }
        }
    }
    
    func loadScores(for year: Int = Calendar.current.component(.year, from: Date())) throws -> [GameScore] {
        let fileManager = FileManager.default
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.Tony.Whist")?
            .appendingPathComponent("Documents")
            .appendingPathComponent("scores_\(year).json"),
              fileManager.fileExists(atPath: iCloudURL.path) else {
            logger.log("❌ No scores file found for \(year) in iCloud Drive")
            return []
        }
        do {
            let data = try Data(contentsOf: iCloudURL)
            let decoder = JSONDecoder()
            // Custom date decoding strategy that handles both formats:
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let isoFormatter = ISO8601DateFormatter()
                // Try without fractional seconds first (for "2024-01-06T21:26:07-05:00")
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                // Then try with fractional seconds (for older files, e.g. "2017-07-06T04:00:00.000Z")
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                // Fallback: use a DateFormatter that accepts the full offset with colon:
                let fallbackFormatter = DateFormatter()
                fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
                fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                if let date = fallbackFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date string does not match expected formats")
            }
            
            return try decoder.decode([GameScore].self, from: data)
        } catch {
            logger.log("❌ Error loading scores for \(year): \(error.localizedDescription)")
            throw ScoresManagerError.fileReadFailed
        }
    }
    
    // MARK: Find Loser
    func findLoser(completion: @escaping (Loser?) -> Void) {
        loadScoresSafely(for: currentYear) { scores in
            guard !scores.isEmpty else {
                completion(nil)
                return
            }
            
            let currentMonth = Calendar.current.component(.month, from: Date())
            
            let calculatePlayerPoints: ([GameScore]) -> [String: Int] = { games in
                var points: [String: Int] = ["gg": 0, "dd": 0, "toto": 0]
                for game in games {
                    let sortedScores = [
                        ("gg", game.ggScore),
                        ("dd", game.ddScore),
                        ("toto", game.totoScore)
                    ].sorted { $0.1 > $1.1 }
                    
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
            
            guard let loser = loserName, let loserId = namePlayerIdAssociation[loser] else {
                completion(nil)
                return
            }
            
            completion(Loser(playerId: loserId, losingMonths: losingMonths))
        }
    }
}

// MARK: - Updated ScoresManager Methods with CloudKit

extension ScoresManager {
    
    /// Saves an array of GameScore objects to CloudKit.
    func saveScores(_ scores: [GameScore], completion: @escaping (Result<Void, Error>) -> Void) {
        let container = CKContainer(identifier: "iCloud.com.Tony.WhistTest")
        let database = container.publicCloudDatabase
        let records = scores.map { $0.toCKRecord() }
        
        // Partition records into chunks of 400
        let chunkSize = 400
        let recordChunks = stride(from: 0, to: records.count, by: chunkSize).map {
            Array(records[$0..<min($0 + chunkSize, records.count)])
        }
        
        let dispatchGroup = DispatchGroup()
        var encounteredError: Error?
        
        // Process each chunk
        for chunk in recordChunks {
            dispatchGroup.enter()
            let operation = CKModifyRecordsOperation(recordsToSave: chunk, recordIDsToDelete: nil)
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .failure(let error):
                    logger.log("❌ Error saving chunk: \(error.localizedDescription)")
                    encounteredError = error
                case .success:
                    logger.log("✅ Chunk of scores saved to CloudKit container!")
                }
                dispatchGroup.leave()
            }
            database.add(operation)
        }
        
        dispatchGroup.notify(queue: .main) {
            if let error = encounteredError {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Loads GameScore objects for a specified year from CloudKit.
    func loadScores(for year: Int = Calendar.current.component(.year, from: Date()),
                    completion: @escaping (Result<[GameScore], Error>) -> Void) {
        let container = CKContainer(identifier: "iCloud.com.Tony.WhistTest")
        let database = container.publicCloudDatabase
        
        // Calculate the start and end dates for the given year.
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let endDate = calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59, second: 59)) else {
            completion(.failure(ScoresManagerError.decodingFailed))
            return
        }
        
        let predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as CVarArg, endDate as CVarArg)
        let query = CKQuery(recordType: "GameScore", predicate: predicate)
        
        var fetchedScores: [GameScore] = []
        let operation = CKQueryOperation(query: query)
        
        operation.recordMatchedBlock = { recordID, result in
            switch result {
            case .failure(let error):
                logger.log("❌ Error matching record \(recordID): \(error.localizedDescription)")
            case .success(let record):
                if let score = GameScore(record: record) {
                    fetchedScores.append(score)
                }
            }
        }
        
        operation.queryResultBlock = { result in
            switch result {
            case .failure(let error):
                logger.log("❌ Error loading scores: \(error.localizedDescription)")
                completion(.failure(ScoresManagerError.cloudKitError(error)))
            case .success:
                completion(.success(fetchedScores))
            }
        }
        
        database.add(operation)
    }
}

// MARK: Restore DB

extension ScoresManager {
    
    /// Deletes all GameScore records from CloudKit.
    func deleteAllScores(completion: @escaping (Result<Void, Error>) -> Void) {
        let container = CKContainer(identifier: "iCloud.com.Tony.WhistTest")
        let database = container.publicCloudDatabase
        let query = CKQuery(recordType: "GameScore", predicate: NSPredicate(value: true))
        var recordIDsToDelete: [CKRecord.ID] = []
        
        let queryOperation = CKQueryOperation(query: query)
        queryOperation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                recordIDsToDelete.append(record.recordID)
            case .failure(let error):
                // Log per-record error if needed
                logger.log("Error matching record \(recordID): \(error.localizedDescription)")
            }
        }
        
        queryOperation.queryResultBlock = { result in
            switch result {
            case .failure(let error):
                completion(.failure(ScoresManagerError.cloudKitError(error)))
            case .success:
                let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
                deleteOperation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(ScoresManagerError.cloudKitError(error)))
                    case .success:
                        completion(.success(()))
                    }
                }
                database.add(deleteOperation)
            }
        }
        
        database.add(queryOperation)
    }
    
    /// Restores the database from backup files in the given directory by first deleting existing scores.
    /// - Parameters:
    ///   - backupDirectory: The URL of the directory containing the backup JSON files.
    ///   - completion: Completion handler returning a Result with success or an Error.
    func restoreBackup(from backupDirectory: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        
        do {
            let backupFiles = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
            if backupFiles.isEmpty {
                logger.log("No files to restore. Aborting")
                return
            }
            
            var allScores: [GameScore] = []
            
            for fileURL in backupFiles where fileURL.pathExtension == "json" {
                logger.log("🔍 Processing backup file: \(fileURL.lastPathComponent)")
                
                let data = try Data(contentsOf: fileURL)
                logger.log("📂 Loaded file \(fileURL.lastPathComponent) with size: \(data.count) bytes")
                
                let decoder = JSONDecoder()
                // Use a custom date decoding strategy to handle string dates.
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = isoFormatter.date(from: dateString) {
                        return date
                    }
                    
                    let alternateFormatter = DateFormatter()
                    alternateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    alternateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                    if let date = alternateFormatter.date(from: dateString) {
                        return date
                    }
                    
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date string does not match expected formats")
                }
                
                do {
                    let scores = try decoder.decode([GameScore].self, from: data)
                    logger.log("✅ Successfully decoded \(scores.count) scores from file \(fileURL.lastPathComponent)")
                    allScores.append(contentsOf: scores)
                } catch {
                    logger.log("🚨 Error decoding file \(fileURL.lastPathComponent): \(error)")
                    throw error
                }
            }
            
            logger.log("Total scores loaded from backup: \(allScores.count)")
            
            // Delete existing scores from CloudKit.
            deleteAllScores { deleteResult in
                switch deleteResult {
                case .failure(let error):
                    logger.log("🚨 Error deleting scores from CloudKit: \(error)")
                    completion(.failure(error))
                case .success:
                    logger.log("✅ Deleted all previous scores from CloudKit. Proceeding to upload backup scores...")
                    self.saveScores(allScores) { saveResult in
                        switch saveResult {
                        case .failure(let error):
                            logger.log("🚨 Error saving backup scores to CloudKit: \(error)")
                        case .success:
                            logger.log("✅ Backup scores saved to CloudKit successfully!")
                        }
                        completion(saveResult)
                    }
                }
            }
        } catch {
            logger.log("🚨 Error restoring backup: \(error)")
            completion(.failure(error))
        }
    }
}
