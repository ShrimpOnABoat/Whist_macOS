//
//  constants.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Application-wide constants.

import Foundation

#if TEST_MODE
struct Constants {
    static let TEST_MODE = true
}
#endif

#if !TEST_MODE
struct Constants {
    static let TEST_MODE = false
}
#endif
