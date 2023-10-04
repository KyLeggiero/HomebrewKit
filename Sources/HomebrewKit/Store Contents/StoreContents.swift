//
//  StoreContents.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 9/12/21.
//

import Foundation

import SwiftyUserDefaults
import CollectionTools



public struct StoreContents {
    
    @Content
    public var apps: [App]
    
    
    init(apps: [App]) {
        self._apps = .init(wrappedValue: apps)
    }
    
    
    
    @propertyWrapper
    public struct Content<WrappedValue: Codable>: Codable {
        public var wrappedValue: WrappedValue
        public var lastCacheDate: Date
        
        
        public init(wrappedValue: WrappedValue, lastCacheDate: Date = .init()) {
            self.wrappedValue = wrappedValue
            self.lastCacheDate = lastCacheDate
        }
    }
}



// MARK: - Searching

extension StoreContents: Searchable {
    public func searched(with query: String) -> Searched<StoreContents> {
        if query.isEmpty {
            return .noSearch(originalValue: self)
        }
        else {
            let lowercasedQuery = query.lowercased()
            
            let filtered = Self(apps: self.apps.filter {
                $0.token.lowercased().contains(lowercasedQuery)
            })
            
            if filtered.apps.isEmpty {
                return .noResults
            }
            else {
                return .resultsFound(results: filtered)
            }
        }
    }
}



// MARK: - Serialization

extension StoreContents: DefaultsSerializable, Codable {
    public static var _defaults: DefaultsCodableBridge<Self> { return DefaultsCodableBridge() }
    public static var _defaultsArray: DefaultsCodableBridge<[Self]> { return DefaultsCodableBridge() }
}



// MARK: - Caching

internal extension StoreContents {
    static var cached: Self {
        get { Defaults.cachedStoreContents }
        set { Defaults.cachedStoreContents = newValue }
    }
}



internal extension DefaultsKeys {
    var cachedStoreContents: DefaultsKey<StoreContents> {
        return .init("StoreContents.cached", defaultValue: .empty)
    }
}



// MARK: - Collection

extension StoreContents: MutableCollection {
    
    public typealias __Basis = [App]
    public typealias Element = __Basis.Element
    public typealias Index = __Basis.Index
    
    
    @inline(__always)
    public var startIndex: __Basis.Index { apps.startIndex }
    
    @inline(__always)
    public var endIndex: __Basis.Index { apps.endIndex }
    
    @inline(__always)
    public subscript(position: __Basis.Index) -> __Basis.Element {
        get {
            apps[position]
        }
        
        set {
            apps[position] = newValue
        }
    }
    
    public func index(after i: __Basis.Index) -> __Basis.Index { apps.index(after: i) }
}



extension StoreContents: CollectionWhichCanBeEmpty {
    public init() {
        self.init(apps: .empty)
    }
}



extension StoreContents: BidirectionalCollection {
    public func index(before i: __Basis.Index) -> __Basis.Index {
        apps.index(before: i)
    }
}



extension StoreContents: RandomAccessCollection {}



extension StoreContents: RangeReplaceableCollection {
    public mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C : Collection, Element == C.Element {
        apps.replaceSubrange(subrange, with: newElements)
    }
}



// MARK: - Debugging

#if DEBUG
public extension Array where Element == App {
    static let demo =
            (1...64)
                .compactMap(formatter.string)
                .map { appId in
                    App(token: appId)
                }
    
    
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter
    }()
}



public extension StoreContents {
    static var demo: Self { Self(apps: .demo) }
}
#endif
