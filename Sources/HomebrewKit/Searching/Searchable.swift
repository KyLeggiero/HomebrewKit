//
//  Searchable.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 9/12/21.
//

import Foundation



/// A type which can be searched
public protocol Searchable {
    
    /// The type of query that can search this type
    associatedtype Query
    
    
    /// Searches this instance and returns a copy that has been searched
    /// - Parameter query: The query which will search this instance
    /// - Returns: A version of this instance which has been searched with `query`
    func searched(with query: Query) -> Searched<Self>
}



/// The result of a search
public enum Searched<Value> {
    
    /// Nothing matched the search query
    case noResults
    
    /// The query matched some results
    /// - Parameter results: The results of the search; only the values which matched the query
    case resultsFound(results: Value)
    
    /// No search has been performed at all
    /// - Parameter originalValue: The unfiltered value without performing a search
    case noSearch(originalValue: Value)
}



// MARK: - Transparent conformance

// MARK: Optional

public extension Optional where Wrapped: Searchable {
    func searched(with query: Wrapped.Query) -> Optional<Searched<Wrapped>> {
        switch self {
        case .some(let value):
            switch value.searched(with: query) {
            case .noResults:
                return .some(.noResults)
                
            case .resultsFound(results: let results):
                return .some(.resultsFound(results: results))
                
            case .noSearch(originalValue: let original):
                return .some(.noSearch(originalValue: original))
            }
            
        case .none:
            return .none
        }
    }
}



// MARK: Loadable

public extension Loadable where Value: Searchable {
    func searched(with query: Value.Query) -> Loadable<Searched<Value>> {
        switch self {
        case .loadingButNoCache:
            return .loadingButNoCache
            
        case .cachedAndLoadingInTheBackground(cachedValue: let cachedValue, previousError: _):
            switch cachedValue.searched(with: query) {
            case .noResults:
                return .cachedAndLoadingInTheBackground(cachedValue: .noResults)
                
            case .resultsFound(results: let results):
                return .cachedAndLoadingInTheBackground(cachedValue: .resultsFound(results: results))
                
            case .noSearch(originalValue: let original):
                return .cachedAndLoadingInTheBackground(cachedValue: .noSearch(originalValue: original))
            }
            
        case .loaded(value: let value, lastError: _):
            switch value.searched(with: query) {
            case .noResults:
                return .loaded(value: .noResults)
                
            case .resultsFound(results: let results):
                return .loaded(value: .resultsFound(results: results))
                
            case .noSearch(originalValue: let original):
                return .loaded(value: .noSearch(originalValue: original))
            }
            
        case .failed(error: let error):
            return .failed(error: error)
        }
    }
}
