import Foundation

@MainActor
@Observable
final class CommitDiffViewerTabState: Identifiable {
    let id = UUID()
    let commit: GitCommit
    let projectPath: String
    var mode: VCSTabState.ViewMode = .unified
    var selectedFilePath: String?
    var currentHunkIndex: Int = 0

    private(set) var files: [CommitChangedFile] = []
    private(set) var isLoadingFiles = false
    private(set) var filesError: String?
    private(set) var diffsByPath: [String: DiffCache.LoadedDiff] = [:]
    private(set) var loadingPaths: Set<String> = []
    private(set) var errorsByPath: [String: String] = [:]

    @ObservationIgnored private var diffTasks: [String: Task<Void, Never>] = [:]

    var displayTitle: String { commit.shortHash }

    var totalAdditions: Int { files.reduce(0) { $0 + $1.additions } }
    var totalDeletions: Int { files.reduce(0) { $0 + $1.deletions } }

    init(commit: GitCommit, projectPath: String) {
        self.commit = commit
        self.projectPath = projectPath
        loadFiles()
    }

    func navigateToHunk(delta: Int, hunkCount: Int) {
        guard hunkCount > 0 else { return }
        currentHunkIndex = (currentHunkIndex + delta + hunkCount) % hunkCount
    }

    func loadFiles(forceFull: Bool = false) {
        isLoadingFiles = true
        filesError = nil
        Task { @MainActor in
            do {
                let loaded = try await GitRepositoryService().commitChangedFiles(
                    repoPath: projectPath,
                    hash: commit.hash
                )
                files = loaded
                isLoadingFiles = false
                if let first = loaded.first, !first.isBinary {
                    selectedFilePath = first.path
                    loadDiff(for: first.path, forceFull: forceFull)
                } else if loaded.first != nil {
                    selectedFilePath = loaded.first?.path
                }
            } catch {
                filesError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isLoadingFiles = false
            }
        }
    }

    func selectFile(_ filePath: String) {
        selectedFilePath = filePath
        currentHunkIndex = 0
        guard diffsByPath[filePath] == nil, !loadingPaths.contains(filePath) else { return }
        loadDiff(for: filePath)
    }

    func selectNextFile() {
        guard !files.isEmpty else { return }
        let index = files.firstIndex(where: { $0.path == selectedFilePath }) ?? -1
        let next = min(index + 1, files.count - 1)
        selectFile(files[next].path)
    }

    func selectPrevFile() {
        guard !files.isEmpty else { return }
        let index = files.firstIndex(where: { $0.path == selectedFilePath }) ?? files.count
        let prev = max(index - 1, 0)
        selectFile(files[prev].path)
    }

    func loadDiff(for filePath: String, forceFull: Bool = false) {
        diffTasks[filePath]?.cancel()
        loadingPaths.insert(filePath)
        errorsByPath[filePath] = nil
        let hash = commit.hash
        let repoPath = projectPath
        let lineLimit = forceFull ? nil : DiffLoader.previewLineLimit
        let task = Task { @MainActor in
            do {
                let result = try await GitRepositoryService().commitFileDiff(
                    repoPath: repoPath,
                    hash: hash,
                    filePath: filePath,
                    lineLimit: lineLimit
                )
                guard !Task.isCancelled else { return }
                diffsByPath[filePath] = DiffCache.LoadedDiff(
                    rows: result.rows,
                    additions: result.additions,
                    deletions: result.deletions,
                    truncated: result.truncated
                )
                loadingPaths.remove(filePath)
                diffTasks.removeValue(forKey: filePath)
            } catch {
                guard !Task.isCancelled else { return }
                errorsByPath[filePath] = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                loadingPaths.remove(filePath)
                diffTasks.removeValue(forKey: filePath)
            }
        }
        diffTasks[filePath] = task
    }
}
