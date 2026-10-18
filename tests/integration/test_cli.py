"""Black-box tests; ptrace may be restricted on some CI/container hosts."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
BIN = ROOT / 'build' / 'rewind64'


def run(*args):
    return subprocess.run([str(BIN), *map(str, args)], capture_output=True,
                          text=True, timeout=12, cwd=ROOT)


class CliTests(unittest.TestCase):
    def test_help(self):
        result = run('--help')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Trace every instruction', result.stdout)
        self.assertIn('run PROGRAM', result.stdout)

    def test_version(self):
        result = run('--version')
        self.assertEqual(result.returncode, 0)
        self.assertIn('v0.1.0-dev', result.stdout)

    def test_unknown(self):
        result = run('replay', 'nonexistent.r64')
        self.assertEqual(result.returncode, 2)
        self.assertIn('unsupported command', result.stdout)

    def test_missing_target(self):
        result = run('run')
        self.assertEqual(result.returncode, 2)

    def test_exit0(self):
        result = run('run', ROOT / 'build' / 'exit0')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Initial stop:', result.stdout)
        self.assertIn('After step:', result.stdout)
        self.assertEqual(result.stdout.count('Registers:'), 2)
        self.assertIn('Target exited with status 0', result.stdout)

    def test_exit7(self):
        result = run('run', ROOT / 'build' / 'exit7')
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
        self.assertIn('Target exited with status 7', result.stdout)

    def test_application_trap_is_not_swallowed(self):
        result = run('run', ROOT / 'build' / 'trap')
        self.assertEqual(result.returncode, 128 + 5, result.stdout + result.stderr)
        self.assertIn('Target terminated by signal 5', result.stdout)

    def test_failed_exec(self):
        result = run('run', '/definitely-not-a-real-executable-rewind64')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('execvp', result.stderr)
        self.assertEqual(result.returncode, 127, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
