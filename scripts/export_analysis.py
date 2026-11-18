"""Render separate timing/resource PNGs from actual Vivado OOC text reports."""
from __future__ import annotations
import argparse
from datetime import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sys


class ReportError(ValueError):
    pass


def numeric(token):
    token = token.strip().replace(',', '')
    if token.upper() in {'N/A', 'NA', '--', '-', ''}:
        return None
    try:
        value = float(token)
    except ValueError as exc:
        raise ReportError(f'Not a number: {token!r}') from exc
    if not math.isfinite(value):
        raise ReportError(f'Nonfinite report number: {token!r}')
    return value


def parse_timing(text):
    """Vivado Design Timing Summary: each endpoint count is one column."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if not all(name in line for name in ('WNS(ns)', 'TNS(ns)', 'WHS(ns)', 'THS(ns)')):
            continue
        for row in lines[index + 1:index + 13]:
            tokens = row.split()
            if len(tokens) < 8 or not any(re.search(r'\d', token) for token in tokens):
                continue
            try:
                values = [numeric(token) for token in tokens]
            except ReportError:
                continue
            keys = ['wns_ns', 'tns_ns', 'setup_failing_endpoints', 'setup_total_endpoints',
                    'whs_ns', 'ths_ns', 'hold_failing_endpoints', 'hold_total_endpoints',
                    'wpws_ns', 'tpws_ns', 'pulse_failing_endpoints', 'pulse_total_endpoints']
            return dict(zip(keys, values))
    if re.search(r'no (?:timing )?paths(?: were)? (?:found|defined)|no clocks(?: were)? (?:found|defined)', text, re.I):
        return {key: None for key in ['wns_ns', 'tns_ns', 'setup_failing_endpoints', 'setup_total_endpoints',
                                     'whs_ns', 'ths_ns', 'hold_failing_endpoints', 'hold_total_endpoints']}
    raise ReportError('Design Timing Summary table not found. Keep the .rpt and check its Vivado format.')


def timing_status(values):
    required = ['wns_ns', 'tns_ns', 'whs_ns', 'ths_ns', 'setup_failing_endpoints',
                'hold_failing_endpoints', 'setup_total_endpoints', 'hold_total_endpoints']
    if any(values.get(key) is None for key in required):
        return 'INCOMPLETE'
    if values['setup_total_endpoints'] <= 0 or values['hold_total_endpoints'] <= 0:
        return 'INCOMPLETE'
    if (any(values[key] < 0 for key in ['wns_ns', 'tns_ns', 'whs_ns', 'ths_ns']) or
            values['setup_failing_endpoints'] > 0 or values['hold_failing_endpoints'] > 0):
        return 'VIOLATED'
    return 'MET'


def parse_utilization(text):
    aliases = {
        'slice luts': 'LUT', 'clb luts': 'LUT',
        'slice registers': 'FF', 'clb registers': 'FF',
        'block ram tile': 'BRAM', 'block ram': 'BRAM',
        'dsps': 'DSP', 'dsp48e1': 'DSP', 'dsp48e2': 'DSP',
    }
    header = None
    found = {}
    for line in text.splitlines():
        if not line.strip().startswith('|'):
            continue
        fields = [value.strip() for value in line.strip().strip('|').split('|')]
        lowered = [value.lower().replace(' ', '') for value in fields]
        if 'used' in lowered and 'available' in lowered:
            header = {name: i for i, name in enumerate(lowered)}
            continue
        label = fields[0].rstrip('* ').strip().lower()
        key = aliases.get(label)
        if not key or header is None:
            continue
        try:
            used = numeric(fields[header['used']])
            available = numeric(fields[header['available']])
            pct_index = next((header[k] for k in ('util%', 'utilization%') if k in header), None)
            printed_pct = fields[pct_index] if pct_index is not None else ''
            pct = None if printed_pct.startswith(('<', '>')) else numeric(printed_pct)
        except (IndexError, ReportError) as exc:
            raise ReportError(f'Invalid utilization row: {line}') from exc
        if used is None or available is None or used < 0 or available <= 0:
            raise ReportError(f'Missing/invalid usage or capacity: {line}')
        # Preserve printed percentage if supplied; otherwise calculate from printed counts.
        if pct is None:
            pct = used * 100 / available
        found[key] = {'label': fields[0].rstrip('* ').strip(), 'used': used,
                      'available': available, 'percent': pct}
    missing = set(('LUT', 'FF', 'BRAM', 'DSP')) - found.keys()
    if missing:
        raise ReportError(f'Missing resource rows: {sorted(missing)}. No missing value is assumed to be zero.')
    return found


def validate_period(value):
    period = float(value)
    if not math.isfinite(period) or period <= 0:
        raise ValueError('Clock period must be a positive finite value in ns')
    return period


def pillow():
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError as exc:
        raise RuntimeError('PNG export needs Pillow. Run with the same Python: python -m pip install Pillow') from exc
    return Image, ImageDraw, ImageFont


def font(size, bold=False):
    _, _, ImageFont = pillow()
    windows = Path(os.environ.get('WINDIR', 'C:/Windows')) / 'Fonts'
    names = [str(windows / ('segoeuib.ttf' if bold else 'segoeui.ttf')),
             'DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf',
             '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else
             '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


INK = '#14243B'
MUTED = '#586B82'
TEAL = '#087E83'
BG = '#F4F7FB'
BORDER = '#D4DEE9'
ORANGE = '#B65616'


def number(value, precision=None):
    if value is None:
        return 'N/A'
    if precision is not None:
        return f'{value:,.{precision}f}'
    return f'{value:,.0f}' if float(value).is_integer() else f'{value:,.2f}'


def canvas(kind, info, stage):
    Image, ImageDraw, _ = pillow()
    image = Image.new('RGB', (1800, 1150), BG)
    draw = ImageDraw.Draw(image)
    def text(x, y, value, size=30, color=INK, bold=False):
        draw.text((x, y), str(value), fill=color, font=font(size, bold))
    heading = f'{info["top"].upper()} {kind}  |  {stage.replace("_", " ").upper()}'
    heading_size = 48
    while heading_size > 20 and draw.textbbox((0, 0), heading, font=font(heading_size, True))[2] > 1660:
        heading_size -= 2
    text(70, 45, heading, heading_size, bold=True)
    clock_label = f'{1000/info["period_ns"]:g} MHz target' if info.get('clock_port', 'clk') else 'no automatic clock'
    text(73, 122, f'{info["part"]}  |  {info["period_ns"]:g} ns target  |  {clock_label}', 27, MUTED)
    text(73, 166, 'Synthesis estimate; no placement/routing yet' if stage == 'post_synth' else
         'Placed and routed core; inspect raw reports and constraints', 25, MUTED)
    draw.rounded_rectangle((60, 1014, 1740, 1115), radius=16, fill='#FFF1DF')
    text(82, 1030, 'MODULE OOC: review external I/O and reset constraints before system signoff.', 25, ORANGE, True)
    text(82, 1070, f'Source hash {info["source_hash"][:16]}  |  Reports generated locally by Vivado', 23, MUTED)
    if info.get('test_data'):
        text(73, 218, 'TEST FIXTURE - NOT AN FPGA MEASUREMENT', 27, '#B3261E', True)
    return image, draw, text


def render_timing(path, info, stage, values):
    image, draw, text = canvas('TIMING', info, stage)
    state = timing_status(values)
    color = TEAL if state == 'MET' else '#B3261E' if state == 'VIOLATED' else ORANGE
    text(75, 270, f'SETUP / HOLD: {state}  (reported paths)', 32, color, True)
    for i, (key, label) in enumerate([('wns_ns', 'WNS - setup worst slack'), ('tns_ns', 'TNS - setup total negative slack'),
                                      ('whs_ns', 'WHS - hold worst slack'), ('ths_ns', 'THS - hold total negative slack')]):
        x, y = 70 + (i % 2) * 845, 340 + (i // 2) * 215
        draw.rounded_rectangle((x, y, x+815, y+187), radius=18, fill='white', outline=BORDER, width=2)
        text(x+26, y+20, label, 27, MUTED)
        val = values.get(key)
        text(x+26, y+73, number(val, 3) + ' ns', 53,
             ORANGE if val is None else '#B3261E' if val < 0 else TEAL, True)
    text(80, 796, 'Failing / analyzed endpoints', 28, INK, True)
    text(80, 846, f'Setup: {number(values.get("setup_failing_endpoints"))} / {number(values.get("setup_total_endpoints"))}', 28)
    text(910, 846, f'Hold: {number(values.get("hold_failing_endpoints"))} / {number(values.get("hold_total_endpoints"))}', 28)
    pulse_bad = any(values.get(key) is not None and values[key] < 0 for key in ('wpws_ns', 'tpws_ns'))
    text(80, 908, f'Pulse width: WPWS {number(values.get("wpws_ns"),3)} ns / TPWS {number(values.get("tpws_ns"),3)} ns', 25, '#B3261E' if pulse_bad else MUTED)
    text(80, 950, 'Check *_check_timing.rpt for unconstrained paths; this image is not board-level timing closure.', 22, MUTED)
    image.save(path, format='PNG')


def render_utilization(path, info, stage, values):
    image, draw, text = canvas('UTILIZATION', info, stage)
    for i, key in enumerate(('LUT', 'FF', 'BRAM', 'DSP')):
        item = values[key]
        y = 278 + i*174
        draw.rounded_rectangle((70, y, 1730, y+151), radius=16, fill='white', outline=BORDER, width=2)
        text(93, y+16, f'{key}  /  {item["label"]}', 29, INK, True)
        text(1100, y+16, f'{number(item["used"])} / {number(item["available"])}  ({item["percent"]:.2f}%)', 27, TEAL, True)
        x0, x1 = 97, 1696
        draw.rounded_rectangle((x0, y+82, x1, y+115), radius=8, fill='#E8EEF5')
        fraction = max(0, min(1, item['percent']/100))
        if fraction:
            draw.rectangle((x0, y+82, x0+max(2,(x1-x0)*fraction), y+115),
                           fill='#B3261E' if item['percent']>100 else TEAL)
    text(80, 985, 'Used / Available and percentages come from report_utilization. BRAM is measured in tiles.', 22, MUTED)
    image.save(path, format='PNG')


def initialize(results, period, sources, top='core', part='xc7z020clg484-1', clock_port='clk', include_dirs=()):
    directory = Path(results)
    paths = [Path(source).resolve() for source in sources]
    for folder in include_dirs:
        paths.extend(sorted(p.resolve() for p in Path(folder).rglob('*') if p.suffix in ('.vh', '.svh')))
    paths = list(dict.fromkeys(paths))
    digest = hashlib.sha256()
    source_hashes = {}
    for path in paths:
        payload = path.read_bytes()
        digest.update(path.name.encode()+b'\0'+payload)
        source_hashes[str(path)] = hashlib.sha256(payload).hexdigest()
    info = {'top': top, 'part': part, 'clock_port': clock_port, 'period_ns': validate_period(period),
            'created_at': datetime.now().astimezone().isoformat(),
            'source_hash': digest.hexdigest(), 'sources': source_hashes, 'scope': 'module_ooc'}
    directory.mkdir(parents=True, exist_ok=True)
    (directory/'run_info.json').write_text(json.dumps(info, indent=2)+'\n', encoding='utf-8')
    return info


def export(results, stage):
    directory = Path(results)
    info = json.loads((directory/'run_info.json').read_text(encoding='utf-8'))
    validate_period(info['period_ns'])
    timing = parse_timing((directory/'timing'/f'{stage}.rpt').read_text(encoding='utf-8', errors='replace'))
    utilization = parse_utilization((directory/'utilization'/f'{stage}.rpt').read_text(encoding='utf-8', errors='replace'))
    # Write temporary images first: missing/invalid report data cannot leave half a successful stage.
    t = directory/'timing'/f'{stage}.tmp.png'
    u = directory/'utilization'/f'{stage}.tmp.png'
    render_timing(t, info, stage, timing)
    render_utilization(u, info, stage, utilization)
    t.replace(t.with_name(f'{stage}.png'))
    u.replace(u.with_name(f'{stage}.png'))
    metrics = {'stage': stage, 'setup_hold_status': timing_status(timing), 'timing': timing, 'utilization': utilization}
    (directory/f'{stage}.json').write_text(json.dumps(metrics, indent=2)+'\n', encoding='utf-8')
    print(f'PNG: {directory/"timing"/(stage+".png")}')
    print(f'PNG: {directory/"utilization"/(stage+".png")}')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest='command', required=True)
    check = sub.add_parser('check')
    check.add_argument('--period', type=float, default=10.0)
    init = sub.add_parser('init')
    init.add_argument('--results', type=Path, required=True)
    init.add_argument('--period', type=float, required=True)
    init.add_argument('--sources', nargs='+', type=Path, required=True)
    init.add_argument('--top', default='core')
    init.add_argument('--part', default='xc7z020clg484-1')
    init.add_argument('--clock-port', default='clk')
    init.add_argument('--include-dirs', nargs='*', type=Path, default=[])
    render = sub.add_parser('export')
    render.add_argument('--results', type=Path, required=True)
    render.add_argument('--stage', choices=['post_synth', 'post_route'], required=True)
    args = ap.parse_args(argv)
    try:
        if args.command == 'check':
            validate_period(args.period)
            pillow()
            print('Python/Pillow image export ready')
        elif args.command == 'init':
            initialize(args.results, args.period, args.sources, args.top, args.part, args.clock_port, args.include_dirs)
            print(f'Analysis metadata: {args.results/"run_info.json"}')
        else:
            pillow()
            export(args.results, args.stage)
    except (ValueError, OSError, RuntimeError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
