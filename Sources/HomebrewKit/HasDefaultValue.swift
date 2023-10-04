//
//  HasDefaultValue.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 12/23/21.
//

import Foundation



/// A type which has a default value: some instance of this type which is appropriate as a backup or first-time value in most circumstances
public protocol HasDefaultValue {
    
    /// The default value of this type
    static var defaultValue: Self { get }
}
