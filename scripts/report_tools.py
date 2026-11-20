"""Hash report inputs and run the full-model testbench with Verilator."""

import argparse
import hashlib
from pathlib import Path
import subprocess
import sys


def fingerprint(values, paths):
    digest = hashlib.sha256()
    for value in values:
        digest.update(value.encode("utf-8") + b"\0")
    for path in paths:
        digest.update(str(path).encode("utf-8") + b"\0")
        files = sorted(p for p in path.rglob("*") if p.is_file()) if path.is_dir() else [path]
        for file in files:
            digest.update(str(file.relative_to(path.parent)).encode("utf-8") + b"\0")
            digest.update(hashlib.sha256(file.read_bytes()).digest())
    return digest.hexdigest()


def simulate(args):
    run = args.run.resolve()
    run.mkdir(parents=True, exist_ok=True)
    command = [
        args.verilator, "--binary", "--timing", "-Wno-fatal", "-CFLAGS", "-std=c++20",
        "-j", "4", "--top-module", "tb_core", "--Mdir", str(run / "obj"),
    ]
    command += [f"+incdir+{path}" for path in args.include]
    command += [f"+define+{define}" for define in args.define]
    command += [str(path) for path in args.sources]
    with (run / "compile.log").open("w", encoding="utf-8") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    executable = run / "obj" / ("Vtb_core.exe" if sys.platform == "win32" else "Vtb_core")
    with (run / "simulate.log").open("w", encoding="utf-8") as log:
        subprocess.run(
            [str(executable), f"+vectors_dir={args.vectors}", f"+weight_path={args.weights}",
             f"+snr_dir={run}"], stdout=log, stderr=subprocess.STDOUT, check=True,
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    key = commands.add_parser("key")
    key.add_argument("--value", action="append", default=[])
    key.add_argument("paths", type=Path, nargs="+")
    sim = commands.add_parser("simulate")
    sim.add_argument("--verilator", required=True)
    sim.add_argument("--run", type=Path, required=True)
    sim.add_argument("--vectors", type=Path, required=True)
    sim.add_argument("--weights", type=Path, required=True)
    sim.add_argument("--include", action="append", default=[])
    sim.add_argument("--define", action="append", default=[])
    sim.add_argument("sources", nargs="+", type=Path)
    args = parser.parse_args()
    if args.command == "key":
        print(fingerprint(args.value, args.paths))
    else:
        try:
            simulate(args)
        except (OSError, subprocess.CalledProcessError) as error:
            parser.exit(1, f"Verilator failed: {error}. See logs in {args.run}\n")


if __name__ == "__main__":
    main()
