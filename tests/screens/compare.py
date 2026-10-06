"""Screenshot regression check (0.53).

  python tests/screens/compare.py <captured_dir>            compare against tests/screens/golden/<size>/
  python tests/screens/compare.py <captured_dir> --accept   make the captures the new approved images

A screen fails when more than THRESHOLD of its pixels changed visibly (any
channel off by more than 40). Animated screens (the Endless Rift, Riftbreak,
a fight) get a looser limit, since sprites move. Writes diff.png next to the
captures: approved | captured | changed pixels in red, for every failure.
Exit code 1 when anything failed."""
import os, shutil, sys
from PIL import Image, ImageChops

THRESHOLD = 0.015
LOOSE = {"endless": 0.12, "riftbreak": 0.12, "fight": 0.06, "title": 0.04}
HERE = os.path.dirname(os.path.abspath(__file__))


def changed(a, b):
    d = ImageChops.difference(a.convert("RGB"), b.convert("RGB")).convert("L").point(lambda v: 255 if v > 40 else 0)
    return d, sum(1 for v in d.getdata() if v) / float(a.width * a.height)


def main():
    cap = sys.argv[1]
    imgs = sorted(f for f in os.listdir(cap) if f.endswith(".png") and f != "diff.png")
    if not imgs:
        sys.exit("no captures in " + cap)
    size = "%dx%d" % Image.open(os.path.join(cap, imgs[0])).size
    gold = os.path.join(HERE, "golden", size)
    if "--accept" in sys.argv:
        os.makedirs(gold, exist_ok=True)
        for f in imgs:
            shutil.copy(os.path.join(cap, f), os.path.join(gold, f))
        print("approved %d screens at %s" % (len(imgs), size))
        return
    fails, rows = [], []
    for f in imgs:
        g = os.path.join(gold, f)
        if not os.path.exists(g):
            print("NEW   %-22s (no approved image yet)" % f)
            continue
        a, b = Image.open(g), Image.open(os.path.join(cap, f))
        if a.size != b.size:
            fails.append(f); print("FAIL  %-22s size %s vs %s" % (f, a.size, b.size)); continue
        d, frac = changed(a, b)
        limit = LOOSE.get(f[:-4], THRESHOLD)
        ok = frac <= limit
        print("%s  %-22s %5.2f%% changed (limit %.1f%%)" % ("ok  " if ok else "FAIL", f, frac * 100, limit * 100))
        if not ok:
            fails.append(f)
            red = Image.new("RGB", a.size, (230, 40, 40))
            mark = b.convert("RGB").copy(); mark.paste(red, mask=d)
            rows.append([a.convert("RGB"), b.convert("RGB"), mark])
    if rows:
        w, h = rows[0][0].size
        sheet = Image.new("RGB", (w * 3 // 2, h // 2 * len(rows)))
        for r, imgs3 in enumerate(rows):
            for c, im in enumerate(imgs3):
                sheet.paste(im.resize((w // 2, h // 2)), (c * w // 2, r * h // 2))
        sheet.save(os.path.join(cap, "diff.png"))
    print("%d of %d screens changed" % (len(fails), len(imgs)))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
