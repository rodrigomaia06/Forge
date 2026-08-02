#!/usr/bin/env python3
"""Renames attachments exported from an .xcresult back to their readable names.

The UI tests can only attach, not write: their process runs inside the simulator. An exported
attachment is named by UUID, so the readable name comes from the manifest the export writes
alongside them.

Usage: recover-screenshots.py <raw-export-dir> <output-dir>
"""

import json
import os
import shutil
import sys

# A failing UI test attaches its own diagnostics: a recording, a synthesized event per tap, a
# snapshot per failure. They are named by timestamp and are not screens.
DIAGNOSTIC_MARKERS = ("Snapshot", "Synthesized", "Recording", ".txt", ".mp4")


def collect(node, pairs):
    if isinstance(node, dict):
        name = node.get("suggestedHumanReadableName") or node.get("name")
        exported = node.get("exportedFileName")
        if name and exported:
            pairs.append((name, exported))
        for value in node.values():
            collect(value, pairs)
    elif isinstance(node, list):
        for value in node:
            collect(value, pairs)


def main():
    raw, out = sys.argv[1], sys.argv[2]
    manifest = os.path.join(raw, "manifest.json")

    if not os.path.exists(manifest):
        print("No manifest; leaving the exported files as they are.")
        for name in os.listdir(raw):
            source = os.path.join(raw, name)
            if os.path.isfile(source):
                shutil.copy2(source, os.path.join(out, name))
        return

    pairs = []
    with open(manifest) as handle:
        collect(json.load(handle), pairs)

    for name, exported in sorted(set(pairs)):
        source = os.path.join(raw, exported)
        if not os.path.exists(source):
            continue
        # Attachment names arrive as "history_0_<uuid>.png". The readable part is everything
        # before the first underscore, which is why capture names use hyphens.
        stem = name.split("_")[0]
        if not stem.endswith(".png") and not stem.endswith(".txt"):
            stem += ".png"
        if any(word in stem for word in DIAGNOSTIC_MARKERS) and not stem.endswith(".txt"):
            continue
        shutil.copy2(source, os.path.join(out, stem))
        print("  ", stem)


if __name__ == "__main__":
    main()
