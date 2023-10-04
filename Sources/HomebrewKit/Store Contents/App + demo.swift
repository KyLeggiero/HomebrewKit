//
//  App + demo.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 12/23/21.
//

import Foundation
import FunctionTools



public extension App {
    static let demo = Self.init(
        token: "___XX-example",
        name: "Example App",
        oneLiner: "The best example app for testing your app store, since 2021",
        latestVersion: "2.7.6",
        url: URL(string: "https://example.com/index.html")!)
    
    
    static let demo_oldInstalled = demo { app in
        app.installedVersion = "2.2.0"
        app.downloadSize = .init(value: 123.456789, unit: .megabytes)
    }
    
    
    static let demo_currentInstalled = demo { app in
        app.installedVersion = app.latestVersion
    }
    
    
    static let demo_unsafe = demo { app in
        app.url = URL(string: "http://example.com/index.html")!
    }
}



private extension App {
    static func demo(withModifications mutator: (inout Self) -> Void) -> Self {
        var demo = self.demo
        mutator(&demo)
        return demo
    }
}
