#!/usr/bin/env bash
# Config checks for the moon-proto-monorepo skill. Mirrors ../SKILL.md.
# Read-only: takes no repo input, mutates nothing, prompts for nothing.
set -u

usage() {
  cat <<'EOF'
Usage: bash scripts/moon-checks.sh [--format text|json] [--json] [--output FILE] [--help]

Validate a moon v2 + proto monorepo against the moon-proto-monorepo rules. Run
from the repo root (the directory containing .moon/). Non-interactive, idempotent.

Options:
  --format text|json  Output format (default: text).
  --json              Shorthand for --format json.
  --output FILE       Write the report to FILE instead of stdout ("-" = stdout).
  -h, --help          Show this help.

Prerequisites: bash, find, awk. `moon`/`proto` optional — graph cross-checks are
skipped (NOTE on stderr) when absent; all file/grep checks still run.

Checks (each maps to a SKILL.md rule id):
  dead-glob (F2/R1.1)                 a projects glob/source matching zero paths
  undiscovered-project (R1.1/R1.2)    a moon.yml no glob/source covers
  invalid-toolchain-default (F1/R3.2) toolchains.default 'unknown' or out-of-set
  toolchain-not-enabled (R2.2)        default: <id> with no block in toolchains.yml
  v1-key (F8/R3.5)                    type/platform/singular toolchain/project.name
  v1-file (F8)                        .moon/toolchain.yml or .moon/tasks.yml
  invalid-enum (F13/R3.3)             layer/stack/language outside its closed set
  missing-schema (consistency)        $schema in some configs but not all
  malformed-maintainer (R3.4)         maintainers entry not 'Name <email>'
  metadata-gap (R3.4)                 maintainers set on some projects, missing on others
  inline-secret (F7/R6.3)             literal token/password/secret in config
  cache-on-nondeterministic (F5)      cache:true on start/serve/dev/migrate/up/down/watch
  tasks-file-no-inheritedby (F9/R5.2) a .moon/tasks/*.yml (not all.yml) lacking inheritedBy
  plugin-locator (F11/R2.4/2.5)       a [plugins.*] locator with // or a /main/ branch ref
  bogus-env (F12/R2.6)                a known-nonexistent env var (ENABLE_MOON / MOON_OFFLINE)

The locator and env checks sweep both .prototools and any .prototools.<env>
overlay. An overlay re-pointing [env].file without re-declaring any base
explicit [env] key emits an advisory NOTE on stderr (R2.7), not a violation.

Output: structured report on stdout (text|json). Diagnostics on stderr. Detail
lists capped at 100; exact counts in the summary.

Exit codes: 0 = clean, 1 = one or more violations, 2 = bad usage, 3 = missing
prerequisite (awk/find).
EOF
}

FORMAT=text
OUT="-"
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --json) FORMAT=json ;;
    --format) shift; FORMAT="${1:-}";;
    --output) shift; OUT="${1:-}";;
    *) usage >&2; exit 2 ;;
  esac
  shift
done
case "$FORMAT" in text|json) :;; *) printf 'Error: --format must be text or json, got "%s"\n' "$FORMAT" >&2; exit 2;; esac
command -v awk  >/dev/null 2>&1 || { echo "Error: awk not found (required)"  >&2; exit 3; }
command -v find >/dev/null 2>&1 || { echo "Error: find not found (required)" >&2; exit 3; }

diag() { printf '%s\n' "$*" >&2; }
# Violations accumulate as TSV "check<TAB>detail". add_v must always run in the
# top-level shell (never inside a `cmd | while` pipe, which is a subshell) — use
# `done < <(cmd)` process substitution or capture-then-`<<<` so mutations persist.
violations=""
add_v() { violations+="$1"$'\t'"$2"$'\n'; }

WS=".moon/workspace.yml"
TC=".moon/toolchains.yml"
[ -f "$WS" ] || diag "NOTE: $WS not found — workspace checks limited (is this a moon repo root?)"

shopt -s nullglob globstar 2>/dev/null || true

# All project moon.yml files (exclude the .moon/ config dir; include root moon.yml).
projects_files=$(find . \( -path ./.git -o -name node_modules -o -path ./.moon \) -prune -o -name moon.yml -print 2>/dev/null | sed 's#^\./##')

# --- Enabled toolchain ids (block names) from toolchains.yml --------------------
enabled_ids=""
if [ -f "$TC" ]; then
  enabled_ids=$(awk '/^[a-zA-Z_][a-zA-Z0-9_-]*:[[:space:]]*$/ { k=$1; sub(":","",k); if (k!="proto") print k }' "$TC")
fi
is_enabled() { printf '%s\n' "$enabled_ids" | grep -qx "$1"; }

# --- 1. Parse projects globs + sources from workspace.yml ----------------------
globs=""; sources=""
if [ -f "$WS" ]; then
  parsed=$(awk '
    function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); return s }
    function unq(s){ gsub(/^["'"'"']|["'"'"']$/,"",s); return s }
    /^projects:/ { inp=1; insrc=0; next }
    inp && /^[^[:space:]]/ { inp=0 }
    inp {
      if ($0 ~ /^[[:space:]]+globs:/) { insrc=0; next }
      if ($0 ~ /^[[:space:]]+sources:/) { insrc=1; next }
      if ($0 ~ /^[[:space:]]*-[[:space:]]*/) { v=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",v); v=unq(trim(v)); if(v!="") print "G\t"v; next }
      if (insrc && $0 ~ /:/) { p=$0; sub(/^[^:]*:[[:space:]]*/,"",p); p=unq(trim(p)); if(p!="") print "S\t"p }
    }
  ' "$WS")
  globs=$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="G"{print $2}')
  sources=$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="S"{print $2}')
fi

# Expand each glob; flag zero-match. Collect covered dirs for the discovery check.
covered=""
while IFS= read -r g; do
  [ -z "$g" ] && continue
  matches=0
  for p in $g; do [ -e "$p" ] && { matches=1; covered+="${p%/}"$'\n'; }; done
  [ "$matches" -eq 0 ] && add_v "dead-glob" "$WS: glob '$g' matches no path"
done <<< "$globs"
while IFS= read -r s; do
  [ -z "$s" ] && continue
  sp="${s%/}"; [ "$sp" = "" ] && sp="."
  covered+="$sp"$'\n'
  [ -e "$sp" ] || add_v "dead-glob" "$WS: source '$s' points at a missing path"
done <<< "$sources"

# --- 2. Undiscovered projects --------------------------------------------------
if [ -f "$WS" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    d=$(dirname "$f"); d="${d#./}"; [ "$d" = "" ] && d="."
    printf '%s\n' "$covered" | grep -qx "$d" || \
      add_v "undiscovered-project" "$f (dir '$d' not covered by any projects glob/source)"
  done <<< "$projects_files"
fi

# --- 3. Per-project moon.yml checks --------------------------------------------
LAYERS="application automation configuration library scaffolding tool unknown"
STACKS="backend data frontend infrastructure systems unknown"
LANGS="bash batch go javascript php python ruby rust typescript unknown"
in_set() { printf '%s' "$2" | tr ' ' '\n' | grep -qx "$1"; }

schema_present=0; schema_absent=0
maint_present=""; maint_absent=""

while IFS= read -r f; do
  [ -z "$f" ] && continue

  if grep -q '^\$schema:' "$f"; then schema_present=$((schema_present+1)); else schema_absent=$((schema_absent+1)); fi

  # toolchains.default
  td=$(awk '
    /^toolchains:/ {intc=1; next}
    intc && /^[^[:space:]]/ {intc=0}
    intc && /^[[:space:]]+default:/ { v=$2; gsub(/["'"'"']/,"",v); print v; exit }
  ' "$f")
  if [ -n "$td" ]; then
    if [ "$td" = "unknown" ]; then
      add_v "invalid-toolchain-default" "$f: toolchains.default 'unknown' is invalid (use a toolchain id or 'system')"
    elif [ "$td" != "system" ]; then
      if [ -f "$TC" ] && ! is_enabled "$td"; then
        add_v "toolchain-not-enabled" "$f: toolchains.default '$td' has no block in $TC"
      elif [ ! -f "$TC" ]; then
        add_v "toolchain-not-enabled" "$f: toolchains.default '$td' but no $TC exists"
      fi
    fi
  fi

  # enum values
  lay=$(awk -F': *' '/^layer:/{print $2; exit}' "$f" | tr -d '"'\''')
  stk=$(awk -F': *' '/^stack:/{print $2; exit}' "$f" | tr -d '"'\''')
  lng=$(awk -F': *' '/^language:/{print $2; exit}' "$f" | tr -d '"'\''')
  [ -n "$lay" ] && ! in_set "$lay" "$LAYERS" && add_v "invalid-enum" "$f: layer '$lay' not in {$LAYERS}"
  [ -n "$stk" ] && ! in_set "$stk" "$STACKS" && add_v "invalid-enum" "$f: stack '$stk' not in {$STACKS}"
  [ -n "$lng" ] && ! in_set "$lng" "$LANGS" && printf '%s' "$lng" | grep -q '[^a-z0-9-]' && \
    add_v "invalid-enum" "$f: language '$lng' is malformed (lowercase kebab or a known id)"

  # v1 keys
  grep -Eq '^type:' "$f"      && add_v "v1-key" "$f: 'type:' is v1 — use 'layer:'"
  grep -Eq '^platform:' "$f"  && add_v "v1-key" "$f: 'platform:' is v1 — use 'toolchains.default:'"
  grep -Eq '^toolchain:' "$f" && add_v "v1-key" "$f: singular 'toolchain:' is v1 — use 'toolchains:'"
  awk '/^project:/{inp=1;next} inp&&/^[^[:space:]]/{inp=0} inp&&/^[[:space:]]+name:/{print;exit}' "$f" | grep -q . \
    && add_v "v1-key" "$f: 'project.name' is v1 — use 'project.title'"

  # maintainers: presence + format. Capture list items, loop in this shell.
  maint_lines=$(awk '
    /^[[:space:]]*maintainers:/ {inm=1; next}
    inm {
      if ($0 ~ /^[[:space:]]*-/) { print; next }
      if ($0 ~ /^[[:space:]]*[a-zA-Z]/) { inm=0 }
    }
  ' "$f" 2>/dev/null)
  if grep -Eq '^[[:space:]]*maintainers:' "$f"; then
    maint_present+="$f"$'\n'
    while IFS= read -r m; do
      [ -z "$m" ] && continue
      mv=$(printf '%s' "$m" | sed 's/^[[:space:]]*-[[:space:]]*//; s/^["'\'']//; s/["'\'']$//')
      [ -z "$mv" ] && continue
      printf '%s' "$mv" | grep -Eq '.+<[^<>@[:space:]]+@[^<>[:space:]]+>' || \
        add_v "malformed-maintainer" "$f: maintainer '$mv' is not 'Name <email>'"
    done <<< "$maint_lines"
  else
    maint_absent+="$f"$'\n'
  fi

  # inline secrets (literal value, not a $VAR reference)
  sec=$(grep -inE '(token|password|passwd|secret|api[_-]?key|access[_-]?key)["'\'' ]*:[[:space:]]*["'\'']?[A-Za-z0-9/_+:.@-]{6,}' "$f" \
        | grep -ivE ':[[:space:]]*["'\'']?\$' \
        | grep -ivE 'description|title')
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    add_v "inline-secret" "$f: possible inline secret — $(printf '%s' "$hit" | sed 's/^[0-9]*://; s/^[[:space:]]*//' | cut -c1-60)"
  done <<< "$sec"

  # cache:true on a non-deterministic task name. Only keys at the task-indent
  # level (direct children of `tasks:`) are task names — deeper keys like
  # `options:`/`env:` must not overwrite `cur`.
  ndt=$(awk '
    function lead(s){ match(s,/^ */); return RLENGTH }
    /^tasks:/ { intasks=1; tind=-1; next }
    intasks && /^[^ ]/ { intasks=0 }
    intasks {
      if ($0 ~ /^ +[a-zA-Z0-9_-]+:[ ]*$/) {
        ind=lead($0); if (tind<0) tind=ind
        if (ind==tind) { name=$0; sub(/:.*/,"",name); gsub(/ /,"",name); cur=name }
      }
      if ($0 ~ /cache:[ ]*true/ && cur ~ /(^|-)(start|dev|serve|migrate|up|down|watch)(-|$)/) print cur
    }
  ' "$f")
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    add_v "cache-on-nondeterministic" "$f: task '$t' has cache:true but looks non-deterministic"
  done <<< "$ndt"

done <<< "$projects_files"

# $schema consistency (some but not all)
if [ "$schema_present" -gt 0 ] && [ "$schema_absent" -gt 0 ]; then
  add_v "missing-schema" "\$schema set in $schema_present config(s), absent in $schema_absent — standardize (all or none)"
fi

# metadata-gap: maintainers on some projects but missing on others
np=$(printf '%s' "$maint_present" | grep -c . || true)
na=$(printf '%s' "$maint_absent"  | grep -c . || true)
if [ "$np" -gt 0 ] && [ "$na" -gt 0 ]; then
  while IFS= read -r f; do [ -n "$f" ] && add_v "metadata-gap" "$f: no project.maintainers (set on $np other project(s))"; done <<< "$maint_absent"
fi

# --- 4. .moon/tasks/*.yml inheritedBy + v1 files -------------------------------
[ -f .moon/toolchain.yml ] && add_v "v1-file" ".moon/toolchain.yml is v1 — rename to .moon/toolchains.yml"
[ -f .moon/tasks.yml ]     && add_v "v1-file" ".moon/tasks.yml is v1 — move tasks under .moon/tasks/**/* with inheritedBy"
if [ -d .moon/tasks ]; then
  for tf in .moon/tasks/*.yml .moon/tasks/*.yaml; do
    [ -e "$tf" ] || continue
    base=$(basename "$tf")
    case "$base" in all.yml|all.yaml) continue;; esac
    grep -q '^inheritedBy:' "$tf" || \
      add_v "tasks-file-no-inheritedby" "$tf: no inheritedBy — applies to ALL projects (name it all.yml if intended, else scope it)"
  done
fi

# --- 5. .prototools (+ .prototools.<env> overlays): locators + env checks -----
base_env_keys=""
if [ -f .prototools ]; then
  base_env_keys=$(awk '/^\[env\]/{ine=1;next} ine&&/^\[/{ine=0} ine&&/=/{print}' .prototools | sed 's/[[:space:]]*=.*//' | grep -v '^file$')
fi
for pt in .prototools .prototools.*; do
  [ -f "$pt" ] || continue
  plines=$(awk '/^\[plugins/{inp=1;next} inp&&/^\[/{inp=0} inp&&/=/{print}' "$pt")
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    val=$(printf '%s' "$line" | sed 's/^[^=]*=[[:space:]]*//; s/^["'\'']//; s/["'\'']$//')
    printf '%s' "$val" | grep -Eq '://[^/]+//' && add_v "plugin-locator" "$pt: locator '$val' has a double slash"
    printf '%s' "$val" | grep -Eq '(/main/|@main$|/master/|@master$)' && add_v "plugin-locator" "$pt: locator '$val' pins a moving branch — pin a tag/sha"
  done <<< "$plines"

  elines=$(awk '/^\[env\]/{ine=1;next} ine&&/^\[/{ine=0} ine&&/=/{print}' "$pt")
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    key=$(printf '%s' "$line" | sed 's/[[:space:]]*=.*//')
    case "$key" in
      ENABLE_MOON|MOON_OFFLINE) add_v "bogus-env" "$pt [env]: '$key' is not a real moon/proto var — remove it" ;;
    esac
  done <<< "$elines"

  # R2.7 advisory: an overlay re-pointing [env].file while re-declaring NONE of
  # the base's explicit [env] keys — those base values override its dotenv.
  if [ "$pt" != .prototools ] && [ -n "$base_env_keys" ]; then
    okeys=$(printf '%s\n' "$elines" | sed 's/[[:space:]]*=.*//')
    if printf '%s\n' "$okeys" | grep -qx 'file'; then
      redeclared=0
      while IFS= read -r k; do
        [ -z "$k" ] && continue
        printf '%s\n' "$okeys" | grep -qx "$k" && { redeclared=1; break; }
      done <<< "$base_env_keys"
      [ "$redeclared" -eq 0 ] && diag "NOTE: $pt re-points [env].file but re-declares no base explicit [env] key ($(printf '%s' "$base_env_keys" | tr '\n' ' ')) — explicit base keys OVERRIDE the overlay's dotenv (R2.7)"
    fi
  fi
done

# --- advisory notes -----------------------------------------------------------
command -v moon  >/dev/null 2>&1 || diag "NOTE: moon not on PATH — project graph verified by glob expansion only"
command -v proto >/dev/null 2>&1 || diag "NOTE: proto not on PATH — pinned-vs-installed check skipped"

# --- Render -------------------------------------------------------------------
vcount=$(printf '%s' "$violations" | grep -c . || true)
CAP=100

render_text() {
  echo "# moon-proto-monorepo checks"
  echo "violations: $vcount"
  if [ "$vcount" -gt 0 ]; then
    echo; echo "## Violations"
    printf '%s' "$violations" | grep . | head -n "$CAP" | awk -F'\t' '{printf "- %s: %s\n", $1, $2}'
    [ "$vcount" -gt "$CAP" ] && echo "- ... and $((vcount - CAP)) more (use --json --output FILE)"
  fi
}
render_json() {
  local vj
  vj=$(printf '%s' "$violations" | grep . | head -n "$CAP" \
    | awk -F'\t' 'function esc(s){gsub(/\\/,"\\\\",s);gsub(/"/,"\\\"",s);return s}
        {printf "%s{\"check\":\"%s\",\"detail\":\"%s\"}", (NR>1?",":""), esc($1), esc($2)}')
  local trunc=false; [ "$vcount" -gt "$CAP" ] && trunc=true
  printf '{"summary":{"violations":%d,"truncated":%s},"violations":[%s]}\n' "$vcount" "$trunc" "$vj"
}

if [ "$FORMAT" = json ]; then report=$(render_json); else report=$(render_text); fi
if [ "$OUT" = "-" ] || [ -z "$OUT" ]; then printf '%s\n' "$report"; else printf '%s\n' "$report" > "$OUT"; diag "report written to $OUT"; fi

[ "$vcount" -gt 0 ] && exit 1
exit 0
