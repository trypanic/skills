#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = []
# ///
"""Lightweight validator for bounded-context knowledge packages.

The script intentionally uses only Python's standard library. It catches common
structural issues; governance review still requires the reference checklists.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ALLOWED_INTENTS = {
    "fix_bug",
    "investigate_incident",
    "add_feature",
    "change_contract",
    "change_workflow",
    "refactor_no_behavior_change",
    "migrate_context",
    "update_docs",
    "split_context",
}

REQUIRED_MANIFEST_TOKENS = [
    "apiVersion: context/v1",
    "kind: BoundedContext",
    "identity:",
    "name:",
    "owner:",
    "responsibilities:",
    "boundaries:",
    "entrypoints:",
]

SCHEMA_BODY_PATTERNS = [
    r'"\$schema"\s*:',
    r"\$schema\s*:",
    r'"properties"\s*:',
    r"\bproperties\s*:",
    r'"required"\s*:',
    r"\brequired\s*:",
    r"\btype\s*:\s*object\b",
]


@dataclass
class Finding:
    severity: str
    path: Path
    message: str


def finding_to_dict(finding: Finding, root: Path) -> dict[str, str]:
    return {
        "severity": finding.severity,
        "path": rel(finding.path, root),
        "message": finding.message,
    }


def rel(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def add(findings: list[Finding], severity: str, path: Path, message: str) -> None:
    findings.append(Finding(severity, path, message))


def check_manifest(context: Path, findings: list[Finding]) -> None:
    manifest = context / "manifest.yaml"
    if not manifest.exists():
        add(findings, "ERROR", manifest, "missing required manifest.yaml")
        return

    text = read_text(manifest)
    for token in REQUIRED_MANIFEST_TOKENS:
        if token not in text:
            add(findings, "ERROR", manifest, f"missing manifest token: {token}")

    status_match = re.search(r"^\s*status:\s*([a-z_]+)\s*$", text, re.MULTILINE)
    if status_match and status_match.group(1) not in {
        "proposed",
        "active",
        "deprecated",
        "retired",
    }:
        add(
            findings,
            "ERROR",
            manifest,
            "identity.status must be proposed, active, deprecated, or retired",
        )

    if len(text.splitlines()) > 180:
        add(findings, "WARN", manifest, "manifest is long; move prose to focused docs")

    published_dir = context / "contracts" / "published"
    if published_dir.exists() and any(p.is_file() for p in published_dir.rglob("*")):
        if "published:" not in text:
            add(
                findings,
                "ERROR",
                manifest,
                "contracts/published exists but manifest lacks contracts.published",
            )

    consumed_dir = context / "contracts" / "consumed"
    if consumed_dir.exists() and any(p.is_file() for p in consumed_dir.rglob("*")):
        if "consumed:" not in text:
            add(
                findings,
                "WARN",
                manifest,
                "contracts/consumed exists but manifest may lack contracts.consumed",
            )


def check_guide(context: Path, findings: list[Finding]) -> None:
    guide = context / "guide.md"
    if not guide.exists():
        add(findings, "ERROR", guide, "missing required guide.md")
        return

    text = read_text(guide)
    expected = [
        "What this context owns",
        "What this context does not own",
        "Start here",
        "Contracts",
        "Code entrypoints",
    ]
    for heading in expected:
        if heading not in text:
            add(findings, "WARN", guide, f"guide may be missing section: {heading}")


def check_context_map(context: Path, findings: list[Finding]) -> None:
    context_map = context / "context-map.yaml"
    if not context_map.exists():
        add(
            findings,
            "WARN",
            context_map,
            "missing context-map.yaml; acceptable only if agents/loaders do not depend on it",
        )
        return

    text = read_text(context_map)
    required = [
        "apiVersion: context-map/v1",
        "context:",
        "bootstrap:",
        "intents:",
        "tasks:",
    ]
    for token in required:
        if token not in text:
            add(findings, "ERROR", context_map, f"missing context-map token: {token}")

    allowed_block = re.search(
        r"intents:\s*\n\s*allowed:\s*\n(?P<body>(?:\s*-\s*[a-z_]+\s*\n)+)",
        text,
    )
    if allowed_block:
        intents = {
            line.split("-", 1)[1].strip()
            for line in allowed_block.group("body").splitlines()
            if "-" in line
        }
        unknown = sorted(intent for intent in intents if intent not in ALLOWED_INTENTS)
        for intent in unknown:
            add(findings, "ERROR", context_map, f"unknown intent: {intent}")

    if "guardrails:" not in text:
        add(findings, "WARN", context_map, "missing guardrails section")


def check_consumed_contracts(context: Path, findings: list[Finding]) -> None:
    consumed_dir = context / "contracts" / "consumed"
    if not consumed_dir.exists():
        return

    for path in consumed_dir.rglob("*"):
        if not path.is_file():
            continue
        text = read_text(path)
        for pattern in SCHEMA_BODY_PATTERNS:
            if re.search(pattern, text):
                add(
                    findings,
                    "ERROR",
                    path,
                    "consumed contract appears to contain a schema body; use a reference instead",
                )
                break


def check_reachability(context: Path, findings: list[Finding]) -> None:
    guide = context / "guide.md"
    context_map = context / "context-map.yaml"
    haystack = ""
    if guide.exists():
        haystack += read_text(guide)
    if context_map.exists():
        haystack += "\n" + read_text(context_map)

    if not haystack:
        return

    ignored = {
        "manifest.yaml",
        "guide.md",
        "context-map.yaml",
        "README.md",
        "open-questions.md",
        "glossary.md",
    }
    for path in context.rglob("*"):
        if not path.is_file():
            continue
        relative = rel(path, context)
        if relative in ignored:
            continue
        if relative.startswith("."):
            continue
        if relative not in haystack and path.name not in haystack:
            add(
                findings,
                "WARN",
                path,
                "document may be unreachable from guide.md or context-map.yaml",
            )


def check_long_markdown(context: Path, findings: list[Finding]) -> None:
    for path in context.rglob("*.md"):
        text = read_text(path)
        line_count = len(text.splitlines())
        if line_count > 300 and "## Reading Map" not in text:
            add(findings, "WARN", path, "long markdown file lacks a Reading Map")


def validate(context: Path) -> list[Finding]:
    findings: list[Finding] = []
    if not context.exists():
        add(findings, "ERROR", context, "path does not exist")
        return findings
    if not context.is_dir():
        add(findings, "ERROR", context, "path is not a directory")
        return findings

    check_manifest(context, findings)
    check_guide(context, findings)
    check_context_map(context, findings)
    check_consumed_contracts(context, findings)
    check_reachability(context, findings)
    check_long_markdown(context, findings)
    return findings


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate a bounded-context knowledge package.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  scripts/validate_context_package.py docs/contexts/orders
  scripts/validate_context_package.py --format json docs/contexts/orders

Exit codes:
  0  no structural errors found
  1  validation errors found
  2  invalid command-line usage
""",
    )
    parser.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        help="Output format. Use json for automation. Default: text.",
    )
    parser.add_argument("context_path", help="Path to docs/contexts/<context-id>")
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    context = Path(args.context_path).resolve()
    findings = validate(context)

    root = Path.cwd().resolve()
    errors = [finding for finding in findings if finding.severity == "ERROR"]
    warnings = [finding for finding in findings if finding.severity == "WARN"]
    exit_code = 1 if errors else 0

    if args.format == "json":
        print(
            json.dumps(
                {
                    "ok": not errors,
                    "context_path": rel(context, root),
                    "summary": {
                        "errors": len(errors),
                        "warnings": len(warnings),
                        "findings": len(findings),
                    },
                    "findings": [
                        finding_to_dict(finding, root) for finding in findings
                    ],
                },
                indent=2,
                sort_keys=True,
            )
        )
        return exit_code

    if not findings:
        print("OK: no structural findings")
        return exit_code

    for finding in findings:
        print(f"{finding.severity}: {rel(finding.path, root)}: {finding.message}")

    print(f"\nSummary: {len(errors)} error(s), {len(warnings)} warning(s)")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
