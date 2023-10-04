//
//  NonCodable.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 12/23/21.
//

import Foundation



/// Marks a field as not being a member of encoding nor decoding; it is only to be used at runtime and not serialized.
/// When its parent type is encoded, this field is skipped. When it's decoded, this is initialized to its default value.
@propertyWrapper
public struct NonCodable<Value: HasDefaultValue> {
    
    /// The runtime-only value to neither be encoded nor decoded
    public var wrappedValue: Value
    
    
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}



extension NonCodable: Encodable {
    public func encode(to encoder: Encoder) throws {
        return
    }
}



extension NonCodable: Decodable {
    public init(from decoder: Decoder) throws {
        self.init(wrappedValue: .defaultValue)
    }
}
