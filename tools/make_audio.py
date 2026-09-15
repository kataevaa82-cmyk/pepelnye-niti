"""Create small, original, deterministic PCM effects; no downloaded media."""
from array import array
from pathlib import Path
import math
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050


def render(name, duration, sample):
    target = ROOT / 'assets' / 'audio' / f'{name}.wav'
    target.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(1609)
    frames = array('h')
    for i in range(int(RATE * duration)):
        t = i / RATE
        value = max(-0.95, min(0.95, sample(t, duration, rng)))
        frames.append(round(value * 32767))
    if sys.byteorder != 'little':
        frames.byteswap()
    with wave.open(str(target), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(frames.tobytes())


def main():
    tau = math.tau
    render('hit', .25, lambda t, d, r: math.exp(-t * 27) *
           (r.uniform(-.7, .7) + .22 * math.sin(tau * 87 * t)))
    render('pulse', .65, lambda t, d, r: math.sin(math.pi * t / d) * math.exp(-t * 4) *
           (.4 * math.sin(tau * (290 * t - 155 * t * t)) + r.uniform(-.06, .06)))
    render('core', 1.0, lambda t, d, r: math.sin(math.pi * t / d) * math.exp(-t * 3) *
           (.3 * math.sin(tau * 659.25 * t) + .18 * math.sin(tau * 987.77 * t)))
    # All periodic components fit the exact four-second loop; no seam.
    render('workshop', 4.0, lambda t, d, r: .12 * math.sin(tau * 55 * t) +
           .045 * math.sin(tau * 82.5 * t) * (.8 + .2 * math.sin(tau * .25 * t)))
    print('Generated 4 original mono WAV assets.')


if __name__ == '__main__':
    main()
