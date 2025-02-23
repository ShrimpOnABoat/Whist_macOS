//
//  AppDelegate.swift
//  Whist
//
//  Created by Tony Buffard on 2025-02-22.
//

import Cocoa
import GameKit

class AppDelegate: NSObject, NSApplicationDelegate, GKLocalPlayerListener {
    
    // Store the pending invite URL if launched via URL or command-line.
    var pendingInviteURL: URL?
    
    // Check for command-line arguments before the app fully launches.
    func applicationWillFinishLaunching(_ notification: Notification) {
        let args = ProcessInfo.processInfo.arguments
        for arg in args {
            if arg.starts(with: "--gc-invite=") {
                let inviteURLString = String(arg.dropFirst("--gc-invite=".count))
                if let url = URL(string: inviteURLString) {
                    pendingInviteURL = url
                    print("Found pending invite from command-line: \(url)")
                }
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        authenticateLocalPlayer()
    }
    
    // This method is invoked when the app is launched via a URL.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            // Check for your custom URL scheme. For example, "gamecenter://invite?inviteID=..."
            if url.scheme?.lowercased() == "gamecenter" {
                pendingInviteURL = url
                print("Found pending invite from URL: \(url)")
            }
        }
    }
    
    func authenticateLocalPlayer() {
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { [weak self] viewController, error in
            if let vc = viewController {
                // On macOS, present the Game Center login view controller as a modal.
                if let window = NSApplication.shared.windows.first,
                   let rootVC = window.contentViewController {
                    rootVC.presentAsModalWindow(vc)
                }
            } else if localPlayer.isAuthenticated {
                // Register for Game Center events.
                localPlayer.register(self!)
                print("Local player authenticated.")
                // Now check if an invite was passed at launch.
                if let inviteID = self?.checkForPendingInvite() {
                    self?.handleInvite(withID: inviteID)
                }
            } else {
                print("Game Center authentication failed: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }
    
    /// Parse the pending invite URL (if any) to extract an invite ID.
    /// We assume the URL is in the form:
    ///    gamecenter://invite?inviteID=YOUR_INVITE_ID&senderID=...
    func checkForPendingInvite() -> String? {
        if let url = pendingInviteURL {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems
            if let inviteID = queryItems?.first(where: { $0.name.lowercased() == "inviteid" })?.value {
                // Clear the stored URL after processing.
                pendingInviteURL = nil
                print("Extracted inviteID: \(inviteID)")
                return inviteID
            }
        }
        return nil
    }
    
    /// Handle the invitation using the extracted invite ID.
    /// Note: There is no public API to convert an invite ID to a GKInvite, so here you must implement
    /// your own logic—perhaps by contacting your server or showing a custom UI—to let the player join the match.
    func handleInvite(withID inviteID: String) {
        print("Handling Game Center invite with ID: \(inviteID)")
        // TODO: Implement your logic to join the match using the inviteID.
        // For example, you might present a custom UI or use your server to fetch match details.
    }
    
    // MARK: - GKLocalPlayerListener
    // This callback handles invites accepted while the app is already running.
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        handleInvite(withGKInvite: invite)
    }
    
    /// Helper to handle GKInvite objects (for in-app invites).
    func handleInvite(withGKInvite invite: GKInvite) {
        if let window = NSApplication.shared.windows.first,
           let rootVC = window.contentViewController,
           let mmvc = GKMatchmakerViewController(invite: invite) {
            rootVC.presentAsModalWindow(mmvc)
        }
    }
}
