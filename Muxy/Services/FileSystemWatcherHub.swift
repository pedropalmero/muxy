import Foundation

final class FileSystemWatcherSubscription: @unchecked Sendable {
    fileprivate let id = UUID()
    fileprivate let directoryPath: String
    fileprivate let handler: @Sendable () -> Void
    fileprivate let debounceInterval: TimeInterval
    fileprivate weak var hub: FileSystemWatcherHub?

    private let lock = NSLock()
    private var pendingWork: DispatchWorkItem?

    fileprivate init(
        directoryPath: String,
        handler: @escaping @Sendable () -> Void,
        debounceInterval: TimeInterval,
        hub: FileSystemWatcherHub
    ) {
        self.directoryPath = directoryPath
        self.handler = handler
        self.debounceInterval = debounceInterval
        self.hub = hub
    }

    fileprivate func schedule(on queue: DispatchQueue) {
        let handler = self.handler
        let work = DispatchWorkItem { handler() }
        lock.lock()
        pendingWork?.cancel()
        pendingWork = work
        lock.unlock()
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    fileprivate func cancelPending() {
        lock.lock()
        pendingWork?.cancel()
        pendingWork = nil
        lock.unlock()
    }

    deinit {
        cancelPending()
        hub?.unsubscribe(id: id, directoryPath: directoryPath)
    }
}

final class FileSystemWatcherHub: @unchecked Sendable {
    static let shared = FileSystemWatcherHub()

    private struct Entry {
        let watcher: FileSystemWatcher
        var schedulers: [UUID: @Sendable () -> Void]
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private let debounceQueue = DispatchQueue(label: "app.muxy.fs-debounce", qos: .utility)

    func subscribe(
        directoryPath: String,
        debounceInterval: TimeInterval = 0.3,
        handler: @escaping @Sendable () -> Void
    ) -> FileSystemWatcherSubscription? {
        let subscription = FileSystemWatcherSubscription(
            directoryPath: directoryPath,
            handler: handler,
            debounceInterval: debounceInterval,
            hub: self
        )

        let queue = debounceQueue
        let scheduler: @Sendable () -> Void = { [weak subscription] in
            subscription?.schedule(on: queue)
        }

        lock.lock()
        defer { lock.unlock() }

        if var entry = entries[directoryPath] {
            entry.schedulers[subscription.id] = scheduler
            entries[directoryPath] = entry
            return subscription
        }

        guard let watcher = FileSystemWatcher(directoryPath: directoryPath, handler: { [weak self] in
            self?.fire(directoryPath: directoryPath)
        })
        else {
            return nil
        }

        entries[directoryPath] = Entry(
            watcher: watcher,
            schedulers: [subscription.id: scheduler]
        )

        return subscription
    }

    fileprivate func unsubscribe(id: UUID, directoryPath: String) {
        lock.lock()
        guard var entry = entries[directoryPath] else {
            lock.unlock()
            return
        }
        entry.schedulers.removeValue(forKey: id)
        if entry.schedulers.isEmpty {
            entries.removeValue(forKey: directoryPath)
        } else {
            entries[directoryPath] = entry
        }
        lock.unlock()
    }

    private func fire(directoryPath: String) {
        lock.lock()
        let schedulers = entries[directoryPath]?.schedulers.values.map(\.self) ?? []
        lock.unlock()
        for scheduler in schedulers {
            scheduler()
        }
    }
}
