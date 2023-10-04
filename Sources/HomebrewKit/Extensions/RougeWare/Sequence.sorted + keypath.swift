//
//  Sequence.sorted + keypath.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 11/13/21.
//

import Foundation



public extension Sequence {
    func sorted<Field>(by field: KeyPath<Element, Field>) -> [Element]
    where Field: Comparable {
        self.sorted(by: { $0[keyPath: field] > $1[keyPath: field] })
    }
}
