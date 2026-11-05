#!/usr/bin/env python3
"""Generate original, loop-safe industrial music using only the stdlib.

Run from the project root:
    python tools/generate_music.py
"""

from array import array
import hashlib
import math
from pathlib import Path
import random
import sys
import wave


SAMPLE_RATE = 44100
DURATION = 32.0
FRAME_COUNT = int(SAMPLE_RATE * DURATION)
MASTER_SEED = 24011987
TARGET_PEAK = 0.75
TAU = 2.0 * math.pi
ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "audio" / "music"


def smooth01(value):
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def edge_envelope(t, duration, attack, release):
    attack_gain = smooth01(t / attack) if attack else 1.0
    release_gain = smooth01((duration - t) / release) if release else 1.0
    return attack_gain * release_gain


def midi(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def mix(destination, source, gain=1.0):
    for i, value in enumerate(source):
        destination[i] += gain * value


def add_circular_delay(destination, source, delay_seconds, gain):
    """Delay on a circular timeline, including the tail across the seam."""
    delay = int(round(delay_seconds * SAMPLE_RATE))
    split = FRAME_COUNT - delay
    for i in range(split):
        destination[i + delay] += gain * source[i]
    for i in range(split, FRAME_COUNT):
        destination[i - split] += gain * source[i]


def add_tone(samples, start, duration, frequency, amplitude, voice, velocity=1.0, phase=0.0):
    """Render one enveloped voice; every event can wrap around the loop."""
    first = int(round(start * SAMPLE_RATE)) % FRAME_COUNT
    count = min(int(round(duration * SAMPLE_RATE)), FRAME_COUNT)
    amplitude *= velocity
    for offset in range(count):
        t = offset / SAMPLE_RATE
        angle = TAU * frequency * t + phase
        if voice == "pad":
            envelope = edge_envelope(t, duration, 1.25, 2.0)
            envelope *= 0.92 + 0.08 * math.sin(TAU * 0.31 * t + phase)
            tone = math.sin(angle) + 0.15 * math.sin(2.0 * angle + 0.2)
            tone += 0.055 * math.sin(3.0 * angle + 0.4)
            tone += 0.22 * math.sin(TAU * frequency * 1.0017 * t + phase)
        elif voice == "soft_arp":
            envelope = edge_envelope(t, duration, 0.025, min(0.55, duration * 0.45))
            envelope *= 0.55 + 0.45 * math.exp(-2.8 * t / duration)
            tone = math.sin(angle) + 0.11 * math.sin(2.0 * angle)
            tone += 0.035 * math.sin(3.0 * angle + 0.3)
        elif voice == "sub":
            envelope = edge_envelope(t, duration, 0.12, 0.8)
            envelope *= 0.88 + 0.12 * math.exp(-2.0 * t / duration)
            tone = math.sin(angle) + 0.12 * math.sin(2.0 * angle)
        elif voice == "bass":
            envelope = edge_envelope(t, duration, 0.006, 0.065)
            envelope *= 0.72 + 0.28 * math.exp(-5.0 * t / duration)
            tone = math.sin(angle) + 0.27 * math.sin(2.0 * angle)
            tone += 0.095 * math.sin(3.0 * angle) + 0.025 * math.sin(5.0 * angle)
        elif voice == "arp":
            envelope = edge_envelope(t, duration, 0.004, min(0.07, duration * 0.45))
            envelope *= 0.48 + 0.52 * math.exp(-5.5 * t / duration)
            tone = math.sin(angle) + 0.22 * math.sin(2.0 * angle)
            tone += 0.075 * math.sin(3.0 * angle + 0.15)
        elif voice == "stab":
            envelope = edge_envelope(t, duration, 0.035, 0.5)
            envelope *= 0.75 + 0.25 * math.exp(-3.0 * t / duration)
            tone = math.sin(angle) + 0.12 * math.sin(2.0 * angle)
            tone += 0.04 * math.sin(3.0 * angle)
        else:
            raise ValueError(f"Unknown voice: {voice}")
        index = first + offset
        if index >= FRAME_COUNT:
            index -= FRAME_COUNT
        samples[index] += amplitude * envelope * tone


def add_kick(samples, start, amplitude=0.28):
    duration = 0.46
    first = int(round(start * SAMPLE_RATE)) % FRAME_COUNT
    count = int(duration * SAMPLE_RATE)
    for offset in range(count):
        t = offset / SAMPLE_RATE
        phase = TAU * (47.0 * t + 78.0 * 0.032 * (1.0 - math.exp(-t / 0.032)))
        body = math.sin(phase) + 0.16 * math.sin(2.0 * phase)
        envelope = edge_envelope(t, duration, 0.0015, 0.065) * math.exp(-t / 0.14)
        index = first + offset
        if index >= FRAME_COUNT:
            index -= FRAME_COUNT
        samples[index] += amplitude * envelope * body


def add_snare(samples, start, rng, amplitude=0.105):
    duration = 0.29
    first = int(round(start * SAMPLE_RATE)) % FRAME_COUNT
    count = int(duration * SAMPLE_RATE)
    low = 0.0
    for offset in range(count):
        t = offset / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        low += 0.19 * (noise - low)
        metal = math.sin(TAU * 176.0 * t) + 0.35 * math.sin(TAU * 327.0 * t)
        envelope = edge_envelope(t, duration, 0.001, 0.07) * math.exp(-t / 0.095)
        value = 0.58 * (noise - low) + 0.42 * metal
        index = first + offset
        if index >= FRAME_COUNT:
            index -= FRAME_COUNT
        samples[index] += amplitude * envelope * value


def add_hat(samples, start, rng, amplitude=0.025, duration=0.075):
    first = int(round(start * SAMPLE_RATE)) % FRAME_COUNT
    count = int(duration * SAMPLE_RATE)
    low = 0.0
    for offset in range(count):
        t = offset / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        low += 0.32 * (noise - low)
        envelope = edge_envelope(t, duration, 0.001, 0.022) * math.exp(-t / 0.026)
        value = 0.75 * (noise - low) + 0.25 * math.sin(TAU * 1320.0 * t)
        index = first + offset
        if index >= FRAME_COUNT:
            index -= FRAME_COUNT
        samples[index] += amplitude * envelope * value


def add_air(samples, start, duration, rng, amplitude=0.022):
    """A soft, enveloped pressure-valve texture with no edge discontinuity."""
    first = int(round(start * SAMPLE_RATE)) % FRAME_COUNT
    count = int(duration * SAMPLE_RATE)
    low = 0.0
    slower = 0.0
    for offset in range(count):
        t = offset / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        low += 0.045 * (noise - low)
        slower += 0.006 * (low - slower)
        envelope = edge_envelope(t, duration, 0.8, 1.1)
        envelope *= 0.8 + 0.2 * math.sin(TAU * 0.7 * t)
        index = first + offset
        if index >= FRAME_COUNT:
            index -= FRAME_COUNT
        samples[index] += amplitude * envelope * (low - slower)


def add_loop_drone(samples):
    """Periodic machine fundamentals: frequencies and LFOs complete whole cycles."""
    fundamental = round(midi(38) * DURATION) / DURATION
    fifth = round(midi(45) * DURATION) / DURATION
    for i in range(FRAME_COUNT):
        t = i / SAMPLE_RATE
        loop_phase = TAU * i / FRAME_COUNT
        angle = TAU * fundamental * t
        breath = 0.88 + 0.12 * math.sin(4.0 * loop_phase - 0.4)
        drone = math.sin(angle) + 0.18 * math.sin(2.0 * angle + 0.15)
        drone += 0.055 * math.sin(3.0 * angle + 0.3)
        samples[i] += 0.055 * breath * drone
        samples[i] += 0.011 * (0.9 + 0.1 * math.sin(2.0 * loop_phase)) * math.sin(TAU * fifth * t)


def make_menu():
    rng = random.Random(MASTER_SEED + 101)
    samples = [0.0] * FRAME_COUNT
    tonal = [0.0] * FRAME_COUNT
    add_loop_drone(samples)

    chords = (
        (50, 53, 57, 60, 64),       # Dm9
        (46, 50, 53, 57, 62),       # Bbmaj7
        (48, 52, 55, 57, 60),       # Fmaj9/C
        (45, 50, 52, 57, 59),       # Aadd9
    )
    roots = (38, 34, 41, 33)
    arp_order = (0, 2, 1, 3, 4, 2, 1, 3)

    for section in range(4):
        start = section * 8.0
        chord = chords[section]
        for note_index, note in enumerate(chord):
            add_tone(tonal, start - 0.35, 9.3, midi(note), 0.038, "pad",
                     phase=note_index * 0.37)
        add_tone(samples, start - 0.2, 8.9, midi(roots[section]), 0.115, "sub")
        add_tone(samples, start + 3.8, 4.7, midi(roots[section] + 7), 0.035, "sub")
        for step, chord_index in enumerate(arp_order):
            if step in (3, 6):
                continue
            note = chord[chord_index] + 12
            velocity = (0.82, 0.64, 0.76, 0.68)[(step + section) % 4]
            add_tone(tonal, start + step, 1.85, midi(note), 0.082,
                     "soft_arp", velocity=velocity, phase=0.15 * section)
        add_air(samples, start + 3.7, 3.5, rng, amplitude=0.032)

    mix(samples, tonal, 0.9)
    for delay, gain in ((0.75, 0.22), (1.5, 0.13), (2.75, 0.075), (4.5, 0.035)):
        add_circular_delay(samples, tonal, delay, gain)
    return samples


def make_battle():
    rng = random.Random(MASTER_SEED + 202)
    samples = [0.0] * FRAME_COUNT
    tonal = [0.0] * FRAME_COUNT

    # Sixteen bars at 120 BPM; harmony changes every four bars.
    pads = (
        (50, 53, 57, 60),           # Dm7
        (46, 50, 53, 58),           # Bb
        (50, 55, 58, 62),           # Gm/D
        (49, 52, 57, 61),           # A7
    )
    arps = (
        (62, 65, 69, 72),
        (58, 62, 65, 69),
        (58, 62, 67, 70),
        (57, 61, 64, 69),
    )
    roots = (38, 34, 31, 33)
    bass_patterns = (
        (0, 0, 12, 0, 0, 7, 12, 7),
        (0, 12, 0, 7, 0, 12, 7, 12),
    )
    arp_patterns = (
        (0, None, 1, 2, 3, None, 2, 1, 0, 2, None, 3, 1, None, 2, 3),
        (0, 2, None, 1, 3, None, 2, None, 1, None, 3, 2, 0, 2, None, 3),
    )

    for section in range(4):
        section_start = section * 8.0
        for note_index, note in enumerate(pads[section]):
            add_tone(tonal, section_start - 0.15, 8.65, midi(note), 0.032,
                     "stab", phase=note_index * 0.29)

    for bar in range(16):
        section = bar // 4
        bar_start = bar * 2.0
        root = roots[section]
        bass_pattern = bass_patterns[(bar + section) % 2]
        for step, interval in enumerate(bass_pattern):
            accent = 1.0 if step in (0, 4) else 0.78
            if bar % 4 == 3 and step == 7:
                interval = 12
                accent = 0.92
            add_tone(samples, bar_start + step * 0.25, 0.215,
                     midi(root + interval), 0.145, "bass", velocity=accent)

        arp_pattern = arp_patterns[(bar + section) % 2]
        for step, chord_index in enumerate(arp_pattern):
            if chord_index is None:
                continue
            note = arps[section][chord_index]
            if bar % 4 == 3 and step >= 12:
                note += 12
            velocity = 0.9 if step % 4 == 0 else 0.65
            add_tone(tonal, bar_start + step * 0.125, 0.17,
                     midi(note), 0.072, "arp", velocity=velocity)

        for beat in range(4):
            add_kick(samples, bar_start + beat * 0.5, amplitude=0.255 if beat else 0.285)
        if bar % 4 == 3:
            add_kick(samples, bar_start + 1.75, amplitude=0.19)
        add_snare(samples, bar_start + 0.5, rng, amplitude=0.092)
        add_snare(samples, bar_start + 1.5, rng, amplitude=0.105)
        for eighth in range(8):
            if eighth in (3, 7) and bar % 2 == 0:
                continue
            add_hat(samples, bar_start + eighth * 0.25, rng,
                    amplitude=0.022 if eighth % 2 == 0 else 0.015,
                    duration=0.065 if eighth < 7 else 0.11)
        if bar % 4 == 3:
            add_snare(samples, bar_start + 1.875, rng, amplitude=0.045)

    mix(samples, tonal, 0.92)
    for delay, gain in ((0.375, 0.18), (0.75, 0.095), (1.125, 0.04)):
        add_circular_delay(samples, tonal, delay, gain)
    return samples


def master(samples):
    """Remove DC, leave 25% peak headroom, and quantize to signed PCM16."""
    dc = math.fsum(samples) / FRAME_COUNT
    centered = [value - dc for value in samples]
    peak = max(abs(value) for value in centered)
    if peak == 0.0:
        raise RuntimeError("Refusing to write silent music")
    gain = TARGET_PEAK / peak
    pcm = array("h", (int(round(max(-1.0, min(1.0, value * gain)) * 32767.0))
                      for value in centered))
    if sys.byteorder != "little":
        pcm.byteswap()
    return pcm


def write_music(filename, samples):
    pcm = master(samples)
    path = OUTPUT_DIR / filename
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.setnframes(FRAME_COUNT)
        output.writeframes(pcm.tobytes())
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    print(f"{filename}: {FRAME_COUNT} frames, peak={TARGET_PEAK:.2f}, sha256={digest}")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    write_music("menu_loop.wav", make_menu())
    write_music("battle_loop.wav", make_battle())


if __name__ == "__main__":
    main()
