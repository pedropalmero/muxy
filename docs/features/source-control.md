# Source Control

A full git UI for the active worktree. Open with `⌘K`, or **File → Source Control**.

```mermaid
flowchart TB
  Header[Header: worktree | branch | PR pill | refresh]
  Commit[Commit area: message | Commit ⌘↵ | Pull ↓N | Push ↑N]
  Sections[Sections: Staged | Changes | History | Pull Requests]
  Header --> Commit --> Sections
```

## Display modes

Configurable in **Settings → General**:

| Mode | Where it appears |
| --- | --- |
| Tab | Regular workspace tab |
| Attached | Side panel on the main window |
| Window | Separate "Source Control" window (id `vcs`) |

## Status

Files are grouped into **Staged**, **Changes** (modified, tracked), and **Untracked**. Toggle between flat list and folder tree. Stage/unstage individual files or whole directories. Discard is in the right-click menu.

## Keyboard navigation

When the Source Control panel owns keyboard focus, `Tab` / `Shift+Tab` cycle between panel sections and the commit message without changing app-wide tab behavior. `↑` / `↓` move through the visible rows inside the focused section, including folder rows in folder-tree mode. `Return` activates the focused row (opens a file in the editor, checks out a pull request, or toggles a folder/section), and `Space` toggles the inline diff, folder, or section collapse. While a file row is focused you can `S` to stage, `U` to unstage, `D` to discard, or `O` to open its diff in a new tab. Use `Shift+S`, `Shift+U`, and `Shift+D` for stage all, unstage all, and discard all.

## Diffs

Click a file to see its diff inline. Supports:

- **Unified** and **Split** views (toolbar toggle).
- Syntax highlighting.
- Collapsible context lines.
- Hover blame (toggle on) showing author and date for each line.

For deeper inspection, **Open in Diff Viewer** opens the file as a standalone diff tab.

## Commit, push, pull

- Type a message in the commit box; **Commit** with `⌘↵`. Auto-stage toggle picks up unstaged changes when enabled.
- **Push** uploads to the upstream branch; shows ↑N when ahead. Pushing a branch with no upstream prompts to set one.
- **Pull** fetches and merges; shows ↓N when behind.

## Branches & worktrees

The branch dropdown switches branches (refused if there are uncommitted changes). **Create Branch…** creates and checks out a new branch. The worktree picker is shared with the topbar — see [Worktrees](worktrees.md).

## Pull requests

If `origin` is on GitHub and `gh` is authenticated, Muxy shows:

- **PR pill** in the header (state, base, mergeability).
- **Pull Requests** section with search, state filter (Open/Closed/Merged/All), and manual or interval-based auto-sync (Off / 5m / 15m / 30m / 1h).
- **Create PR…** sheet with branch strategy, draft toggle, and "Open in browser after creation".
- Per-PR actions: open on GitHub, merge, close, refresh.

## History

The Commit History section lists recent commits chronologically. Right-click a commit for **Show Diff**, **Copy Hash**, etc.

## Layout

Staged / Changes / History / Pull Requests are vertically resizable; their split ratios persist per project.
