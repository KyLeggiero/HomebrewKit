//
//  Loadable.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 9/12/21.
//

import Foundation
import CollectionTools



public enum Loadable<Value> {
    case cachedAndLoadingInTheBackground(cachedValue: Value, previousError: Error? = nil)
    case loadingButNoCache(errorSoFar: Error? = nil)
    case loaded(value: Value, lastError: Error? = nil)
    case failed(error: Error)
    
    public static var loadingButNoCache: Self { .loadingButNoCache() }
}



public extension Loadable {
    
    private mutating func _markAsLoading_basicImplementation() {
        switch self {
        case .cachedAndLoadingInTheBackground(cachedValue: _),
                .loadingButNoCache:
            return // already marked as loading
            
        case .loaded(let value, lastError: let error):
            self = .cachedAndLoadingInTheBackground(cachedValue: value, previousError: error)
            
        case .failed(error: let error):
            self = .loadingButNoCache(errorSoFar: error)
        }
    }
    
    
    mutating func markAsLoading() {
        self._markAsLoading_basicImplementation()
    }
    
    
    mutating func markAsLoading() where Value: Collection {
        var copy = whereEmptyCacheIsMarkedAsNoCache()
        copy._markAsLoading_basicImplementation()
        self = copy
    }
    
    
    func whereEmptyCacheIsMarkedAsNoCache() -> Self
    where Value: Collection {
        switch self {
        case .cachedAndLoadingInTheBackground(cachedValue: let cachedValue, previousError: let error) where cachedValue.isEmpty,
                .loaded(value: let cachedValue, lastError: let error) where cachedValue.isEmpty:
            return .loadingButNoCache(errorSoFar: error)
            
        case .cachedAndLoadingInTheBackground(cachedValue: _, previousError: _),
                .loadingButNoCache(errorSoFar: _),
                .loaded(value: _, lastError: _),
                .failed(error: _):
            return self
        }
    }
    
    
    mutating func markAsNoLongerLoading() where Value: CollectionWhichCanBeEmpty {
        switch self {
        case .cachedAndLoadingInTheBackground(cachedValue: let cachedValue, previousError: _):
            self = .loaded(value: cachedValue)
            
        case .loadingButNoCache:
            self = .loaded(value: .empty)
            
        case .loaded(value: _),
                .failed(error: _):
            // nothing to do
            break
        }
    }
    
    
    mutating func markAsNoLongerLoading(backupWhenNoValueCached: Value) {
        switch self {
        case .cachedAndLoadingInTheBackground(cachedValue: let cachedValue, previousError: _):
            self = .loaded(value: cachedValue)
            
        case .loadingButNoCache:
            self = .loaded(value: backupWhenNoValueCached)
            
        case .loaded(value: _),
                .failed(error: _):
            // nothing to do
            break
            
        }
    }
    
    
    mutating func clearError() {
        switch self {
        case .cachedAndLoadingInTheBackground(cachedValue: let cachedValue, previousError: _):
            self = .cachedAndLoadingInTheBackground(cachedValue: cachedValue)
            
        case .loadingButNoCache(errorSoFar: _):
            self = .loadingButNoCache()
            
        case .loaded(value: let value, lastError: _):
            self = .loaded(value: value)
            
        case .failed(error: _):
            self = .loadingButNoCache()
        }
    }
    
    
    var latestError: Error? {
        switch self {
        case .cachedAndLoadingInTheBackground(cachedValue: _, previousError: let error),
                .loadingButNoCache(errorSoFar: let error),
                .loaded(value: _, lastError: let error):
            return error
            
        case .failed(error: let error):
            return error
        }
    }
}



// MARK: - Passthrough conformance

extension Loadable: Sequence where Value: CollectionWhichCanBeEmpty {
    public typealias Iterator = Value.Iterator
    
    public func makeIterator() -> Value.Iterator {
        valueCollection.makeIterator()
    }
    
    
    fileprivate var valueCollection: Value {
        switch self {
        case .loadingButNoCache,
                .failed(error: _):
            return .empty
            
        case .cachedAndLoadingInTheBackground(cachedValue: let value, previousError: _),
                .loaded(value: let value, lastError: _):
            return value
        }
    }
}



extension Loadable: Collection where Value: CollectionWhichCanBeEmpty {
    
    public typealias Element = Value.Element
    
    public typealias Index = Value.Index
    
    
    
    public var startIndex: Value.Index {
        valueCollection.startIndex
    }
    
    
    public var endIndex: Value.Index {
        valueCollection.endIndex
    }
    
    
    public subscript(position: Value.Index) -> Value.Element {
        valueCollection[position]
    }
    
    
    public func index(after i: Value.Index) -> Value.Index {
        valueCollection.index(after: i)
    }
}



extension Loadable: BidirectionalCollection where Value: CollectionWhichCanBeEmpty, Value: BidirectionalCollection {
    public func index(before i: Value.Index) -> Value.Index {
        valueCollection.index(before: i)
    }
}



extension Loadable: RandomAccessCollection where Value: CollectionWhichCanBeEmpty, Value: RandomAccessCollection {
}



extension Loadable: MutableCollection where Value: CollectionWhichCanBeEmpty, Value: MutableCollection {
    public subscript(position: Value.Index) -> Value.Element {
        get {
            valueCollection[position]
        }
        set {
            valueCollection[position] = newValue
        }
    }
    
    
    fileprivate var valueCollection: Value {
        get {
            switch self {
            case .loadingButNoCache:
                return .empty
                
            case .cachedAndLoadingInTheBackground(cachedValue: let value, previousError: _),
                    .loaded(value: let value, lastError: _):
                return value
                
            case .failed(error: _):
                return .empty
            }
        }
        
        set {
            switch self {
            case .loadingButNoCache(errorSoFar: _) where newValue.isEmpty,
                    .failed(error: _):
                return // No change needed
                
                
            case .cachedAndLoadingInTheBackground(cachedValue: _, previousError: let previousErrors) where newValue.isEmpty:
                self = .loadingButNoCache(errorSoFar: previousErrors)
                
                
            case .loadingButNoCache(errorSoFar: let error),
                    .cachedAndLoadingInTheBackground(cachedValue: _, previousError: let error):
                self = .cachedAndLoadingInTheBackground(cachedValue: newValue, previousError: error)
                
                
            case .loaded(value: _, lastError: let lastError):
                self = .loaded(value: newValue, lastError: lastError)
            }
        }
    }
}



extension Loadable: RangeReplaceableCollection
where Value: CollectionWhichCanBeEmpty,
      Value: MutableCollection,
      Value: RangeReplaceableCollection
{
    @inline(__always)
    public init() {
        self = .loaded(value: .init())
    }
    
//    @inline(__always)
//    init(repeating repeatedValue: Element, count: Int) {
//        self = .loaded(value: .init(repeating: repeatedValue, count: count))
//    }
//
//    @inline(__always)
//    init<S>(_ elements: S) where S : Sequence, Element == S.Element {
//        self = .loaded(value: .init(elements))
//    }
//
//    @inline(__always)
//    mutating func append(_ newElement: Element) {
//        valueCollection.append(newElement)
//    }
//
//    @inline(__always)
//    mutating func append<S>(contentsOf newElements: S) where S : Sequence, Element == S.Element {
//        valueCollection.append(contentsOf: newElements)
//    }
//
//    @inline(__always)
//    mutating func insert(_ newElement: Element, at i: Index) {
//        valueCollection.insert(newElement, at: i)
//    }
//
//    @inline(__always)
//    mutating func insert<S>(contentsOf newElements: S, at i: Index) where S : Collection, Element == S.Element {
//        valueCollection.insert(contentsOf: newElements, at: i)
//    }
//
//    @inline(__always)
//    mutating func remove(at i: Index) -> Element {
//        valueCollection.remove(at: i)
//    }
//
//    @inline(__always)
//    mutating func removeFirst() -> Value.Element {
//        valueCollection.removeFirst()
//    }
//
//    @inline(__always)
//    mutating func removeAll(keepingCapacity keepCapacity: Bool) {
//        valueCollection.removeAll(keepingCapacity: keepCapacity)
//    }
//
//    @inline(__always)
//    mutating func removeAll(where shouldBeRemoved: (Value.Element) throws -> Bool) rethrows {
//        try valueCollection.removeAll(where: shouldBeRemoved)
//    }

    @inline(__always)
    public mutating func replaceSubrange<C>(
        _ subrange: Range<Value.Index>,
        with newElements: C)
    where C : Collection, Value.Element == C.Element {
        valueCollection.replaceSubrange(subrange, with: newElements)
    }

//    @inline(__always)
//    mutating func reserveCapacity(_ n: Int) {
//        valueCollection.reserveCapacity(n)
//    }
//
//    @inline(__always)
//    subscript(bounds: Range<Value.Index>) -> Slice<Value> {
//        valueCollection[bounds]
//    }
//
//    @inline(__always)
//    subscript(bounds: Index) -> Element {
//        valueCollection[bounds]
//    }
}
