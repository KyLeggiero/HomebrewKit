//
//  CliApp.swift
//  CliApp
//
//  Created by Test User on 9/13/21.
//

import Foundation



///// An app that exists on the CLI
//@dynamicMemberLookup
//public protocol CliApp {
//    
//    func run(with commands: [Command])
//}
//
//
//
//public extension CliApp {
//    static subscript<C>(dynamicMember keyPath: KeyPath<CliAppCommands<Self>.Type, C>) -> C
//    where C: Command, C.App == Self
//    {
//        CliAppCommands.self[keyPath: keyPath]
//    }
//    
//    
//    static subscript<SubApp>(dynamicMember keyPath: KeyPath<CliAppSubApps<Self>.Type, SubApp>) -> SubApp
//    where SubApp: CliAppSubApp, SubApp.Parent == Self
//    {
//        CliAppSubApps.self[keyPath: keyPath]
//    }
//}
//
//
//
///// A command for a CLI app, like `--quiet` or `--message="Hello, world!"`
//public protocol CliAppCommand {
//    
//    associatedtype App: CliApp
//    
//    associatedtype ArgumentStyle: CliAppCommandArgumentStyle
//    
//    /// The name of the command, like `"--message"`.
//    /// Empty string signifies that the command can be used naked, like `ls`
//    static var commandName: String { get }
//    
//    
//    /// The arguments which were passed to this command
//    var arguments: [Argument] { get }
//}
//
//
//
//public extension CliAppCommand {
//    typealias Argument = CliAppCommandArgument
//}
//
//
//
//public struct CliAppCommandArgument {
//    
//    /// The text of the argument, like `"Hello, world!"` or `"Baz.md"`
//    public let text: String
//}
//
//
//
//public protocol CliAppCommandArgumentStyle {
//    
//    /// Determines how many of the given arguments should be passed to a command.
//    ///
//    /// The returned number is the count of contiguous arguments starting with the first in the given array, so `0` means none are accepted, `1` means only the first, `2` means the first two, etc.
//    ///
//    /// - Returns: The number of initial arguments in the given array which are acccepted by this style. If this is equal to or greater than the length of the array, all values are passed to the command, so `.max` always means to pass all the arguments.
//    func numberOfAcceptedArguments(in remainingArguments: [CliAppCommandArgument]) -> UInt
//}
//
//
//
///// The command does not take arguments, like `--quiet`
//public struct CliAppCommandArgumentStyle_DoesNotTakeArguments: CliAppCommandArgumentStyle {
//    public func numberOfAcceptedArguments(in remainingArguments: [CliAppCommandArgument]) -> UInt { 0 }
//}
//
//
//
///// The command takes one argument after its name, like `--message "Hello, world!"`
//public struct CliAppCommandArgumentStyle_TakesOneArgumentAfterName: CliAppCommandArgumentStyle {
//    public func numberOfAcceptedArguments(in remainingArguments: [CliAppCommandArgument]) -> UInt { 1 }
//}
//
//
//
///// The command takes one argument after its name and an equals symbol, like `--output=Errors.log`
//public struct CliAppCommandArgumentStyle_TakesOneArgumentWithEqualsSymbol: CliAppCommandArgumentStyle {
//    public func numberOfAcceptedArguments(in remainingArguments: [CliAppCommandArgument]) -> UInt { 1 }
//}
//
//
//
///// The command takes all argument after its name and before the next command, like `--files Foo.swift Bar.png Baz.md`
//public struct CliAppCommandArgumentStyle_TakesAllArgumentsAfterNameUntilNextCommand: CliAppCommandArgumentStyle {
//    public func numberOfAcceptedArguments(in remainingArguments: [CliAppCommandArgument]) -> UInt {
//        .init(remainingArguments
//                .lazy
//                .prefix(while: { !$0.text.hasPrefix("--") })
//                .count)
//    }
//}
//
//
//
///// The command takes the remainder of all CLI arguments, like `-- FileName.app --fileNameWithTwoDashes`
//public struct CliAppCommandArgumentStyle_TakesRemainderOfArguments: CliAppCommandArgumentStyle {
//    public func numberOfAcceptedArguments(in remainingArguments: [CliAppCommandArgument]) -> UInt { remainingArguments.count }
//}
//
//
//
//public extension CliApp {
//    typealias Command = CliAppCommand
//}
//
//
//
//public enum CliAppCommands<App: CliApp> {}
//
//
//
//public protocol CliAppSubApp: CliApp {
//    associatedtype Parent: CliApp
//}
//
//
//
//public enum CliAppSubApps<Parent: CliApp> {}
