//
//  CLI.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 1/3/22.
//

import Combine
import SwiftUI

import CollectionTools
import SpecialString
import SimpleLogging
import SerializationTools



/// A Swifty abstraction of a command-line interface
public struct CLI {
    
    /// The serial queue which guarantees commands are executed in order without conflicts
    private let commandQueue = CommandQueue()
    
    /// The command processor (e.g. Bash or Zsh)
    private let commandProcessorPath: CommandProcessor
    
    
    public init(commandProcessorPath: CommandProcessor = .zsh) {
        self.commandProcessorPath = commandProcessorPath
    }
}



// MARK: - CommandProcessor

public extension CLI {
    
    /// Processes command-line commands
    struct CommandProcessor {
        
        /// The path to the processor, like `"/bin/bash"` or `"/bin/zsh"`
        public let path: String
        
        /// The argument to pass to the command processor execuable which tells it to treat further arguments as a command and its arguments to be processed, like `"-c"` with `bash -c`. If this processor doesn't need an argument and just treats all arguments as commands, set this to `nil`
        public let executionArgument: String?
    }
}



public extension CLI.CommandProcessor {
    static let zsh = Self(path: "/bin/zsh", executionArgument: "-c")
    
    @inline(__always)
    static var `default`: Self { .zsh }
}



// MARK: - CommandQueue

private extension CLI {
    
    /// Processes command-line commands
    struct CommandQueue {
        let _backingQueue = OperationQueue()
        
        init() {
            self._backingQueue.qualityOfService = .userInitiated
        }
    }
}



private extension CLI.CommandQueue {
    final class CommandOperation: Foundation.Operation {
        let cli: CLI
        let command: String
        let arguments: [String]
        private(set) var result: Result?
        
        
        init(cli: CLI,
             command: String,
             arguments: [String])
        {
            self.cli = cli
            self.command = command
            self.arguments = arguments
        }
        
        
        override func main() {
            do {
                result = .success(try _runImmediately())
            }
            catch let error as Error {
                result = .failure(error)
            }
            catch {
                result = .failure(.other(error))
            }
        }
        
        
        private func _runImmediately() throws -> Data? {
            try cli._runImmediately(command: command, arguments: arguments)
        }
        
        
        typealias Result = Swift.Result<Data?, CLI.CommandQueue.CommandOperation.Error>
        
        
        
        enum Error: Swift.Error {
            case noResultAfterRunning
            case other(Swift.Error)
        }
    }
}



fileprivate extension CLI.CommandQueue {
    func enqueue(in cli: CLI, command: String, arguments: [String]) async throws -> Data? {
        let operation = CommandOperation(cli: cli, command: command, arguments: arguments)
        return try await withCheckedThrowingContinuation { continuation in
            operation.completionBlock = {
                guard let result = operation.result else {
                    return continuation.resume(with: .failure(CommandOperation.Error.noResultAfterRunning))
                }
                
                continuation.resume(with: result)
            }
            
            _backingQueue.addOperation(operation)
        }
    }
}



// MARK: - Core operations

private extension CLI {
    
    /// Creates a new process which is designed to run commands on behalf of the user
    func newProcess() -> Process {
        let process = Process()
        process.qualityOfService = .userInteractive
        return process
    }
    
    /// Creates a new process which is dedicated to run the given command with the given arguments
    ///
    /// - Parameters:
    ///   - commandProcessorPath: _optional_ - A path to the command processor of your choice. Defaults
    ///   - command:              The command to run, like `"brew"` or `"echo`
    ///   - arguments:            All arguments to send to the given command via CLI
    /// - Returns: A new process prepared to run the given command & its arguments
    func newProcess(command: String, arguments: [String]) -> Process {
        let process = newProcess()
        //        process.launchPath = commandProcessorPath
        //        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/brew").resolvingSymlinksInPath()
        //        process.arguments = arguments
        
        //        process.launchPath = NSHomeDirectory()
        process.executableURL = URL(fileURLWithPath: commandProcessorPath.path)
        process.arguments = (commandProcessorPath.executionArgument.map { [$0] } ?? [])
        + [([command] + arguments).joined(separator: " ")]
        
        return process
    }
    
    
    /// Streams the output given by running the given command with the given arguments to a publisher
    ///
    ///  This operates by running the given command on the CLI. So, passing `"command"` for the command and `["--foo", "bar"]`for the arguments would be like typing `command --foo bar` into the command line.
    ///
    /// - Parameters:
    ///   - command:   The command to run
    ///   - arguments: The arguments to send to the given command via its CLI
    ///
    /// - Returns: A publisher which publishes the data that the given command sends to the standard output
    func _runImmediately(command: String, arguments: [String]) throws -> Data? {
        log(verbose: "\(command) \(arguments.joined(separator: " "))")
        defer { logExit() }
        
        let process = newProcess(command: command, arguments: arguments)
        let readPipe = Pipe()
        process.standardOutput = readPipe
        
        
        
        log(verbose: " \t\(command) – About to run")
        
        do {
            try process.run()
            log(verbose: " \t\(command) – Running")
            
            var unsafePipeBuffer = Data(capacity: 1024)
            var errorToThrow: Error? = nil
            let semaphore = DispatchSemaphore.default
            
            DispatchQueue(label: "Read queue for \(command) (\(Date())", qos: .userInteractive).async {
                defer {
                    semaphore.signal()
                }
                
                log(verbose: " \t\(command) – Reading from pipe...")
                do {
                    while let x = try readPipe.fileHandleForReading.read(upToCount: 1024 * 1024) {
                        log(verbose: " \t\(command) –  +\(x.count) bytes...")
                        unsafePipeBuffer.append(x)
                    }
                    log(verbose: " \t\(command) – Done reading \(unsafePipeBuffer.count) bytes from pipe")
                }
                catch {
                    log(error: error)
                    errorToThrow = error
                    return
                }
            }
            
            if let errorToThrow {
                throw errorToThrow
            }
            
            process.waitUntilExit()
            semaphore.wait()
            log(verbose: " \t\(command) – Done running")
            
            if let outputData = unsafePipeBuffer.nonEmptyOrNil {
                log(verbose: " \t\(command) – Done running - got \(outputData.count) bytes of output")
                return outputData
            }
            else {
                log(verbose: " \t\(command) – Done running - no output")
                // Read nothing and threw nothing? OK; empty output
                return nil
            }
        }
        catch {
            log(error: error)
            throw error
        }
    }
    
    
    private func enqueue(command: String, arguments: [String]) async throws -> Data? {
        try await commandQueue.enqueue(in: self, command: command, arguments: arguments)
    }
}



public extension CLI {
    
    func run(command: String, arguments: [String]) async throws -> Data? {
        try await enqueue(command: command, arguments: arguments)
    }
    
    
    /// Streams the output given by running the given command with the given arguments to a publisher
    ///
    ///  This operates by running the given command on the CLI. So, passing `"command"` for the command and `"--foo", "bar"`for the arguments would be like typing `command --foo bar` into the command line.
    ///
    /// - Parameters:
    ///   - command:   The command to run
    ///   - arguments: The arguments to send to the given command via its CLI
    ///
    /// - Returns: A publisher which publishes the data you requested
    @inline(__always)
    func run(_ command: String, _ arguments: String...) async throws -> Data? {
        try await run(command: command, arguments: arguments)
    }
    
    
    /// Streams the output given by running the given command with the given arguments to a publisher
    ///
    ///  This operates by running the given command on the CLI. So, passing `"command"` for the command and `["--foo", "bar"]`for the arguments would be like typing `command --foo bar` into the command line.
    ///
    /// - Parameters:
    ///   - encoding:  _optional_ - The encoding with which to interpret the data into a string. Defaults to `.utf8`
    ///   - command:   The command to run
    ///   - arguments: The arguments to send to the given command via its CLI
    ///
    /// - Returns: A publisher which publishes the strings you requested
    func run(encoding: String.Encoding = .utf8, command: String, arguments: [String]) async throws -> String? {
        try await run(command: command, arguments: arguments)
            .map { data in
                try String(data: data, encoding: encoding)
                    .unwrappedOrThrow(error: JsonEncodingError.failedToEncodeDataToString(attemptedEncoding: encoding))
            }
    }
    
    
    /// Streams the output given by running the given command with the given arguments to a publisher
    ///
    ///  This operates by running the given command on the CLI. So, passing `"command"` for the command and `"--foo", "bar"`for the arguments would be like typing `command --foo bar` into the command line.
    ///
    /// - Parameters:
    ///   - encoding:  _optional_ - The encoding with which to interpret the data into a string. Defaults to `.utf8`
    ///   - command:   The command to run
    ///   - arguments: The arguments to send to the given command via its CLI
    ///
    /// - Returns: A publisher which publishes the strings you requested
    func run(encoding: String.Encoding = .utf8, _ command: String, _ arguments: String...) async throws -> String? {
        try await run(encoding: encoding, command: command, arguments: arguments)
    }
    
    
    /// Returns the output given by running the given command with the given arguments
    ///
    ///  This operates by running the given command on the CLI. So, passing `"command"` for the command and `["--foo", "bar"]`for the arguments would be like typing `command --foo bar` into the command line.
    ///
    /// - Parameters:
    ///   - command:   The command to run
    ///   - arguments: The arguments to send to the given command via its CLI
    ///
    /// - Returns: The data that the given command sent to the standard output
    func output(command: String, arguments: [String]) async throws -> Data? {
        try await run(command: command, arguments: arguments)
    }
    
    
    /// Returns the output given by running the given command with the given arguments
    ///
    ///  This operates by running the given command on the CLI. So, passing `"command"` for the command and `["--foo", "bar"]`for the arguments would be like typing `command --foo bar` into the command line.
    ///
    /// - Parameters:
    ///   - encoding:  _optional_ - The encoding with which to interpret the data into a string. Defaults to `.utf8`
    ///   - command:   The command to run
    ///   - arguments: The arguments to send to the given command via its CLI
    ///
    /// - Returns: The string that the given command sent to the standard output
    func output(encoding: String.Encoding = .utf8, command: String, arguments: [String]) async throws -> String? {
        guard
            let outputData = try await output(command: command, arguments: arguments) as Data?
        else {
            assertionFailure("No output")
            return .empty
        }
        
        guard
            let outputString = String(data: outputData, encoding: .utf8)
        else {
            assertionFailure("Output was not UTF-8")
            return .empty
        }
        
        return outputString
    }
    
    
    /// Returns the output given by running the given command with the given arguments, split into substrings by newline characters
    ///
    ///  This operates by running the given command on the CLI. So, passing `"command"` for the command and `["--foo", "bar"]`for the arguments would be like typing `command --foo bar` into the command line.
    ///
    /// - Parameters:
    ///   - encoding:  _optional_ - The encoding with which to interpret the data into a string. Defaults to `.utf8`
    ///   - command:   The command to run
    ///   - arguments: The arguments to send to the given command via its CLI
    ///
    /// - Returns: The lines of strings that the given command sent to the standard output
    func outputLines(encoding: String.Encoding = .utf8, command: String, arguments: [String]) async throws -> [Substring] {
        try await output(encoding: encoding, command: command, arguments: arguments)?
            .split(whereSeparator: \.isNewline)
            ?? []
    }
    
    
    
    typealias OutputDataPublisher = AnyPublisher<Data, Error>
    typealias OutputStringsPublisher = AnyPublisher<String, Error>
}



// MARK: - Sanity check

public extension CLI {
    
    /// Just performs a simple command to make sure that our CLI stuff is working well
    /// - Returns: `true` iff the sanity check works as expected. `false` indicates that CLI interactions are very much **not** working as expected
    func sanityCheck() async -> Bool {
        let testValue = UUID().description
        
        do {
            return try await output(command: "echo", arguments: ["-n", testValue]) == testValue
        }
        catch {
            log(error: error)
            return false
        }
    }
}
