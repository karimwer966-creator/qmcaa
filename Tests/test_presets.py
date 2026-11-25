#!/usr/bin/env python3
"""Validate shipped .set input names and effective built-in risk settings."""
import re
import unittest
from decimal import Decimal
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
EA = ROOT/'Experts/QSMC/QSMC.mq5'
RISK_INPUTS = {
    'risk_percent':'InpRiskPercent', 'max_daily_loss_pct':'InpDailyLossLimitPct',
    'max_spread_points':'InpMaxSpreadPoints', 'max_positions':'InpMaxPositions',
    'max_total_exposure_lots':'InpMaxExposureLots', 'max_daily_trades':'InpMaxDailyTrades',
    'cooldown_seconds':'InpCooldownSeconds', 'max_drawdown_pct':'InpMaxDrawdownPct',
    'sl_atr_mult':'InpStopAtrMultiplier', 'min_rr':'InpMinimumRR',
    'tp_rr':'InpTargetRR', 'min_confidence':'InpMinimumConfidence',
}


def load_set(path):
    values = {}
    for number, line in enumerate(path.read_text(encoding='ascii').splitlines(), 1):
        if not line.strip() or line.startswith(';'):
            continue
        if '=' not in line or '||' in line:
            raise ValueError(f'{path}:{number}: malformed/optimization input')
        key, value = line.split('=', 1)
        if key in values:
            raise ValueError(f'{path}:{number}: duplicate {key}')
        values[key] = value
    return values


class GoldPresetTests(unittest.TestCase):
    def test_complete_safe_inputs_and_effective_risk(self):
        inputs = re.findall(r'^input\s+\w+\s+(Inp\w+)\s*=', EA.read_text(), re.M)
        source = (ROOT/'Include/QSMC/Core/QSMC_Preset.mqh').read_text()
        for profile, enumeration in [('Conservative','0'), ('Balanced','1')]:
            with self.subTest(profile=profile):
                values = load_set(ROOT/f'Presets/QSMC_Gold_{profile}.set')
                self.assertEqual(set(values), set(inputs))
                self.assertEqual(values['InpMode'], '1')  # ANALYSIS, enum verified below
                self.assertEqual(values['InpPreset'], enumeration)
                self.assertEqual(values['InpOverridePresetRisk'], 'false')
                self.assertEqual(values['InpRealAcknowledgement'], '')
                self.assertEqual(values['InpTesterNewsCsv'], '')
                self.assertEqual(values['InpSymbol'], '')
                self.assertEqual(values['InpOwnerMagic'], '53000001')
                self.assertEqual(values['InpMagicOffset'], '0')
                self.assertEqual(values['InpClosedBarsOnly'], 'true')
                self.assertEqual(values['InpSessionsEnabled'], 'true')
                self.assertEqual(values['InpFridayCutoffHour'], '20')
                self.assertEqual(values['InpFridayCutoffMinute'], '0')
                self.assertEqual(values['InpExecutionTimeframe'], '15')
                self.assertEqual(values['InpHigherTimeframe'], '16388')
                self.assertEqual(values['InpLowerTimeframe'], '5')
                block = source.split(f'case QSMC_PRESET_{profile.upper()}:',1)[1].split('break;',1)[0]
                effective = dict(re.findall(r'cfg\.(\w+)\s*=\s*([\d.]+);', block))
                self.assertEqual(set(effective), set(RISK_INPUTS))
                for field, input_name in RISK_INPUTS.items():
                    self.assertEqual(Decimal(values[input_name]), Decimal(effective[field]), field)
                self.assertGreater(Decimal(effective['risk_percent']), 0)
                self.assertLessEqual(Decimal(effective['risk_percent']), Decimal('0.5'))
                self.assertEqual(effective['max_positions'], '1')
                self.assertTrue(values['InpNewsKeywords'])
        types = (ROOT/'Include/QSMC/Core/QSMC_Types.mqh').read_text()
        self.assertRegex(types, r'QSMC_MODE_ANALYSIS\s*=\s*1')
        self.assertRegex(types, r'QSMC_PRESET_CONSERVATIVE\s*=\s*0')
        self.assertRegex(types, r'QSMC_PRESET_BALANCED\s*=\s*1')

    def test_parser_preserves_keywords_and_rejects_duplicate(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'test.set'
            path.write_text('; comment\nInpNewsKeywords=CPI;FED;NFP\nInpSymbol=\n')
            self.assertEqual(load_set(path)['InpNewsKeywords'], 'CPI;FED;NFP')
            path.write_text('InpMode=1\nInpMode=3\n')
            with self.assertRaises(ValueError):
                load_set(path)
            path.write_text('InpMode=1||1||1||3||Y\n')
            with self.assertRaises(ValueError):
                load_set(path)

    def test_terminal_matrix_template_is_explicitly_unrun(self):
        import csv
        path = ROOT/'Tests/StrategyTester/results_template.csv'
        with path.open(newline='') as stream:
            rows = list(csv.DictReader(stream))
        matrix = (ROOT/'Tests/StrategyTester/README.md').read_text()
        identifiers = re.findall(r'^\| ([A-Z]\d{2}) \|', matrix, re.M)
        self.assertEqual([row['case_id'] for row in rows], identifiers)
        self.assertEqual(len(identifiers), len(set(identifiers)))
        self.assertTrue(all(row['status']=='NOT_RUN' and not row['evidence_path'] for row in rows))

    def test_pure_terminal_harness_has_no_direct_side_effect_calls(self):
        paths = ['Tests/Harness/QSMC_SafetySelftest.mqh',
                 'Scripts/QSMC_SafetySelftest.mq5', 'Experts/QSMC/QSMC_SafetySelftest.mq5']
        forbidden = r'\b(?:OrderSend|OrderCheck|FileOpen|FileDelete|GlobalVariableSet|CalendarValueHistory|AccountInfoDouble|AccountInfoInteger)\s*\('
        for path in paths:
            self.assertNotRegex((ROOT/path).read_text(), forbidden, path)


if __name__ == '__main__':
    unittest.main()
