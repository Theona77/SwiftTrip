//
//  hhApp.swift
//  hh
//
//  Created by Theona Arlinton on 09/04/26.
//

import SwiftUI

@main
struct hhApp: App {
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared
    @StateObject private var homeViewModel = HomeViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(deepLinkHandler)
                .environmentObject(homeViewModel)
                .onOpenURL { url in
                    print("Opened URL:", url) // debug
                    deepLinkHandler.handle(url: url)
                }
        }
    }
}
