//
//  ShwordleApp.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-23.
//

import SwiftUI
import FirebaseCore

@main
struct ShwordleApp: App {
    // Initialize Firebase
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
