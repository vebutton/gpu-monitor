# GPU Monitor App — Project Context for Claude Code

## Environment
- First started: CLI
- Date: 2026-04-24

## User
Vince — builds AI-powered tools and runs local AI models on his M4 Mac.
Has a working SwiftUI app ([token-monitor](https://github.com/vebutton/token-monitor))
that monitors cloud token/cost usage via a menu bar popover — this new app follows
a similar pattern but targets local GPU metrics.

## This Project
A native macOS SwiftUI app that monitors GPU utilization and token usage in real time
when running local AI models on an M4 Mac. It fills the gap left by Activity Monitor,
which shows only basic GPU info. The app displays as a floating window (not pinned to
the menu bar) with real-time graphs over a rolling ~1 hour window, and supports
toggling between frameworks (Whisper, Ollama, etc.) via checkboxes.

- **Full requirements:** [docs/requirements.md](docs/requirements.md)
- **Agent behavior rules:** [prompts/system_prompt.md](prompts/system_prompt.md)

## Input / Output
- **Input:** M4 GPU metrics (via Apple system APIs), framework-level token stats
  (via framework APIs — e.g., Whisper Python, Ollama REST)
- **Output:** Floating macOS window with real-time graphs and current stats

## Interface
Native macOS SwiftUI app — floating window, manually launched.

## Key Integrations
- Apple GPU/Metal performance APIs (M4 chip utilization)
- Framework APIs: Whisper (pip-installed, Python), Ollama (REST API), extensible to others
- Reference app: [token-monitor](https://github.com/vebutton/token-monitor) — SwiftUI
  menu bar app with gauges, `@Observable` state, async/await networking

## How to Work With This User
- Be direct and concise — no hand-holding.
- Don't invent scope beyond what the conversation defined.
- When uncertain about framework APIs or metric availability, surface it rather than guessing.
- Vince's previous SwiftUI app (token-monitor) is the style/pattern reference.

---

## Project Status
- [x] Bootstrap complete — requirements, system prompt, CLAUDE.md populated
- [x] Research M4 GPU metrics APIs — IOReport GPUPH channel (P-state residency)
- [x] Research Whisper/Ollama token metric hooks
- [x] SwiftUI app scaffold (floating window, basic layout)
- [x] GPU utilization display with real-time polling (verified: 90%+ under Whisper load)
- [x] Token usage display per framework (TokenChartView + adapters)
- [x] Rolling ~1hr graph for key metrics (CircularBuffer, 3600 samples)
- [x] Framework selector (Whisper via Unix socket, Ollama via REST)
- [ ] Claude Ultra review on completed codebase (before 2026-05-05)

## Session State
**Last session:** 2026-04-25 (CLI)

### What was accomplished
- Phases 1-3 complete: full working app
- SPM project at `src/GPUMonitor/` (Package.swift, CIOReport system library target)
- GPU utilization via IOReport GPUPH channel (P-state residency, no sudo)
- Verified: hits 90%+ under Whisper GPU load
- Whisper adapter (Unix socket → `scripts/whisper_bridge.py`)
- Ollama adapter (REST API polling localhost:11434)
- Swift Charts for GPU + framework metrics
- Floating window with always-on-top pin toggle
- Framework picker (None / Whisper / Ollama)

### Build & run
```
cd src/GPUMonitor && swift build && .build/debug/GPUMonitor
```

### Implementation plan
`.claude/plans/linear-sparking-moore.md`

### Next steps
- **Claude Ultra review** on completed codebase (before 2026-05-05)
- Optional: git init + first commit, push to GitHub
