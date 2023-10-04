//
//  HomebrewCliApp.swift
//  Homebrew App Store
//
//  Created by Test User on 9/13/21.
//

import Combine
import Foundation
import SwiftUI

import CollectionTools
import FunctionTools
import OptionalTools
import SerializationTools
import SimpleLogging
import SwiftyUserDefaults



private var cancellables = Set<AnyCancellable>()
private let brewCommand = "/usr/local/bin/brew"



/// A way to interface with the Homebrew CLI
public struct Homebrew {
    fileprivate let cli = CLI()
    
    public init() {}
}



// MARK: - Core operations

private extension Homebrew {
    
    
//    /// Creates a new process which is dedicated to run Homebrew with the given arguments
//    ///
//    /// - Parameter arguments: The arguments to send to the Homebrew CLI. So, passing `["foo", "bar"]` would be like typing `brew foo bar` into the command line.
//    /// - Returns: The process you requested
//    func newBrewProcess(arguments: [String]) -> Process {
//        cli.newProcess(command: brewCommand, arguments: arguments)
//    }
    
    
    /// Returns the output given by running Homebrew with the given arguments
    ///
    /// - Parameter arguments: The arguments to send to the Homebrew CLI. So, passing `["foo", "bar"]` would be like typing `brew foo bar` into the command line.
    /// - Returns: The data you requested
    func brewOutput(for arguments: [String]) async throws -> Data? {
        try await cli.output(command: brewCommand, arguments: arguments)
    }
    
    
    /// Returns the output given by running Homebrew with the given arguments
    ///
    /// - Parameter arguments: The arguments to send to the Homebrew CLI. So, passing `["foo", "bar"]` would be like typing `brew foo bar` into the command line.
    ///
    /// - Returns: The string you requested
    func brewOutput(for arguments: [String]) async throws -> String? {
        try await cli.output(encoding: .utf8, command: brewCommand, arguments: arguments)
    }
    
    
    /// Returns the output given by running Homebrew with the given arguments, split into substrings by newline characters
    ///
    /// - Parameter arguments: The arguments to send to the Homebrew CLI. So, passing `["foo", "bar"]` would be like typing `brew foo bar` into the command line.
    /// - Returns: The strings you requested
    func brewOutputLines(for arguments: [String]) async throws -> [Substring] {
        try await cli.outputLines(command: brewCommand, arguments: arguments)
    }
    
    
    /// Streams the output given by running Homebrew with the given arguments to a publisher
    ///
    /// - Parameter arguments: The arguments to send to the Homebrew CLI. So, passing `["foo", "bar"]` would be like typing `brew foo bar` into the command line.
    /// - Returns: A publisher which publishes the data you requested
    func brew(_ arguments: [String]) async throws -> Data? {
        try await cli.run(command: brewCommand, arguments: arguments)
    }
    
    
    /// Streams the output given by running Homebrew with the given arguments to a publisher
    ///
    /// - Parameter arguments: The arguments to send to the Homebrew CLI. So, passing `["foo", "bar"]` would be like typing `brew foo bar` into the command line.
    /// - Returns: A publisher which publishes the data you requested
    @inline(__always)
    func brew(_ arguments: String...) async throws -> Data? { try await brew(arguments) }
    
    
    /// Streams the output given by running Homebrew with the given arguments to a publisher
    ///
    /// - Parameter arguments: The arguments to send to the Homebrew CLI. So, passing `["foo", "bar"]` would be like typing `brew foo bar` into the command line.
    /// - Returns: A publisher which publishes the strings you requested
    func brew(_ arguments: [String]) async throws -> String? {
        try await cli.run(encoding: .utf8, command: brewCommand, arguments: arguments)
    }
    
    
    /// Streams the output given by running Homebrew with the given arguments to a publisher
    ///
    /// - Parameter arguments: The arguments to send to the Homebrew CLI. So, passing `["foo", "bar"]` would be like typing `brew foo bar` into the command line.
    /// - Returns: A publisher which publishes the strings you requested
    func brew(_ arguments: String...) async throws -> String? {
        try await cli.run(command: brewCommand, arguments: arguments)
    }
    
    
    
    typealias BrewOutputDataPublisher = CLI.OutputDataPublisher
    typealias BrewOutputStringsPublisher = CLI.OutputStringsPublisher
}



// MARK: - Sync

public extension Homebrew {
    
    /// Immediately updates/syncs the local cache of Homebrew to match the package servers. This is a thread-blocking call.
    func update() async {
        _ = try? await brewOutput(for: ["update"]) as Data?
    }
}



// MARK: - Getting info about apps

public extension Homebrew {
    
    /// Lists all apps which are currently installed by Homebrew
    func listInstalledApps() async throws -> [App] {
        try await brewOutputLines(for: ["list", "--casks"])
            .map { App(token: .init($0)) }
    }
    
    
    /// Lists all apps which Homebrew offers, whether or not they're installed
    ///
    /// - Parameter forceClearCache: When `true`, clears the cache, performs a new search, caches those results, and returns those results.
    ///                              When `false`, this might use the cache if it's not expired; else it'll act as if this is `true`.
    ///                              Defaults to `false`
    func listAllApps(forceClearCache: Bool = false) async throws -> [App] {
//        let lines = try brewOutputLines(for: ["casks"])
        Defaults.cachedStoreContents.apps
        let lines = try await brewOutputLines(for: ["search", "--quiet", "--casks", "\"\""]).dropFirst()
        log(verbose: "brew casks\n\t" + lines.joined(separator: "\n\t"))
        return lines
            .map { App.init(token: .init($0)) }
    }
    
    
    func fillOutInfo(for app: inout App) async throws {
        defer {
            app.dateInfoLastFilledOut = Date()
        }
        
        let appInfo: HomebrewAppJson
        
        do {
            guard let jsonData: Data = try await brewOutput(for: ["info", "--casks", "--json=v2", app.token]) else {
                log(warning: "No info about cask '\(app.token)'")
                return
            }
            
            appInfo = try HomebrewAppJson(jsonData: jsonData)
        }
        catch {
            log(error: error)
            throw error
        }
        
        func fillOut(for cask: HomebrewAppJson.Cask) async {
            if let firstName = cask.name.first {
                app.name = firstName
            }
            
            app.installedVersion = cask.installed
            app.latestVersion = cask.version
            app.needsUpdate = cask.outdated
            
            do {
                app.downloadSize = try await cask.url?.resourceSize() ?? nil
            }
            catch {
                log(error: error, "Failed to read download size")
            }
        }
        
        
        func fillOut(for formula: HomebrewAppJson.Formula) {
            app.name = formula.name
            app.installedVersion = formula.installed.first?.stable
            app.needsUpdate = formula.outdated
            
            switch formula.versions {
            case .left(let array):
                app.latestVersion = array.first?.stable
                
            case .right(_): // What does a `VersionsObject` look like?
                break // Nothing to do yet 🤔
            }
        }
        
        
        if let cask = appInfo.casks?.first(where: { $0.token == app.token }) {
            await fillOut(for: cask)
        }
        else if let formula = appInfo.formulae?.first(where: { $0.name == app.token }) {
            fillOut(for: formula)
        }
        else if let cask = appInfo.casks?.first {
            await fillOut(for: cask)
        }
        else if let formula = appInfo.formulae?.first {
            fillOut(for: formula)
        }
        else {
            assertionFailure("No matching cask for app: couldn't find match in \(appInfo.casks ?? [])")
        }
    }
}



// MARK: - Installing apps

public extension Homebrew {
    
//    private static var installPublishers = Set<AnyCancellable>()
    
    
    private func _installLikeCommand(_ command: String, token: String) async {
        let _: String? = try? await brew(command, token)
    }
    
    
    @inline(__always)
    func install(appWithToken token: String) async {
        await _installLikeCommand("install", token: token)
    }
    
    
    @inline(__always)
    func install(_ app: App) async { await install(appWithToken: app.token) }
    
    
    @inline(__always)
    func uninstall(appWithToken token: String) async {
        await _installLikeCommand("uninstall", token: token)
    }
    
    
    @inline(__always)
    func uninstall(_ app: App) async { await uninstall(appWithToken: app.token) }
    
    
    /// Upgrades the app with the given token to the latest version
    @inline(__always)
    func upgrade(appWithToken token: String) async {
        await _installLikeCommand("upgrade", token: token)
    }
    
    
    /// Upgrades the given app to the latest version
    @inline(__always)
    func upgrade(_ app: App) async { await upgrade(appWithToken: app.token) }
    
    
    
    // typealias InstallationProgressPublisher = AnyPublisher<InstallationProgress, InstallationError>
    
    
    
//    /// Notes the progress of an installation process
//    enum InstallationProgress {
//
//        /// The installation process is still starting up; nothing is being installed yet
//        case starting
//
//        /// The installation process is ongoing
//        case installing
//
//        /// The installation process has completed
//        case done
//    }
    
    
    
    /// An error which occurred during installation
    enum InstallationError: Error {
        case other(Error)
    }
}
