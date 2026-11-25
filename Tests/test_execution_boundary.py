#!/usr/bin/env python3
"""Host-side source regression checks, NOT MQL compilation/runtime tests.
Run: python3 -m unittest discover -s Tests -p 'test_execution_boundary.py' -v
Requires the host C preprocessor for conditional-source inspection only.
"""
import re
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ExecutionBoundaryTests(unittest.TestCase):
    def test_structure(self):
        subprocess.run([sys.executable, 'Tests/static_check.py'], cwd=ROOT, check=True)

    @unittest.skipUnless(shutil.which('cpp'), 'C preprocessor unavailable')
    def test_preprocessor_build_matrix(self):
        for trading in (False, True):
            for live in (False, True):
                with self.subTest(trading=trading, live=live):
                    command = ['cpp', '-P', '-I', 'Include']
                    if trading:
                        command.append('-DQSMC_ENABLE_REAL_TRADING')
                    if live:
                        command.append('-DQSMC_ALLOW_LIVE_ACCOUNT')
                    command.append('Include/QSMC/Execution/QSMC_RealAdapter.mqh')
                    text = subprocess.check_output(command, cwd=ROOT, text=True)
                    # Default and live-only builds contain no broker call sites.
                    for api in ('OrderSend', 'OrderCheck'):
                        self.assertEqual(len(re.findall(r'\b'+api+r'\s*\(', text)), int(trading))
                    # Both build flags still cannot open the release interlock.
                    self.assertRegex(text, r'bool ReleaseApproved\(\)\s*\{return false;\}')

    def test_arming_and_submission_each_check_release(self):
        text = (ROOT / 'Include/QSMC/Execution/QSMC_RealAdapter.mqh').read_text()
        self.assertEqual(text.count('if(!CQSMCExecutionGates::ReleaseApproved())'), 2)
        self.assertIn('context-free broker Submit forbidden', text)
        self.assertIn('store.IsDirty()', text)
        self.assertIn('execution.pending_uid', text)
        self.assertNotRegex(text, r'\b(?:while|for)\s*\(')

    def test_manager_stays_blocked(self):
        text = (ROOT / 'Include/QSMC/Execution/QSMC_ExecutionManager.mqh').read_text()
        self.assertIn('if(m_mode==QSMC_EXEC_REAL_BLOCKED)', text)
        self.assertNotIn('m_real.Arm(', text)

    def test_reconciliation_cannot_clear_guard(self):
        text = (ROOT / 'Include/QSMC/Execution/QSMC_TradeReconciler.mqh').read_text()
        self.assertNotRegex(text, r'\b(?:OrderSend|SetString|SetInt|Save)\s*\(')
        self.assertIn('DEAL_ENTRY_INOUT', text)
        self.assertIn('unprotectedPositions>0', text)


if __name__ == '__main__':
    unittest.main()
