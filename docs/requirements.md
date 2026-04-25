# GPU Monitor App — Requirements

## Summary
A native macOS SwiftUI app that displays real-time GPU utilization and token usage
metrics when running local AI models on an M4 Mac. Floating window, manual launch,
framework-selectable.

## Platform
- macOS only, Apple Silicon (M4 chip)
- SwiftUI native app
- Minimum deployment target: macOS 14+ (Sonnet — for `@Observable` support)

## UI Requirements

### Window
- Floating window — repositionable anywhere on screen (not docked to menu bar)
- Style similar to Activity Monitor: lightweight, functional
- Always-on-top option (nice to have)

### Graphs
- Real-time rolling graphs with ~1 hour window
- GPU utilization over time
- Token usage over time (framework-dependent)
- Current values displayed alongside graphs

### Framework Selector
- Checkboxes or radio buttons for selecting the active framework
- Only one framework active at a time
- MVP frameworks: Whisper
- Future frameworks: Ollama, others as discovered
- Extensible design — adding a new framework should be straightforward

## Metrics

### GPU Utilization
- Source: Apple system APIs (IOKit, Metal performance counters, or equivalent)
- What to show: GPU usage percentage, potentially memory usage
- Polling interval: 1–2 seconds

### Token Usage
- Source: Framework-level APIs (not chip-level)
- **Whisper (MVP):**
  - Installed via pip (Python)
  - Need to determine: how to surface token/segment counts from a running Whisper job
  - May require a bridge (log parsing, IPC, or a lightweight Python server)
- **Ollama (future):**
  - REST API available at localhost
  - Token stats accessible via API responses
- Design as a protocol/adapter pattern for extensibility

## Excluded (explicit)
- No temperature metrics
- No power draw metrics
- No cloud/API token monitoring (handled by token-monitor app)
- No auto-start or background daemon
- No auto-detection of running frameworks
- No persistent history beyond the rolling window
- No cross-platform support

## Reference
- **Existing app:** [token-monitor](https://github.com/vebutton/token-monitor) —
  SwiftUI menu bar app by same user. Use as pattern reference for:
  - Project structure (Views/, ViewModel/, Model/, Networking/)
  - State management (`@Observable`, `@Environment`)
  - Gauge/progress visualization (`GaugeBarView`)
  - Async data fetching patterns

## Final Gate
- Run Claude Ultra review on the completed codebase before 2026-05-05 (Vince has
  expiring Ultra review credits). This is the final step before shipping.

## Open Questions (to resolve during development)
1. What Apple APIs are available for M4 GPU utilization? (IOKit? Metal? `powermetrics`?)
2. How does Whisper surface token counts? Is there a Python API, log output, or does
   it need a wrapper?
3. What's the best IPC mechanism between a Python framework and a Swift app?
   (Unix socket, REST, shared file, XPC?)
4. Should the floating window use `NSPanel` for proper float-above behavior, or
   standard `NSWindow` with level adjustment?
