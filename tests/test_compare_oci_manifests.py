#!/usr/bin/env python3
"""Tests for the release update-size gate."""

import contextlib
import importlib.machinery
import importlib.util
import io
import json
import pathlib
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "just_scripts/compare-oci-manifests"
LOADER = importlib.machinery.SourceFileLoader("compare_oci_manifests", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
COMPARE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPARE)


class CompareManifestsTests(unittest.TestCase):
    def test_counts_reused_and_new_unique_blobs(self):
        result = COMPARE.compare(
            {"sha256:a": 100, "sha256:b": 200},
            {"sha256:a": 100, "sha256:c": 300, "sha256:d": 400},
        )
        self.assertEqual(result["reused_bytes"], 100)
        self.assertEqual(result["added_bytes"], 700)
        self.assertEqual(result["reused_layers"], 1)
        self.assertEqual(result["added_layers"], 2)
        self.assertEqual(result["largest_added_layers"][0]["digest"], "sha256:d")

    def test_duplicate_descriptors_count_blob_once(self):
        descriptors = [
            {"digest": "sha256:a", "size": 100},
            {"digest": "sha256:a", "size": 100},
        ]
        self.assertEqual(COMPARE.layers({"layers": descriptors}), {"sha256:a": 100})

    def test_rejects_malformed_layer_descriptor(self):
        with self.assertRaises(ValueError):
            COMPARE.layers({"layers": [{"digest": "sha256:a", "size": -1}]})

    def test_rejects_missing_descriptor_fields(self):
        with self.assertRaises(ValueError):
            COMPARE.layers({"layers": [{"digest": "sha256:a"}]})

    def test_malformed_json_fails_comparison(self):
        with tempfile.TemporaryDirectory() as directory:
            previous = pathlib.Path(directory) / "previous.json"
            current = pathlib.Path(directory) / "current.json"
            previous.write_text("not json", encoding="utf-8")
            current.write_text(json.dumps({"layers": []}), encoding="utf-8")
            stderr = io.StringIO()
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(stderr):
                result = COMPARE.main([str(previous), str(current)])

        self.assertEqual(result, 2)
        self.assertIn("manifest comparison failed", stderr.getvalue())

    def test_budget_blocks_unapproved_large_update(self):
        with tempfile.TemporaryDirectory() as directory:
            previous = pathlib.Path(directory) / "previous.json"
            current = pathlib.Path(directory) / "current.json"
            previous.write_text(json.dumps({"layers": []}), encoding="utf-8")
            current.write_text(
                json.dumps({"layers": [{"digest": "sha256:a", "size": 11}]}),
                encoding="utf-8",
            )
            stdout = io.StringIO()
            stderr = io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                result = COMPARE.main([str(previous), str(current), "--max-added-bytes", "10"])

        self.assertEqual(result, 1)
        self.assertIn('"added_bytes": 11', stdout.getvalue())
        self.assertIn("refusing promotion", stderr.getvalue())

    def test_explicit_override_allows_large_update(self):
        with tempfile.TemporaryDirectory() as directory:
            previous = pathlib.Path(directory) / "previous.json"
            current = pathlib.Path(directory) / "current.json"
            previous.write_text(json.dumps({"layers": []}), encoding="utf-8")
            current.write_text(
                json.dumps({"layers": [{"digest": "sha256:a", "size": 11}]}),
                encoding="utf-8",
            )
            stderr = io.StringIO()
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(stderr):
                result = COMPARE.main(
                    [str(previous), str(current), "--max-added-bytes", "10", "--allow-large-update"]
                )

        self.assertEqual(result, 0)
        self.assertIn("approved large update", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
