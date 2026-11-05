#!/usr/bin/env python3
"""Generate original mono industrial-electronic sound effects with stdlib only.

Run from the project root:
    python tools/generate_sfx.py
"""

from array import array
import math
from pathlib import Path
import random
import sys
import wave


SAMPLE_RATE = 44100
MASTER_SEED = 731904
TARGET_PEAK = 0.84
TAU = 2.0 * math.pi
ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "audio" / "sfx"


def frame_count(duration):
    return int(round(duration * SAMPLE_RATE))


def smooth01(value):
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def edge_envelope(t, duration, attack, release):
    attack_gain = smooth01(t / attack) if attack > 0.0 else 1.0
    release_gain = smooth01((duration - t) / release) if release > 0.0 else 1.0
    return attack_gain * release_gain


def sweep_phase(f_start, f_end, t, sweep_duration):
    """Phase of a linear frequency sweep, in radians."""
    sweep_duration = max(1e-9, sweep_duration)
    sweep_t = min(t, sweep_duration)
    phase = f_start * sweep_t + 0.5 * (f_end - f_start) * sweep_t * sweep_t / sweep_duration
    if t > sweep_duration:
        phase += f_end * (t - sweep_duration)
    return TAU * phase


def add_note(samples, start, length, frequency, amplitude, brightness=0.22):
    """Add a compact electronic note with its own click-free envelope."""
    first = max(0, int(start * SAMPLE_RATE))
    count = min(int(length * SAMPLE_RATE), len(samples) - first)
    for j in range(max(0, count)):
        t = j / SAMPLE_RATE
        phase = TAU * frequency * t
        tone = math.sin(phase) + brightness * math.sin(2.0 * phase)
        tone += 0.07 * math.sin(3.0 * phase)
        envelope = edge_envelope(t, length, 0.006, min(0.075, length * 0.35))
        envelope *= math.exp(-2.1 * t / length)
        samples[first + j] += amplitude * envelope * tone


def make_ui(duration, rng):
    samples = []
    low_noise = 0.0
    for i in range(frame_count(duration)):
        t = i / SAMPLE_RATE
        phase = sweep_phase(2100.0, 980.0, t, duration)
        noise = rng.uniform(-1.0, 1.0)
        low_noise += 0.18 * (noise - low_noise)
        click = noise - low_noise
        envelope = edge_envelope(t, duration, 0.0012, 0.009)
        envelope *= math.exp(-t / 0.019)
        sample = 0.78 * math.sin(phase) + 0.18 * math.sin(2.0 * phase)
        samples.append(envelope * (sample + 0.14 * click))
    return samples


def make_place(duration, rng):
    samples = []
    low_noise = 0.0
    for i in range(frame_count(duration)):
        t = i / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        low_noise += 0.11 * (noise - low_noise)
        body_phase = sweep_phase(155.0, 62.0, t, 0.075)
        body = math.sin(body_phase) * math.exp(-t / 0.046)
        metal = (
            math.sin(TAU * 610.0 * t)
            + 0.52 * math.sin(TAU * 947.0 * t)
            + 0.24 * math.sin(TAU * 1421.0 * t)
        ) * math.exp(-t / 0.024)
        impact_noise = low_noise * math.exp(-t / 0.028)
        envelope = edge_envelope(t, duration, 0.002, 0.022)
        samples.append(envelope * (0.9 * body + 0.31 * metal + 0.55 * impact_noise))
    return samples


def make_upgrade(duration, rng):
    del rng
    samples = [0.0] * frame_count(duration)
    for start, frequency in zip((0.0, 0.065, 0.13, 0.195), (523.25, 659.25, 783.99, 1046.50)):
        add_note(samples, start, 0.15, frequency, 0.56)
    for i in range(len(samples)):
        t = i / SAMPLE_RATE
        sweep = math.sin(sweep_phase(330.0, 990.0, t, 0.27))
        samples[i] += 0.09 * sweep * edge_envelope(t, duration, 0.02, 0.06) * math.exp(-t / 0.3)
    return samples


def make_invalid(duration, rng):
    del rng
    samples = []
    for i in range(frame_count(duration)):
        t = i / SAMPLE_RATE
        phase = sweep_phase(185.0, 102.0, t, duration)
        buzz = math.sin(phase) + 0.38 * math.sin(3.0 * phase) + 0.16 * math.sin(5.0 * phase)
        gate = 0.76 + 0.24 * math.sin(TAU * 24.0 * t - math.pi / 2.0)
        envelope = edge_envelope(t, duration, 0.006, 0.026)
        envelope *= 0.82 + 0.18 * math.exp(-t / 0.08)
        samples.append(envelope * gate * buzz)
    return samples


def make_shoot(duration, rng):
    samples = []
    low_noise = 0.0
    for i in range(frame_count(duration)):
        t = i / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        low_noise += 0.24 * (noise - low_noise)
        crack = noise - low_noise
        phase = sweep_phase(1150.0, 235.0, t, 0.065)
        shot = math.sin(phase) + 0.3 * math.sin(2.7 * phase)
        envelope = edge_envelope(t, duration, 0.001, 0.012)
        envelope *= math.exp(-t / 0.026)
        samples.append(envelope * (0.62 * shot + 0.58 * crack))
    return samples


def make_heavy_shot(duration, rng):
    samples = []
    low_noise = 0.0
    for i in range(frame_count(duration)):
        t = i / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        low_noise += 0.075 * (noise - low_noise)
        phase = sweep_phase(112.0, 41.0, t, 0.17)
        body = math.sin(phase) + 0.34 * math.sin(2.0 * phase) + 0.12 * math.sin(3.0 * phase)
        body *= math.exp(-t / 0.105)
        blast = low_noise * math.exp(-t / 0.07)
        mechanical = math.sin(TAU * 420.0 * t) * math.exp(-t / 0.018)
        envelope = edge_envelope(t, duration, 0.002, 0.035)
        samples.append(envelope * (0.94 * body + 1.15 * blast + 0.13 * mechanical))
    return samples


def make_laser(duration, rng):
    samples = []
    low_noise = 0.0
    for i in range(frame_count(duration)):
        t = i / SAMPLE_RATE
        phase = sweep_phase(2750.0, 310.0, t, 0.135)
        carrier = math.sin(phase) + 0.25 * math.sin(2.01 * phase)
        ring = 0.78 + 0.22 * math.sin(TAU * 83.0 * t)
        noise = rng.uniform(-1.0, 1.0)
        low_noise += 0.2 * (noise - low_noise)
        envelope = edge_envelope(t, duration, 0.003, 0.027)
        envelope *= 0.45 + 0.55 * math.exp(-t / 0.09)
        samples.append(envelope * (0.82 * carrier * ring + 0.08 * (noise - low_noise)))
    return samples


def make_hit(duration, rng):
    samples = []
    low_noise = 0.0
    for i in range(frame_count(duration)):
        t = i / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        low_noise += 0.16 * (noise - low_noise)
        tick = noise - low_noise
        metal = math.sin(TAU * 880.0 * t) + 0.45 * math.sin(TAU * 1327.0 * t)
        envelope = edge_envelope(t, duration, 0.001, 0.01)
        envelope *= math.exp(-t / 0.017)
        samples.append(envelope * (0.5 * metal + 0.52 * tick))
    return samples


def make_destroy(duration, rng):
    samples = [0.0] * frame_count(duration)
    low_noise = 0.0
    for i in range(len(samples)):
        t = i / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        low_noise += 0.09 * (noise - low_noise)
        phase = sweep_phase(96.0, 43.0, t, 0.18)
        body = math.sin(phase) * math.exp(-t / 0.085)
        crunch = (0.65 * low_noise + 0.2 * noise) * math.exp(-t / 0.07)
        envelope = edge_envelope(t, duration, 0.002, 0.035)
        samples[i] = envelope * (0.66 * body + 1.1 * crunch)

    # Short, discrete debris transients; no reverb tail.
    for _ in range(9):
        start = rng.uniform(0.018, 0.205)
        length = rng.uniform(0.025, 0.065)
        frequency = rng.uniform(540.0, 1950.0)
        amplitude = rng.uniform(0.12, 0.28)
        first = int(start * SAMPLE_RATE)
        count = min(int(length * SAMPLE_RATE), len(samples) - first)
        for j in range(count):
            t = j / SAMPLE_RATE
            ping = math.sin(TAU * frequency * t) + 0.3 * math.sin(TAU * frequency * 1.61 * t)
            envelope = edge_envelope(t, length, 0.001, min(0.014, length * 0.4))
            samples[first + j] += amplitude * ping * envelope * math.exp(-t / 0.018)
    return samples


def make_buff(duration, rng):
    del rng
    samples = []
    for i in range(frame_count(duration)):
        t = i / SAMPLE_RATE
        phase = sweep_phase(210.0, 840.0, t, 0.29)
        rise = math.sin(phase) + 0.28 * math.sin(2.0 * phase) + 0.1 * math.sin(3.0 * phase)
        shimmer = math.sin(TAU * (620.0 * t + 310.0 * t * t))
        pulse = 0.83 + 0.17 * math.sin(TAU * (8.0 + 22.0 * t) * t)
        envelope = edge_envelope(t, duration, 0.018, 0.055)
        envelope *= 0.72 + 0.28 * t / duration
        samples.append(envelope * pulse * (0.74 * rise + 0.18 * shimmer))
    return samples


def make_base_hit(duration, rng):
    samples = []
    low_noise = 0.0
    for i in range(frame_count(duration)):
        t = i / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        low_noise += 0.065 * (noise - low_noise)
        impact_phase = sweep_phase(92.0, 48.0, t, 0.2)
        impact = math.sin(impact_phase) * math.exp(-t / 0.14)
        alarm_phase = sweep_phase(155.0, 112.0, t, duration)
        alarm = math.sin(alarm_phase) + 0.24 * math.sin(2.0 * alarm_phase)
        alarm *= 0.72 + 0.28 * math.sin(TAU * 13.0 * t - math.pi / 2.0)
        envelope = edge_envelope(t, duration, 0.003, 0.045)
        samples.append(envelope * (0.88 * impact + 0.46 * alarm + 0.36 * low_noise * math.exp(-t / 0.1)))
    return samples


def make_victory(duration, rng):
    del rng
    samples = [0.0] * frame_count(duration)
    for start, frequency in zip((0.0, 0.12, 0.24, 0.36), (523.25, 659.25, 783.99, 1046.50)):
        length = 0.22 if start < 0.36 else 0.50
        add_note(samples, start, length, frequency, 0.52)
    for frequency in (523.25, 659.25, 783.99):
        add_note(samples, 0.52, 0.36, frequency, 0.20, brightness=0.14)
    return samples


def make_defeat(duration, rng):
    del rng
    samples = [0.0] * frame_count(duration)
    for start, frequency in zip((0.0, 0.15, 0.30, 0.45), (392.0, 329.63, 261.63, 196.0)):
        length = 0.29 if start < 0.45 else 0.42
        add_note(samples, start, length, frequency, 0.48, brightness=0.18)
    for i in range(len(samples)):
        t = i / SAMPLE_RATE
        drone = math.sin(sweep_phase(98.0, 49.0, t, 0.82))
        envelope = edge_envelope(t, duration, 0.025, 0.12)
        samples[i] += 0.16 * drone * envelope * math.exp(-t / 0.7)
    return samples


SOUNDS = (
    ("ui.wav", 0.06, make_ui),
    ("place.wav", 0.16, make_place),
    ("upgrade.wav", 0.35, make_upgrade),
    ("invalid.wav", 0.18, make_invalid),
    ("shoot.wav", 0.09, make_shoot),
    ("heavy_shot.wav", 0.24, make_heavy_shot),
    ("laser.wav", 0.16, make_laser),
    ("hit.wav", 0.07, make_hit),
    ("destroy.wav", 0.28, make_destroy),
    ("buff.wav", 0.32, make_buff),
    ("base_hit.wav", 0.35, make_base_hit),
    ("victory.wav", 0.90, make_victory),
    ("defeat.wav", 0.90, make_defeat),
)


def master(samples):
    """Remove DC, guarantee zero-valued edges, and normalize conservatively."""
    if not samples:
        raise ValueError("empty sound")
    mean = sum(samples) / len(samples)
    samples = [sample - mean for sample in samples]

    fade_in = max(1, int(0.0015 * SAMPLE_RATE))
    fade_out = max(1, int(min(0.012, len(samples) / SAMPLE_RATE * 0.18) * SAMPLE_RATE))
    for i in range(len(samples)):
        gain = 1.0
        if i < fade_in:
            gain *= smooth01(i / fade_in)
        remaining = len(samples) - 1 - i
        if remaining < fade_out:
            gain *= smooth01(remaining / fade_out)
        samples[i] *= gain

    peak = max(abs(sample) for sample in samples)
    if peak < 1e-9:
        raise ValueError("sound is silent")
    scale = TARGET_PEAK / peak
    return [sample * scale for sample in samples]


def write_wav(path, samples):
    pcm = array("h", (int(round(max(-1.0, min(1.0, sample)) * 32767.0)) for sample in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Generating {len(SOUNDS)} sounds: {SAMPLE_RATE} Hz, mono, 16-bit PCM")
    for index, (filename, duration, generator) in enumerate(SOUNDS):
        rng = random.Random(MASTER_SEED + index * 1009)
        samples = master(generator(duration, rng))
        path = OUTPUT_DIR / filename
        write_wav(path, samples)
        pcm_peak = max(abs(int(round(sample * 32767.0))) for sample in samples) / 32768.0
        actual_duration = len(samples) / SAMPLE_RATE
        print(f"{filename:15s} duration={actual_duration:.3f}s peak={pcm_peak:.4f}")


if __name__ == "__main__":
    main()
