"""Check source manifests, real TB tops and documented Tcl names without Vivado."""
from pathlib import Path
import re


def check(root):
    for manifest in sorted((root / 'tb').rglob('*.f')):
        top = manifest.stem
        assert manifest.parent.name == top, f'TB directory must match {manifest}'
        tb_source = manifest.parent / f'{top}.sv'
        assert tb_source.is_file(), f'Missing {tb_source}'
        assert re.search(r'\bmodule\s+' + re.escape(top) + r'\b', tb_source.read_text()), top
        sources = []
        for item in manifest.read_text().splitlines():
            item = item.strip()
            if not item or item.startswith(('#', '//')):
                continue
            source = (manifest.parent / item).resolve()
            assert source.is_file(), f'{manifest}: missing {item}'
            assert 'reference_rtl' not in source.parts, f'{manifest}: reference RTL selected'
            sources.append(source)
        assert tb_source.resolve() in sources, f'{manifest}: matching TB source not listed'
        print(f'PASS: {manifest.relative_to(root)} -> {top} ({len(sources)} sources)')
    for name in ['core.sv', 'mac.v', 'residual.v', 'relu.v', 'pooling.v', 'general_average_pooling.v']:
        source = root / 'rtl' / 'compute' / name
        assert re.search(r'\bmodule\s+' + source.stem + r'\b', source.read_text()), name
    for relative in ['README.md', 'docs/CORE_VALIDATION.md']:
        text = (root / relative).read_text()
        for top in re.findall(r'core_sim::launch\s+(tb_\w+)(?:\.sv)?', text):
            assert (root / 'tb' / top / f'{top}.sv').is_file(), (relative, top)
        assert not re.search(r'core_sim::launch\s+(?:modules|stream|core)(?:\s|`|$)', text), relative
    for relative in ['README.md', 'docs/CORE_ANALYSIS.md']:
        text = (root / relative).read_text()
        for source in re.findall(r'core_analysis::run\s+([a-zA-Z0-9_.]+)', text):
            assert (root / 'rtl' / 'compute' / source).is_file(), (relative, source)
    print('PASS: active RTL module names and documented Tcl targets match their actual files')
    print('PASS: analysis commands refer to the actual core.sv RTL file')


if __name__ == '__main__':
    check(Path(__file__).resolve().parents[2])
