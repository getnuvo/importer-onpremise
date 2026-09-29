#!/usr/bin/env python3
"""Replace one chart image tag in values.yaml."""

import re
import sys
from pathlib import Path

COMPONENTS = ("aiService", "importer", "mapping")
TAG_RE = re.compile(r"^\d+\.\d+\.\d+$")


def bump_text(text: str, component: str, tag: str) -> tuple[str, str, bool]:
    # ponytail: scans the component block by indentation, not a YAML parser.
    # Ceiling: a second `image:` at indent 2, or a tag not written as `tag: X`.
    # Upgrade path: yq if the chart nesting changes.
    if component not in COMPONENTS:
        raise ValueError(f"unknown component {component!r}")
    if not TAG_RE.fullmatch(tag):
        raise ValueError(f"tag must be MAJOR.MINOR.PATCH, got {tag!r}")

    lines = text.splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines) if line.startswith(f"{component}:")), None)
    if start is None:
        raise ValueError(f"missing top-level key {component}")

    end = len(lines)
    for i in range(start + 1, len(lines)):
        if re.match(r"^[A-Za-z]", lines[i]):
            end = i
            break

    image_at = next((i for i in range(start + 1, end) if lines[i].startswith("  image:")), None)
    if image_at is None:
        raise ValueError(f"no image block under {component}")

    for i in range(image_at + 1, end):
        line = lines[i]
        if line.startswith("  ") and not line.startswith("   ") and line.strip():
            break
        if not line.startswith("    tag:"):
            continue
        nl = "\n" if line.endswith("\n") else ""
        body = line[:-1] if nl else line
        match = re.match(r"^(\s*tag:\s*)([^\s#]+)(.*)$", body)
        if not match:
            raise ValueError(f"unparseable tag line under {component}")
        old = match.group(2)
        if old == tag:
            return text, old, False
        lines[i] = f"{match.group(1)}{tag}{match.group(3)}{nl}"
        return "".join(lines), old, True

    raise ValueError(f"no image.tag under {component}")


def self_check() -> None:
    fixture = """\
importer:
  image:
    repository: ingestro/importer
    tag: 1.4.0 # keep
    pullPolicy: IfNotPresent

mapping:
  image:
    repository: ingestro/mapping
    tag: 1.1.10 # keep

aiService:
  image:
    repository: ingestro/service
    tag: 1.3.0 # keep

mongo:
  image:
    tag: 7.0
"""
    updated, old, changed = bump_text(fixture, "aiService", "1.3.1")
    assert changed and old == "1.3.0"
    assert "tag: 1.3.1 # keep" in updated
    assert "tag: 1.4.0 # keep" in updated
    assert "tag: 1.1.10 # keep" in updated
    assert "tag: 7.0" in updated
    same, old_again, changed_again = bump_text(updated, "aiService", "1.3.1")
    assert not changed_again and same == updated and old_again == "1.3.1"
    for component, new_tag, needle in (
        ("importer", "1.4.1", "tag: 1.4.1 # keep"),
        ("mapping", "1.1.11", "tag: 1.1.11 # keep"),
    ):
        bumped, _, did = bump_text(fixture, component, new_tag)
        assert did and needle in bumped and "tag: 1.3.0 # keep" in bumped
    for bad in ("latest", "20457-staging", "1.2", "v1.2.3", ""):
        try:
            bump_text(fixture, "aiService", bad)
        except ValueError:
            continue
        raise AssertionError(bad)
    try:
        bump_text(fixture, "mongo", "7.0.1")
    except ValueError:
        return
    raise AssertionError("mongo")


def main(argv: list[str]) -> int:
    if argv[1:] == ["--self-check"]:
        self_check()
        print("ok")
        return 0
    if len(argv) != 4:
        print("usage: bump-image-tag.py <values.yaml> <component> <tag>", file=sys.stderr)
        return 2
    path, component, tag = argv[1], argv[2], argv[3]
    file = Path(path)
    try:
        updated, old, changed = bump_text(file.read_text(), component, tag)
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 1
    if changed:
        file.write_text(updated)
    print(f"changed={'true' if changed else 'false'}")
    print(f"old={old}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
