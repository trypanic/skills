#!/usr/bin/env bash
#
# traceflow invariants suite.
#
# Smoke tests for structural integrity of a traceflow-managed tree.
# Run from the repository root, or set TRACEFLOW_DIR to point at the
# traceflow outcome directory (default: .traceflow).
#
# Usage:
#   bash invariants.sh                       # full sweep
#   bash invariants.sh --area amazon         # restrict to one area
#   bash invariants.sh --invariant 3         # run only invariant 3
#
# Exit code 0 = all pass. Non-zero = drift detected.
#
# This script is read-only. It NEVER edits files. It only reports.

set -u

TF_DIR="${TRACEFLOW_DIR:-.traceflow}"
AREA_FILTER=""
INVARIANT_FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --area) AREA_FILTER="$2"; shift 2 ;;
    --invariant) INVARIANT_FILTER="$2"; shift 2 ;;
    -h|--help)
      sed -n '3,17p' "$0"
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ ! -d "$TF_DIR" ]; then
  echo "FATAL: traceflow directory not found: $TF_DIR" >&2
  echo "set TRACEFLOW_DIR or run from the repository root" >&2
  exit 2
fi

PASS=0
FAIL=0
FAILED_NAMES=()

ok()   { echo "[PASS] $1"; PASS=$((PASS+1)); }
bad()  { echo "[FAIL] $1"; FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); }
info() { echo "       $1"; }

want() {
  # want N name  -> returns 0 if invariant N should run
  if [ -z "$INVARIANT_FILTER" ] || [ "$INVARIANT_FILTER" = "$1" ]; then
    return 0
  fi
  return 1
}

areas() {
  # list of area folders under domain/, filtered if --area is set
  if [ -n "$AREA_FILTER" ]; then
    if [ -d "$TF_DIR/domain/$AREA_FILTER" ]; then
      echo "$AREA_FILTER"
    fi
    return
  fi
  find "$TF_DIR/domain" -maxdepth 1 -mindepth 1 -type d \
    ! -name '_shared' -exec basename {} \; 2>/dev/null
}

#
# Invariant 1: every S0NN in any STATUS.md resolves to a real spec folder.
#
inv_1_status_specs_exist() {
  want 1 || return 0
  local name="1. STATUS.md references resolve to spec folders"
  local missing=0
  for f in $(find "$TF_DIR" -name 'STATUS.md' 2>/dev/null); do
    local area
    area="$(echo "$f" | sed -n 's|.*/specs/\([^/]*\)/STATUS.md|\1|p')"
    [ -z "$area" ] && continue
    for sid in $(grep -oE 'S[0-9]+' "$f" | sort -u); do
      if [ ! -d "$TF_DIR/specs/$area/$sid"* ] 2>/dev/null \
         && [ ! -d "$TF_DIR/specs/$area/archive/$sid"* ] 2>/dev/null; then
        info "missing: $sid referenced in $f"
        missing=$((missing+1))
      fi
    done
  done
  if [ $missing -eq 0 ]; then ok "$name"; else bad "$name ($missing missing)"; fi
}

#
# Invariant 2: ADR numbers are monotonic with no gaps or duplicates.
#
inv_2_adr_numbering() {
  want 2 || return 0
  local name="2. ADR numbers monotonic, no gaps, no duplicates"
  local nums dups gaps
  nums=$(find "$TF_DIR/decisions" -name 'ADR-*.md' 2>/dev/null \
    | grep -oE 'ADR-[0-9]+' | sort -u)
  if [ -z "$nums" ]; then
    ok "$name (no ADRs yet)"
    return 0
  fi
  dups=$(find "$TF_DIR/decisions" -name 'ADR-*.md' 2>/dev/null \
    | grep -oE 'ADR-[0-9]+' | sort | uniq -d)
  if [ -n "$dups" ]; then
    bad "$name (duplicates: $(echo $dups | tr '\n' ' '))"
    return 0
  fi
  local last=0
  gaps=""
  while read -r n; do
    [ -z "$n" ] && continue
    local val
    val=$(echo "$n" | sed 's/ADR-0*//')
    [ -z "$val" ] && val=0
    if [ $last -gt 0 ] && [ $((val - last)) -gt 1 ]; then
      gaps="$gaps $((last+1))..$((val-1))"
    fi
    last=$val
  done <<< "$nums"
  if [ -n "$gaps" ]; then
    bad "$name (gaps:$gaps)"
  else
    ok "$name"
  fi
}

#
# Invariant 3: no two active specs claim the same Owns path.
#
inv_3_owns_uniqueness() {
  want 3 || return 0
  local name="3. Active specs have unique Owns paths"
  local tmpfile
  tmpfile=$(mktemp)
  for area in $(areas); do
    local active_plans
    active_plans=$(find "$TF_DIR/specs/$area" -mindepth 2 -maxdepth 2 \
      -name 'plan.md' -not -path '*/archive/*' 2>/dev/null)
    for plan in $active_plans; do
      local spec_id
      spec_id=$(echo "$plan" | sed -n 's|.*/\(S[0-9]\+-[^/]*\)/plan.md|\1|p')
      awk '/^## Owns/{flag=1; next} /^## /{flag=0} flag && /^- /' "$plan" \
        | sed 's/^- *//' \
        | while read -r p; do
            [ -z "$p" ] && continue
            echo "$area:$spec_id:$p" >> "$tmpfile"
          done
    done
  done
  local dups
  dups=$(awk -F: '{print $3}' "$tmpfile" | sort | uniq -d)
  if [ -z "$dups" ]; then
    ok "$name"
  else
    bad "$name"
    while read -r dup; do
      info "conflict on path: $dup"
      grep -F ":$dup" "$tmpfile" | while read -r line; do
        info "  claimed by $line"
      done
    done <<< "$dups"
  fi
  rm -f "$tmpfile"
}

#
# Invariant 4: delta target paths resolve (or are ADDED, or typed-NONE).
#
inv_4_delta_paths_resolve() {
  want 4 || return 0
  local name="4. Delta target paths resolve (active, non-draft specs)"
  local unresolved=0
  for area in $(areas); do
    local active_plans
    active_plans=$(find "$TF_DIR/specs/$area" -mindepth 2 -maxdepth 2 \
      -name 'plan.md' -not -path '*/archive/*' 2>/dev/null)
    for plan in $active_plans; do
      local state
      state=$(grep -h '^state:' "$(dirname "$plan")/status.md" 2>/dev/null | head -1 | awk '{print $2}')
      [ "$state" = "draft" ] && continue
      [ "$state" = "" ] && continue
      awk '/^## Domain impact/{flag=1; next} /^## /{flag=0} flag && /^- (MODIFIED|REMOVED)/' "$plan" \
        | while read -r line; do
            local target
            target=$(echo "$line" | sed -n 's|^- [A-Z]* \([^:#]*\).*|\1|p')
            [ -z "$target" ] && continue
            if [ ! -e "$TF_DIR/$target" ] && [ ! -e "$target" ]; then
              info "unresolved: $target in $plan"
              unresolved=$((unresolved+1))
            fi
          done
    done
  done
  if [ $unresolved -eq 0 ]; then ok "$name"; else bad "$name ($unresolved unresolved)"; fi
}

#
# Invariant 5: no delta or Owns path crosses area boundaries.
#
inv_5_no_boundary_leaks() {
  want 5 || return 0
  local name="5. No boundary leaks in delta or Owns paths"
  local leaks=0
  for area in $(areas); do
    local plans
    plans=$(find "$TF_DIR/specs/$area" -name 'plan.md' 2>/dev/null)
    for plan in $plans; do
      local paths
      paths=$( \
        ( awk '/^## Owns/{flag=1; next} /^## /{flag=0} flag && /^- /' "$plan"; \
          awk '/^## Domain impact/{flag=1; next} /^## /{flag=0} flag && /^- (ADDED|MODIFIED|REMOVED)/' "$plan" \
            | sed -n 's|^- [A-Z]* \([^:#]*\).*|\1|p' ) \
        | sed 's/^- *//' | grep -v '^$' )
      while read -r p; do
        [ -z "$p" ] && continue
        # legal if it starts with this area's name, _shared/, or a recognized top-level (services/, migrations/, etc.)
        case "$p" in
          "$area"/*|"domain/$area/"*|"decisions/$area/"*|"specs/$area/"*) ;;
          "_shared/"*|"domain/_shared/"*|"decisions/_shared/"*) ;;
          "services/"*|"migrations/"*|"go-pkgs/"*|"internal/"*) ;;
          *)
            info "boundary leak: $p in $plan"
            leaks=$((leaks+1))
            ;;
        esac
      done <<< "$paths"
    done
  done
  if [ $leaks -eq 0 ]; then ok "$name"; else bad "$name ($leaks leaks)"; fi
}

#
# Invariant 6: every ADR has a mandatory type: frontmatter from the enum.
#
inv_6_adr_type_enum() {
  want 6 || return 0
  local name="6. ADR type: field present and from enum"
  local enum_re='^(stack|structure|policy|operational|contract|security|data|conventions-adopted)$'
  local bad_count=0
  for adr in $(find "$TF_DIR/decisions" -name 'ADR-*.md' 2>/dev/null); do
    local t
    t=$(awk '/^---/{f++; next} f==1 && /^type:/{print $2}' "$adr" | head -1 | tr -d ' "')
    if [ -z "$t" ]; then
      info "missing type: in $adr"
      bad_count=$((bad_count+1))
    elif ! echo "$t" | grep -qE "$enum_re"; then
      info "invalid type '$t' in $adr"
      bad_count=$((bad_count+1))
    fi
  done
  if [ $bad_count -eq 0 ]; then ok "$name"; else bad "$name ($bad_count invalid)"; fi
}

#
# Run all invariants.
#
echo "traceflow invariants: dir=$TF_DIR area=${AREA_FILTER:-all}"
echo

inv_1_status_specs_exist
inv_2_adr_numbering
inv_3_owns_uniqueness
inv_4_delta_paths_resolve
inv_5_no_boundary_leaks
inv_6_adr_type_enum

echo
echo "summary: $PASS pass, $FAIL fail"

if [ $FAIL -gt 0 ]; then
  echo "failed: ${FAILED_NAMES[*]}"
  exit 1
fi
exit 0
