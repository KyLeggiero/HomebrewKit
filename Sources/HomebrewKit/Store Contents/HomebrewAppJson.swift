//
//  HomebrewAppJson.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 9/20/21.
//

import Foundation
import Either



/// The output of `brew info --json=v2 APP_NAME`
struct HomebrewAppJson: Codable {
    let casks: [Cask]?
    let formulae: [Formula]?
}



extension HomebrewAppJson {
    struct Cask: Codable {
        let token: String
        let full_token: String
        let name: [String]
        let desc: String?
        let url: URL?
        let version: String
        let installed: String?
        let outdated: Bool
        var size: Measurement<UnitInformationStorage>?
    }
    
    
    
    struct Formula: Codable {
        let name: String
        let full_name: String
        let aliases: [String]
        let desc: String
        let versions: Either<[Version], VersionsObject>
        let installed: [Version]
        let outdated: Bool
        
        
        
        struct Version: Codable {
            let stable: String
        }
        
        
        
        struct VersionsObject: Codable {}
    }
}
