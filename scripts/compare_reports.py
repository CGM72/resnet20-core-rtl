"""Compare versioned core reports from Vivado text and RTL simulation."""
import argparse
from pathlib import Path
import re

from export_analysis import ReportError, parse_timing, parse_utilization


def read_report(path):
    # Vivado/Tcl may write native Windows text. Metric labels are ASCII.
    return path.read_text(encoding="utf-8-sig", errors="replace")


def labeled_version(path):
    for parent in path.parents:
        version = parent / "VERSION"
        if version.is_file():
            return version.read_text(encoding="ascii").strip()
    return "unknown"


def load(path):
    path = path.resolve()
    if path.is_dir() and (path / "reports/core_report.txt").is_file():
        path = path / "reports/core_report.txt"
    if path.is_dir():
        # 1.2.3 stores separate report files in the analysis run directory.
        timing = read_report(path / "timing/post_route.rpt")
        util = read_report(path / "utilization/post_route.rpt")
        snr_path = path / "snr.txt"
        latency_path = path / "latency.txt"
        snr = read_report(snr_path) if snr_path.is_file() else ""
        latency = read_report(latency_path) if latency_path.is_file() else ""
        info = read_report(path / "run_info.tcldict")
        attributes = {}
        for key in ("part", "period_ns"):
            match = re.search(rf"(?:^|\s){key}\s+(\S+)", info)
            attributes[key] = match[1] if match else "unknown"
        tool = re.search(r"^\|?\s*Tool Version\s*:\s*([^\n|]+)", timing, re.M)
        condition = f"{tool[1].strip() if tool else 'Vivado unknown'} | {attributes['part']} | {attributes['period_ns']} ns"
        version = labeled_version(path)
    else:
        sections = re.split(r"^=== (.*?) ===\s*\n", read_report(path), flags=re.M)
        metadata = sections[0]
        content = dict(zip(sections[1::2], sections[2::2], strict=True))
        timing = content.get("Timing (post-route)", "")
        util = content.get("Utilization (post-route)", "")
        snr = content.get("SNR (dB)", "")
        latency = content.get("Latency (cycles)", "")
        if not ((timing and util) or (snr and latency)):
            raise ReportError("No complete implementation or simulation report sections")
        tag = re.search(r"^Version: (.+)$", metadata, re.M)
        version = tag[1].strip() if tag else labeled_version(path)
        implementation = re.search(r"^Implementation: [^|]+\| (.+)$", metadata, re.M)
        simulation = re.search(r"^Simulation: [^|]+\| (.+)$", metadata, re.M)
        condition = implementation[1].strip() if implementation else None
        if simulation and not implementation:
            condition = f"Simulation | {simulation[1].strip()}"

    timing_values = parse_timing(timing) if timing else {}
    resources = parse_utilization(util) if util else {}
    logits = re.search(r"^logits\s+\d+\s+samples\s+([+-]?(?:\d+(?:\.\d+)?|inf))\s+dB\s*$", snr, re.M)
    inference = re.search(r"^inference\s+(\d+)\s+(\d+)\s+(\d+)\s*$", latency, re.M)
    if (snr and not logits) or (latency and not inference):
        raise ReportError("Invalid final logit SNR or full-inference latency")
    if inference and int(inference[2]) - int(inference[1]) != int(inference[3]):
        raise ReportError("Inconsistent full-inference latency")
    timing_fields = tuple(timing_values.get(key) for key in ("wns_ns", "tns_ns", "whs_ns", "ths_ns"))
    used = tuple(resources.get(key, {}).get("used") for key in ("LUT", "FF", "BRAM", "DSP"))
    return (version, *timing_fields, *used, logits[1] if logits else None,
            inference[3] if inference else None), condition, path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reports-dir", type=Path, required=True)
    parser.add_argument("reports", nargs="*", type=Path)
    args = parser.parse_args()
    paths = args.reports or sorted(args.reports_dir.glob("generated/v*/core_report.txt"))
    if len(paths) < 2:
        parser.error("Supply at least two report files or generate reports for two versions")
    entries = []
    for path in paths:
        try:
            entries.append(load(path))
        except (KeyError, OSError, ValueError) as error:
            parser.error(f"{path}: {error}")

    headings = ("Version", "WNS ns", "TNS ns", "WHS ns", "THS ns", "LUT", "FF", "BRAM", "DSP",
                "Logit SNR dB", "Latency cycles")
    rows = [headings]
    for values, _, _ in entries:
        rows.append(tuple("N/A" if value is None else f"{value:g}" if isinstance(value, float) else str(value)
                          for value in values))
    widths = [max(map(len, column)) for column in zip(*rows, strict=True)]
    lines = ["Post-route implementation and full-model RTL simulation",
             " | ".join(f"{value:{width}}" for value, width in zip(headings, widths, strict=True)),
             "-+-".join("-" * width for width in widths)]
    lines.extend(" | ".join(f"{value:{width}}" for value, width in zip(row, widths, strict=True))
                 for row in rows[1:])
    lines.append("")
    if len({condition for _, condition, _ in entries if condition and not condition.startswith("Simulation |")}) > 1:
        lines.append("Implementation conditions differ. Review the Vivado version, FPGA and period below.")
    lines.append("Compare SNR and latency using the same model, input and testbench schedule.")
    lines.extend(f"v{values[0]} | {condition} | {path.resolve()}" for values, condition, path in entries)
    output = args.reports_dir / "version_comparison.txt"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
