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
# snapshot per failure, a description of the issue. They are named by timestamp or by a generic
# phrase and are not screens. The walkthrough's own notes are named "<journey>-<step>-note".
DIAGNOSTIC_MARKERS = ("Snapshot", "Synthesized", "Recording", "Issue Description", "Debug description", "hierarchy for")


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
        if any(word in stem for word in DIAGNOSTIC_MARKERS):
            continue
        # The extension comes from the exported file, never from the readable name. Assuming .png
        # gave the walkthrough's notes a .png name on a text file, so five files in the folder
        # looked like screenshots and opened as nothing.
        extension = os.path.splitext(exported)[1].lower() or ".png"
        if extension not in (".png", ".txt"):
            continue
        stem = os.path.splitext(stem)[0] + extension
        shutil.copy2(source, os.path.join(out, stem))
        print("  ", stem)


if __name__ == "__main__":
    main()
