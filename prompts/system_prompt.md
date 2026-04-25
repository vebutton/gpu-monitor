# GPU Monitor App — Development Guidelines

> Loaded by Claude Code when building this app. Covers architecture decisions,
> coding standards, and constraints specific to this project.

## Architecture
- **SwiftUI** native macOS app targeting Apple Silicon (M4).
- **Floating window** style — not a menu bar app. The window should be repositionable
  anywhere on screen, similar to Activity Monitor. Use `.windowStyle(.plain)` or
  equivalent to achieve a lightweight floating appearance.
- **Single framework at a time** — the app assumes only one local model framework
  is active. No need to aggregate across multiple simultaneous frameworks.
- **Manual launch** — the app is opened by the user when needed. No auto-start,
  no background daemon.

## Coding Standards
- Follow the patterns established in the [token-monitor](https://github.com/vebutton/token-monitor)
  app: `@Observable` for state management, `@Environment` for dependency injection,
  structured concurrency with async/await.
- Organize code into `Views/`, `ViewModel/`, `Model/`, and `Networking/` (or `Metrics/`)
  directories mirroring token-monitor's structure.
- Use Swift async/await for all polling and data fetching — no Combine unless necessary.
- Keep views small and composable.

## Metrics Collection
- **GPU utilization:** Use Apple's IOKit or Metal performance counters to read M4 GPU
  utilization. Research what's actually available — Activity Monitor gets this data
  somehow; find the same source.
- **Token usage:** This lives at the framework level, not the chip level.
  - Whisper: installed via pip, runs from Python. Determine how to surface token/segment
    counts (may need a lightweight bridge or log parser).
  - Ollama: exposes a REST API — pull token stats from there.
  - Design the framework adapter as a protocol so new frameworks can be added via a
    checkbox without restructuring.
- **Polling interval:** Poll at a reasonable cadence (e.g., 1–2 seconds for GPU,
  framework-dependent for tokens). Don't hammer the system.

## What This App Does NOT Do
- No temperature or power draw metrics.
- No cross-platform support — macOS only, Apple Silicon only.
- No cloud metrics — that's what token-monitor is for.
- No auto-detection of running frameworks — the user selects the active one.
- No persistent storage or historical data beyond the rolling window.

## UI Guidelines
- Floating window with real-time graphs (rolling ~1 hour window).
- Visual style inspired by Activity Monitor — clean, functional, not flashy.
- Framework selector via checkboxes (only one active at a time — radio behavior is fine).
- Graphs for GPU utilization and token usage as primary visuals.
- Show current values alongside the graph.
