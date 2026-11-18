"""Synthetic report/parser/export tests. No measured FPGA values are generated here."""
from pathlib import Path
import importlib.util
import json
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('export_analysis', ROOT/'scripts/export_analysis.py')
analysis = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(analysis)

TIMING = '''Vivado test fixture (not a measured design)
Design Timing Summary
---------------------
 WNS(ns) TNS(ns) TNS Failing Endpoints TNS Total Endpoints WHS(ns) THS(ns) THS Failing Endpoints THS Total Endpoints WPWS(ns) TPWS(ns) TPWS Failing Endpoints TPWS Total Endpoints
 ------- ------- --------------------- ------------------- ------- ------- --------------------- ------------------- -------- -------- --------------------- --------------------
 0.125 0.000 0 1264 0.031 0.000 0 1264 1.250 0.000 0 320
'''
UTIL = '''Vivado test fixture (not a measured design)
| Site Type | Used | Fixed | Prohibited | Available | Util% |
| Slice LUTs* | 1200 | 0 | 0 | 53200 | 2.26 |
| Slice Registers | 1600 | 0 | 0 | 106400 | 1.50 |
| Site Type | Used | Fixed | Prohibited | Available | Util% |
| Block RAM Tile | 0.5 | 0 | 0 | 140 | 0.36 |
| DSPs | 1 | 0 | 0 | 220 | 0.45 |
'''


def fixture(directory):
    for child in ('timing', 'utilization'):
        (directory/child).mkdir(parents=True)
    analysis.initialize(directory, 10, [ROOT/'rtl/compute/core.sv'])
    info=json.loads((directory/'run_info.json').read_text())
    info['test_data']=True
    (directory/'run_info.json').write_text(json.dumps(info))
    for stage in ('post_synth','post_route'):
        (directory/'timing'/f'{stage}.rpt').write_text(TIMING)
        (directory/'utilization'/f'{stage}.rpt').write_text(UTIL)


class AnalysisTests(unittest.TestCase):
    def test_timing_columns_and_pulse(self):
        v=analysis.parse_timing(TIMING)
        self.assertEqual(v['whs_ns'], .031)
        self.assertEqual(v['setup_total_endpoints'],1264)
        self.assertEqual(v['wpws_ns'],1.25)
        self.assertEqual(analysis.timing_status(v),'MET')

    def test_setup_violation(self):
        v=analysis.parse_timing(TIMING.replace('0.125 0.000 0 1264','-0.125 -3.125 5 1264'))
        self.assertEqual(analysis.timing_status(v),'VIOLATED')

    def test_hold_violation(self):
        v=analysis.parse_timing(TIMING.replace('0.031 0.000 0 1264','-0.031 -0.062 2 1264'))
        self.assertEqual(v['wns_ns'], .125)
        self.assertEqual(analysis.timing_status(v),'VIOLATED')

    def test_na_not_zero_or_met(self):
        v=analysis.parse_timing(TIMING.replace('0.125','N/A'))
        self.assertIsNone(v['wns_ns'])
        self.assertEqual(analysis.timing_status(v),'INCOMPLETE')

    def test_no_endpoints_not_met(self):
        v=analysis.parse_timing(TIMING.replace('1264','0'))
        self.assertEqual(analysis.timing_status(v),'INCOMPLETE')

    def test_explicit_no_clock_report(self):
        v=analysis.parse_timing('No clocks defined; no timing paths were found.')
        self.assertEqual(analysis.timing_status(v),'INCOMPLETE')
        self.assertIsNone(v['wns_ns'])

    def test_missing_timing_table(self):
        with self.assertRaises(analysis.ReportError):analysis.parse_timing('Unrecognized report format')

    def test_util_header_positions(self):
        u=analysis.parse_utilization(UTIL)
        self.assertEqual(u['LUT']['available'],53200)
        self.assertEqual(u['BRAM']['used'],.5)
        self.assertEqual(u['DSP']['used'],1)

    def test_three_column_utilization(self):
        short=UTIL.replace(' | Fixed | Prohibited','').replace(' | 0 | 0 |',' |')
        self.assertEqual(analysis.parse_utilization(short)['FF']['available'],106400)

    def test_zero_usage_is_valid(self):
        self.assertEqual(analysis.parse_utilization(UTIL.replace('0.5 |','0 |'))['BRAM']['used'],0)

    def test_missing_resource_not_zero(self):
        with self.assertRaises(analysis.ReportError):analysis.parse_utilization(UTIL.replace('| DSPs |','| Unknown |'))

    def test_small_percentage_bound(self):
        u=analysis.parse_utilization(UTIL.replace('Slice LUTs* | 1200','Slice LUTs* | 1').replace('2.26','<0.01'))
        self.assertAlmostEqual(u['LUT']['percent'],1/53200*100)

    def test_bad_period(self):
        for p in (0,-1,float('nan'),float('inf')):
            with self.subTest(period=p),self.assertRaises(ValueError):analysis.validate_period(p)

    def test_export_four_pngs_and_json(self):
        Image,_,_=analysis.pillow()
        with tempfile.TemporaryDirectory() as temp:
            directory=Path(temp);fixture(directory)
            for stage in ('post_synth','post_route'):
                analysis.export(directory,stage)
                data=json.loads((directory/f'{stage}.json').read_text())
                self.assertEqual(data['setup_hold_status'],'MET')
                for child in ('timing','utilization'):
                    with Image.open(directory/child/f'{stage}.png') as image:
                        self.assertEqual(image.format,'PNG')
                        self.assertEqual(image.size,(1800,1150))

    def test_invalid_report_does_not_create_image(self):
        with tempfile.TemporaryDirectory() as temp:
            directory=Path(temp);fixture(directory)
            (directory/'utilization/post_synth.rpt').write_text('Unsupported format')
            with self.assertRaises(analysis.ReportError):analysis.export(directory,'post_synth')
            self.assertFalse((directory/'timing/post_synth.png').exists())

    def test_source_hash_changes(self):
        with tempfile.TemporaryDirectory() as temp:
            directory=Path(temp)
            source=directory/'core.sv';source.write_text('module core; endmodule')
            first=analysis.initialize(directory,10,[source])
            source.write_text('module core; wire changed; endmodule')
            second=analysis.initialize(directory,10,[source])
            self.assertNotEqual(first['source_hash'],second['source_hash'])

    def test_custom_design_metadata_and_header_hash(self):
        with tempfile.TemporaryDirectory() as temp:
            directory=Path(temp)
            source=directory/'filter_impl.sv';source.write_text('module gain_block; endmodule')
            include=directory/'include';include.mkdir()
            header=include/'scale.svh';header.write_text('`define SHIFT 1')
            info=analysis.initialize(directory,12.5,[source],top='gain_block',part='xc7a35tcpg236-1',clock_port='sample_clk',include_dirs=[include])
            self.assertEqual(info['top'],'gain_block')
            self.assertEqual(info['part'],'xc7a35tcpg236-1')
            self.assertEqual(info['clock_port'],'sample_clk')
            self.assertEqual(len(info['sources']),2)
            header.write_text('`define SHIFT 2')
            changed=analysis.initialize(directory,12.5,[source],top='gain_block',part='xc7a35tcpg236-1',clock_port='sample_clk',include_dirs=[include])
            self.assertNotEqual(info['source_hash'],changed['source_hash'])


if __name__=='__main__':
    unittest.main()
