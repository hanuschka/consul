"""Embeds an invisible TrustMark watermark into an image.

Invoked as a subprocess by TrustmarkCommand rather than imported: the runtime
loads PyTorch, which costs roughly 800 MB resident, and that must not live
inside a Rails process.

The payload is a bit string produced by the caller. TrustMark's BCH_5 error
correction carries exactly 61 usable bits at a 100-bit secret length; a longer
payload is silently truncated on decode rather than rejected on encode, so the
length is asserted here instead of being discovered as a corrupted identifier
later.
"""

import argparse
import json
import sys

PAYLOAD_BITS = 61


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--payload", required=True)
    parser.add_argument("--variant", default="Q")
    parser.add_argument("--quality", type=int, default=95)
    parser.add_argument("--threads", type=int, default=2)
    arguments = parser.parse_args()

    if len(arguments.payload) != PAYLOAD_BITS:
        fail(f"payload must be exactly {PAYLOAD_BITS} bits, got {len(arguments.payload)}")

    if set(arguments.payload) - {"0", "1"}:
        fail("payload must contain only 0 and 1")

    import torch

    torch.set_num_threads(arguments.threads)

    from PIL import Image
    from trustmark import TrustMark

    encoder = TrustMark(
        verbose=False,
        model_type=arguments.variant,
        encoding_type=TrustMark.Encoding.BCH_5,
        device="cpu",
    )

    cover = Image.open(arguments.input).convert("RGB")
    watermarked = encoder.encode(cover, arguments.payload, MODE="binary")
    watermarked.save(arguments.output, quality=arguments.quality)

    # Read back before reporting success: a watermark that did not survive the
    # save is indistinguishable from an unmarked image to every later reader,
    # and the caller must be able to tell the difference now.
    recovered, present, _schema = encoder.decode(
        Image.open(arguments.output).convert("RGB"), MODE="binary"
    )

    if not present or recovered != arguments.payload:
        fail("watermark did not survive encoding")

    json.dump({"ok": True, "width": cover.width, "height": cover.height}, sys.stdout)


def fail(message):
    json.dump({"ok": False, "error": message}, sys.stdout)
    sys.exit(1)


if __name__ == "__main__":
    main()
