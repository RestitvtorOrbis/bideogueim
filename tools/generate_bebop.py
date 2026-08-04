#!/usr/bin/env python3
"""Generate the original, deterministic bebop loop used by the game.

The renderer uses only Python's standard library so the musical source stays
reproducible in CI and in the Godot container.  It renders four independent
layers (bass, drums, piano and sax-like lead), mixes them with headroom, and
optionally asks ffmpeg for an OGG Vorbis delivery file.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path


SAMPLE_RATE = 44100
BPM = 188
BARS = 32
BEATS_PER_BAR = 4
BEAT_SECONDS = 60.0 / BPM
TOTAL_BEATS = BARS * BEATS_PER_BAR
DURATION_SECONDS = TOTAL_BEATS * BEAT_SECONDS
SEED = 26431
OUTPUT_NAME = "bebop_night_drive"


def midi_to_hz(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def add_note(buffer: list[float], start: float, duration: float, note: float,
             amplitude: float, voice: str, sample_rate: int) -> None:
    first = max(0, int(start * sample_rate))
    count = min(len(buffer) - first, max(1, int(duration * sample_rate)))
    if count <= 0:
        return
    frequency = midi_to_hz(note)
    for offset in range(count):
        age = offset / sample_rate
        if voice == "bass":
            envelope = min(1.0, age / 0.012) * math.exp(-age / max(duration, 0.08) * 1.9)
            value = (math.sin(2.0 * math.pi * frequency * age) * 0.82
                     + math.sin(4.0 * math.pi * frequency * age) * 0.16
                     + math.sin(6.0 * math.pi * frequency * age) * 0.05)
        elif voice == "piano":
            envelope = min(1.0, age / 0.006) * math.exp(-age / max(duration, 0.06) * 4.6)
            value = (math.sin(2.0 * math.pi * frequency * age) * 0.65
                     + math.sin(4.0 * math.pi * frequency * age) * 0.24
                     + math.sin(6.0 * math.pi * frequency * age) * 0.10
                     + math.sin(8.0 * math.pi * frequency * age) * 0.04)
        else:
            release = min(0.16, max(0.04, duration * 0.28))
            attack = min(1.0, age / 0.018)
            tail = min(1.0, max(0.0, duration - age) / release)
            envelope = attack * tail * (0.86 + 0.14 * math.exp(-age * 2.0))
            vibrato = 1.0 + 0.004 * math.sin(2.0 * math.pi * 5.4 * age)
            phase = 2.0 * math.pi * frequency * age * vibrato
            value = (math.sin(phase) * 0.62 + math.sin(2.0 * phase) * 0.25
                     + math.sin(3.0 * phase) * 0.13 + math.sin(4.0 * phase) * 0.06)
        buffer[first + offset] += amplitude * envelope * value


def add_drum(buffer: list[float], start: float, duration: float, amplitude: float,
             kind: str, rng: random.Random, sample_rate: int) -> None:
    first = max(0, int(start * sample_rate))
    count = min(len(buffer) - first, max(1, int(duration * sample_rate)))
    if count <= 0:
        return
    phase = rng.random() * math.tau
    for offset in range(count):
        age = offset / sample_rate
        if kind == "kick":
            envelope = math.exp(-age * 34.0)
            frequency = 118.0 - 72.0 * min(1.0, age / 0.08)
            value = math.sin(math.tau * frequency * age + phase) * envelope
        elif kind == "snare":
            envelope = math.exp(-age * 31.0)
            noise = rng.uniform(-1.0, 1.0)
            value = (noise * 0.78 + math.sin(math.tau * 184.0 * age) * 0.22) * envelope
        else:
            envelope = math.exp(-age * 22.0)
            noise = rng.uniform(-1.0, 1.0)
            value = (noise * 0.52 + math.sin(math.tau * 3_640.0 * age) * 0.48) * envelope
        buffer[first + offset] += amplitude * value


def chord_for_bar(bar: int) -> tuple[int, ...]:
    # Two eight-bar cycles: minor ii-V language, bright major resolutions and
    # a turnaround. The second cycle changes key for a compact bebop lift.
    first = (
        (48, 51, 55, 58),  # Cm7
        (53, 57, 60, 63),  # F7
        (46, 50, 53, 57),  # Bbmaj7
        (51, 55, 58, 62),  # Ebmaj7
        (45, 48, 51, 55),  # A half-diminished
        (50, 54, 57, 60),  # D7
        (43, 46, 50, 53),  # Gm7
        (48, 52, 55, 58),  # C7
    )
    second = (
        (51, 55, 58, 62),  # Ebmaj7
        (56, 60, 63, 66),  # Ab7
        (49, 53, 56, 60),  # Dbmaj7
        (54, 58, 61, 65),  # Gbmaj7
        (47, 50, 53, 57),  # B half-diminished
        (52, 56, 59, 62),  # E7
        (45, 49, 52, 56),  # Amaj7
        (50, 54, 57, 60),  # D7 turnaround
    )
    return (first if (bar // 8) % 2 == 0 else second)[bar % 8]


def render(seed: int, sample_rate: int) -> tuple[list[float], dict[str, list[float]]]:
    length = int(round(DURATION_SECONDS * sample_rate))
    layers = {name: [0.0] * length for name in ("bass", "drums", "piano", "lead")}
    rng = random.Random(seed)

    for bar in range(BARS):
        bar_start = bar * BEATS_PER_BAR * BEAT_SECONDS
        chord = chord_for_bar(bar)
        root = chord[0]

        # Walking bass: roots, chord tones and chromatic approaches on every beat.
        bass_pattern = (root - 12, chord[1] - 12, chord[2] - 12,
                        chord[0] - 11 if bar % 2 else chord[3] - 12)
        for beat, note in enumerate(bass_pattern):
            add_note(layers["bass"], bar_start + beat * BEAT_SECONDS,
                     BEAT_SECONDS * 0.82, note, 0.31, "bass", sample_rate)

        # Light two-feel kick plus swing ride and snare on 2/4.
        for beat in range(4):
            if beat in (0, 2) or (bar + beat) % 4 == 3:
                add_drum(layers["drums"], bar_start + beat * BEAT_SECONDS,
                         0.23, 0.22, "kick", rng, sample_rate)
            if beat in (1, 3):
                add_drum(layers["drums"], bar_start + beat * BEAT_SECONDS,
                         0.16, 0.20, "snare", rng, sample_rate)
        for eighth in range(8):
            swing_offset = 0.0 if eighth % 2 == 0 else BEAT_SECONDS * 0.34
            ride_time = bar_start + (eighth // 2) * BEAT_SECONDS + swing_offset
            add_drum(layers["drums"], ride_time, 0.12, 0.105, "ride", rng, sample_rate)
            if eighth % 2 == 1 and (bar + eighth) % 3 == 0:
                add_drum(layers["drums"], ride_time, 0.075, 0.045, "snare", rng, sample_rate)

        # Rootless-ish piano voicings, short and late in the beat for comping.
        for beat in (1, 3):
            hit = bar_start + beat * BEAT_SECONDS + BEAT_SECONDS * 0.08
            for index, note in enumerate(chord[1:]):
                add_note(layers["piano"], hit, BEAT_SECONDS * 0.28,
                         note + (12 if index == 2 else 0), 0.075, "piano", sample_rate)
        if bar % 4 == 3:
            hit = bar_start + 3.5 * BEAT_SECONDS
            for note in chord:
                add_note(layers["piano"], hit, BEAT_SECONDS * 0.2, note + 12,
                         0.045, "piano", sample_rate)

        # A deterministic, syncopated sax-like line. Each phrase resolves to a
        # chord tone on beat 1 and leaves space for the rhythm section.
        scale = sorted(set(chord + (chord[0] + 12, chord[1] + 12, chord[3] + 12)))
        phrase_seed = random.Random(seed + bar * 101)
        for eighth in range(6):
            if eighth in (2, 5) and phrase_seed.random() < 0.58:
                continue
            step = phrase_seed.randrange(len(scale))
            note = scale[step] + (12 if bar % 3 == 1 else 0)
            start = bar_start + (eighth * 0.5 + (0.17 if eighth % 2 else 0.0)) * BEAT_SECONDS
            duration = BEAT_SECONDS * (0.28 if eighth % 2 else 0.42)
            add_note(layers["lead"], start, duration, note + 12, 0.14, "lead", sample_rate)

    # Keep the loop boundary quiet for a few samples. This removes the only
    # possible discontinuity while leaving the musical phrase untouched.
    seam = min(128, length // 100)
    for index in range(seam):
        fade = index / max(1, seam - 1)
        for layer in layers.values():
            layer[index] *= fade
            layer[-seam + index] *= 1.0 - fade

    pans = {"bass": (0.48, 0.52), "drums": (0.62, 0.38),
            "piano": (0.40, 0.60), "lead": (0.58, 0.42)}
    gains = {"bass": 0.92, "drums": 0.84, "piano": 0.82, "lead": 0.88}
    stereo = [0.0] * (length * 2)
    for name, layer in layers.items():
        left_pan, right_pan = pans[name]
        gain = gains[name]
        for index, value in enumerate(layer):
            stereo[index * 2] += value * gain * left_pan
            stereo[index * 2 + 1] += value * gain * right_pan
    peak = max(abs(value) for value in stereo) or 1.0
    target = 0.78
    scale = target / peak
    for index in range(len(stereo)):
        stereo[index] = clamp(stereo[index] * scale, -0.98, 0.98)
    return stereo, layers


def write_wav(path: Path, samples: list[float], sample_rate: int) -> tuple[float, str]:
    peak_sample = 0
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        frames = bytearray()
        for value in samples:
            sample = int(clamp(value, -1.0, 1.0) * 32767.0)
            peak_sample = max(peak_sample, abs(sample))
            frames += sample.to_bytes(2, "little", signed=True)
        output.writeframes(frames)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return peak_sample / 32768.0, digest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path,
                        default=Path(__file__).resolve().parents[1] / "assets" / "audio" / "music")
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--sample-rate", type=int, default=SAMPLE_RATE, choices=(44100, 48000))
    parser.add_argument("--force-wav", action="store_true",
                        help="Do not invoke ffmpeg even when it is installed.")
    parser.add_argument("--keep-wav", action="store_true",
                        help="Deprecated compatibility flag; the WAV is always retained.")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    wav_path = args.output_dir / f"{OUTPUT_NAME}.wav"
    ogg_path = args.output_dir / f"{OUTPUT_NAME}.ogg"
    samples, layers = render(args.seed, args.sample_rate)
    peak, digest = write_wav(wav_path, samples, args.sample_rate)
    files = [str(wav_path)]
    ffmpeg = None if args.force_wav else shutil.which("ffmpeg")
    if ffmpeg:
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temporary:
                temp_path = Path(temporary.name)
            shutil.copyfile(wav_path, temp_path)
            subprocess.run([ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                            "-i", str(temp_path), "-map_metadata", "-1",
                            "-c:a", "libvorbis", "-q:a", "5", "-ar", str(args.sample_rate),
                            "-ac", "2", str(ogg_path)], check=True)
            # Keep the PCM master alongside the delivery OGG.  The game uses the
            # WAV as its lossless fallback, and the binary audit relies on that
            # artifact being present after every regeneration.
            files.append(str(ogg_path))
        except (OSError, subprocess.CalledProcessError) as error:
            print(f"ffmpeg conversion unavailable ({error}); keeping PCM WAV")
        finally:
            if temp_path is not None:
                temp_path.unlink(missing_ok=True)
    metrics = {
        "seed": args.seed,
        "duration_seconds": round(DURATION_SECONDS, 6),
        "sample_rate": args.sample_rate,
        "channels": 2,
        "peak": round(peak, 6),
        "sha256": digest,
        "files": files,
        "layer_rms": {
            name: round(math.sqrt(sum(value * value for value in layer) / len(layer)), 6)
            for name, layer in layers.items()
        },
    }
    print(json.dumps(metrics, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
