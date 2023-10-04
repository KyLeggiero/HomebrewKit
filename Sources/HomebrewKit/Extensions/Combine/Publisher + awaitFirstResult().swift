//
//  Publisher + awaitFirstResult().swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 11/25/21.
//

import Combine
import Foundation

import SimpleLogging



var logInstances = UInt()



public extension Publisher {
    
    /// Blocks this thread to collect all output, then returns it. **If the publisher never completes, this never returns!** If the publisher fails, that failure is thrown.
    /// - Returns: All output this publisher sends
    /// - Throws: If the publisher fails, its faiure error is thrown
    func blockAndCollectAllOutput() throws -> [Output] {
        let semaphore = DispatchSemaphore(value: 0)
        var failure: Failure?
        var outputs = [Output]()
        
        let thisInstance = logInstances
        logInstances += 1
        
        let sink = sink { completion in
                switch completion {
                case .failure(let cause):
                    log(error: "\(thisInstance): \t Failed")
                    log(error: cause)
                    failure = cause
                    
                case .finished:
                    log(verbose: "\(thisInstance): \t Finished cleanly")
                    break
                }
            
            log(verbose: "\(thisInstance): Signaling...")
                semaphore.signal()
            }
            receiveValue: { value in
                log(verbose: "\(thisInstance): \t Appending...")
                outputs.append(value)
            }
        
        defer {
            log(verbose: "\(thisInstance): Cleaning up...")
            sink.cancel()
        }
        
        log(verbose: "\(thisInstance): Waiting...")
        semaphore.wait()
        log(verbose: "\(thisInstance): Received signal")
        
        
        if let failure = failure {
            throw failure
        }
        else {
            return outputs
        }
    }
    
    
    func awaitFirstResult() -> Output
    where Failure == Never
    {
        let semaphore = DispatchSemaphore(value: 0)
        var output: Output?
        
        let sink = first().sink { value in
            output = value
            semaphore.signal()
        }
        
        semaphore.wait()
        
        defer {
            sink.cancel()
        }
        
        return output!
    }
}
