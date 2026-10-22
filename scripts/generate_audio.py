#!/usr/bin/env python3
"""Synthesizes Cozy Shopkeeper's original sound effects and music loop.

Everything is generated from sine/triangle waves and noise — no samples or
third-party audio. Requires numpy; ffmpeg is used to encode the music to AAC.

    python3 scripts/generate_audio.py App/Resources/Audio
"""
import os
import subprocess
import sys
import wave

import numpy as np

RATE = 44100


def note(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def env(n, attack=0.005, decay=0.3, rate=RATE):
    t = np.arange(n) / rate
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def bell_tone(freq, dur, decay=0.35, partials=((1, 1.0), (2.01, 0.35), (3.0, 0.12), (4.2, 0.06))):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for mult, amp in partials:
        out += amp * np.sin(2 * np.pi * freq * mult * t) * np.exp(-t / (decay / mult ** 0.5))
    return out * env(n, 0.003, 10)


def soft_tone(freq, dur, decay=0.5):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    tri = 2 / np.pi * np.arcsin(np.sin(2 * np.pi * freq * t))
    return (0.7 * np.sin(2 * np.pi * freq * t) + 0.3 * tri) * env(n, 0.01, decay)


def place(buf, sound, start_s):
    i = int(start_s * RATE)
    end = min(len(buf), i + len(sound))
    buf[i:end] += sound[: end - i]


def finish(x, peak=0.6, fade_out=True):
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1
    x = x / m * peak
    if fade_out:
        fade = int(0.01 * RATE)
        x[-fade:] *= np.linspace(1, 0, fade)
    return x


def write_wav(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def sfx(out_dir):
    sounds = {}

    b = np.zeros(int(0.55 * RATE))
    place(b, bell_tone(note("E6"), 0.5, 0.18), 0)
    place(b, bell_tone(note("B6"), 0.45, 0.2) * 0.8, 0.07)
    sounds["coin"] = finish(b, 0.5)

    b = np.zeros(int(0.8 * RATE))
    for i, n in enumerate(["C6", "E6", "G6", "C7"]):
        place(b, bell_tone(note(n), 0.5, 0.2) * (0.9 - i * 0.1), i * 0.06)
    sounds["tip"] = finish(b, 0.5)

    b = np.zeros(int(1.4 * RATE))
    place(b, bell_tone(note("G6"), 1.2, 0.45, ((1, 1), (2.76, 0.4), (5.4, 0.15))), 0)
    place(b, bell_tone(note("C7"), 1.0, 0.4, ((1, 1), (2.76, 0.35), (5.4, 0.1))) * 0.7, 0.16)
    sounds["bell"] = finish(b, 0.42)

    n = int(0.08 * RATE)
    noise = np.random.default_rng(4).standard_normal(n)
    kernel = np.ones(12) / 12
    click = np.convolve(noise, kernel, mode="same") * env(n, 0.001, 0.012)
    click += 0.6 * np.sin(2 * np.pi * 720 * np.arange(n) / RATE) * env(n, 0.001, 0.02)
    sounds["tap"] = finish(click, 0.35)

    b = np.zeros(int(1.0 * RATE))
    for i, n_ in enumerate(["C5", "E5", "G5", "C6", "E6"]):
        place(b, soft_tone(note(n_), 0.6, 0.25) * 0.8, i * 0.07)
    sounds["upgrade"] = finish(b, 0.5)

    b = np.zeros(int(1.6 * RATE))
    for i, n_ in enumerate(["G5", "C6", "E6"]):
        place(b, bell_tone(note(n_), 0.6, 0.25), i * 0.1)
    for n_ in ["C6", "E6", "G6"]:
        place(b, bell_tone(note(n_), 1.2, 0.5) * 0.6, 0.35)
    sounds["unlock"] = finish(b, 0.5)

    b = np.zeros(int(0.6 * RATE))
    place(b, soft_tone(note("E4"), 0.3, 0.12), 0)
    place(b, soft_tone(note("C4"), 0.4, 0.18), 0.13)
    sounds["decline"] = finish(b, 0.4)

    for name, x in sounds.items():
        write_wav(os.path.join(out_dir, f"sfx_{name}.wav"), x)


def music(out_dir):
    bpm = 88
    beat = 60 / bpm
    bars = 16
    total = int(bars * 4 * beat * RATE)
    buf = np.zeros(total)

    # I - vi - IV - V in C, voiced softly.
    chords = [["C3", "G3", "E4"], ["A2", "E3", "C4"], ["F2", "C3", "A3"], ["G2", "D3", "B3"]]
    for bar in range(bars):
        chord = chords[bar % 4]
        start = bar * 4 * beat
        for i, n_ in enumerate(chord):
            pad = soft_tone(note(n_), 4 * beat + 1.5, 2.2) * 0.22
            place_wrap(buf, pad, start + i * 0.02)
        # gentle bass pulse on beats 1 and 3
        for b_ in (0, 2):
            place_wrap(buf, soft_tone(note(chord[0]), beat * 1.5, 0.5) * 0.25, start + b_ * beat)

    # Music-box melody (pentatonic), two 8-bar phrases.
    melody = [
        ("E5", 0, 1), ("G5", 1, 1), ("A5", 2, 1), ("G5", 3, 1),
        ("E5", 4, 1.5), ("D5", 5.5, 0.5), ("C5", 6, 2),
        ("D5", 8, 1), ("E5", 9, 1), ("G5", 10, 1), ("E5", 11, 1),
        ("D5", 12, 2), ("G4", 14, 2),
        ("E5", 16, 1), ("G5", 17, 1), ("C6", 18, 1.5), ("A5", 19.5, 0.5),
        ("G5", 20, 1), ("E5", 21, 1), ("D5", 22, 2),
        ("C5", 24, 1), ("D5", 25, 1), ("E5", 26, 1), ("G5", 27, 1),
        ("E5", 28, 1.5), ("D5", 29.5, 0.5), ("C5", 30, 2),
    ]
    for phrase in range(2):
        offset = phrase * 32
        for n_, start_beat, length in melody:
            tone = bell_tone(note(n_), length * beat + 1.2, 0.55, ((1, 1), (2.0, 0.25), (3.0, 0.08))) * 0.32
            place_wrap(buf, tone, (offset + start_beat) * beat)
        # A few twinkles in the second phrase
        if phrase == 1:
            for b_ in (3.5, 11.5, 19.5, 27.5):
                place_wrap(buf, bell_tone(note("E7"), 0.6, 0.15) * 0.06, (offset + b_) * beat)

    x = finish(buf, 0.45, fade_out=False)  # seamless loop: no fade
    wav_path = os.path.join(out_dir, "music_maple_corner.wav")
    write_wav(wav_path, x)
    m4a_path = os.path.join(out_dir, "music_maple_corner.m4a")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "aac", "-b:a", "96k", m4a_path], check=True)
    os.remove(wav_path)


def place_wrap(buf, sound, start_s):
    """Adds a sound, wrapping its tail to the start so the loop is seamless."""
    i = int(start_s * RATE) % len(buf)
    remaining = len(sound)
    src = 0
    while remaining > 0:
        chunk = min(remaining, len(buf) - i)
        buf[i:i + chunk] += sound[src:src + chunk]
        remaining -= chunk
        src += chunk
        i = 0


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "App/Resources/Audio"
    os.makedirs(out, exist_ok=True)
    sfx(out)
    music(out)
    print("Audio written to", out)
