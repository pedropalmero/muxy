import CoreServices
import Foundation

final class FileSystemWatcher: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.muxy.fs-watcher", qos: .utility)
    private var stream: FSEventStreamRef?
    private var handler: (@Sendable () -> Void)?

    init?(directoryPath: String, handler: @escaping @Sendable () -> Void) {
        guard FileManager.default.fileExists(atPath: directoryPath) else { return nil }

        self.handler = handler

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let paths = [directoryPath] as CFArray
        guard let stream = FSEventStreamCreate(
            nil,
            { _, clientInfo, numEvents, eventPaths, eventFlags, _ in
                guard let clientInfo, numEvents > 0 else { return }
                let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(clientInfo).takeUnretainedValue()
                guard let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String]
                else { return }
                let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))

                let hasInteresting = zip(paths, flags).contains { path, flag in
                    !FileSystemWatcher.isNoise(path: path, flag: flag)
                }
                guard hasInteresting else { return }

                watcher.handler?()
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )
        else { return nil }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    deinit {
        handler = nil
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    fileprivate static func isNoise(path: String, flag: UInt32) -> Bool {
        let isGitInternal = path.contains("/.git/")
        if isGitInternal, path.hasSuffix(".lock") { return true }
        if isGitInternal, flag & UInt32(kFSEventStreamEventFlagItemIsDir) != 0 { return true }
        if path.contains("/node_modules/") { return true }
        if path.contains("/DerivedData/") { return true }
        if path.hasSuffix(".o") || path.hasSuffix(".a") || path.hasSuffix(".dylib") { return true }
        return false
    }
}
