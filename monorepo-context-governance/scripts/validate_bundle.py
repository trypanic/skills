#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = []
# ///
"""Validate an OKF-aligned knowledge bundle or a single bounded-context package.

Covers the statically checkable subset of the governance rules:
E1 (frontmatter type), E2 (context.md shape), E3 (owner in OWNERS),
E4 (no schema bodies in consumed), E5 (consumed ids resolve to a publisher),
E7 (entrypoints resolve, with --repo-root), plus structural checks
(reserved files, published contract folders, deprecated-needs-replacement,
v1 artifacts, reading maps).

E6/E8/E9/E10 (schema diff, ADR immutability, generation diff, anti-drift gate)
need CI wiring and are out of scope here.

Uses only the standard library. Frontmatter parsing is intentionally shallow
(line/indent based) — it handles the shapes emitted by the bundled templates.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


RESERVED_FILES = {"index.md", "log.md"}
VALID_STATUS = {"proposed", "active", "deprecated", "retired"}
VALID_STABILITY = {"draft", "stable", "deprecated"}
V1_ARTIFACTS = {"manifest.yaml", "guide.md", "README.md", "context-map.yaml"}
NULLISH = {"", "null", "~", "none"}

SCHEMA_BODY_PATTERNS = [
    r'"\$schema"\s*:',
    r"\$schema\s*:",
    r'"properties"\s*:',
    r'"required"\s*:\s*\[',
    r"\btype\s*:\s*object\b",
    r"^\s*(message|syntax)\s",  # protobuf
]


@dataclass
class Finding:
    severity: str  # ERROR | WARN
    path: Path
    message: str


@dataclass
class ContextFacts:
    directory: Path
    context_id: str = ""
    published: list = field(default_factory=list)
    consumed: list = field(default_factory=list)
    entrypoints: dict = field(default_factory=dict)
    owner_team: str = ""


def rel(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def strip_comment(value: str) -> str:
    """Drop a trailing ` # comment`. Heuristic: quoted values with inner ` #` break."""
    cut = value.find(" #")
    if cut != -1:
        value = value[:cut]
    return value.strip()


def parse_frontmatter(text: str) -> str | None:
    """Return the raw frontmatter block body, or None if absent."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return "\n".join(lines[1:i])
    return None


def fm_scalar(fm: str, key: str) -> str:
    match = re.search(rf"^{re.escape(key)}:\s*(.*)$", fm, re.MULTILINE)
    if not match:
        return ""
    return strip_comment(match.group(1)).strip("\"'")


def fm_nested_scalar(fm: str, parent: str, key: str) -> str:
    """Find `key:` on an indented line following a top-level `parent:` line."""
    lines = fm.splitlines()
    inside = False
    for raw in lines:
        stripped = raw.strip()
        if not stripped:
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        if indent == 0:
            inside = stripped.startswith(f"{parent}:")
            continue
        if inside and stripped.startswith(f"{key}:"):
            return strip_comment(stripped.split(":", 1)[1]).strip("\"'")
    return ""


def scan_contract_entries(fm: str) -> tuple[list, list]:
    """Collect published/consumed entries from a context.md frontmatter."""
    published: list = []
    consumed: list = []
    target = None
    current = None
    in_contracts = False
    for raw in fm.splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        if indent == 0:
            in_contracts = stripped.startswith("contracts:")
            target, current = None, None
            continue
        if not in_contracts:
            continue
        if stripped.startswith("published:"):
            target, current = published, None
            continue
        if stripped.startswith("consumed:"):
            target, current = consumed, None
            continue
        if target is None:
            continue
        if stripped.startswith("- "):
            current = {}
            target.append(current)
            stripped = stripped[2:].strip()
        if current is not None and ":" in stripped:
            key, _, value = stripped.partition(":")
            current[key.strip()] = strip_comment(value).strip("\"'")
    return published, consumed


def scan_entrypoints(fm: str) -> dict:
    result: dict = {}
    in_block = False
    key = None
    for raw in fm.splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        if indent == 0:
            in_block = stripped.startswith("entrypoints:")
            key = None
            continue
        if not in_block:
            continue
        match = re.match(r"(source|tests|runtime):\s*(.*)$", stripped)
        if match:
            key = match.group(1)
            rest = strip_comment(match.group(2))
            result.setdefault(key, [])
            if rest.startswith("["):
                items = [
                    item.strip().strip("\"'")
                    for item in rest.strip("[]").split(",")
                    if item.strip()
                ]
                result[key].extend(items)
                key = None
            continue
        if key and stripped.startswith("- "):
            result[key].append(strip_comment(stripped[2:]).strip("\"'"))
    return result


def add(findings: list[Finding], severity: str, path: Path, message: str) -> None:
    findings.append(Finding(severity, path, message))


def check_markdown_files(scan_root: Path, bundle_root: Path | None, findings: list[Finding]) -> None:
    """E1 + reserved-file rules + reading-map advisory over every .md file."""
    for path in sorted(scan_root.rglob("*.md")):
        if any(part.startswith(".") for part in path.parts):
            continue
        text = read_text(path)
        fm = parse_frontmatter(text)
        if path.name in RESERVED_FILES:
            is_bundle_root_index = (
                path.name == "index.md"
                and bundle_root is not None
                and path.parent == bundle_root
            )
            if is_bundle_root_index:
                if fm is None or "okf_version" not in fm:
                    add(findings, "WARN", path,
                        "bundle root index.md should declare okf_version in frontmatter")
                continue
            if fm is not None:
                add(findings, "ERROR", path,
                    "reserved file must not carry frontmatter "
                    "(only the bundle root index.md may declare okf_version)")
            continue
        if fm is None:
            add(findings, "ERROR", path,
                "missing YAML frontmatter (every non-reserved .md needs a type field) [E1]")
            continue
        if not fm_scalar(fm, "type"):
            add(findings, "ERROR", path, "frontmatter has no non-empty type field [E1]")
        body = text[len(fm):]
        if len(body.splitlines()) > 300 and "## reading map" not in text.lower():
            add(findings, "WARN", path, "long document lacks a reading map [A3]")


def check_context(context_dir: Path, owners: set[str] | None, findings: list[Finding]) -> ContextFacts | None:
    facts = ContextFacts(directory=context_dir)
    context_md = context_dir / "context.md"
    if not context_md.exists():
        add(findings, "ERROR", context_md, "missing required context.md [E2]")
        return None

    fm = parse_frontmatter(read_text(context_md))
    if fm is None:
        add(findings, "ERROR", context_md, "context.md has no frontmatter [E2]")
        return None

    if fm_scalar(fm, "type") != "BoundedContext":
        add(findings, "ERROR", context_md, "context.md type must be BoundedContext [E2]")

    facts.context_id = fm_scalar(fm, "id")
    if not facts.context_id:
        add(findings, "ERROR", context_md, "missing id [E2]")
    elif facts.context_id != context_dir.name:
        add(findings, "ERROR", context_md,
            f"id '{facts.context_id}' does not match directory name '{context_dir.name}' [E2]")

    status = fm_scalar(fm, "status")
    if status not in VALID_STATUS:
        add(findings, "ERROR", context_md,
            f"status '{status}' invalid; expected one of {sorted(VALID_STATUS)} [E2]")

    facts.owner_team = fm_nested_scalar(fm, "owner", "team")
    if not facts.owner_team:
        add(findings, "ERROR", context_md, "missing owner.team [E2]")
    elif owners is not None and facts.owner_team not in owners:
        add(findings, "ERROR", context_md,
            f"owner.team '{facts.owner_team}' does not resolve in docs/OWNERS [E3]")

    facts.published, facts.consumed = scan_contract_entries(fm)
    facts.entrypoints = scan_entrypoints(fm)

    for entry in facts.published:
        cid = entry.get("id", "")
        label = cid or "<missing id>"
        if not cid:
            add(findings, "ERROR", context_md, "published contract entry missing id")
        if not entry.get("version"):
            add(findings, "ERROR", context_md, f"published contract '{label}' missing version")
        stability = entry.get("stability", "")
        if stability and stability not in VALID_STABILITY:
            add(findings, "ERROR", context_md,
                f"published contract '{label}' stability '{stability}' invalid")
        if stability == "deprecated" and entry.get("replacement", "").lower() in NULLISH:
            add(findings, "ERROR", context_md,
                f"deprecated contract '{label}' must declare a replacement")

    for entry in facts.consumed:
        cid = entry.get("id", "")
        label = cid or "<missing id>"
        if not cid:
            add(findings, "ERROR", context_md, "consumed contract entry missing id")
        if not entry.get("version"):
            add(findings, "ERROR", context_md, f"consumed contract '{label}' missing version")
        for forbidden in ("ref", "schema", "from", "path"):
            if forbidden in entry:
                add(findings, "ERROR", context_md,
                    f"consumed contract '{label}' declares '{forbidden}'; "
                    "consume by id + version only — resolution goes through the registry")

    check_published_folders(context_dir, facts, findings)
    check_consumed_folder(context_dir, findings)

    for name in sorted(V1_ARTIFACTS - {"context-map.yaml"}):
        if (context_dir / name).exists():
            add(findings, "WARN", context_dir / name,
                "v1 artifact; merge its content into context.md")

    return facts


def check_published_folders(context_dir: Path, facts: ContextFacts, findings: list[Finding]) -> None:
    published_dir = context_dir / "contracts" / "published"
    if not published_dir.is_dir():
        if facts.published:
            add(findings, "WARN", published_dir,
                "contracts declared as published but contracts/published/ is missing")
        return
    for contract_dir in sorted(p for p in published_dir.iterdir() if p.is_dir()):
        contract_md = contract_dir / "contract.md"
        if not contract_md.exists():
            add(findings, "ERROR", contract_md, "published contract folder missing contract.md")
        else:
            fm = parse_frontmatter(read_text(contract_md))
            if fm is None or fm_scalar(fm, "type") != "Contract":
                add(findings, "ERROR", contract_md, "contract.md must have type: Contract frontmatter")
            elif not fm_scalar(fm, "id") or not fm_scalar(fm, "version"):
                add(findings, "ERROR", contract_md, "contract.md frontmatter missing id or version")
        schemas = [p for p in contract_dir.iterdir() if p.is_file() and p.suffix != ".md"]
        if not schemas:
            add(findings, "WARN", contract_dir,
                "no schema file next to contract.md; the schema is the source of truth")


def check_consumed_folder(context_dir: Path, findings: list[Finding]) -> None:
    consumed_dir = context_dir / "contracts" / "consumed"
    if not consumed_dir.is_dir():
        return
    for path in sorted(consumed_dir.rglob("*")):
        if not path.is_file():
            continue
        text = read_text(path)
        for pattern in SCHEMA_BODY_PATTERNS:
            if re.search(pattern, text, re.MULTILINE):
                add(findings, "ERROR", path,
                    "consumed contract material contains a schema body; "
                    "consumed contracts are id + version references only [E4]")
                break


def check_cross_context(contexts: list[ContextFacts], findings: list[Finding]) -> None:
    published_ids: dict[str, Path] = {}
    for facts in contexts:
        for entry in facts.published:
            cid = entry.get("id", "")
            if not cid:
                continue
            if cid in published_ids:
                add(findings, "ERROR", facts.directory / "context.md",
                    f"published contract id '{cid}' already published by "
                    f"{published_ids[cid]} — ids must be globally unique")
            else:
                published_ids[cid] = facts.directory / "context.md"
    for facts in contexts:
        for entry in facts.consumed:
            cid = entry.get("id", "")
            if cid and cid not in published_ids:
                add(findings, "ERROR", facts.directory / "context.md",
                    f"consumed contract '{cid}' has no publisher in this bundle [E5]")


def check_entrypoints(contexts: list[ContextFacts], repo_root: Path, findings: list[Finding]) -> None:
    for facts in contexts:
        for key in ("source", "tests"):
            for pointer in facts.entrypoints.get(key, []):
                candidate = repo_root / pointer
                if not candidate.exists():
                    add(findings, "ERROR", facts.directory / "context.md",
                        f"entrypoints.{key} '{pointer}' does not resolve under {repo_root} [E7]")


def load_owners(bundle_root: Path) -> set[str] | None:
    owners_file = bundle_root / "OWNERS"
    if not owners_file.exists():
        return None
    teams = set()
    for line in read_text(owners_file).splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            teams.add(line.split()[0])
    return teams


def validate(path: Path, repo_root: Path | None) -> list[Finding]:
    findings: list[Finding] = []
    if not path.is_dir():
        add(findings, "ERROR", path, "path does not exist or is not a directory")
        return findings

    contexts_dir = path / "contexts"
    if contexts_dir.is_dir():
        # Bundle mode.
        bundle_root = path
        owners = load_owners(bundle_root)
        if owners is None:
            add(findings, "WARN", bundle_root / "OWNERS",
                "missing docs/OWNERS; owner resolution [E3] skipped")
        check_markdown_files(bundle_root, bundle_root, findings)
        contexts: list[ContextFacts] = []
        for context_dir in sorted(p for p in contexts_dir.iterdir() if p.is_dir()):
            facts = check_context(context_dir, owners, findings)
            if facts:
                contexts.append(facts)
        if not contexts:
            add(findings, "WARN", contexts_dir, "no context packages found")
        check_cross_context(contexts, findings)
        if repo_root:
            check_entrypoints(contexts, repo_root, findings)
    elif (path / "context.md").exists():
        # Single-context mode: cross-context resolution [E5] is skipped.
        check_markdown_files(path, None, findings)
        facts = check_context(path, None, findings)
        if facts and repo_root:
            check_entrypoints([facts], repo_root, findings)
    else:
        add(findings, "ERROR", path,
            "not a bundle root (no contexts/ directory) and not a context package (no context.md)")
    return findings


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate an OKF knowledge bundle (docs/ root) or a single context package.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  scripts/validate_bundle.py docs/
  scripts/validate_bundle.py docs/contexts/orders
  scripts/validate_bundle.py docs/ --repo-root . --format json

Exit codes:
  0  no errors found (warnings allowed)
  1  validation errors found
  2  invalid command-line usage
""",
    )
    parser.add_argument("path", help="Bundle root (contains contexts/) or a single context directory")
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=None,
        help="Repository root for resolving entrypoints.source / entrypoints.tests [E7]",
    )
    parser.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        help="Output format. Use json for automation. Default: text.",
    )
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    target = Path(args.path).resolve()
    repo_root = args.repo_root.resolve() if args.repo_root else None

    findings = validate(target, repo_root)
    findings.sort(key=lambda f: (f.severity != "ERROR", str(f.path)))

    cwd = Path.cwd().resolve()
    errors = [f for f in findings if f.severity == "ERROR"]
    warnings = [f for f in findings if f.severity == "WARN"]
    exit_code = 1 if errors else 0

    if args.format == "json":
        print(json.dumps(
            {
                "ok": not errors,
                "path": rel(target, cwd),
                "summary": {"errors": len(errors), "warnings": len(warnings)},
                "findings": [
                    {"severity": f.severity, "path": rel(f.path, cwd), "message": f.message}
                    for f in findings
                ],
            },
            indent=2,
            sort_keys=True,
        ))
        return exit_code

    if not findings:
        print("OK: no findings")
        return exit_code
    for f in findings:
        print(f"{f.severity}: {rel(f.path, cwd)}: {f.message}")
    print(f"\nSummary: {len(errors)} error(s), {len(warnings)} warning(s)")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
