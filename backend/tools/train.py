"""Fine-tune the vision model on the photos collected in teach mode.

    cd backend
    .venv/bin/python tools/train.py                 # dataset → train → check → install
    .venv/bin/python tools/train.py --epochs 30     # quicker
    .venv/bin/python tools/train.py --dry-run       # only build the YOLO dataset and print counts

Starts from the COCO-pretrained yolo26n.pt and retrains it for the kinds in data/dataset/
(one class per vision_label). The result is checked on held-back photos and installed as
data/models/current.pt only if it scores at least as well as the model already there (or if
the kinds changed, or with --force). A backend started with KIOSK_VISION=data/models/current.pt
picks it up within a few seconds, no restart needed.

Training runs here, not in the kiosk: it takes minutes on a Mac (Apple GPU) and would take
hours on a Pi. Needs requirements-vision.txt.
"""

import argparse
import hashlib
import json
import os
import shutil
import sys
import time
from pathlib import Path

BACKEND = Path(__file__).resolve().parent.parent
EMPTY = "_empty"


def is_val(stem: str, frac: float) -> bool:
    """Stable split by file name: a photo stays in the same split across runs, so a model trained
    earlier never saw today's validation photos and the before/after comparison is fair."""
    return int(hashlib.sha1(stem.encode()).hexdigest()[:8], 16) / 0xFFFFFFFF < frac


def build_dataset(src: Path, dst: Path, val_frac: float = 0.2, min_photos: int = 10) -> dict:
    """Teach-mode folders → Ultralytics YOLO layout (symlinked images + label txt) + data.yaml."""
    kinds = sorted(d.name for d in src.iterdir() if d.is_dir() and d.name != EMPTY) if src.is_dir() else []
    counts = {k: sum(1 for p in (src / k).glob("*.jpg") if p.with_suffix(".json").exists()) for k in kinds}
    skipped = {k: n for k, n in counts.items() if n < min_photos}
    classes = [k for k in kinds if k not in skipped]
    if not classes:
        raise SystemExit(f"No kind has {min_photos}+ photos in {src} yet (have: {counts or 'nothing'}). "
                         "Collect more in teach mode.")

    if dst.exists():
        shutil.rmtree(dst)
    for split in ("train", "val"):
        (dst / "images" / split).mkdir(parents=True)
        (dst / "labels" / split).mkdir(parents=True)

    split_counts = {"train": 0, "val": 0}

    def add(img: Path, lines: list[str], split: str):
        name = f"{img.parent.name}-{img.stem}"
        (dst / "images" / split / f"{name}.jpg").symlink_to(img.resolve())
        (dst / "labels" / split / f"{name}.txt").write_text("".join(f"{line}\n" for line in lines))
        split_counts[split] += 1

    for ci, kind in enumerate(classes):
        photos = sorted(p for p in (src / kind).glob("*.jpg") if p.with_suffix(".json").exists())
        val = [p for p in photos if is_val(p.stem, val_frac)]
        if not val:                      # every class needs at least one validation photo
            val = photos[-1:]
        for p in photos:
            meta = json.loads(p.with_suffix(".json").read_text())
            (x, y, w, h), (iw, ih) = meta["bbox"], meta["size"]
            line = f"{ci} {(x + w / 2) / iw:.6f} {(y + h / 2) / ih:.6f} {w / iw:.6f} {h / ih:.6f}"
            add(p, [line], "val" if p in val else "train")
    for p in sorted((src / EMPTY).glob("*.jpg")) if (src / EMPTY).is_dir() else []:
        add(p, [], "val" if is_val(p.stem, val_frac) else "train")   # empty tray: nothing to find

    yaml = dst / "data.yaml"
    yaml.write_text(f"path: {dst}\ntrain: images/train\nval: images/val\nnames:\n"
                    + "".join(f"  {i}: {k}\n" for i, k in enumerate(classes)))
    return {"yaml": yaml, "classes": classes, "counts": counts, "skipped": skipped, "split": split_counts}


def pick_device(arg: str) -> str:
    if arg != "auto":
        return arg
    import torch
    if torch.backends.mps.is_available():
        return "mps"
    return "0" if torch.cuda.is_available() else "cpu"


def score(model_path: Path, yaml: Path, device: str) -> float:
    """mAP50-95 on the validation photos."""
    from ultralytics import YOLO
    m = YOLO(str(model_path)).val(data=str(yaml), split="val", device=device, plots=False, verbose=False)
    return float(m.box.map)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dataset", type=Path, default=Path(os.environ.get("KIOSK_DATASET", BACKEND / "data" / "dataset")))
    ap.add_argument("--out", type=Path, default=BACKEND / "data" / "models" / "current.pt")
    ap.add_argument("--base", default="yolo26n.pt", help="starting weights (COCO-pretrained by default)")
    ap.add_argument("--epochs", type=int, default=60)
    ap.add_argument("--imgsz", type=int, default=640)
    ap.add_argument("--device", default="auto", help="auto | mps | cpu | 0 (CUDA)")
    ap.add_argument("--min-photos", type=int, default=10, help="skip kinds with fewer photos")
    ap.add_argument("--force", action="store_true", help="install even if it scores worse than the current model")
    ap.add_argument("--dry-run", action="store_true", help="only build the dataset")
    args = ap.parse_args()

    runs = BACKEND / "runs"
    ds = build_dataset(args.dataset, runs / "dataset", min_photos=args.min_photos)
    counts = ds["counts"]
    print("kinds: " + ", ".join(f"{k} ({counts[k]})" for k in ds["classes"]))
    if ds["skipped"]:
        print(f"skipped (< {args.min_photos} photos): {', '.join(f'{k} ({n})' for k, n in ds['skipped'].items())}")
    print(f"photos: {ds['split']['train']} train, {ds['split']['val']} validation (incl. empty tray)")
    if args.dry_run:
        print(f"dataset: {ds['yaml']}")
        return

    from ultralytics import YOLO
    device = pick_device(args.device)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    print(f"training {args.base} for {args.epochs} epochs on {device}…", flush=True)
    t0 = time.time()
    model = YOLO(args.base)
    model.train(data=str(ds["yaml"]), epochs=args.epochs, imgsz=args.imgsz, device=device,
                project=str(runs / "train"), name=stamp, exist_ok=True, plots=False, patience=20)
    best = Path(model.trainer.save_dir) / "weights" / "best.pt"
    new = score(best, ds["yaml"], device)
    print(f"trained in {(time.time() - t0) / 60:.1f} min: mAP50-95 {new:.3f} on {ds['split']['val']} validation photos")

    old = None
    if args.out.exists():
        old_classes = sorted(YOLO(str(args.out)).names.values())
        if old_classes == sorted(ds["classes"]):
            old = score(args.out, ds["yaml"], device)
            print(f"current model: mAP50-95 {old:.3f}")
        else:
            print("current model knows different kinds, replacing it")
    if old is not None and new < old and not args.force:
        print(f"not installed: worse than the current model (kept {args.out}; new one is {best}; --force installs it)")
        sys.exit(1)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    tmp = args.out.with_suffix(".pt.tmp")
    shutil.copyfile(best, tmp)
    os.replace(tmp, args.out)              # atomic: the backend never sees a half-written file
    args.out.with_suffix(".json").write_text(json.dumps({
        "trained": stamp, "base": args.base, "epochs": args.epochs, "classes": ds["classes"],
        "photos": ds["counts"], "map50_95": round(new, 4), "previous_map50_95": old,
    }, indent=2) + "\n")
    print(f"installed {args.out}")


if __name__ == "__main__":
    main()
