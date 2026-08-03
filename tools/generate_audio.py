"""Genera la banda sonora original y los ambientes de la Fase 6.

Los loops largos se sintetizan como WAV y se convierten a Ogg Vorbis mediante
FFmpeg. No se descarga ni se samplea audio externo: todos los tonos, ruidos,
envolventes y cantos se producen de forma determinista en este archivo.
"""

from __future__ import annotations

import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio" / "original"
SAMPLE_RATE = 44_100
RNG = np.random.default_rng(20260803)


def midi(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def normalize(signal: np.ndarray, peak: float) -> np.ndarray:
    current = float(np.max(np.abs(signal)))
    if current > 0.0:
        signal = signal * (peak / current)
    return signal


def write_wav(path: Path, signal: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    signal = np.clip(signal, -1.0, 1.0)
    pcm = np.int16(signal * 32767.0)
    channels = 1 if pcm.ndim == 1 else pcm.shape[1]
    with wave.open(str(path), "wb") as output:
        output.setnchannels(channels)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def periodic_noise(seconds: float, cutoff_hz: float, channels: int = 1) -> np.ndarray:
    """Ruido filtrado en frecuencia; la IFFT hace que el resultado sea periódico."""
    count = round(seconds * SAMPLE_RATE)
    frequencies = np.fft.rfftfreq(count, 1.0 / SAMPLE_RATE)
    rolloff = np.exp(-((frequencies / cutoff_hz) ** 2.0))
    result = []
    for _channel in range(channels):
        spectrum = (RNG.normal(size=frequencies.size) + 1j * RNG.normal(size=frequencies.size)) * rolloff
        spectrum[0] = 0.0
        channel = np.fft.irfft(spectrum, n=count)
        result.append(normalize(channel, 1.0))
    return np.column_stack(result) if channels > 1 else result[0]


def add_note(
    mix: np.ndarray,
    start: float,
    duration: float,
    frequency: float,
    amplitude: float,
    pan: float,
    timbre: str = "pad",
) -> None:
    begin = round(start * SAMPLE_RATE)
    length = min(round(duration * SAMPLE_RATE), len(mix) - begin)
    if begin < 0 or length <= 0:
        return
    t = np.arange(length, dtype=np.float64) / SAMPLE_RATE
    attack = min(1.8 if timbre == "pad" else 0.018, duration * 0.3)
    release = min(2.2 if timbre == "pad" else duration * 0.88, duration * 0.45)
    envelope = np.minimum(t / max(attack, 0.001), 1.0)
    envelope *= np.minimum((duration - t) / max(release, 0.001), 1.0)
    envelope = np.clip(envelope, 0.0, 1.0)

    phase = 2.0 * np.pi * frequency * t
    if timbre == "bell":
        tone = (
            np.sin(phase)
            + 0.38 * np.sin(phase * 2.01)
            + 0.18 * np.sin(phase * 3.98)
        ) * np.exp(-t * 1.65)
    else:
        tone = (
            np.sin(phase)
            + 0.22 * np.sin(phase * 2.0 + 0.4)
            + 0.09 * np.sin(phase * 0.5)
        ) / 1.31

    left = np.sqrt((1.0 - pan) * 0.5)
    right = np.sqrt((1.0 + pan) * 0.5)
    mix[begin : begin + length, 0] += tone * envelope * amplitude * left
    mix[begin : begin + length, 1] += tone * envelope * amplitude * right


def build_music() -> Path:
    seconds = 48.0
    mix = np.zeros((round(seconds * SAMPLE_RATE), 2), dtype=np.float64)
    # Dm – Bb – F – C, tres vueltas de cuatro compases lentos.
    chords = [
        (50, 57, 62, 65),
        (46, 53, 58, 62),
        (41, 48, 53, 57),
        (48, 55, 60, 64),
    ]
    melody = [74, 72, 69, 65, 69, 70, 69, 65, 72, 69, 67, 64]
    for bar in range(12):
        start = bar * 4.0
        chord = chords[bar % len(chords)]
        for index, note in enumerate(chord):
            add_note(mix, start, 4.0, midi(note), 0.052 if index else 0.07, -0.55 + index * 0.36)
        add_note(mix, start + 0.35, 2.7, midi(melody[bar]), 0.052, (-0.35 if bar % 2 == 0 else 0.35), "bell")
        if bar % 2 == 1:
            add_note(mix, start + 2.25, 1.5, midi(chord[2] + 12), 0.027, 0.42, "bell")

    air = periodic_noise(seconds, 900.0, 2)
    t = np.arange(len(mix), dtype=np.float64) / SAMPLE_RATE
    breathing = 0.5 + 0.5 * np.sin(2.0 * np.pi * t / 12.0 - np.pi / 2.0)
    mix += air * (0.0025 + breathing[:, None] * 0.002)
    # La composición empieza y termina casi en silencio para que el enlace sea limpio.
    fade = round(0.7 * SAMPLE_RATE)
    ramp = np.sin(np.linspace(0.0, np.pi / 2.0, fade)) ** 2
    mix[:fade] *= ramp[:, None]
    mix[-fade:] *= ramp[::-1, None]
    path = AUDIO / "horizon_theme.wav"
    write_wav(path, normalize(mix, 0.62))
    return path


def build_wind() -> Path:
    seconds = 24.0
    base = periodic_noise(seconds, 720.0, 2)
    low = periodic_noise(seconds, 95.0, 2)
    t = np.arange(len(base), dtype=np.float64) / SAMPLE_RATE
    gust = 0.42 + 0.18 * np.sin(2.0 * np.pi * t / 12.0) + 0.12 * np.sin(2.0 * np.pi * t / 6.0 + 1.3)
    wind = base * gust[:, None] * 0.24 + low * 0.13
    path = AUDIO / "valley_wind.wav"
    write_wav(path, normalize(wind, 0.5))
    return path


def add_bird_call(mix: np.ndarray, start: float, base_frequency: float, pan: float) -> None:
    duration = 0.72
    begin = round(start * SAMPLE_RATE)
    length = round(duration * SAMPLE_RATE)
    t = np.arange(length, dtype=np.float64) / SAMPLE_RATE
    pulses = np.maximum(np.sin(2.0 * np.pi * 4.2 * t), 0.0) ** 1.8
    envelope = np.sin(np.pi * np.clip(t / duration, 0.0, 1.0)) ** 1.4
    frequency = base_frequency + 520.0 * np.sin(2.0 * np.pi * 2.1 * t) + 260.0 * t
    phase = 2.0 * np.pi * np.cumsum(frequency) / SAMPLE_RATE
    call = (np.sin(phase) + 0.22 * np.sin(phase * 2.01)) * pulses * envelope * 0.14
    left = np.sqrt((1.0 - pan) * 0.5)
    right = np.sqrt((1.0 + pan) * 0.5)
    mix[begin : begin + length, 0] += call * left
    mix[begin : begin + length, 1] += call * right


def build_birds() -> Path:
    seconds = 32.0
    bed = periodic_noise(seconds, 2600.0, 2) * 0.008
    mix = bed
    calls = [(3.2, 1850.0, -0.7), (8.6, 2240.0, 0.55), (15.4, 1680.0, 0.2), (23.3, 2080.0, -0.35), (28.1, 1940.0, 0.75)]
    for call in calls:
        add_bird_call(mix, *call)
    path = AUDIO / "distant_birds.wav"
    write_wav(path, normalize(mix, 0.52))
    return path


def build_hoofbeats() -> list[Path]:
    paths = []
    for index, frequency in enumerate((118.0, 132.0, 106.0, 124.0), start=1):
        seconds = 0.28
        count = round(seconds * SAMPLE_RATE)
        t = np.arange(count, dtype=np.float64) / SAMPLE_RATE
        impact = RNG.normal(size=count) * np.exp(-t * 42.0) * 0.48
        body = np.sin(2.0 * np.pi * frequency * t) * np.exp(-t * 24.0)
        earth = np.sin(2.0 * np.pi * frequency * 0.48 * t + 0.35) * np.exp(-t * 14.0)
        click = np.sin(2.0 * np.pi * frequency * 5.2 * t) * np.exp(-t * 65.0)
        signal = impact + body * 0.68 + earth * 0.24 + click * 0.13
        path = AUDIO / f"hoof_{index}.wav"
        write_wav(path, normalize(signal, 0.78))
        paths.append(path)
    return paths


def build_waterfall() -> Path:
    """Capa estéreo periódica: masa grave, agua aireada y pulsos de impacto."""
    seconds = 20.0
    broad = periodic_noise(seconds, 6800.0, 2)
    body = periodic_noise(seconds, 820.0, 2)
    rumble = periodic_noise(seconds, 145.0, 2)
    t = np.arange(len(broad), dtype=np.float64) / SAMPLE_RATE
    surge = 0.72 + 0.16 * np.sin(2.0 * np.pi * t / 5.0) + 0.08 * np.sin(2.0 * np.pi * t / 2.5 + 0.8)
    water = broad * surge[:, None] * 0.18 + body * 0.32 + rumble * 0.22
    path = AUDIO / "waterfall.wav"
    write_wav(path, normalize(water, 0.58))
    return path


def convert_to_ogg(wav_path: Path) -> Path:
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise RuntimeError("FFmpeg es necesario para generar los loops Ogg.")
    ogg_path = wav_path.with_suffix(".ogg")
    subprocess.run(
        [ffmpeg, "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "5", str(ogg_path)],
        check=True,
    )
    wav_path.unlink()
    return ogg_path


def main() -> None:
    AUDIO.mkdir(parents=True, exist_ok=True)
    loops = [convert_to_ogg(builder()) for builder in (build_music, build_wind, build_birds)]
    hoofbeats = build_hoofbeats()
    waterfall = convert_to_ogg(build_waterfall())
    for path in [*loops, *hoofbeats, waterfall]:
        print(f"GENERATED {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
