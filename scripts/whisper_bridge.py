#!/usr/bin/env python3
"""
Whisper Bridge for GPU Monitor.

Drop-in replacement for the `whisper` CLI that also sends real-time
progress metrics to the GPU Monitor app via a Unix domain socket.

Usage (mirrors the whisper CLI flags you already use):
    python whisper_bridge.py audio.m4a --model large --device mps --fp16 False

The bridge listens on /tmp/gpu-monitor-whisper.sock. Start GPU Monitor
first, select Whisper in the framework picker, then run this script.
"""

import argparse
import json
import os
import socket
import sys
import time
import threading

SOCKET_PATH = "/tmp/gpu-monitor-whisper.sock"


class MetricsBridge:
    """Manages the Unix socket server and sends metrics to connected clients."""

    def __init__(self, socket_path=SOCKET_PATH):
        self.socket_path = socket_path
        self.server = None
        self.client = None
        self.start_time = time.time()
        self.segment_count = 0

    def start_server(self):
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)

        self.server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server.bind(self.socket_path)
        self.server.listen(1)
        self.server.settimeout(60)

        print(f"[whisper_bridge] Listening on {self.socket_path}")
        print("[whisper_bridge] Waiting for GPU Monitor to connect...")

        try:
            self.client, _ = self.server.accept()
            print("[whisper_bridge] GPU Monitor connected")
        except socket.timeout:
            print("[whisper_bridge] No client connected, running without metrics")
            self.client = None

    def send_metric(self, segment_count, position_seconds, tokens_processed=None):
        if self.client is None:
            return
        elapsed = time.time() - self.start_time
        msg = {
            "type": "progress",
            "segment_count": segment_count,
            "position_seconds": position_seconds,
            "processing_time_seconds": elapsed,
            "tokens_processed": tokens_processed,
        }
        try:
            self.client.sendall((json.dumps(msg) + "\n").encode("utf-8"))
        except (BrokenPipeError, ConnectionResetError):
            self.client = None

    def send_complete(self):
        if self.client is None:
            return
        msg = {
            "type": "complete",
            "segment_count": self.segment_count,
            "position_seconds": 0,
            "processing_time_seconds": time.time() - self.start_time,
            "tokens_processed": None,
        }
        try:
            self.client.sendall((json.dumps(msg) + "\n").encode("utf-8"))
        except (BrokenPipeError, ConnectionResetError):
            pass

    def cleanup(self):
        if self.client:
            self.client.close()
        if self.server:
            self.server.close()
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)


def make_segment_callback(bridge):
    """Returns a write function that intercepts Whisper's verbose output
    to detect newly decoded segments and push metrics in real-time."""
    class SegmentInterceptor:
        def __init__(self):
            self.count = 0
            self.last_end = 0.0
        def write(self, text):
            sys.__stdout__.write(text)
            # Whisper verbose output prints lines like:
            # [00:00.000 --> 00:05.000]  Some transcribed text
            if text.strip().startswith("[") and " --> " in text:
                self.count += 1
                bridge.segment_count = self.count
                try:
                    ts = text.strip().split(" --> ")[1].split("]")[0]
                    parts = ts.split(":")
                    mins = float(parts[0])
                    secs = float(parts[1])
                    self.last_end = mins * 60 + secs
                except (IndexError, ValueError):
                    pass
                bridge.send_metric(
                    segment_count=self.count,
                    position_seconds=self.last_end,
                )
        def flush(self):
            sys.__stdout__.flush()
    return SegmentInterceptor()


def parse_bool(value):
    """Parse boolean string the same way Whisper CLI does."""
    if isinstance(value, bool):
        return value
    return value.lower() not in ("false", "0", "no")


def main():
    parser = argparse.ArgumentParser(description="Whisper Bridge for GPU Monitor")
    parser.add_argument("audio_file", help="Path to audio file to transcribe")
    parser.add_argument("--model", default="base",
                        help="Whisper model size (tiny/base/small/medium/large)")
    parser.add_argument("--device", default=None,
                        help="Device to use (cpu/mps/cuda)")
    parser.add_argument("--language", default=None,
                        help="Language code (e.g., en)")
    parser.add_argument("--output_dir", default=None,
                        help="Directory for output files")
    parser.add_argument("--fp16", default="True",
                        help="Use fp16 (True/False)")
    parser.add_argument("--condition_on_previous_text", default="True",
                        help="Condition on previous text (True/False)")
    parser.add_argument("--task", default="transcribe",
                        help="Task: transcribe or translate")
    parser.add_argument("--initial_prompt", default=None,
                        help="Initial prompt for the decoder")
    args = parser.parse_args()

    if not os.path.exists(args.audio_file):
        print(f"Error: File not found: {args.audio_file}", file=sys.stderr)
        sys.exit(1)

    bridge = MetricsBridge()

    try:
        # Start socket server in background
        server_thread = threading.Thread(target=bridge.start_server, daemon=True)
        server_thread.start()

        # Import and load Whisper
        print(f"[whisper_bridge] Loading Whisper model '{args.model}'...")
        import whisper
        model = whisper.load_model(args.model, device=args.device)

        # Wait for server thread to finish accepting (or timeout)
        server_thread.join(timeout=5)

        print(f"[whisper_bridge] Transcribing: {args.audio_file}")
        bridge.start_time = time.time()

        # Intercept stdout to capture segment-by-segment progress
        interceptor = make_segment_callback(bridge)
        sys.stdout = interceptor

        result = model.transcribe(
            args.audio_file,
            language=args.language,
            task=args.task,
            fp16=parse_bool(args.fp16),
            condition_on_previous_text=parse_bool(args.condition_on_previous_text),
            initial_prompt=args.initial_prompt,
            verbose=True,
        )

        # Restore stdout
        sys.stdout = sys.__stdout__

        # Send final metrics
        segments = result.get("segments", [])
        bridge.segment_count = len(segments)
        if segments:
            bridge.send_metric(
                segment_count=len(segments),
                position_seconds=segments[-1]["end"],
            )
        bridge.send_complete()

        elapsed = time.time() - bridge.start_time
        print(f"\n[whisper_bridge] Complete: {len(segments)} segments in {elapsed:.1f}s")

        # Write output files if requested (same formats as whisper CLI)
        if args.output_dir:
            os.makedirs(args.output_dir, exist_ok=True)
            base = os.path.splitext(os.path.basename(args.audio_file))[0]

            from whisper.utils import get_writer
            for fmt in ["txt", "vtt", "srt", "tsv", "json"]:
                writer = get_writer(fmt, args.output_dir)
                writer(result, args.audio_file)
            print(f"[whisper_bridge] Output written to {args.output_dir}/")

    except ImportError:
        print("Error: whisper not installed. Run: pip install openai-whisper",
              file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n[whisper_bridge] Interrupted")
    finally:
        sys.stdout = sys.__stdout__
        bridge.cleanup()


if __name__ == "__main__":
    main()
