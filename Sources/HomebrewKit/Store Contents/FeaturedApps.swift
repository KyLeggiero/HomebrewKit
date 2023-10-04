//
//  FeaturedApps.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 11/21/21.
//

import Foundation



public struct FeaturedApps: Codable {
    public var apps: [App]
    
    public init(apps: [App] = []) {
        self.apps = apps
    }
}
