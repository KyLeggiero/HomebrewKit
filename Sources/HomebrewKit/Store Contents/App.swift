//
//  App.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 9/12/21.
//

import Foundation



/// Represents an app in the store. Two apps are considered distinct and unique solely by their `token` field, which is used in hashing and equating
public struct App {
    
    /// The machine-readable name of this app, uniquely identifying it within Homebrew
    public let token: String
    
    /// The human-readable name of this app, which will appear in headings and title fields
    public var name: String?
    
    /// A one-line description of this app
    public var oneLiner: String?
    
    /// The version of this app which is currently installed, or `nil` if it's not installed
    public var installedVersion: String?
    
    /// The latest version of this app, installed or not
    public var latestVersion: String?
    
    /// `true` iff this app needs to be updated
    public var needsUpdate: Bool?
    
    /// The date at which the info in this app was last filled-out using `Homebrew.fillOutInfo(for:)`
    internal var dateInfoLastFilledOut: Date = .distantPast
    
    /// The URL where the app package can be downloaded
    public var url: URL?
    
    /// The number of bytes expected to be downloaded when installing this package
    public var downloadSize: Measurement<UnitInformationStorage>?
    
    
    public init(token: String,
                name: String? = nil,
                oneLiner: String? = nil,
                installedVersion: String? = nil,
                latestVersion: String? = nil,
                needsUpdate: Bool? = nil,
                dateInfoLastFilledOut: Date = .distantPast,
                url: URL? = nil,
                downloadSize: Measurement<UnitInformationStorage>? = nil)
    {
        self.token = token
        self.name = name
        self.oneLiner = oneLiner
        self.installedVersion = installedVersion
        self.latestVersion = latestVersion
        self.needsUpdate = needsUpdate
        self.dateInfoLastFilledOut = dateInfoLastFilledOut
        self.url = url
        self.downloadSize = downloadSize
    }
    
    
    // MARK: - Runtime state
    
    /// A runtime-only state tracking which stage of installation this app is in
    @NonCodable
    public var installationStage: InstallationStage = .atRest
}



public extension App {
    
    /// How long until we can consider the filled-out app info to be old enough to be expired?
    private static let appInfoExpirationInterval: TimeInterval = 60 * 60 * 24 * 7 * 2 // 2 weeks! 🙀
    
    /// `true` iff this app's info can still be considered up-to-date
    var isFilledOut: Bool {
        let secondsSinceInfoLastFilledOut = -dateInfoLastFilledOut.timeIntervalSinceNow
        return secondsSinceInfoLastFilledOut < Self.appInfoExpirationInterval
    }
}



public extension App {
    var isInstalled: Bool {
        nil != installedVersion
    }
    
    
    enum InstallationStage: String, HasDefaultValue {
        case atRest
        case installing
        case uninstalling
        
        
        public static let defaultValue = atRest
    }
}



// MARK: - Serialization

extension App: Codable {}



// MARK: - Comparison

extension App: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}



// MARK: - Hashable {

extension App: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.token)
    }
}



// MARK: - Identifiable

extension App: Identifiable {
    public var id: Int { hashValue }
}
