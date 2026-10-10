#!/usr/bin/env python3
"""Generate small, deterministic mono WAVs; no packages or external samples.

Run before Godot import. Frequencies and envelopes are deliberately restrained;
actual loudness and the feel of these sounds still require listening on a device.
"""
from __future__ import annotations

import hashlib
import io
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "assets" / "audio"
RATE = 22050
TAU = 2.0 * math.pi


def make_sound(name: str, seconds: float) -> bytes:
    count = int(RATE * seconds)
    seed = int.from_bytes(hashlib.sha256(name.encode()).digest()[:8], "big")
    rng = random.Random(seed)
    samples = bytearray()
    filtered = 0.0
    for index in range(count):
        t = index / RATE
        u = index / max(1, count - 1)
        filtered = filtered * 0.96 + rng.uniform(-1.0, 1.0) * 0.04
        envelope = min(1.0, t / 0.025) * min(1.0, (seconds - t) / 0.06)
        if name == "pod_hum":
            # Integer cycles create a quiet loop with matched endpoints.
            signal = 0.10 * math.sin(TAU * 66 * t) + 0.04 * math.sin(TAU * 99 * t)
            signal *= 0.8 + 0.2 * math.sin(TAU * t / seconds)
        elif name == "water":
            signal = 0.22 * filtered + 0.025 * math.sin(TAU * 42 * t)
            signal += 0.024 * math.sin(TAU * (370 * t + 35 * math.sin(t * 7))) * math.sin(TAU * t * 1.5) ** 12
        elif name == "warning":
            pulse = 1.0 if (t % 0.28) < 0.14 else 0.0
            signal = pulse * 0.19 * math.sin(TAU * 610 * t)
        elif name == "pulse":
            signal = 0.34 * math.sin(TAU * (100 * t + 900 * t * t)) * math.exp(-5 * u)
            signal += 0.20 * filtered * math.exp(-3 * u)
        elif name == "pickup":
            signal = 0.20 * math.sin(TAU * (560 * t + 400 * t * t)) * math.exp(-5 * u)
        elif name == "success":
            notes = (261.6256, 329.6276, 391.9954, 523.2511)
            signal = 0.0
            for note_index, frequency in enumerate(notes):
                age = t - note_index * 0.22
                if age > 0:
                    signal += 0.075 * math.sin(TAU * frequency * age) * math.exp(-age * 1.8) * min(1.0, age / 0.02)
        elif name == "membrane":
            signal = 0.17 * math.sin(TAU * (170 * t - 30 * t * t)) * math.exp(-2 * u)
            signal += 0.18 * filtered * math.sin(math.pi * u)
        elif name == "hogara":
            signal = 0.16 * math.sin(TAU * (49 * t + 1.2 * math.sin(TAU * t * 0.3)))
            signal += 0.08 * math.sin(TAU * 73.5 * t) + 0.14 * filtered
            signal *= math.sin(math.pi * u) ** 2
        elif name == "ui":
            signal = 0.12 * math.sin(TAU * 720 * t) * math.exp(-7 * u)
        else:
            raise ValueError(name)
        value = max(-1.0, min(1.0, signal * envelope))
        samples.extend(struct.pack("<h", round(value * 32767)))
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(samples)
    return buffer.getvalue()


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    sounds = {"pod_hum": 4.0, "water": 4.0, "warning": 0.65, "pulse": 0.7,
              "pickup": 0.35, "success": 2.2, "membrane": 0.8, "hogara": 2.0, "ui": 0.14}
    for name, duration in sounds.items():
        path = DESTINATION / f"{name}.wav"
        data = make_sound(name, duration)
        if not path.exists() or path.read_bytes() != data:
            path.write_bytes(data)
        with wave.open(str(path), "rb") as wav:
            assert wav.getnframes() == int(RATE * duration) and wav.getnchannels() == 1
    print(f"ASSETS_OK: {len(sounds)} deterministic PCM16 WAVs / {RATE} Hz")


if __name__ == "__main__":
    main()
