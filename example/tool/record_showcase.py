"""Record DemoStudio autoplay on a booted iPhone simulator; export square clips.

Build/install the autoplay example first (see example/README.md). This tool
uses simctl and FFmpeg. Raw full-screen footage stays in a temporary directory;
only square component clips and preview PNGs are delivered.
"""
import argparse
import json
from pathlib import Path
import selectors
import signal
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", default="booted")
    parser.add_argument("--bundle", default="com.example.example")
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    events = []
    with tempfile.TemporaryDirectory(prefix="globe-recording-") as temp:
        source = Path(temp) / "source.mp4"
        recorder = subprocess.Popen(
            ["xcrun", "simctl", "io", args.device, "recordVideo",
             "--codec=h264", "--mask=ignored", str(source)],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
        )
        app = None
        try:
            for line in recorder.stderr:
                print(line.rstrip(), flush=True)
                if "Recording started" in line:
                    break
            else:
                raise RuntimeError("Simulator video recorder did not start")
            epoch = time.time()
            # Flutter stdout goes to the simulator's unified log even when
            # simctl launch --console has no connected VM-service client.
            app = subprocess.Popen(
                ["xcrun", "simctl", "spawn", args.device, "log", "stream",
                 "--style", "compact", "--predicate",
                 'eventMessage CONTAINS "flutter: SHOWCASE "'],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, bufsize=1,
            )
            time.sleep(0.5)
            subprocess.run(["xcrun", "simctl", "launch",
                "--terminate-running-process", args.device, args.bundle], check=True)
            selector = selectors.DefaultSelector()
            selector.register(app.stdout, selectors.EVENT_READ)
            deadline = time.monotonic() + 100
            done = False
            while time.monotonic() < deadline and not done:
                for key, _ in selector.select(timeout=1):
                    line = key.fileobj.readline()
                    if not line and app.poll() is not None:
                        raise RuntimeError("App exited before autoplay finished")
                    if "flutter: SHOWCASE {" not in line:
                        continue
                    event = json.loads(line.split("SHOWCASE ", 1)[1])
                    if event["time"] / 1000 < epoch:
                        continue
                    events.append(event)
                    print(json.dumps(event), flush=True)
                    done = event["event"] == "done"
            if not done:
                raise RuntimeError("Autoplay timed out; use SHOWCASE_AUTOPLAY=true")
            selector.close()
        finally:
            recorder.send_signal(signal.SIGINT)
            recorder.communicate(timeout=30)
            if app is not None:
                app.terminate()
                try:
                    app.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    app.kill()
                    app.wait()

        crop = next(e for e in events if e["event"] == "crop")
        scenes = [e for e in events if e["event"] == "scene"]
        if len(scenes) != 3 or len({e['id'] for e in scenes}) != 3:
            raise RuntimeError(f"Expected 3 distinct scenes, got {len(scenes)}")
        for scene in scenes:
            start = max(0, scene["time"] / 1000 - epoch + 0.3)
            target = args.output / (scene["id"] + ".mp4")
            duration = scene["duration"] - 0.6
            vf = (f"crop={crop['side']}:{crop['side']}:{crop['x']}:{crop['y']},"
                  "scale=720:720:flags=lanczos,fps=30")
            subprocess.run([
                args.ffmpeg, "-hide_banner", "-loglevel", "error", "-ss",
                str(start), "-i", str(source), "-t", str(duration), "-vf", vf,
                "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "18",
                "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(target),
            ], check=True)
            subprocess.run([
                args.ffmpeg, "-hide_banner", "-loglevel", "error", "-ss", "3",
                "-i", str(target), "-frames:v", "1",
                str(args.output / (scene["id"] + ".png")),
            ], check=True)
            print(f"Exported {target.name}: 720 × 720, {duration}s, 30fps", flush=True)
        (args.output / "capture.json").write_text(
            json.dumps({"crop": crop, "events": events, "recording_epoch": epoch},
                       indent=2) + "\n", encoding="utf-8",
        )
        print(f"Done: {args.output}", flush=True)


if __name__ == "__main__":
    main()
