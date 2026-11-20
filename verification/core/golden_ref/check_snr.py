"""Verify full-model RTL dumps and export independent layer SNR measurements."""

import argparse
import json
import math
import re
from pathlib import Path

from generate_resnet20_core import RESNET, read_program
from float_reference import WeightReader, infer
from quantized_reference import rounded, sat

ROOT = RESNET.parents[1]


def read_words(path):
    tokens = path.read_text(encoding="ascii").split()
    if any(re.fullmatch(r"[0-9a-fA-F]{4}", token) is None for token in tokens):
        raise ValueError(f"{path}: invalid 16-bit hex sample")
    words = [int(token, 16) for token in tokens]
    return [word - 65536 if word >= 32768 else word for word in words]


def measure(name, words, reference, frac_bits):
    if not words or len(words) != len(reference):
        raise ValueError(f"{name}: expected {len(reference)} samples, got {len(words)}")
    errors = [word / (1 << frac_bits) - ref for word, ref in zip(words, reference, strict=True)]
    signal = math.fsum(ref * ref for ref in reference)
    noise = math.fsum(error * error for error in errors)
    if noise == 0:
        snr = math.inf
    elif signal == 0:
        snr = -math.inf
    else:
        snr = 10 * (math.log10(signal) - math.log10(noise))
    return {
        "name": name, "samples": len(words), "frac_bits": frac_bits,
        "snr_db": snr if math.isfinite(snr) else str(snr),
        "max_abs_error": max(map(abs, errors)),
    }


def verify(run, vectors, weights):
    rows = (run / "scoreboard_results.txt").read_text(encoding="ascii").splitlines()
    if len(rows) != 2 or rows[1] != "complete":
        raise ValueError("Testbench did not complete successfully")
    count, frac_bits, tb_snr = rows[0].split()
    frac_bits = int(frac_bits)
    if not 0 <= frac_bits <= 15:
        raise ValueError(f"Invalid output fractional width: {frac_bits}")

    references = {}

    def checkpoint(name, values):
        references[name] = values

    image = read_words(vectors / "input_q5_10.hex")
    if len(image) != 32 * 32 * 3:
        raise ValueError("Invalid input image size")
    references["fc"] = infer(image, WeightReader(weights), checkpoint)
    report = []
    core_logits = None
    for index, (name, _, _, _, _, out_channels, *_) in enumerate(read_program()):
        if out_channels == 0:
            continue
        actual = read_words(run / f"layer_{index:02d}_actual.hex")
        expected = read_words(vectors / "expected" / f"layer_{index:02d}.hex")
        if actual != expected:
            raise ValueError(f"{name}: RTL samples differ from the integer oracle")
        if name == "fc":
            core_logits = actual
        row = measure(name, actual, references[name], 10)
        report.append({"command_index": index, **row})

    logits = read_words(run / "logits_actual.hex")
    if core_logits is None:
        raise ValueError("The command manifest has no FC output")
    formatted_logits = [sat(rounded(word * (1 << frac_bits), 1 << 10)) for word in core_logits]
    if logits != formatted_logits:
        raise ValueError("Final logits differ from the formatted FC output")
    final = measure("logits", logits, references["fc"], frac_bits)
    snr = float(final["snr_db"])
    if int(count) != final["samples"] or not math.isclose(snr, float(tb_snr), abs_tol=1e-8):
        raise ValueError("Testbench and independent final logit SNR differ")
    if snr < 50:
        raise ValueError(f"Final logit SNR {snr:.2f} dB is below 50 dB")
    final["tb_snr_db"] = float(tb_snr) if math.isfinite(snr) else tb_snr
    report.append(final)
    (run / "results.json").write_text(json.dumps(report, indent=2, allow_nan=False) + "\n",
                                    encoding="utf-8")
    for row in report:
        print(f"{row['name']:24} {row['samples']:5} samples  {float(row['snr_db']):8.2f} dB")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, default=ROOT / "build/sim/tb_core/snr")
    parser.add_argument("--vectors", type=Path, default=ROOT / "tb/tb_core/vectors")
    parser.add_argument("--weights", type=Path, default=RESNET / "weight.bin")
    args = parser.parse_args()
    verify(args.run, args.vectors, args.weights)
