//
//  DesmosPopUpApp.swift
//  DesmosPopUp
//
//  Created by Oori Schubert on 1/18/25.
//

import SwiftUI

@main
struct DesmosPopUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Option A: No windows
        // (You rely on AppDelegate for everything)
//        EmptyScene()
        
        // Option B: Provide just a settings scene (optional)
        Settings {
            Text("Configure Options Here")
        }
    }
}

struct EmptyScene: Scene {
    var body: some Scene {
        // No windows
        // You can do nothing here
        WindowGroup {
            EmptyView()
        }.windowStyle(HiddenTitleBarWindowStyle())
    }
}
