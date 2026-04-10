# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
swift build                          # Build all targets
swift test                           # Run all tests (Swift Testing framework)
swift run planner                    # Launch macOS app
swift run planner ~/path/to/plan.md  # Open a specific plan file
```

## Architecture

Swift 6.0 package (macOS 14.0+) with two targets:

- **PlanViewerCore** (library) - Cross-platform models, markdown parsing, plan scanning, comment/workspace persistence, prompt generation
- **planner** (executable) - macOS SwiftUI app with CLI entry point; falls back to a message on non-macOS

### Core Layer (`Sources/PlanViewerCore/`)

- `Models.swift` - Domain types: `PlanDocument`, `PlanComment`, `CommentAnchor`, `PlanPromptBuilder`
- `MarkdownLines.swift` - Parses raw markdown into typed `MarkdownLine` objects with `MarkdownLineKind` enum; precomputes `AttributedString` for rendering
- `PlanScanner.swift` - Recursively scans `~/.claude/plans` and custom workspace targets; extracts metadata from `.jsonl` files; supports git worktrees
- `CommentStore.swift` / `WorkspaceStore.swift` - JSON persistence for comments and workspace config

### App Layer (`Sources/planner/`)

- `AppModel.swift` - `@MainActor` `ObservableObject` bridging core models to SwiftUI; manages selected plan, comments, drafts, prompt generation
- `PlanMarkdownView.swift` - Main rendering view (most complex file); syntax highlighting, inline comments, selection UI, prompt preview
- `SidebarView.swift` / `ContentView.swift` - Navigation layout using `NavigationSplitView`

### Data Flow

Views bind to `AppModel` via `@EnvironmentObject`. All core models are `Sendable`. `PlanPromptBuilder` uses placeholder substitution (`{{file_comments}}`, `{{inline_comments}}`, etc.) for customizable templates.

## Testing

Tests use Swift Testing (`@Test` + `#expect()`), not XCTest. Tests create temp directories and clean up with `defer`. All tests are in `Tests/PlanViewerCoreTests/PlanViewerCoreTests.swift`.

## Platform Guards

UI code is guarded with `#if canImport(AppKit) && canImport(SwiftUI)`. Non-macOS builds produce a fallback message.
