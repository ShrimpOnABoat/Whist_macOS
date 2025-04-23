//
//  PresenceManager.swift
//  Whist
//
//  Created by Tony Buffard on 2025-04-22.
//


import FirebaseDatabase
import FirebaseAuth

class PresenceManager: ObservableObject {
    static let shared = PresenceManager()
    
    private var databaseRef: DatabaseReference?
    private var connectedRef: DatabaseReference?
    private var userStatusRef: DatabaseReference?
    private var playerId: String?

    private init() {}

    func configure(with playerId: String) {
        self.playerId = playerId
        self.databaseRef = Database.database().reference()
        self.connectedRef = databaseRef?.child(".info/connected")
        self.userStatusRef = databaseRef?.child("status/\(playerId)")
    }

    func startTracking() {
        guard let connectedRef = connectedRef,
              let userStatusRef = userStatusRef,
              let playerId = playerId else {
            print("[Presence] Error: PresenceManager not configured with playerId.")
            return
        }

        connectedRef.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }

            if let connected = snapshot.value as? Bool, connected {
                let onlineData: [String: Any] = [
                    "online": true,
                    "last_changed": ServerValue.timestamp()
                ]
                let offlineData: [String: Any] = [
                    "online": false,
                    "last_changed": ServerValue.timestamp()
                ]

                userStatusRef.onDisconnectSetValue(offlineData)
                userStatusRef.setValue(onlineData)
                print("[Presence] \(playerId) is online.")
            } else {
                print("[Presence] \(playerId) is offline (connection lost).")
            }
        }
    }
    
    func checkPresence(of playerId: String, completion: @escaping (Bool?) -> Void) {
        let statusRef = Database.database().reference(withPath: "status/\(playerId)/online")
        statusRef.observeSingleEvent(of: .value) { snapshot in
            if let isOnline = snapshot.value as? Bool {
                completion(isOnline)
            } else {
                completion(nil) // presence unknown
            }
        }
    }
}
