#!/usr/bin/env python3
"""Decode actual MP4 frames and add timestamp margins to review contact sheets.

Only the supplementary contact sheets are scaled/labelled. The encoded video is
never modified and no interpolation, colour correction or image enhancement runs.
"""
import math
import json
from pathlib import Path
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

video, output, mode = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
output.mkdir(parents=True, exist_ok=True)
try:
    caption_font = ImageFont.load_default(size=15)
except TypeError:
    caption_font = ImageFont.load_default()
probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_frames", "-show_entries", "frame=best_effort_timestamp_time", "-of", "json", str(video)], check=True, capture_output=True, text=True, timeout=120)
timestamps = [float(frame["best_effort_timestamp_time"]) for frame in json.loads(probe.stdout)["frames"]]
assert timestamps and timestamps == sorted(timestamps), "Missing or unordered source frame timestamps"
sequences = [("timeline", 0, timestamps[-1], 0.5)]
if mode == "plains":
    sequences.append(("web-reaction", 15, min(20, timestamps[-1] - 15), 2))
elif mode == "graveyard":
    sequences.append(("sound-and-passage", 3, min(18, timestamps[-1] - 3), 2))
elif mode == "kangaku":
    sequences.append(("warning-and-dodge", 0, min(10, timestamps[-1]), 4))
selection_manifest = {"video": str(video), "selection": "Nearest original decoded frame to each requested time; labels show actual original PTS. No fps resampling.", "sequences": []}
for label, start, seconds, fps in sequences:
    folder = output / label
    folder.mkdir(exist_ok=True)
    for stale in folder.glob("*.png"):
        stale.unlink()
    for stale in output.glob(f"{label}-*.jpg"):
        stale.unlink()
    wanted = [start + sample / fps for sample in range(math.ceil(seconds * fps)) if start + sample / fps <= timestamps[-1]]
    indices = sorted({min(range(len(timestamps)), key=lambda index: abs(timestamps[index] - timestamp)) for timestamp in wanted})
    assert indices, f"No source frames for {label}"
    select = "+".join(f"eq(n\\,{index})" for index in indices)
    subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", str(video), "-vf", f"select={select},scale=480:270", "-fps_mode", "vfr", str(folder / "%03d.png")], check=True, timeout=120)
    frames = sorted(folder.glob("*.png"))
    assert len(frames) == len(indices), f"Decoded selection count mismatch for {label}"
    selection_manifest["sequences"].append({"label": label, "frames": [{"file": str(frame.relative_to(output)), "source_frame_index": source_index, "pts_seconds": timestamps[source_index]} for frame, source_index in zip(frames, indices)]})
    for part, offset in enumerate(range(0, len(frames), 12)):
        group = frames[offset:offset + 12]
        sheet = Image.new("RGB", (4 * 480, math.ceil(len(group) / 4) * 296), "#10191b")
        draw = ImageDraw.Draw(sheet)
        for index, frame in enumerate(group):
            x, y = (index % 4) * 480, (index // 4) * 296
            with Image.open(frame) as decoded:
                sheet.paste(decoded, (x, y + 26))
            timestamp = timestamps[indices[offset + index]]
            draw.text((x + 8, y + 6), f"{video.name} | {timestamp:06.3f}s | decoded frame", fill="white", font=caption_font)
        sheet.save(output / f"{label}-{part + 1:02d}.jpg", quality=95)
(output / "selected-frames.json").write_text(json.dumps(selection_manifest, indent=2) + "\n")
print(f"FILMSTRIPS_OK {output}")
