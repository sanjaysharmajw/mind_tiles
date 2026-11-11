"""Generates every audio asset used by Mind Tiles.

All sounds are synthesized from scratch by this script (sine/triangle tones
with simple envelopes), so they are original works released under CC0 by the
project. Re-run with:  python3 tool/generate_audio.py
"""

import math
import os
import shutil
import subprocess
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def note(n):
    """Frequency for a MIDI note number."""
    return 440.0 * 2 ** ((n - 69) / 12)


def tone(freq, dur, vol=0.5, shape="sine", attack=0.005, release=0.08, vibrato=0.0):
    samples = []
    total = int(dur * RATE)
    for i in range(total):
        t = i / RATE
        f = freq * (1 + vibrato * math.sin(2 * math.pi * 5 * t))
        phase = 2 * math.pi * f * t
        if shape == "sine":
            v = math.sin(phase)
        elif shape == "triangle":
            v = 2 / math.pi * math.asin(math.sin(phase))
        elif shape == "soft":
            v = 0.8 * math.sin(phase) + 0.2 * math.sin(2 * phase)
        else:
            v = math.sin(phase)
        env = 1.0
        if t < attack:
            env = t / attack
        remaining = dur - t
        if remaining < release:
            env *= max(0.0, remaining / release)
        samples.append(v * env * vol)
    return samples


def decay(samples, rate=8.0):
    return [s * math.exp(-rate * i / RATE) for i, s in enumerate(samples)]


def mix(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def offset(samples, seconds):
    return [0.0] * int(seconds * RATE) + samples


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.89 / peak)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples
        )
        w.writeframes(frames)
    print("wrote", path, f"{len(samples) / RATE:.2f}s")


def main():
    os.makedirs(OUT, exist_ok=True)
    random.seed(7)

    # Tile flip: a short wooden "tock".
    tap = decay(tone(note(84), 0.09, 0.6, "soft", release=0.03), 40)
    noise = [random.uniform(-1, 1) * 0.15 * math.exp(-90 * i / RATE) for i in range(int(0.03 * RATE))]
    write("flip.wav", mix(tap, noise))

    # UI button: soft high click.
    write("button.wav", decay(tone(note(91), 0.06, 0.4, "sine", release=0.02), 55))

    # Match: two-note rising chime with a sparkle on top.
    match = mix(
        decay(tone(note(76), 0.35, 0.45, "soft"), 6),
        offset(decay(tone(note(83), 0.45, 0.45, "soft"), 6), 0.08),
        offset(decay(tone(note(95), 0.3, 0.12, "sine"), 10), 0.1),
    )
    write("match.wav", match)

    # Mismatch: gentle descending "bwomp" (not harsh).
    mismatch = mix(
        decay(tone(note(57), 0.18, 0.4, "triangle", vibrato=0.01), 6),
        offset(decay(tone(note(52), 0.28, 0.4, "triangle", vibrato=0.01), 6), 0.12),
    )
    write("mismatch.wav", mismatch)

    # Hint: airy shimmer.
    hint = mix(*[offset(decay(tone(note(n), 0.3, 0.2, "sine"), 9), i * 0.05) for i, n in enumerate([88, 91, 95, 100])])
    write("hint.wav", hint)

    # Victory fanfare: major arpeggio then chord.
    arp = [72, 76, 79, 84]
    parts = [offset(decay(tone(note(n), 0.5, 0.35, "soft"), 4), i * 0.11) for i, n in enumerate(arp)]
    chord = [offset(decay(tone(note(n), 1.2, 0.25, "soft", release=0.6), 2.5), 0.5) for n in (72, 76, 79, 84, 88)]
    write("victory.wav", mix(*(parts + chord)))

    # Failure: slow descending minor figure.
    lose = [offset(decay(tone(note(n), 0.5, 0.35, "triangle"), 3.5), i * 0.22) for i, n in enumerate([67, 63, 60, 55])]
    write("fail.wav", mix(*lose))

    # Star pop for results screen.
    write("star.wav", mix(decay(tone(note(88), 0.25, 0.4, "sine"), 12), offset(decay(tone(note(93), 0.25, 0.25, "sine"), 12), 0.04)))

    # Background music: calm pentatonic loop, 16 bars of 1s at 60bpm-ish pulse.
    progression = [(48, 55, 64), (45, 52, 60), (41, 48, 57), (43, 50, 59)]
    melody_scale = [72, 74, 76, 79, 81, 84]
    bar = 2.0
    music = [0.0] * int(bar * 8 * RATE)
    for b in range(8):
        root = progression[b % 4]
        start = b * bar
        for n in root:
            pad = offset(tone(note(n), bar, 0.07, "sine", attack=0.4, release=0.6), start)
            for i, s in enumerate(pad):
                if i < len(music):
                    music[i] += s
        for step in range(4):
            if random.random() < 0.8:
                n = random.choice(melody_scale)
                pluck = offset(decay(tone(note(n), 0.45, 0.09, "soft", release=0.2), 5), start + step * 0.5)
                for i, s in enumerate(pluck):
                    if i < len(music):
                        music[i] += s
    write("music_loop.wav", music)
    # Compress the music loop to AAC (keeps every file < 512 KiB for
    # YouTube Playables and shrinks the app). Uses macOS afconvert.
    wav = os.path.join(OUT, "music_loop.wav")
    m4a = os.path.join(OUT, "music_loop.m4a")
    if shutil.which("afconvert"):
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "64000", wav, m4a], check=True)
        os.remove(wav)
        print("wrote", m4a)
    else:
        print("afconvert not found: convert music_loop.wav to AAC .m4a manually")


if __name__ == "__main__":
    main()
