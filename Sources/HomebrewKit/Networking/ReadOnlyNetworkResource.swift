//
//  NetworkResource.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 11/21/21.
//

import Combine
import Foundation

import OptionalTools
import SimpleLogging



/// A read-only network resource. That is, a value that is stored somewhere on the Internet which is meant to be read by this client, not modified by this client in any way.
///
/// This is meant to be a very simple one-size-fits-all solution to having a single value you want to fetch. If you need more advanced behavior, you should use more advanced solutions.
///
/// One behavior to note is that this will retry an attempt to fetch the given resource indefinitely until it receives a success. Retry attempts will automatically be spaced farther apart the more times a retry fails, up to 1 minute. That is to say, if this attempts to fetch the resource and fails, it will wait up to a minute to retry, but it will always retry. This behavior is independent of the refresh interval; it will happen regardless of what you set that to. If you do set a refresh interval, then that value will only be used after a successful fetch.
///
/// It's also worth noting that this will never attempt to fetch the resource more often than once per second, even if you set the refresh interval to be less than 1 second.
@propertyWrapper
public final class ReadOnlyNetworkResource<Resource: Codable>: ObservableObject {
    
    public private(set) var wrappedValue: Resource? { // Only updated from `setLatestUpdate`
        didSet {
            saveValueIntoCache(wrappedValue)
        }
    }
    
    public private(set) var updateFeed: UpdateFeed! // Auto updated; do not manually update
    
    private let id = UUID()
    
    private let source: URL
    
    private let refershInterval: TimeInterval?
    
    private let cachingPolicy: CachingPolicy
    
    @Published
    private var latestUpdate: Loadable<Update> = .loadingButNoCache // Only updated from `setLatestUpdate`
    
    private let updateQueue: DispatchQueue
    
    
    /// Creates a property wrapper for a read-only network resource
    ///
    /// - Note: See the `ReadOnlyNetworkResource` type documentation for behavior details
    ///
    /// - Parameters:
    ///   - source:          The URL where the resource can be found
    ///   - cachingPolicy:   _optional_ - How to cache this resource. Defaults to `.cacheInUserDefaults` using standard user defaults and the given URL as the key
    ///   - refreshInterval: _optional_ - How often to check the given URL to see if the resource has changed. `nil` means to only check once* when the value is initialized. If a non-nil value is set, this will never check more often than once per second, so any value less than `1` will be changed to `1`. Defaults to `nil`.
    public init(source: URL,
                cachingPolicy: CachingPolicy,
                refreshInterval: TimeInterval? = nil)
    {
        self.source = source
        self.cachingPolicy = cachingPolicy
        self.refershInterval = refreshInterval.map { max(1, $0) }
        
        self.updateQueue = DispatchQueue(label: "Update queue for \(ReadOnlyNetworkResource.self) \(id)")
        self.updateFeed = $latestUpdate.compactMap { loadable in
            switch loadable {
            case .loadingButNoCache(errorSoFar: _),
                    .failed(error: _):
                return .none
                
            case .cachedAndLoadingInTheBackground(cachedValue: let update, previousError: _),
                    .loaded(value: let update, lastError: _):
                return .some(update)
            }
        }
        .eraseToAnyPublisher()
        
        self.wrappedValue = loadValueFromCache()
        
        
        beginUpdating()
    }
    
    
    /// Creates a property wrapper for a read-only network resource
    ///
    /// - Note: See the `ReadOnlyNetworkResource` type documentation for behavior details
    ///
    /// - Parameters:
    ///   - source:          The URL where the resource can be found
    ///   - cachingPolicy:   _optional_ - How to cache this resource. Defaults to `.cacheInUserDefaults` using standard user defaults and the given URL as the key
    ///   - refreshInterval: _optional_ - How often to check the given URL to see if the resource has changed. `nil` means to only check once* when the value is initialized. If a non-nil value is set, this will never check more often than once per second, so any value less than `1` will be changed to `1`. Defaults to `nil`.
    public convenience init(source: URL,
                            refreshInterval: TimeInterval? = nil)
    {
        self.init(source: source,
                  cachingPolicy: .cacheInUserDefaults(key: source.description),
                  refreshInterval: refreshInterval)
    }
    
    
    /// Creates a property wrapper for a read-only network resource
    ///
    /// - Note: See the `ReadOnlyNetworkResource` type documentation for behavior details
    ///
    /// - Parameters:
    ///   - source:          A string representing the URL where the resource can be found
    ///   - cachingPolicy:   _optional_ - How to cache this resource. Defaults to `.cacheInUserDefaults` using standard user defaults and the given URL as the key
    ///   - refreshInterval: _optional_ - How often to check the given URL to see if the resource has changed. `nil` means to only check once* when the value is initialized. If a non-nil value is set, this will never check more often than once per second, so any value less than `1` will be changed to `1`. Defaults to `nil`.
    public convenience init(source: StaticString,
                            cachingPolicy: CachingPolicy,
                            refreshInterval: TimeInterval? = nil)
    {
        self.init(source: URL(string: source.description)!,
                  cachingPolicy: cachingPolicy,
                  refreshInterval: refreshInterval)
    }
    
    
    /// Creates a property wrapper for a read-only network resource
    ///
    /// - Note: See the `ReadOnlyNetworkResource` type documentation for behavior details
    ///
    /// - Parameters:
    ///   - source:          A string representing the URL where the resource can be found
    ///   - cachingPolicy:   _optional_ - How to cache this resource. Defaults to `.cacheInUserDefaults` using standard user defaults and the given URL as the key
    ///   - refreshInterval: _optional_ - How often to check the given URL to see if the resource has changed. `nil` means to only check once* when the value is initialized. If a non-nil value is set, this will never check more often than once per second, so any value less than `1` will be changed to `1`. Defaults to `nil`.
    public convenience init(source: StaticString,
                            refreshInterval: TimeInterval? = nil)
    {
        self.init(source: URL(string: source.description)!,
                   refreshInterval: refreshInterval)
    }
}



public extension ReadOnlyNetworkResource {
    
    /// Signifies an error that occurred while fetching the resource
    enum UpdateError: Error {
        
        /// Thrown when the resource at the given URL was successfully found and downloaded, but when attempting to decode it, an error occurred.
        case successfulDownloadButDecodeFailed(cause: Error)
        
        /// Some unexpected error occurred
        case other(cause: Error)
    }
}



public extension ReadOnlyNetworkResource {
    
    enum CachingPolicy {
        case doNotCache
        case cacheInUserDefaults(instance: UserDefaults = .standard, key: String)
    }
}



// MARK: - Update Feed

public extension ReadOnlyNetworkResource {
    
    /// The value that encapsulates an update that's sent through the update feed
    typealias Update = Result<Resource, UpdateError>
    
    /// The type of publisher which will provide a feed describing updates which this network resource receives
    typealias UpdateFeed = AnyPublisher<Update, Never>
}



// MARK: - Background updates

private extension ReadOnlyNetworkResource {
    
    /// Tells this subsystem to begin updating in the background
    func beginUpdating() {
        enqueueBackgroundUpdate()
    }
    
    
    /// Asynchronously sets the latest update to the given successfully-decoded resource and performs any necessary ceremony as well
    ///
    /// - Note: This sets the value using the main queue
    ///
    /// - Parameter newValue: The successfully-decoded resource
    private func setLatestUpdate(_ newValue: Resource) {
        DispatchQueue.main.async {
            log(info: "Successfully updated resource")
            self.latestUpdate = .loaded(value: .success(newValue))
            self.wrappedValue = newValue
        }
    }
    
    
    /// Asynchronously sets the latest update to the given error and performs any necessary ceremony as well
    ///
    /// - Note: This sets the value using the main queue
    ///
    /// - Parameter error: The error describing why the resource could not be fetched
    func setLatestUpdate(_ error: UpdateError) { // FIXME: no longer required?
        DispatchQueue.main.async {
            log(error: error)
            switch self.latestUpdate {
            case .cachedAndLoadingInTheBackground(cachedValue: let previous, previousError: _):
                self.latestUpdate = .cachedAndLoadingInTheBackground(cachedValue: previous, previousError: error)
                
            case .failed(error: _),
                    .loadingButNoCache(errorSoFar: _):
                self.latestUpdate = .failed(error: error)
                
            case .loaded(value: _, lastError: _):
                self.latestUpdate = .failed(error: error)
            }
        }
    }
    
    
    /// Enqueues a new update in the background, optionally after a given delay
    ///
    /// - Parameter delay: _optional_ - How long to wait before attempting to update the resource. `nil` signifies to not wait at all. Defaults to `nil`
    func enqueueBackgroundUpdate(after delay: TimeInterval? = nil) {
        
        func updateNow() {
            log(verbose: "Updating...")
            
            do {
                self.setLatestUpdate(try Resource(jsonData: try Data(contentsOf: self.source)))
                
                
                if let refreshInterval = self.refershInterval {
                    log(verbose: "Will refresh \(refreshInterval) seconds from now...")
                    self.enqueueBackgroundUpdate(after: max(1, refreshInterval))
                }
            }
            catch {
                self.setLatestUpdate(.other(cause: error))
                self.enqueueBackgroundUpdate(after: min(60, (delay ?? 1) * 1.1))
            }
        }
        
        
        if let delay = delay {
            log(verbose: "Delaying background update for \(delay) seconds")
            updateQueue.asyncAfter(deadline: DispatchTime.now() + delay, execute: updateNow)
            log(verbose: "Update delay-enqueued")
        }
        else {
            log(verbose: "Enqueuing background update right now")
            updateQueue.async(execute: updateNow)
            log(verbose: "Update enqueued")
        }
    }
}



// MARK: - Caching

private extension ReadOnlyNetworkResource {
    
    func saveValueIntoCache(_ newValue: Resource?) {
        guard let newValue = newValue else {
            return
        }
        
        do {
            switch cachingPolicy {
            case .doNotCache: return
            case .cacheInUserDefaults(instance: let instance, key: let key):
                instance.set(try newValue.jsonData(), forKey: key)
            }
        }
        catch {
            log(error: error)
            assertionFailure()
        }
    }
    
    
    func loadValueFromCache() -> Resource? {
        do {
            switch cachingPolicy {
            case .doNotCache: return nil
            case .cacheInUserDefaults(instance: let instance, key: let key):
                if let cachedData = instance.data(forKey: key) {
                    return try Resource(jsonData: cachedData)
                }
                else {
                    return nil
                }
            }
        }
        catch {
            log(error: error)
            assertionFailure()
            
            return nil
        }
    }
}
