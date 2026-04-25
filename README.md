# GPU Monitor

A native macOS app that displays real-time GPU metrics for Apple Silicon Macs.
Built for monitoring local AI model workloads (Whisper, Ollama, etc.).

![SwiftUI](https://img.shields.io/badge/SwiftUI-macOS%2014+-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2FM2%2FM3%2FM4-silver)

## Features

- **Live GPU utilization** — rolling 5-minute chart sampled every second
- **Frequency and power readouts** — current clock tier and wattage
- **Framework adapters** — monitor Whisper transcription progress or Ollama model activity
- **Floating window** — stays on top of other windows, toggleable pin

## Build & Run

Requires macOS 14+ and Apple Silicon.

```bash
cd src/GPUMonitor
swift build
.build/debug/GPUMonitor
```

## Framework Adapters

### Whisper

Monitor transcription progress via the included Python bridge:

```bash
# Select "Whisper" in the app's framework picker, then run:
python3 scripts/whisper_bridge.py audio.m4a \
    --model large --device mps --fp16 False \
    --output_dir output/
```

The bridge accepts the same flags as the `whisper` CLI and writes output in all
standard formats (txt, vtt, srt, json, tsv).

### Ollama

Polls the Ollama REST API at `localhost:11434` to show active models and VRAM
usage. Start Ollama normally — the adapter connects automatically when selected.

## How It Works

GPU metrics come from Apple's IOReport framework — the same data source Activity
Monitor uses. The app subscribes to GPU P-state residency and energy channels,
sampling once per second. Framework adapters connect over Unix socket (Whisper)
or HTTP (Ollama) to overlay application-level metrics.

For a deep dive into M4 GPU architecture, P-states, and unified memory, see
[docs/gpu-architecture.md](docs/gpu-architecture.md).

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

## License

MIT
