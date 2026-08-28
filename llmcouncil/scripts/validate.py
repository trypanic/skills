#!/usr/bin/env python3
"""llmcouncil validator: envelope gate + run auditor (protocol llmcouncil/v1).

Implements the checks of the JSON Schemas in ../schemas/ plus the
cross-checks defined in ../references/evaluation.md, using ONLY the Python
standard library (no jsonschema dependency).

Prerequisites: Python 3.8+.

Usage:
  validate.py envelope --stage {opinion,review,synthesis} [--seat NAME]
              [--labels A,B,C] FILE
  validate.py run DIR
  validate.py --help

  envelope   Gate a single response envelope right after a subagent reply.
             --seat cross-checks the member/reviewer field against the
             requested seat. --labels (review stage only) cross-checks
             evaluations coverage and final_ranking permutation against the
             issued labels; without it only internal consistency is checked.
  run        Audit a complete run directory: structure, manifest, every
             stored envelope, aggregate-ranking recomputation, and
             cross-file consistency.

Output: one finding per line, "LEVEL CODE where: message", then a RESULT
line. With --json, a single JSON object instead. Error codes are documented
in ../references/evaluation.md and are a stable API.

Exit codes:
  0  no errors (warnings allowed)
  1  at least one error finding
  2  usage or I/O error at the CLI level
"""

import argparse
import json
import os
import re
import string
import sys
from fractions import Fraction

PROTOCOL = "llmcouncil/v1"
SEAT_RE = re.compile(r"^council-[a-z][a-z-]*$")
LABEL_RE = re.compile(r"^[A-Z]$")
RUN_ID_RE = re.compile(r"^[0-9]{8}-[0-9]{6}-[a-z0-9]+(-[a-z0-9]+)*$")
SCORE_KEYS = ("accuracy", "insight", "completeness")
STATUSES = ("ok", "retried", "failed")
SUCCESS = ("ok", "retried")


class Findings:
    def __init__(self):
        self.items = []

    def error(self, code, where, message):
        self.items.append(("ERROR", code, where, message))

    def warn(self, code, where, message):
        self.items.append(("WARN", code, where, message))

    @property
    def errors(self):
        return [f for f in self.items if f[0] == "ERROR"]

    @property
    def warnings(self):
        return [f for f in self.items if f[0] == "WARN"]


def is_str_list(value, allow_empty_list=True):
    return isinstance(value, list) and (allow_empty_list or value) and all(
        isinstance(item, str) and item.strip() for item in value
    )


def check_common(env, stage, where, f):
    """Protocol and stage constants; returns False if env is not a dict."""
    if not isinstance(env, dict):
        f.error("E-ENV-002", where, "envelope must be a JSON object")
        return False
    if env.get("protocol") != PROTOCOL:
        f.error("E-ENV-003", where + ".protocol",
                "expected %r, got %r" % (PROTOCOL, env.get("protocol")))
    if env.get("stage") != stage:
        f.error("E-ENV-003", where + ".stage",
                "expected %r, got %r" % (stage, env.get("stage")))
    return True


def check_keys(env, required, optional, where, f):
    for key in required:
        if key not in env:
            f.error("E-ENV-001", "%s.%s" % (where, key), "missing required key")
    for key in env:
        if key not in required and key not in optional:
            f.error("E-ENV-002", "%s.%s" % (where, key), "unexpected key")


def check_confidence(env, where, f):
    conf = env.get("confidence")
    if "confidence" in env and not (
        isinstance(conf, (int, float)) and not isinstance(conf, bool) and 0 <= conf <= 1
    ):
        f.error("E-ENV-002", where + ".confidence",
                "expected number in [0,1], got %r" % (conf,))


def validate_opinion(env, f, seat=None, where="opinion"):
    if not check_common(env, "opinion", where, f):
        return
    check_keys(env, ("protocol", "stage", "member", "answer_md", "key_points",
                     "confidence"), ("assumptions", "limitations"), where, f)
    member = env.get("member")
    if "member" in env and not (isinstance(member, str) and SEAT_RE.match(member)):
        f.error("E-ENV-002", where + ".member",
                "expected seat name matching ^council-[a-z][a-z-]*$, got %r" % (member,))
    if seat and isinstance(member, str) and member != seat:
        f.error("E-ENV-002", where + ".member",
                "expected requested seat %r, got %r" % (seat, member))
    answer = env.get("answer_md")
    if "answer_md" in env:
        if not (isinstance(answer, str) and answer.strip()):
            f.error("E-ENV-002", where + ".answer_md", "expected non-empty string")
        else:
            if len(answer) < 200:
                f.warn("W-ENV-101", where + ".answer_md",
                       "suspiciously short (%d chars)" % len(answer))
            leaks = sorted(set(re.findall(r"\bcouncil-[a-z][a-z-]*", answer)))
            if leaks:
                f.error("E-ENV-004", where + ".answer_md",
                        "anonymity leak: mentions seat name(s) %s"
                        % ", ".join(leaks))
    points = env.get("key_points")
    if "key_points" in env and not (
        is_str_list(points) and 1 <= len(points) <= 7
    ):
        f.error("E-ENV-002", where + ".key_points",
                "expected array of 1-7 non-empty strings")
    for key in ("assumptions", "limitations"):
        if key in env and not is_str_list(env[key]):
            f.error("E-ENV-002", "%s.%s" % (where, key),
                    "expected array of non-empty strings")
    check_confidence(env, where, f)


def validate_review(env, f, seat=None, labels=None, where="review"):
    if not check_common(env, "review", where, f):
        return
    check_keys(env, ("protocol", "stage", "reviewer", "evaluations",
                     "final_ranking"), (), where, f)
    reviewer = env.get("reviewer")
    if "reviewer" in env and not (isinstance(reviewer, str) and SEAT_RE.match(reviewer)):
        f.error("E-ENV-002", where + ".reviewer",
                "expected seat name matching ^council-[a-z][a-z-]*$, got %r" % (reviewer,))
    if seat and isinstance(reviewer, str) and reviewer != seat:
        f.error("E-ENV-002", where + ".reviewer",
                "expected requested seat %r, got %r" % (seat, reviewer))

    eval_labels = []
    evaluations = env.get("evaluations")
    if "evaluations" in env:
        if not isinstance(evaluations, list) or len(evaluations) < 2:
            f.error("E-ENV-002", where + ".evaluations",
                    "expected array with at least 2 evaluations")
        else:
            for i, ev in enumerate(evaluations):
                w = "%s.evaluations[%d]" % (where, i)
                if not isinstance(ev, dict):
                    f.error("E-ENV-002", w, "expected object")
                    continue
                check_keys(ev, ("label", "strengths", "weaknesses", "scores"), (), w, f)
                label = ev.get("label")
                if "label" in ev:
                    if not (isinstance(label, str) and LABEL_RE.match(label)):
                        f.error("E-ENV-002", w + ".label",
                                "expected single uppercase letter, got %r" % (label,))
                    else:
                        eval_labels.append(label)
                for key in ("strengths", "weaknesses"):
                    if key in ev and not (is_str_list(ev[key]) and ev[key]):
                        f.error("E-ENV-002", "%s.%s" % (w, key),
                                "expected non-empty array of non-empty strings")
                scores = ev.get("scores")
                if "scores" in ev:
                    if not isinstance(scores, dict):
                        f.error("E-ENV-002", w + ".scores", "expected object")
                    else:
                        check_keys(scores, SCORE_KEYS, (), w + ".scores", f)
                        for key in SCORE_KEYS:
                            val = scores.get(key)
                            if key in scores and not (
                                isinstance(val, int) and not isinstance(val, bool)
                                and 1 <= val <= 5
                            ):
                                f.error("E-ENV-002", "%s.scores.%s" % (w, key),
                                        "expected integer 1-5, got %r" % (val,))

    ranking = env.get("final_ranking")
    ranking_ok = (
        isinstance(ranking, list) and len(ranking) >= 2
        and all(isinstance(l, str) and LABEL_RE.match(l) for l in ranking)
    )
    if "final_ranking" in env and not ranking_ok:
        f.error("E-ENV-002", where + ".final_ranking",
                "expected array of 2+ single uppercase letters")

    expected = sorted(labels) if labels is not None else sorted(set(eval_labels))
    if eval_labels and (
        sorted(eval_labels) != expected or len(set(eval_labels)) != len(eval_labels)
    ):
        f.error("E-REV-001", where + ".evaluations",
                "labels %s must cover each issued label exactly once (issued: %s)"
                % (sorted(eval_labels), expected))
    if ranking_ok and sorted(ranking) != expected:
        f.error("E-REV-002", where + ".final_ranking",
                "%s is not a permutation of the issued labels %s" % (ranking, expected))


def validate_synthesis(env, f, where="synthesis"):
    if not check_common(env, "synthesis", where, f):
        return
    check_keys(env, ("protocol", "stage", "chairman", "answer_md", "consensus",
                     "disputes", "confidence"), ("dissent_note",), where, f)
    if "chairman" in env and env.get("chairman") != "council-chairman":
        f.error("E-ENV-002", where + ".chairman",
                "expected 'council-chairman', got %r" % (env.get("chairman"),))
    answer = env.get("answer_md")
    if "answer_md" in env:
        if not (isinstance(answer, str) and answer.strip()):
            f.error("E-ENV-002", where + ".answer_md", "expected non-empty string")
        elif len(answer) < 200:
            f.warn("W-ENV-101", where + ".answer_md",
                   "suspiciously short (%d chars)" % len(answer))
    if "consensus" in env and not is_str_list(env["consensus"]):
        f.error("E-ENV-002", where + ".consensus",
                "expected array of non-empty strings")
    disputes = env.get("disputes")
    if "disputes" in env:
        if not isinstance(disputes, list):
            f.error("E-ENV-002", where + ".disputes", "expected array")
        else:
            for i, d in enumerate(disputes):
                w = "%s.disputes[%d]" % (where, i)
                if not isinstance(d, dict):
                    f.error("E-ENV-002", w, "expected object")
                    continue
                check_keys(d, ("topic", "positions"), (), w, f)
                for key in ("topic", "positions"):
                    if key in d and not (isinstance(d[key], str) and d[key].strip()):
                        f.error("E-ENV-002", "%s.%s" % (w, key),
                                "expected non-empty string")
    if "dissent_note" in env and not isinstance(env.get("dissent_note"), str):
        f.error("E-ENV-002", where + ".dissent_note", "expected string")
    check_confidence(env, where, f)


ENVELOPE_VALIDATORS = {
    "opinion": lambda env, f, seat, labels: validate_opinion(env, f, seat=seat),
    "review": lambda env, f, seat, labels: validate_review(env, f, seat=seat, labels=labels),
    "synthesis": lambda env, f, seat, labels: validate_synthesis(env, f),
}


def load_json(path, f, code="E-IO-001"):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError) as exc:
        f.error(code, path, "cannot read/parse JSON: %s" % exc)
        return None


def compute_aggregate(review_envelopes, label_map):
    """Expected aggregate ranking per references/evaluation.md."""
    positions = {}
    for env in review_envelopes:
        for pos, label in enumerate(env.get("final_ranking", []), start=1):
            positions.setdefault(label, []).append(pos)
    rows = []
    for label, pos_list in positions.items():
        mean = Fraction(sum(pos_list), len(pos_list))
        rows.append({
            "label": label,
            "member": label_map.get(label),
            "mean_exact": mean,
            "mean_rank": round(float(mean), 2),
            "first_places": sum(1 for p in pos_list if p == 1),
            "rankings_count": len(pos_list),
        })
    rows.sort(key=lambda r: (r["mean_exact"], -r["first_places"], r["label"]))
    return rows


def audit_run(run_dir, f):
    run_dir = run_dir.rstrip("/")
    manifest_path = os.path.join(run_dir, "manifest.json")
    for rel in ("README.md", "00-question.md", "manifest.json",
                "01-opinions", "02-reviews", "03-synthesis", "envelopes"):
        if not os.path.exists(os.path.join(run_dir, rel)):
            f.error("E-RUN-001", rel, "required run path missing")
    man = load_json(manifest_path, f) if os.path.exists(manifest_path) else None
    if man is None:
        return
    if not isinstance(man, dict):
        f.error("E-RUN-002", "manifest.json", "manifest must be a JSON object")
        return

    # --- manifest scalar fields ---
    if man.get("protocol") != PROTOCOL:
        f.error("E-RUN-002", "manifest.protocol",
                "expected %r, got %r" % (PROTOCOL, man.get("protocol")))
    run_id = man.get("run_id")
    if not (isinstance(run_id, str) and RUN_ID_RE.match(run_id)):
        f.error("E-RUN-002", "manifest.run_id", "invalid run_id %r" % (run_id,))
    elif os.path.basename(os.path.abspath(run_dir)) != run_id:
        f.error("E-RUN-002", "manifest.run_id",
                "run_id %r does not match directory name %r"
                % (run_id, os.path.basename(os.path.abspath(run_dir))))
    if not (isinstance(man.get("question"), str) and man.get("question").strip()):
        f.error("E-RUN-002", "manifest.question", "expected non-empty string")
    provider = man.get("provider")
    if not (isinstance(provider, dict)
            and isinstance(provider.get("harness"), str)
            and isinstance(provider.get("model"), str)):
        f.error("E-RUN-002", "manifest.provider",
                "expected object with string 'harness' and 'model'")
    seats = man.get("seats")
    if not (isinstance(seats, list) and len(seats) >= 2
            and len(set(seats)) == len(seats)
            and all(isinstance(s, str) and SEAT_RE.match(s) for s in seats)):
        f.error("E-RUN-002", "manifest.seats", "expected 2+ unique seat names")
        seats = []
    validation = man.get("validation")
    if not (isinstance(validation, dict)
            and validation.get("final_run_check") in ("pending", "pass", "fail", "manual")
            and is_str_list(validation.get("notes", []))):
        f.error("E-RUN-002", "manifest.validation",
                "expected object with final_run_check in "
                "{pending,pass,fail,manual} and notes: string array")

    # --- label map ---
    label_map = man.get("label_map")
    labels = []
    if not isinstance(label_map, dict):
        f.error("E-RUN-004", "manifest.label_map", "expected object")
        label_map = {}
    else:
        labels = sorted(label_map.keys())
        expected_labels = list(string.ascii_uppercase[: len(labels)])
        if labels != expected_labels:
            f.error("E-RUN-004", "manifest.label_map",
                    "labels %s must be consecutive from 'A'" % labels)
        values = list(label_map.values())
        if len(set(values)) != len(values) or not all(v in seats for v in values):
            f.error("E-RUN-004", "manifest.label_map",
                    "values must be unique and belong to manifest.seats")

    stages = man.get("stages")
    if not isinstance(stages, dict):
        f.error("E-RUN-002", "manifest.stages", "expected object")
        return

    # --- stage 1: opinions ---
    opinions = stages.get("opinions")
    successful_opinions = 0
    if not isinstance(opinions, list):
        f.error("E-RUN-002", "manifest.stages.opinions", "expected array")
    else:
        members = [o.get("member") for o in opinions if isinstance(o, dict)]
        if seats and sorted(members) != sorted(seats):
            f.error("E-RUN-002", "manifest.stages.opinions",
                    "must hold exactly one entry per configured seat")
        for o in opinions:
            if not isinstance(o, dict):
                f.error("E-RUN-002", "manifest.stages.opinions", "entry must be object")
                continue
            member, label = o.get("member"), o.get("label")
            status, env_rel = o.get("status"), o.get("envelope")
            where = "manifest.stages.opinions[%s]" % member
            if status not in STATUSES:
                f.error("E-RUN-002", where + ".status", "invalid status %r" % (status,))
                continue
            if status in SUCCESS:
                successful_opinions += 1
                if label not in label_map or label_map.get(label) != member:
                    f.error("E-RUN-006", where + ".label",
                            "label %r inconsistent with label_map" % (label,))
                if not isinstance(env_rel, str):
                    f.error("E-RUN-005", where + ".envelope", "missing envelope path")
                else:
                    env_path = os.path.join(run_dir, env_rel)
                    if not os.path.exists(env_path):
                        f.error("E-RUN-005", env_rel, "envelope file missing")
                    else:
                        env = load_json(env_path, f)
                        if env is not None:
                            validate_opinion(env, f, seat=member, where=env_rel)
                if isinstance(label, str) and isinstance(member, str):
                    md_rel = os.path.join("01-opinions", "%s-%s.md" % (label, member))
                    if not os.path.exists(os.path.join(run_dir, md_rel)):
                        f.error("E-RUN-001", md_rel, "opinion markdown artifact missing")
            else:
                f.warn("W-RUN-102", where, "seat failed Stage 1 and was excluded")
                if label is not None or env_rel is not None:
                    f.error("E-RUN-006", where,
                            "failed entry must have null label and envelope")
    if successful_opinions < 2:
        f.error("E-RUN-003", "manifest.stages.opinions",
                "quorum not met: %d successful opinions (need 2)" % successful_opinions)
    if successful_opinions != len(label_map):
        f.error("E-RUN-004", "manifest.label_map",
                "%d labels for %d successful opinions"
                % (len(label_map), successful_opinions))

    # --- stage 2: reviews ---
    reviews = stages.get("reviews")
    review_envelopes = []
    if not isinstance(reviews, list):
        f.error("E-RUN-002", "manifest.stages.reviews", "expected array")
    else:
        reviewers = [r.get("reviewer") for r in reviews if isinstance(r, dict)]
        if seats and sorted(reviewers) != sorted(seats):
            f.error("E-RUN-002", "manifest.stages.reviews",
                    "must hold exactly one entry per configured seat "
                    "(Stage 1 failures still review)")
        for r in reviews:
            if not isinstance(r, dict):
                f.error("E-RUN-002", "manifest.stages.reviews", "entry must be object")
                continue
            reviewer, status, env_rel = r.get("reviewer"), r.get("status"), r.get("envelope")
            where = "manifest.stages.reviews[%s]" % reviewer
            if status not in STATUSES:
                f.error("E-RUN-002", where + ".status", "invalid status %r" % (status,))
                continue
            if status in SUCCESS:
                if not isinstance(env_rel, str):
                    f.error("E-RUN-005", where + ".envelope", "missing envelope path")
                    continue
                env_path = os.path.join(run_dir, env_rel)
                if not os.path.exists(env_path):
                    f.error("E-RUN-005", env_rel, "envelope file missing")
                    continue
                env = load_json(env_path, f)
                if env is not None:
                    validate_review(env, f, seat=reviewer, labels=labels, where=env_rel)
                    review_envelopes.append(env)
                md_rel = os.path.join("02-reviews", "review-by-%s.md" % reviewer)
                if not os.path.exists(os.path.join(run_dir, md_rel)):
                    f.error("E-RUN-001", md_rel, "review markdown artifact missing")
            else:
                f.warn("W-RUN-102", where, "seat failed Stage 2 and was excluded")
                if env_rel is not None:
                    f.error("E-RUN-006", where, "failed entry must have null envelope")
        if review_envelopes and not os.path.exists(
            os.path.join(run_dir, "02-reviews", "rankings.md")
        ):
            f.error("E-RUN-001", "02-reviews/rankings.md",
                    "aggregate rankings artifact missing")

    # --- aggregate ranking ---
    stored = stages.get("aggregate_ranking")
    if not isinstance(stored, list):
        f.error("E-RUN-002", "manifest.stages.aggregate_ranking", "expected array")
    else:
        expected = compute_aggregate(review_envelopes, label_map)
        if not review_envelopes:
            f.warn("W-RUN-101", "manifest.stages.reviews",
                   "degraded run: zero successful reviews")
            if stored:
                f.error("E-RUN-007", "manifest.stages.aggregate_ranking",
                        "must be empty when no reviews succeeded")
        elif len(stored) != len(expected):
            f.error("E-RUN-007", "manifest.stages.aggregate_ranking",
                    "has %d rows, recomputation gives %d" % (len(stored), len(expected)))
        else:
            for i, (s, e) in enumerate(zip(stored, expected)):
                where = "manifest.stages.aggregate_ranking[%d]" % i
                if not isinstance(s, dict):
                    f.error("E-RUN-007", where, "entry must be object")
                    continue
                mismatches = []
                if s.get("label") != e["label"]:
                    mismatches.append("label %r != %r" % (s.get("label"), e["label"]))
                if s.get("member") != e["member"]:
                    mismatches.append("member %r != %r" % (s.get("member"), e["member"]))
                mean = s.get("mean_rank")
                if not (isinstance(mean, (int, float)) and not isinstance(mean, bool)
                        and abs(mean - float(e["mean_exact"])) <= 0.005 + 1e-9):
                    mismatches.append("mean_rank %r != %s" % (mean, e["mean_rank"]))
                for key in ("first_places", "rankings_count"):
                    if s.get(key) != e[key]:
                        mismatches.append("%s %r != %r" % (key, s.get(key), e[key]))
                if mismatches:
                    f.error("E-RUN-007", where, "; ".join(mismatches))

    # --- stage 3: synthesis ---
    synthesis = stages.get("synthesis")
    if not isinstance(synthesis, dict):
        f.error("E-RUN-002", "manifest.stages.synthesis", "expected object")
    else:
        status, env_rel = synthesis.get("status"), synthesis.get("envelope")
        if status not in SUCCESS:
            f.error("E-RUN-008", "manifest.stages.synthesis",
                    "synthesis status is %r; run has no final answer" % (status,))
        else:
            if not isinstance(env_rel, str):
                f.error("E-RUN-005", "manifest.stages.synthesis.envelope",
                        "missing envelope path")
            else:
                env_path = os.path.join(run_dir, env_rel)
                if not os.path.exists(env_path):
                    f.error("E-RUN-005", env_rel, "envelope file missing")
                else:
                    env = load_json(env_path, f)
                    if env is not None:
                        validate_synthesis(env, f, where=env_rel)
            if not os.path.exists(os.path.join(run_dir, "03-synthesis", "final-answer.md")):
                f.error("E-RUN-001", "03-synthesis/final-answer.md",
                        "final answer artifact missing")


def report(f, as_json):
    result = "fail" if f.errors else "pass"
    if as_json:
        print(json.dumps({
            "result": result,
            "errors": len(f.errors),
            "warnings": len(f.warnings),
            "findings": [
                {"level": lvl, "code": code, "where": where, "message": msg}
                for lvl, code, where, msg in f.items
            ],
        }, indent=2))
    else:
        for lvl, code, where, msg in f.items:
            print("%s %s %s: %s" % (lvl, code, where, msg))
        print("RESULT: %s (%d errors, %d warnings)"
              % (result.upper(), len(f.errors), len(f.warnings)))
    return 1 if f.errors else 0


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="validate.py",
        description="llmcouncil envelope gate + run auditor (protocol llmcouncil/v1). "
                    "Stdlib only; error codes documented in references/evaluation.md.",
    )
    parser.add_argument("--json", action="store_true",
                        help="emit findings as a single JSON object")
    sub = parser.add_subparsers(dest="command", required=True)

    p_env = sub.add_parser("envelope", help="gate a single response envelope")
    p_env.add_argument("--stage", required=True,
                       choices=("opinion", "review", "synthesis"))
    p_env.add_argument("--seat", help="requested seat name to cross-check")
    p_env.add_argument("--labels",
                       help="comma-separated issued labels (review stage), e.g. A,B,C")
    p_env.add_argument("file", help="path to the envelope JSON file")

    p_run = sub.add_parser("run", help="audit a complete run directory")
    p_run.add_argument("dir", help="path to .llmcouncil/<run_id>/")

    args = parser.parse_args(argv)
    f = Findings()

    if args.command == "envelope":
        labels = None
        if args.labels:
            labels = [l.strip() for l in args.labels.split(",") if l.strip()]
            if not all(LABEL_RE.match(l) for l in labels):
                parser.error("--labels must be single uppercase letters, e.g. A,B,C")
        if not os.path.exists(args.file):
            print("validate.py: file not found: %s" % args.file, file=sys.stderr)
            return 2
        env = load_json(args.file, f)
        if env is not None:
            ENVELOPE_VALIDATORS[args.stage](env, f, args.seat, labels)
    else:
        if not os.path.isdir(args.dir):
            print("validate.py: not a directory: %s" % args.dir, file=sys.stderr)
            return 2
        audit_run(args.dir, f)

    return report(f, args.json)


if __name__ == "__main__":
    sys.exit(main())
