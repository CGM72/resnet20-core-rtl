"""Check that an RTL readability patch changes only whitespace and comments.

Run from a Git checkout: python verification/tools/check_rtl_tokens.py
For extracted ZIPs, use --reference-dir with the unpacked 1.1.0 directory.
This is a maintainer check; Vivado simulation/analysis never invokes Python here.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
RTL_FILES = (
    'core.v', 'mac.v', 'residual.v', 'relu.v',
    'pooling.v', 'general_average_pooling.v',
)
# Keep strings, synthesis-attribute delimiters and multicharacter operators intact.
LEXEME = re.compile(
    r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/|'
    r'\(\*|\*\)|[A-Za-z_$][A-Za-z0-9_$]*|'
    r"(?:\d+)?'[sS]?[bBoOdDhH][0-9a-fA-F_xXzZ?]+|"
    r'\d+(?:\.\d+)?|===|!==|<<<|>>>|<<|>>|<=|>=|==|!=|'
    r'&&|\|\||~\^|\^~|\*\*|[^\s]', re.S,
)


def rtl_tokens(text):
    return [m.group() for m in LEXEME.finditer(text)
            if not m.group().startswith(('//', '/*'))]


def check(reference_ref='v1.1.0', reference_dir=None):
    results = []
    for filename in RTL_FILES:
        path = Path('rtl/compute') / filename
        if reference_dir:
            original = (reference_dir / path).read_text(encoding='utf-8')
        else:
            original = subprocess.check_output(
                ['git', 'show', f'{reference_ref}:{path.as_posix()}'],
                cwd=ROOT, text=True, encoding='utf-8',
            )
        before = rtl_tokens(original)
        after = rtl_tokens((ROOT / path).read_text(encoding='utf-8'))
        if before != after:
            raise RuntimeError(f'RTL tokens changed: {path}; not a readability-only patch')
        digest = hashlib.sha256('\n'.join(after).encode()).hexdigest()
        results.append({'file': path.as_posix(), 'token_count': len(after),
                        'token_sha256': digest, 'identical': True})
        print(f'PASS unchanged RTL tokens: {path} ({len(after)} tokens)')
    return results


def check_formal(executable, reference_ref, reference_dir, log_path=None):
    """Independently compare the default core's synthesized sequential logic."""
    def quote(path):
        return '"' + str(path).replace('\\', '/').replace('"', '\\"') + '"'

    with tempfile.TemporaryDirectory(prefix='rtl_patch_') as temp:
        reference = Path(temp)
        for filename in RTL_FILES:
            path = Path('rtl/compute') / filename
            if reference_dir:
                data = (reference_dir / path).read_bytes()
            else:
                data = subprocess.check_output(
                    ['git', 'show', f'{reference_ref}:{path.as_posix()}'], cwd=ROOT,
                )
            (reference / filename).write_bytes(data)
        commands = []
        for directory, label in ((reference, 'gold'), (ROOT/'rtl/compute', 'gate')):
            sources = ' '.join(quote(directory/name) for name in RTL_FILES)
            commands.extend([
                f'read_verilog -sv -DSYNTHESIS {sources}',
                'hierarchy -check -top core', 'proc', 'opt', 'flatten',
                'memory_map', 'opt', f'rename core {label}', f'design -stash {label}',
            ])
        commands.extend([
            'design -copy-from gold -as gold gold',
            'design -copy-from gate -as gate gate',
            'equiv_make gold gate equiv', 'hierarchy -top equiv', 'equiv_struct',
            'async2sync', 'opt', 'equiv_simple', 'equiv_induct -seq 4',
            'equiv_status -assert',
        ])
        result = subprocess.run(
            [executable, '-Q', '-T', '-p', '; '.join(commands)],
            cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )
        if log_path:
            log_path.parent.mkdir(parents=True, exist_ok=True)
            log_path.write_text(result.stdout, encoding='utf-8')
        if result.returncode or 'Equivalence successfully proven!' not in result.stdout:
            raise RuntimeError('Yosys equivalence failed:\n' + result.stdout[-4000:])
        for line in result.stdout.splitlines():
            if 'are proven' in line or 'Equivalence successfully' in line:
                print(line.strip())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    reference = parser.add_mutually_exclusive_group()
    reference.add_argument('--base-ref', default='v1.1.0')
    reference.add_argument('--reference-dir', type=Path)
    parser.add_argument('--json', type=Path, help='Optional maintainer result file')
    parser.add_argument('--yosys', help='Optional Yosys executable for default-core equivalence')
    parser.add_argument('--formal-log', type=Path, help='Optional Yosys proof log')
    args = parser.parse_args()
    records = check(args.base_ref, args.reference_dir)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(records, indent=2)+'\n', encoding='utf-8')
    if args.yosys:
        check_formal(args.yosys, args.base_ref, args.reference_dir, args.formal_log)
