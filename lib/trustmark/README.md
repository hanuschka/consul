# TrustMark watermarking runtime

Invisible watermarking for AI-generated images, embedded before the picture is
attached so every resized rendering inherits it.

The runtime is Python. Ruby reaches it through `TrustmarkCommand`, which runs
`embed_watermark.py` as a guarded subprocess.

**Marking is mandatory and this runtime is required in every environment.** An
AI image that cannot be marked is not attached at all: generation fails and the
error is shown to the user. A box without `torch` and `trustmark` installed
cannot generate AI images — that is deliberate, because publishing an unmarked
generated picture is what the mark exists to prevent. Uploads of ordinary
pictures are unaffected.

## Installing on a server

`scripts/install_deps.sh watermark` does everything in this section, on both
Ubuntu and macOS, and is safe to re-run. The manual steps below are what it
performs.

Roughly 4.4 GB on disk on Linux, 770 MB on macOS where there is no CUDA build
to avoid, and about 840 MB resident per run. Neither figure is carried by the
Rails process: the subprocess exits after each image.

```bash
python3 -m venv /opt/trustmark
/opt/trustmark/bin/pip install \
  --index-url https://download.pytorch.org/whl/cpu \
  torch torchvision
/opt/trustmark/bin/pip install trustmark
```

The CPU wheel index matters on Linux. Resolving `torch` from PyPI there pulls
the CUDA build, which costs an extra 250 MB of resident memory at import, adds
gigabytes of unused NVIDIA libraries, and is slower on a machine with no GPU.

On macOS there is no CUDA build to avoid, so a developer machine installs into
`~/.local/share/trustmark` with plain `pip install trustmark` and no index
flag.

Then warm the model cache, as part of the same install:

```bash
/opt/trustmark/bin/python -c "from trustmark import TrustMark; TrustMark(model_type='Q')"
```

This is not optional. The weights are roughly 143 MB and download on first use,
which takes longer than the encode deadline allows — so without warming, the
first AI image generated on a fresh box fails, and it fails as "watermarking
unavailable" in front of whoever happened to try it. After warming, an encode
takes roughly 180 ms.

## Enabling it

Installing to `/opt/trustmark` needs no further configuration: that path is
checked by default, as is `~/.local/share/trustmark` for a developer machine
where creating `/opt` needs root.

Anywhere else, point at the interpreter explicitly:

```bash
TRUSTMARK_PYTHON=/some/other/venv/bin/python
```

The runtime is required. With no interpreter found, or one without the
packages, every attempt to generate an AI image fails with a message naming
what is missing.

## Checking it works

```bash
bin/rails runner 'puts TrustmarkCommand.runtime_status'
```

`ready` is the only healthy answer. `interpreter_missing` means
`TRUSTMARK_PYTHON` is unset or not executable; `libraries_missing` means the
interpreter exists but `torch` or `trustmark` is not installed in it, and
`TrustmarkCommand.missing_libraries` names which.

The same check is reported per box in the internal API stats report, under
`features.ai.image_watermarking`, alongside the existing import-tool and
headless-browser dependency checks — so a box that cannot generate AI images is
visible centrally rather than only when someone tries.

## What the mark survives

Measured against the variants this app actually serves. A watermark embedded in
the original is recovered intact from the projekt banner, the welcome header,
the card thumbnail and the public API rendering.

It does not survive the map popup, which crops a 16:9 source to a square and
discards roughly 43% of the image width. The failure is the aspect-ratio crop
rather than the downscale — the same file rendered at 600x600 also loses the
mark, while a 300px-wide uncropped rendering keeps it.
