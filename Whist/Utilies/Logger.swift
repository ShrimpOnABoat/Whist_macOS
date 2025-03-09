//
//  Logger.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Logging utility for debugging.

import Foundation

/// A simple logger that writes to console and file with timestamps and function information.
class SimpleLogger {
    // MARK: - Properties
    
    /// Singleton instance for easy access
    static let shared = SimpleLogger()
    
    /// URL to the log file
    private let logFileURL: URL
    
    /// Queue for safe file writing
    private let fileQueue = DispatchQueue(label: "com.simplelogger.filequeue", qos: .background)
    
    // MARK: - Initialization
    
    init() {
        // Create logs directory in the application's caches directory
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let logsDirectory = cachesDirectory.appendingPathComponent("Logs")
        
        // Create the directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        logFileURL = logsDirectory.appendingPathComponent("log-Whist.txt")
        
        // If the file exists, remove it to start fresh on each launch
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            try? FileManager.default.removeItem(at: logFileURL)
        }

        // Create a new log file
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        
        print("Log file created at: \(logFileURL)")
    }
    
    // MARK: - Logging Methods
    
    /// Logs a message to console and file with timestamp and function information
    func log(_ message: String, function: String = #function) {
        // Create timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        // Format the log entry
        let logEntry = "[\(timestamp)] [\(function)] \(message)"
        
        // Print to console
        print(logEntry)
        
        // Write to file (on background queue)
        fileQueue.async {
            do {
                // Append log entry to file with newline
                let fileHandle = try FileHandle(forWritingTo: self.logFileURL)
                fileHandle.seekToEndOfFile()
                if let data = "\(logEntry)\n".data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } catch {
                print("Error writing to log file: \(error)")
            }
        }
    }
    
    func fatalErrorAndLog(_ message: String) -> Never {
        log(message)
        fatalError(message)
    }
    
    /// Returns the content of the current log file
    func getLogContent() -> String? {
        try? String(contentsOf: logFileURL, encoding: .utf8)
    }
    
    /// Clears the current log file
    func clearLog() {
        fileQueue.async {
            try? "".write(to: self.logFileURL, atomically: true, encoding: .utf8)
        }
    }
    
    /// Returns the URL to the current log file
    func getLogFileURL() -> URL {
        return logFileURL
    }
}

// Global logger for easy access
let logger = SimpleLogger.shared

// MARK: - Example Usage

/*
// Examples of how to use the logger
func someFunction() {
    logger.log("This is a test message")
    logger.log("Processing user data")
    
    // More complex test
    for i in 1...3 {
        logger.log("Processing item \(i)")
    }
}

// someFunction()
// print("Log file is at: \(logger.getLogFileURL().path)")
*/
