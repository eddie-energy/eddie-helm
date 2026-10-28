"""Check optional Ponton conversation prefixes in Helm output."""

import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ENV_NAME = "REGION_CONNECTOR_AT_EDA_CONVERSATION_ID_PREFIX"


class PontonPrefixTest(unittest.TestCase):
    def render(self, ponton):
        with tempfile.TemporaryDirectory() as directory:
            values = Path(directory) / "values.json"
            values.write_text(json.dumps({"regionConnectors": {"ponton": ponton}}))
            return subprocess.run(
                [
                    "helm", "template", "prefix-test", str(ROOT / "chart"),
                    "-f", str(ROOT / "chart/examples/values.internal.yaml"),
                    "-f", str(values),
                    "--show-only", "templates/core/eddie-core-deployment.yaml",
                ],
                capture_output=True, text=True, check=False,
            )

    def test_enabled_connector_without_prefix(self):
        result = self.render({"enabled": True})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("REGION_CONNECTOR_AT_EDA_ENABLED", result.stdout)
        self.assertNotIn(ENV_NAME, result.stdout)

    def test_empty_prefix_preserves_default_output(self):
        default = self.render({"enabled": True})
        empty = self.render({"enabled": True, "conversationIdPrefix": ""})
        self.assertEqual(empty.returncode, 0, empty.stderr)
        self.assertEqual(default.returncode, 0, default.stderr)
        self.assertEqual(default.stdout, empty.stdout)

    def test_prefix_is_rendered_as_a_string(self):
        for prefix in ["D4G", "aB123", "123"]:
            with self.subTest(prefix=prefix):
                result = self.render({"enabled": True, "conversationIdPrefix": prefix})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.count(ENV_NAME), 1)
                self.assertRegex(result.stdout, re.escape(ENV_NAME) + r'\s+value: "' + prefix + '"')

    def test_disabled_connector_omits_prefix(self):
        result = self.render({"enabled": False, "conversationIdPrefix": "D4G"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("REGION_CONNECTOR_AT_EDA_ENABLED", result.stdout)
        self.assertNotIn(ENV_NAME, result.stdout)

    def test_invalid_characters_are_rejected(self):
        for prefix in ["D4G-", "D4G_", "D4G ", "D4G\n", "ä"]:
            with self.subTest(prefix=prefix):
                result = self.render({"enabled": True, "conversationIdPrefix": prefix})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("conversationIdPrefix", result.stderr)

    def test_nonstring_prefix_is_rejected(self):
        result = self.render({"enabled": True, "conversationIdPrefix": 123})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("conversationIdPrefix", result.stderr)


if __name__ == "__main__":
    unittest.main()
