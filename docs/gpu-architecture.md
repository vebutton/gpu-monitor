# GPU Monitor

A native macOS app that displays real-time GPU metrics for Apple Silicon Macs.
Built for monitoring local AI model workloads (Whisper, Ollama, etc.) on the M4 chip.

![SwiftUI](https://img.shields.io/badge/SwiftUI-macOS%2014+-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2FM2%2FM3%2FM4-silver)

## What It Shows

### GPU Utilization Chart
A rolling 5-minute chart of GPU utilization percentage, sampled every second.
The data comes from Apple's private IOReport framework — the same source Activity
Monitor uses — reading the **GPUPH** (GPU Performance State History) channel.

This measures the percentage of time the GPU is in an active P-state vs. OFF.
Under a heavy workload like Whisper transcription, expect 85–95% sustained utilization.

### Stats Row

| Metric | Source | What It Means |
|--------|--------|---------------|
| **GPU** | GPUPH P-state residency | % of time the GPU is active (not idle) |
| **Freq** | Peak active P-state | Estimated clock frequency — which speed tier the GPU is running at |
| **Power** | Energy Model (nanojoules) | GPU power draw in watts, derived from energy counter deltas |
| **Segments** | Framework adapter | Decoded segments (only when a framework is active) |

### Processing Rate Chart
When a framework is selected, shows segments decoded per second averaged over a
10-second rolling window. This reflects application-level throughput, not hardware
utilization — the GPU may be pegged at 95% while output rate fluctuates because
segments vary in decoding complexity.

## Understanding the M4 GPU

### Architecture
The M4 chip has **10 GPU cores** with a SIMD (Single Instruction, Multiple Data)
architecture optimized for parallel workloads — matrix math, image processing,
and neural network inference.

### Unified Memory
Unlike traditional PCs where the CPU and GPU have separate memory pools, Apple
Silicon uses **unified memory**. The GPU and CPU share the same physical LPDDR5X
RAM (up to 120 GB/s bandwidth). This means:

- **No copying** — data doesn't move between CPU and GPU memory, it's already there
- **Shared pool** — a 16 GB Mac gives the GPU access to the same 16 GB the CPU uses
- **Efficiency** — critical for local AI models that need to load large weight matrices

When Whisper runs on `--device mps` (Metal Performance Shaders), the model weights
sit in unified memory and the GPU reads them directly.

### P-States and Dynamic Frequency
The M4 GPU doesn't run at a fixed clock speed. It uses **16 performance states**
(P-states), scaling from OFF through ~400 MHz up to ~1,578 MHz:

- **OFF (P0)** — GPU is idle, no power draw
- **P1–P5** — Low-frequency states for light workloads (UI compositing, video)
- **P6–P10** — Mid-range for moderate compute
- **P11–P15** — Full speed for heavy ML inference, 3D rendering

The "GPU utilization" percentage is: `time in any active P-state / total time`.
The "Freq" readout shows the P-state tier where the GPU spent the most time.

### What 90%+ Utilization Looks Like
During a Whisper `large` model transcription on MPS:
- GPU utilization: **90–95%** sustained
- Frequency: **~1.5 GHz** (top P-states)
- Power: **Several watts** of the chip's power budget
- All 10 GPU cores active, running matrix multiplications in parallel

## Build & Run

Requires macOS 14+ and Apple Silicon.

```bash
cd src/GPUMonitor
swift build
.build/debug/GPUMonitor
```

The app launches a floating window that stays on top of other windows.
Click the pin icon to toggle always-on-top behavior.

## Framework Adapters

### Whisper
Monitors transcription progress via a Python bridge script over Unix socket.

```bash
# In the app, select "Whisper" in the framework picker, then:
python3 scripts/whisper_bridge.py audio.m4a \
    --model large --device mps --fp16 False \
    --output_dir output/
```

The bridge accepts the same flags as the `whisper` CLI and writes output files
in all standard formats (txt, vtt, srt, json, tsv).

### Ollama
Polls the Ollama REST API at `localhost:11434` to show active models and VRAM
usage. Start Ollama normally — the adapter connects automatically when selected.

## How It Works

1. **IOReport** (private API) — subscribes to "GPU Stats" and "Energy Model"
   channel groups, samples every second, computes deltas for utilization and power
2. **Swift Charts** — renders the rolling time-series graphs
3. **SwiftUI** — floating window via `NSPanel` subclass with `@Observable` state
4. **Framework adapters** — protocol-based, extensible. Whisper uses Unix domain
   socket IPC; Ollama uses HTTP polling

## Project Structure

```
src/GPUMonitor/
  Sources/
    CIOReport/              # C bridging for IOReport private API
    GPUMonitor/
      GPUMonitorApp.swift   # App entry point, floating window
      FloatingPanel.swift   # NSPanel subclass
      Model/                # GPUState, MetricSample, CircularBuffer
      Metrics/              # GPUMetricsProvider, framework adapters
      ViewModel/            # MonitorViewModel (@Observable)
      Views/                # SwiftUI views (charts, stats, picker)
scripts/
  whisper_bridge.py         # Python bridge for Whisper metrics
```
