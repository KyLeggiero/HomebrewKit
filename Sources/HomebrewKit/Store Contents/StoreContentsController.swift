//
//  StoreContentsController.swift
//  Homebrew App Store
//
//  Created by Ky Leggiero on 9/12/21.
//

import Foundation

import CollectionTools
import ConcurrencyTools
import SimpleLogging



///// The queue upon which all refresh work is done
//fileprivate let updateQueue = DispatchQueue(label: "Homebrew update queue",
//                                            qos: .background)



@globalActor
fileprivate final actor UpdateQueue {
    static let shared = UpdateQueue()
    
    
    static func run<T>(resultType: T.Type = T.self, body: @MainActor @Sendable () async throws -> T) async rethrows -> T where T : Sendable {
        try await body()
    }
}



@discardableResult
fileprivate func onUpdateQueue<Value>(priority: TaskPriority? = nil, perform action: @escaping @Sendable () async throws -> Value)
-> Task<Value, Error>
where Value: Sendable
{
    Task.detached(priority: priority) {
        try await UpdateQueue.run { try await action() }
    }
}



/// Controls knowledge about the contents of the store
public final class StoreContentsController: ObservableObject {
    
    @Published
    public private(set) var contents = Loadable.cachedAndLoadingInTheBackground(cachedValue: StoreContents.cached).whereEmptyCacheIsMarkedAsNoCache() {
        didSet {
            switch contents {
            case .cachedAndLoadingInTheBackground(cachedValue: _),
                    .loadingButNoCache:
                break
                
            case .loaded(let value, lastError: _):
                StoreContents.cached = value
                
            case .failed(error: let error):
                assertionFailure("Handle this later: \(error)")
            }
        }
    }
    
    
    public init() {
    }
}



// MARK: - Loading

public extension StoreContentsController {
    
    /// Enqueues a background refresh
    func refreshContents(with homebrew: Homebrew) {
        
        self.contents.markAsLoading()
        
        onUpdateQueue {
            defer {
                self.contents.markAsNoLongerLoading()
            }
            
            do {
                await homebrew.update()
                
                let newApps = try await homebrew.listAllApps()
                
                //                let newContents = StoreContents(apps: )
                //                let newContents = StoreContents(apps: try HomebrewCliApp().listInstalledApps())
                //                let newContents = StoreContents.demo
                
                let diff = newApps.difference(from: self.contents).inferringMoves()
                
                await MainActor.run {
                    for change in diff {
                        switch change {
                        case .insert(offset: let newIndex, element: let newApp, associatedWith: _):
                            self.contents.insert(newApp, at: newIndex)
                            
                        case .remove(offset: _, element: let oldApp, associatedWith: _):
                            self.contents.remove(firstInstanceOf: oldApp)
                        }
                    }
                }
                
                for (index, var app) in self.contents.enumerated().sorted(by: \(offset: Int, element: StoreContents.Element).element.dateInfoLastFilledOut) {
//                    do {
//                        try await homebrew.fillOutInfo(for: &app)
//                    }
//                    catch {
//                        log(error: error, "Error while filling out info for \(app)")
//                        assertionFailure("\(error)")
//                    }
                    
                    await MainActor.run { [app] in
                        self.contents[index] = app
                    }
                }
            }
            catch {
                assertionFailure("\(error)")
            }
        }
    }
    
    
    func refresh(app: App, with homebrew: Homebrew) async {
        var app = app
        
        try? await homebrew.fillOutInfo(for: &app)
        
        if let index = contents.firstIndex(of: app) {
            onMainActor { [app, self] in
                self.contents[index] = app
            }
        }
        else {
            contents.append(app)
        }
    }
}
