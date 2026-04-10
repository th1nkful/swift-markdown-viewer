# swift-markdown-viewer

A native Swift markdown plan reviewer for Claude-generated plans.

## What it does

- scans `~/.claude/plans` automatically
- lets you add extra repo/worktree directories into the same workspace
- opens a specific plan directly with `planner /path/to/plan.md`
- renders markdown natively in SwiftUI with line numbers
- supports file-level comments and inline line-range comments
- copies all feedback into a Claude-friendly prompt

## Project layout

- `Sources/PlanViewerCore`: cross-platform models, scanning, persistence, markdown parsing, prompt generation
- `Sources/planner`: macOS SwiftUI app and CLI entry point
- `Tests/PlanViewerCoreTests`: focused core tests

## Build and run

### Run tests

```bash
swift test
```

### Run the app on macOS

```bash
swift run planner
```

### Open a specific plan on macOS

```bash
swift run planner ~/path/to/plan.md
```

## Notes

- The executable is named `planner`, so you can copy or symlink the built binary anywhere on your `PATH`.
- On non-macOS platforms the executable prints a short message instead of launching the app.
