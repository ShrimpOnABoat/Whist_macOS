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
    private let recordID = CKRecord.ID(recordName: "sharedGameStateRecordID")
    private let gameStateDataKey = "gameStateData"

    init() {
        logger.log("GamePersistence initialized for CloudKit.")
    }

    func saveGameState(_ state: GameState) async {
        do {
            let encodedData = try JSONEncoder().encode(state)

            let record: CKRecord
            do {
                record = try await publicDatabase.record(for: recordID)
                logger.log("Found existing CloudKit record to update.")
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: recordType, recordID: recordID)
                logger.log("Creating new CloudKit record.")
            } catch {
                logger.log("Error fetching CloudKit record: \(error.localizedDescription). Cannot save state.")
                return
            }

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

    func loadGameState() async -> GameState? {
        do {
            let record = try await publicDatabase.record(for: recordID)
            logger.log("CloudKit record fetched successfully.")

            guard let data = record[gameStateDataKey] as? Data else {
                logger.log("Error: gameStateData field not found or not Data in CloudKit record.")
                return nil
            }

            let decodedState = try JSONDecoder().decode(GameState.self, from: data)
            logger.log("GameState successfully loaded and decoded from CloudKit.")
            return decodedState

        } catch let error as CKError where error.code == .unknownItem {
            logger.log("No saved game state found in CloudKit (RecordID: \(recordID.recordName)).")
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
            let deletedRecordID = try await publicDatabase.deleteRecord(withID: recordID)
            logger.log("Saved game state cleared successfully from CloudKit (RecordID: \(deletedRecordID.recordName)).")
        } catch let error as CKError where error.code == .unknownItem {
            logger.log("No saved game state found in CloudKit to clear.")
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
