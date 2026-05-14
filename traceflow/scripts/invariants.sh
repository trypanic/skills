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
      awk '
        /^## Owns/      {owns=1; paths=0; next}
        /^## /          {owns=0; paths=0; next}
        owns && /^### Paths/ {paths=1; next}
        owns && /^### /      {paths=0; next}
        paths && /^- /
      ' "$plan" \
        | sed 's/^- *//' \
        | while IFS= read -r p; do
            [ -z "$p" ] && continue
            printf '%s\t%s\t%s\n' "$area" "$spec_id" "$p" >> "$tmpfile"
          done
    done
  done
  local dups
  dups=$(awk -F'\t' '{print $3}' "$tmpfile" | sort | uniq -d)
  if [ -z "$dups" ]; then
    ok "$name"
  else
    bad "$name"
    while IFS= read -r dup; do
      info "conflict on path: $dup"
      awk -F'\t' -v d="$dup" '$3 == d {print $1 ":" $2 ":" $3}' "$tmpfile" \
        | while IFS= read -r line; do
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
        ( awk '
            /^## Owns/      {owns=1; paths=0; next}
            /^## /          {owns=0; paths=0; next}
            owns && /^### Paths/ {paths=1; next}
            owns && /^### /      {paths=0; next}
            paths && /^- /
          ' "$plan"; \
          awk '/^## Domain impact/{flag=1; next} /^## /{flag=0} flag && /^- (ADDED|MODIFIED|REMOVED)/' "$plan" \
            | sed -n 's|^- [A-Z]* \([^:#]*\).*|\1|p' ) \
        | sed 's/^- *//' | grep -v '^$' )
      while read -r p; do
        [ -z "$p" ] && continue
        # Area-boundary rule applies ONLY to traceflow-managed paths
        # (domain/, decisions/, specs/, ideas/). Real code/infra paths
        # outside .traceflow/ are not subject to area scoping — "area"
        # is a docs-scoping concept, not a code-scoping concept.
        case "$p" in
          domain/*|decisions/*|specs/*|ideas/*)
            case "$p" in
              "domain/$area/"*|"decisions/$area/"*|"specs/$area/"*|"ideas/$area/"*) ;;
              "domain/_shared/"*|"decisions/_shared/"*|"specs/_shared/"*|"ideas/_shared/"*) ;;
              *)
                info "boundary leak: $p in $plan"
                leaks=$((leaks+1))
                ;;
            esac
            ;;
          *) ;;
        esac
      done <<< "$paths"
    done
  done
  if [ $leaks -eq 0 ]; then ok "$name"; else bad "$name ($leaks leaks)"; fi
}

#
# Helpers for diagram invariants (7-10).
#

# list every diagrams/ directory under domain/, including _shared/
diagram_dirs() {
  if [ -n "$AREA_FILTER" ]; then
    local d="$TF_DIR/domain/$AREA_FILTER/diagrams"
    [ -d "$d" ] && echo "$d"
    return
  fi
  find "$TF_DIR/domain" -mindepth 2 -maxdepth 2 -type d -name 'diagrams' 2>/dev/null
}

# list every fragment file (canonical-owner candidates) across all areas
fragment_files() {
  find "$TF_DIR/domain" -path '*/diagrams/_fragments/F-*.md' 2>/dev/null
}

# list every behavior diagram. Behavior diagrams MUST follow the
# <NN>-<slug>.md convention. We treat files matching 01-* through 98-*
# as behaviors. 00-* is reserved for composites; 99-* for the index.
# Non-numeric files (README, COVERAGE, ad-hoc notes) are ignored — they
# fall outside the diagram axis.
behavior_files() {
  for d in $(diagram_dirs); do
    find "$d" -maxdepth 1 -type f -regextype posix-extended \
      -regex '.*/(0[1-9]|[1-8][0-9]|9[0-8])-[a-z0-9][a-z0-9_-]*\.md' 2>/dev/null
  done
}

# all diagram files including fragments and composites
all_diagram_files() {
  for d in $(diagram_dirs); do
    find "$d" -type f -name '*.md' 2>/dev/null \
      | grep -vE '/(README|99-index)\.md$' || true
    [ -d "$d/_fragments" ] && find "$d/_fragments" -type f -name 'F-*.md' 2>/dev/null
  done
}

# extract every fragment anchor from a diagram file (from both Mermaid notes and Fragments-used block)
# emits one line per anchor: "<fragment-id>\t<step-spec>"
extract_anchors() {
  local file="$1"
  # Mermaid splice markers: lines containing ⟶ F-<slug> §<range>
  # Also from `## Fragments used` block bullets.
  grep -oE '(_shared/)?F-[a-z0-9][a-z0-9_-]*[[:space:]]*§[[:space:]]*[A-Za-z0-9_,-]+' "$file" 2>/dev/null \
    | sed -E 's/[[:space:]]*§[[:space:]]*/\t/' \
    | sort -u
}

# resolve a fragment ID (with optional _shared/ prefix) to its canonical file path
# echoes path on stdout if found, empty otherwise. echoes "AMBIGUOUS" if >1 file.
resolve_fragment() {
  local fid="$1"
  local slug shared_prefix
  case "$fid" in
    _shared/F-*) shared_prefix=1; slug="${fid#_shared/}" ;;
    F-*)         shared_prefix=0; slug="$fid" ;;
    *)           echo ""; return 0 ;;
  esac

  local matches
  if [ "$shared_prefix" = "1" ]; then
    matches=$(find "$TF_DIR/domain/_shared/diagrams/_fragments" -maxdepth 1 -name "${slug}.md" 2>/dev/null)
  else
    matches=$(find "$TF_DIR/domain" -path '*/diagrams/_fragments/*' -name "${slug}.md" 2>/dev/null)
  fi
  local count
  count=$(echo "$matches" | grep -c . 2>/dev/null || echo 0)
  if [ "$count" = "0" ] || [ -z "$matches" ]; then
    echo ""
  elif [ "$count" = "1" ]; then
    echo "$matches"
  else
    echo "AMBIGUOUS"
  fi
}

# expand a step-spec like "S1-S3", "S1,S4", "all" into a list of step numbers
# echoes one step number per line ("all" returns the sentinel ALL)
expand_steps() {
  local spec="$1"
  if [ "$spec" = "all" ]; then
    echo "ALL"
    return
  fi
  # split on commas first, then handle ranges
  local part
  for part in $(echo "$spec" | tr ',' ' '); do
    case "$part" in
      S*-S*)
        local lo hi
        lo=$(echo "$part" | sed -nE 's/^S([0-9]+)-S[0-9]+$/\1/p')
        hi=$(echo "$part" | sed -nE 's/^S[0-9]+-S([0-9]+)$/\1/p')
        if [ -n "$lo" ] && [ -n "$hi" ]; then
          seq "$lo" "$hi"
        fi
        ;;
      S*)
        echo "$part" | sed -nE 's/^S([0-9]+)$/\1/p'
        ;;
    esac
  done
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
# Invariant 7: every F-<slug> §<range> anchor resolves to a real ### SN heading
# in the canonical fragment file.
#
inv_7_anchors_resolve() {
  want 7 || return 0
  local name="7. Fragment anchors resolve to real step headings"
  local unresolved=0
  local diag
  for diag in $(behavior_files); do
    [ -z "$diag" ] && continue
    while IFS=$'\t' read -r fid spec; do
      [ -z "$fid" ] && continue
      local path
      path=$(resolve_fragment "$fid")
      if [ -z "$path" ]; then
        info "no canonical owner for $fid (referenced in $diag)"
        unresolved=$((unresolved+1))
        continue
      fi
      if [ "$path" = "AMBIGUOUS" ]; then
        # invariant 8 reports this in detail; skip here
        continue
      fi
      if [ "$spec" = "all" ]; then
        continue
      fi
      local step
      for step in $(expand_steps "$spec"); do
        [ "$step" = "ALL" ] && continue
        [ -z "$step" ] && continue
        if ! grep -qE "^### S${step}\." "$path"; then
          info "$fid §S$step does not resolve in $path (referenced in $diag)"
          unresolved=$((unresolved+1))
        fi
      done
    done < <(extract_anchors "$diag")
  done
  if [ $unresolved -eq 0 ]; then ok "$name"; else bad "$name ($unresolved unresolved anchors)"; fi
}

#
# Invariant 8: each fragment ID exists in exactly one file (single canonical owner).
#
inv_8_fragment_uniqueness() {
  want 8 || return 0
  local name="8. Fragment IDs have a single canonical owner"
  local tmpfile
  tmpfile=$(mktemp)
  local f basename slug
  for f in $(fragment_files); do
    basename=$(basename "$f" .md)
    printf '%s\t%s\n' "$basename" "$f" >> "$tmpfile"
  done
  local dups
  dups=$(awk -F'\t' '{print $1}' "$tmpfile" | sort | uniq -d)
  if [ -z "$dups" ]; then
    ok "$name"
  else
    bad "$name"
    local dup
    while IFS= read -r dup; do
      [ -z "$dup" ] && continue
      info "duplicate fragment: $dup"
      awk -F'\t' -v d="$dup" '$1 == d {print "  " $2}' "$tmpfile" \
        | while IFS= read -r line; do
            info "$line"
          done
    done <<< "$dups"
  fi
  rm -f "$tmpfile"
}

#
# Invariant 9: cross-area fragment references resolve only under
# domain/_shared/diagrams/_fragments/.
#
inv_9_cross_area_fragments() {
  want 9 || return 0
  local name="9. Cross-area fragment refs scoped to _shared/"
  local leaks=0
  local diag
  for diag in $(behavior_files); do
    [ -z "$diag" ] && continue
    # determine this diagram's area
    local area
    area=$(echo "$diag" | sed -nE 's|.*/domain/([^/]+)/diagrams/.*|\1|p')
    [ -z "$area" ] && continue
    while IFS=$'\t' read -r fid spec; do
      [ -z "$fid" ] && continue
      case "$fid" in
        _shared/F-*) continue ;;            # explicitly shared — fine
        F-*) ;;                             # area-local reference
        *) continue ;;
      esac
      # for area-local refs, check the fragment is owned by THIS area's bucket
      local matches
      matches=$(find "$TF_DIR/domain/$area/diagrams/_fragments" -maxdepth 1 -name "${fid}.md" 2>/dev/null)
      if [ -z "$matches" ]; then
        # not in this area — is it elsewhere (cross-area leak) or absent?
        local elsewhere
        elsewhere=$(find "$TF_DIR/domain" -path "*/diagrams/_fragments/${fid}.md" 2>/dev/null)
        if [ -n "$elsewhere" ]; then
          info "cross-area leak: $diag references $fid, owned by $elsewhere"
          info "  (move to domain/_shared/diagrams/_fragments/ and reference as _shared/$fid, OR copy into area $area)"
          leaks=$((leaks+1))
        fi
      fi
    done < <(extract_anchors "$diag")
  done
  if [ $leaks -eq 0 ]; then ok "$name"; else bad "$name ($leaks cross-area leaks)"; fi
}

#
# Invariant 10: every behavior diagram has a `## Fragments used` block.
#
inv_10_fragments_used_block() {
  want 10 || return 0
  local name="10. Behavior diagrams have ## Fragments used block"
  local missing=0
  local diag
  for diag in $(behavior_files); do
    [ -z "$diag" ] && continue
    if ! grep -qE '^## Fragments used' "$diag"; then
      info "missing ## Fragments used in $diag"
      missing=$((missing+1))
    fi
  done
  if [ $missing -eq 0 ]; then ok "$name"; else bad "$name ($missing missing)"; fi
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
inv_7_anchors_resolve
inv_8_fragment_uniqueness
inv_9_cross_area_fragments
inv_10_fragments_used_block

echo
echo "summary: $PASS pass, $FAIL fail"

if [ $FAIL -gt 0 ]; then
  echo "failed: ${FAILED_NAMES[*]}"
  exit 1
fi
exit 0
