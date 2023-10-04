//
//  URL Extensions.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 11/25/21.
//

import Combine
import Foundation

import SimpleLogging



/// An array of all URL schemes (protocols) known to be secure
private let secureSchemes = ["https", "sftp", "ftps"]



public extension URL {
    
    /// Attempts to discover the size of the resource to which this URL points.
    ///
    /// - Returns: A publisher which will send the size to all subscribers once the size of the indicated resource has been found, or `nil` if it couldn't be found, or any error that might've occurred when trying to get the size
    func resourceSize() async throws -> Measurement<UnitInformationStorage>? {
        
        let request: URLRequest = {
            var request = URLRequest(url: self)
            request.httpMethod = "HEAD"
            return request
        }()
        
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.waitsForConnectivity = true
        let session = URLSession(configuration: config)
        
        let (_, response) = try await session.data(for: request)
        let contentLength = response.expectedContentLength
//        response."Content-Length"
//        log(verbose: response)
//        log(verbose: data)
        
        if contentLength == -1 {
            return nil
        }
        else {
            return Measurement<UnitInformationStorage>(value: .init(contentLength), unit: .bytes)
        }
    }
    
    
    /// Whether this URL represents a secure protocol, like HTTPS
    var isSecure: Bool {
        if let scheme = self.scheme?.lowercased() {
            return secureSchemes.contains(scheme)
        }
        else {
            return false
        }
    }
}
