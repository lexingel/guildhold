"""Builds the 0.69 sound pass: new effects derived from the game's own CC0
sounds (assets/audio/sfx, see CREDITS.txt) by pitch, filtering and layering,
plus a little synthesis. Deterministic. Needs ffmpeg on PATH.
Usage: python tools/derive_sfx.py"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
rng = np.random.default_rng(69)
_cache = {}


def load(name):
    """A source effect as mono float32 at SR (decoded by ffmpeg)."""
    if name in _cache:
        return _cache[name].copy()
    src = os.path.join(DIR, name + (".wav" if name.startswith("gen_") else ".ogg"))
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", src, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    _cache[name] = x
    return x.copy()


def pitch(x, k):
    """Resample: k > 1 higher and shorter."""
    n = max(1, int(len(x) / k))
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def lp(x, hz):
    b, a = signal.butter(2, hz / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, hz):
    b, a = signal.butter(2, hz / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def cut(x, secs):
    n = int(SR * secs)
    y = x[:n].copy()
    f = min(len(y), int(SR * 0.04))
    if f:
        y[-f:] *= np.linspace(1, 0, f)
    return y


def gain(x, g):
    return x * g


def mix(*parts):
    """Layers [(signal, offset seconds), ...] or plain signals at 0."""
    items = [(p, 0.0) if not isinstance(p, tuple) else p for p in parts]
    n = max(int(SR * off) + len(s) for s, off in items)
    out = np.zeros(n)
    for s, off in items:
        i = int(SR * off)
        out[i:i + len(s)] += s
    return out


def t(d):
    return np.linspace(0, d, int(SR * d), endpoint=False)


def env(n, a=0.005, decay=5.0):
    e = np.exp(-np.linspace(0, decay, n))
    na = max(1, int(SR * a))
    e[:na] *= np.linspace(0, 1, na)
    return e


def tone(f, d, decay=5.0, harm=(1.0,)):
    tt = t(d)
    s = sum(w * np.sin(2 * np.pi * f * (i + 1) * tt) for i, w in enumerate(harm))
    return s * env(len(tt), decay=decay)


def chime(f, d=0.9):
    return tone(f, d, 4.0, (1.0, 0.0, 0.35, 0.0, 0.12))


def sweep(f0, f1, d, decay=3.0):
    tt = t(d)
    f = np.geomspace(f0, f1, len(tt))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), decay=decay)


def whoosh(d=0.28, f0=600, f1=3000):
    n = rng.uniform(-1, 1, int(SR * d))
    sos = signal.butter(2, [f0 / (SR / 2), min(0.95, f1 / (SR / 2))], "band", output="sos")
    y = signal.sosfilt(sos, n)
    w = np.sin(np.linspace(0, np.pi, len(y))) ** 2
    return y * w


def crackle(d=0.4, density=0.02):
    n = np.zeros(int(SR * d))
    hits = rng.random(len(n)) < density / 40
    n[hits] = rng.uniform(-1, 1, hits.sum())
    return lp(n, 5000) * env(len(n), decay=2.5) * 4


def loudness(x):
    """dBFS RMS of the loudest 0.4 s (the whole clip when shorter), after a
    gentle high-pass: a rough short-term loudness, enough to even out a set."""
    y = hp(np.asarray(x, dtype=np.float64), 100)
    w = int(SR * 0.4)
    if len(y) <= w:
        r = np.sqrt(np.mean(y ** 2))
    else:
        c = np.concatenate([[0.0], np.cumsum(y ** 2)])
        r = np.sqrt(np.max(c[w:] - c[:-w]) / w)
    return 20 * np.log10(max(r, 1e-9))


# Loudness targets (0.65: they were all set to the same peak, so a long
# rumble played far louder than a click). Small UI ticks sit under the
# moments; the big moments sit a little over.
TARGET_DB = -20.0
TARGETS = {"tab": -27.0, "node_pick": -25.0, "boss_down": -17.0, "title": -18.0, "payday": -18.0, "relic_pick": -18.0, "camp_omen": -22.0}
CEILING = 0.9


def save(name, x):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) or 1.0)
    x = x * 10 ** ((TARGETS.get(name, TARGET_DB) - loudness(x)) / 20)
    m = np.max(np.abs(x))
    if m > CEILING:   # the peak ceiling wins: a very peaky effect ends a little quieter
        x = x / m * CEILING
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    out = os.path.join(DIR, name + ".ogg")
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-i", path, "-c:a", "libvorbis", "-q:a", "3", out], check=True)
    os.remove(path)


RECIPES = {
    # A Path's moment (15): played when its rule or Signature fires.
    "path_shieldwall": lambda: mix(pitch(load("shield"), 0.8), gain(lp(load("hit_heavy"), 900), 0.6)),
    "path_bloodrage": lambda: mix(pitch(load("hit_heavy"), 0.85), (gain(cut(pitch(load("boss"), 1.7), 0.35), 0.5), 0.02)),
    "path_weaponmaster": lambda: mix(pitch(load("attack"), 1.25), (pitch(load("attack"), 1.4), 0.09)),
    "path_marksman": lambda: mix(hp(pitch(load("attack"), 1.6), 900), (gain(tone(2400, 0.06, 30), 0.4), 0.0)),
    "path_trapper": lambda: mix(pitch(load("craft"), 0.85), (gain(lp(load("hit"), 2000), 0.5), 0.03)),
    "path_stalker": lambda: gain(lp(pitch(load("windup"), 1.3), 2500), 0.8),
    "path_evocation": lambda: mix(load("gen_burn"), (gain(lp(pitch(load("hit_heavy"), 0.7), 700), 0.9), 0.05)),
    "path_warding": lambda: mix(pitch(load("shield"), 1.4), gain(chime(1320), 0.5)),
    "path_augury": lambda: mix(gain(pitch(load("story"), 1.2), 0.7), gain(chime(988, 1.2), 0.6)),
    "path_mercy": lambda: mix(pitch(load("heal"), 1.1), (gain(chime(1568), 0.45), 0.05)),
    "path_aegis": lambda: mix(pitch(load("shield"), 0.7), gain(lp(pitch(load("stun"), 0.9), 1800), 0.5)),
    "path_zeal": lambda: mix(pitch(load("ability"), 1.2), (gain(load("hit"), 0.6), 0.05)),
    "path_assassin": lambda: mix(cut(pitch(load("attack"), 1.7), 0.25), (gain(lp(cut(load("knockout"), 0.4), 1200), 0.5), 0.08)),
    "path_skirmisher": lambda: mix(whoosh(0.22, 900, 5000), (gain(cut(pitch(load("attack"), 1.5), 0.2), 0.7), 0.12)),
    "path_scrapper": lambda: mix(pitch(load("hit"), 0.9), (gain(pitch(load("heal"), 1.3), 0.5), 0.06)),
    # A foe struck, and a foe felled, by region (10).
    "foe_hit_vale": lambda: lp(load("hit"), 6000),
    "foe_hit_marsh": lambda: mix(lp(pitch(load("hit"), 0.85), 1200), gain(lp(whoosh(0.15, 200, 900), 600), 0.4)),
    "foe_hit_ashen": lambda: mix(pitch(load("hit"), 0.95), gain(crackle(0.3), 0.6)),
    "foe_hit_glass": lambda: mix(hp(pitch(load("hit"), 1.4), 600), gain(chime(2093, 0.5), 0.35)),
    "foe_hit_city": lambda: mix(gain(pitch(load("hit"), 0.7)[::-1][-int(SR * 0.08):], 0.35), (pitch(load("hit"), 0.7), 0.08)),
    "foe_down_vale": lambda: cut(load("knockout"), 1.0),
    "foe_down_marsh": lambda: lp(cut(pitch(load("knockout"), 0.85), 1.1), 1500),
    "foe_down_ashen": lambda: mix(cut(load("knockout"), 1.0), gain(crackle(0.8, 0.04), 0.7)),
    "foe_down_glass": lambda: mix(hp(cut(pitch(load("knockout"), 1.3), 0.8), 500), (gain(chime(1760, 1.0), 0.5), 0.05)),
    "foe_down_city": lambda: mix(lp(cut(pitch(load("knockout"), 0.7), 1.2), 2000), (gain(sweep(300, 90, 0.8), 0.4), 0.0)),
    # Fights (5).
    "dodge": lambda: whoosh(0.2, 1200, 6000),
    "guard": lambda: mix(pitch(load("shield"), 0.9), gain(lp(load("hit"), 900), 0.4)),
    "ward": lambda: mix(gain(pitch(load("shield"), 1.3), 0.7), gain(chime(1175, 0.7), 0.5)),
    "boss_down": lambda: mix(pitch(load("knockout"), 0.6), (pitch(load("hit_heavy"), 0.8), 0.0), (gain(lp(load("stun"), 1200), 0.5), 0.15)),
    "elite_down": lambda: mix(pitch(load("knockout"), 0.8), (gain(load("hit_heavy"), 0.5), 0.0)),
    # Camp, the map, Resolve (11).
    "camp_event": lambda: mix(gain(cut(pitch(load("level_up"), 1.1), 0.9), 0.8), gain(chime(1046), 0.3)),
    "camp_dilemma": lambda: mix(pitch(load("story"), 0.9), (gain(chime(587, 1.0), 0.35), 0.05)),
    "camp_omen": lambda: mix(gain(lp(pitch(load("boss"), 0.6), 700), 0.7), gain(tone(55, 1.4, 2.0, (1.0, 0.5)), 0.6)),
    "tab": lambda: gain(pitch(load("ui_click"), 1.2), 0.6),
    "node_pick": lambda: mix(pitch(load("ui_confirm"), 0.9), (gain(lp(load("hit"), 800), 0.25), 0.0)),
    "resolve_down": lambda: mix(gain(sweep(520, 330, 0.45, 4.0), 0.6), gain(tone(196, 0.5, 4.0, (1.0, 0.3)), 0.4)),
    "resolve_waver": lambda: mix(gain(lp(pitch(load("windup"), 0.7), 1500), 0.7), gain(tone(73, 1.2, 2.5, (1.0, 0.4, 0.2)), 0.7)),
    "relic_pick": lambda: mix(pitch(load("relic"), 0.9), (gain(load("unlock"), 0.6), 0.12)),
    "title": lambda: mix(gain(cut(pitch(load("victory"), 1.1), 0.8), 0.8), (gain(chime(1318, 0.8), 0.4), 0.1)),
    "payday": lambda: mix(load("coin"), (pitch(load("coin"), 1.12), 0.09), (pitch(load("coin"), 1.26), 0.18)),
}


if __name__ == "__main__":
    for name, make in RECIPES.items():
        x = make()
        save(name, x)
    print("%d effects written to %s" % (len(RECIPES), os.path.normpath(DIR)))
