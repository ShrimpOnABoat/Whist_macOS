//
//  GamePersistence.swift
//  Whist
//
//  Created by Tony Buffard on 2025-01-21.
//  Handles saving and loading GameState to/from CloudKit.

import Foundation
import CloudKit

class GamePersistence {
    private let container = CKContainer(identifier: "iCloud.com.Tony.WhistTest") //CKContainer.default()
    private var publicDatabase: CKDatabase { container.publicCloudDatabase }
    private let recordType = "SavedGameState"
    private let gameStateDataKey = "gameStateData"
    private var saveWorkItem: DispatchWorkItem?

    init() {
        logger.log("GamePersistence initialized for CloudKit.")
    }

    func saveGameState(_ state: GameState) async {
        do {
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            let (matchResults, _) = try await publicDatabase.records(matching: query, resultsLimit: 50)
            for (recordID, result) in matchResults {
                if case .success = result {
                    try await publicDatabase.deleteRecord(withID: recordID)
                    logger.log("Deleted previous saved game record with ID: \(recordID.recordName)")
                }
            }
        } catch {
            logger.log("Warning: Failed to clear old saved game records before saving: \(error.localizedDescription)")
        }

        do {
            let encodedData = try JSONEncoder().encode(state)

            let record = CKRecord(recordType: recordType)
            record["createdAt"] = Date() as CKRecordValue
            record[gameStateDataKey] = encodedData as CKRecordValue

            try await publicDatabase.save(record)
            logger.log("GameState saved successfully to CloudKit (RecordID: \(record.recordID.recordName)).")

        } catch let error as CKError {
            logger.log("CloudKit Error saving game state: \(error.localizedDescription) (\(error.code.rawValue))")
            if error.code == .networkUnavailable || error.code == .networkFailure {
                logger.log("Network unavailable. Check internet connection.")
            } else if error.code == .notAuthenticated {
                logger.log("User not authenticated with iCloud.")
            } else if error.code == .permissionFailure {
                logger.log("Permission denied. Check CloudKit security roles/permissions.")
            }
        } catch {
            logger.log("Error encoding or saving game state to CloudKit: \(error.localizedDescription)")
        }
    }

    func scheduleSave(state: GameState) {
        saveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task {
                await self?.saveGameState(state)
            }
        }

        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    func loadGameState() async -> GameState? {
        do {
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            let (matchResults, _) = try await publicDatabase.records(matching: query, resultsLimit: 1)
            guard let record = matchResults.compactMap({ (_, result) in try? result.get() }).first else {
                logger.log("No saved game state found in CloudKit.")
                return nil
            }
            logger.log("CloudKit record fetched successfully.")

            guard let data = record[gameStateDataKey] as? Data else {
                logger.log("Error: gameStateData field not found or not Data in CloudKit record.")
                return nil
            }

            let decodedState = try JSONDecoder().decode(GameState.self, from: data)
            logger.log("GameState successfully loaded and decoded from CloudKit.")
            return decodedState

        } catch let error as CKError where error.code == .unknownItem {
            logger.log("No saved game state found in CloudKit.")
            return nil
        } catch let error as CKError {
            logger.log("CloudKit Error loading game state: \(error.localizedDescription) (\(error.code.rawValue))")
            if error.code == .networkUnavailable || error.code == .networkFailure {
                logger.log("Network unavailable. Check internet connection.")
            } else if error.code == .notAuthenticated {
                logger.log("User not authenticated with iCloud.")
            }
            return nil
        } catch {
            logger.log("Error decoding game state from CloudKit data: \(error.localizedDescription)")
            return nil
        }
    }

    func clearSavedGameState() async {
        do {
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            let (matchResults, _) = try await publicDatabase.records(matching: query, resultsLimit: 50)
            for (recordID, result) in matchResults {
                if case .success = result {
                    try await publicDatabase.deleteRecord(withID: recordID)
                    logger.log("Deleted saved game record with ID: \(recordID.recordName)")
                }
            }
        } catch let error as CKError {
            logger.log("CloudKit Error clearing saved game state: \(error.localizedDescription) (\(error.code.rawValue))")
            if error.code == .networkUnavailable || error.code == .networkFailure {
                logger.log("Network unavailable. Check internet connection.")
            } else if error.code == .notAuthenticated {
                logger.log("User not authenticated with iCloud.")
            }
        } catch {
            logger.log("Error clearing saved game state from CloudKit: \(error.localizedDescription)")
        }
    }
}
