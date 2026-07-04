#!/usr/bin/env bash
# Architecture checks for the go-modularization skill. Mirrors ../SKILL.md.
set -u

usage() {
  cat <<'EOF'
Usage: bash scripts/arch-checks.sh [--format text|json] [--json] [--output FILE]
                                   [--baseline FILE] [--help]

Validate a Go repo against the go-modularization layout rules. Run from the
repo root. Non-interactive, read-only: takes no repo input, mutates nothing,
prompts for nothing (safe to retry; idempotent).

Options:
  --format text|json  Output format (default: text).
  --json              Shorthand for --format json.
  --output FILE       Write the report to FILE instead of stdout ("-" = stdout).
  --baseline FILE     Ratchet against FILE, a previous run's --json report.
  -h, --help          Show this help.

Ratchet semantics (--baseline): a violation whose exact check+detail pair
appears in FILE is "standing" — still listed (text: a separate "## Standing
violations (baseline)" section; json: an additive "standing" array plus
summary.standing, both present only when the flag is given) — but only NEW
violations fail the run. Keep FILE checked in; regenerate it (without
--baseline) only as standing violations get fixed, so the baseline shrinks
and never grows.

Prerequisites: bash, find, awk. Go toolchain optional — build/vet/import
checks are skipped (NOTE on stderr) when neither go.mod nor go.work is at the
root; folder and migration checks still run.

Checks: forbidden folder names; forbidden top-level config/middleware/events/
messages; go build + go vet (module dirs with zero .go files are skipped);
module topology (single root go.mod, or go.work with every module dir
registered under `use`; orphan multi-module flagged); nine import invariants
(layer->adapter, inner->generated-contracts, cross-service internal,
kernel<->contracts, contracts->business, go-pkgs->internal, adapter->adapter,
imports-cmd); one cmd/main.go per service (services with no non-test .go
files — non-Go services — are skipped); no Go under scripts/; migration
filename grammar + up/down pairing (a grammar-failing file with a script
extension under migrations/ is flagged misplaced-script instead);
promotion-threshold counts grouped per context stem (report-only heuristic
grouping — confirm the context before promoting; never fails the run);
streaming adapter files over ~400 LOC (`streaming-file-loc`, report-only);
exported Transition/CanTransitionTo under a domain/ dir with no non-test
call site outside it and no *_conformance_test.go exercising it
(`decorative-state-machine`, report-only).

Output: structured report on stdout (text or json). Diagnostics on stderr.
Detail lists are capped at 100 entries; exact counts are always in the summary.
Report-only findings render under "## Report-only findings" (text) and an
always-present "warnings" array + summary.warnings (json); like promotion
candidates, they never affect the exit code and are never baselined.

Exit codes: 0 = clean (with --baseline: no new violations), 1 = one or more
violations (with --baseline: one or more new violations), 2 = bad usage
(including a missing or unreadable --baseline FILE), 3 = missing prerequisite
(awk/find).
EOF
}

FORMAT=text
OUT="-"
BASELINE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --json) FORMAT=json ;;
    --format) shift; FORMAT="${1:-}";;
    --output) shift; OUT="${1:-}";;
    --baseline) shift; BASELINE="${1:-}"
                [ -n "$BASELINE" ] || { echo "Error: --baseline requires a FILE argument" >&2; exit 2; } ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done
case "$FORMAT" in text|json) :;; *) printf 'Error: --format must be text or json, got "%s"\n' "$FORMAT" >&2; exit 2;; esac
if [ -n "$BASELINE" ] && { [ ! -f "$BASELINE" ] || [ ! -r "$BASELINE" ]; }; then
  printf 'Error: --baseline file "%s" is missing or unreadable\n' "$BASELINE" >&2; exit 2
fi
command -v awk  >/dev/null 2>&1 || { echo "Error: awk not found (required)"  >&2; exit 3; }
command -v find >/dev/null 2>&1 || { echo "Error: find not found (required)" >&2; exit 3; }

diag() { printf '%s\n' "$*" >&2; }   # diagnostics → stderr

# Violations accumulate as TSV "check<TAB>detail" lines; warnings (report-only,
# never affect the exit code, never baselined) use the same TSV shape;
# promotions are report-only plain lines.
violations=""
warnings=""
promotions=""
add_v() { violations+="$1"$'\t'"$2"$'\n'; }
add_w() { warnings+="$1"$'\t'"$2"$'\n'; }
add_p() { promotions+="$1"$'\n'; }

# 1. Forbidden folder names anywhere (vendor/.git/node_modules pruned).
while IFS= read -r d; do [ -n "$d" ] && add_v "forbidden-folder" "$d"; done < <(
  find . \( -path ./vendor -o -path ./.git -o -name node_modules \) -prune -o -type d \( \
    -name pkg -o -name shared -o -name common -o -name lib -o -name utils \
    -o -name helpers -o -name mapper -o -name dto -o -name gateway -o -name workers \
    -o -name misc -o -name application -o -name infrastructure -o -name interfaces \) -print)

# 1b. Forbidden config/middleware/events/messages at repo root or service root.
for d in config middleware events messages; do
  [ -d "$d" ] && add_v "forbidden-top-level" "./$d"
  for svc in services/*/; do
    [ -d "${svc}${d}" ] && add_v "forbidden-service-root" "${svc}${d}"
  done
done

# Go-toolchain checks need a root module (go.mod) or a workspace (go.work).
have_mod=0;  [ -f go.mod ]  && have_mod=1
have_work=0; [ -f go.work ] && have_work=1
run_go=0; { [ "$have_mod" -eq 1 ] || [ "$have_work" -eq 1 ]; } && run_go=1
[ "$run_go" -eq 0 ] && diag "NOTE: no go.mod or go.work at root — skipping build/vet/import checks"

# `use` directives from go.work (empty under single-module).
uses=""
[ "$have_work" -eq 1 ] && uses=$(awk '
  /^[[:space:]]*use[[:space:]]*\(/  {blk=1; next}
  blk && /\)/                        {blk=0; next}
  blk                                {p=$1; sub(/^\.\//,"",p); sub(/\/+$/,"",p); if(p!="")print p; next}
  /^[[:space:]]*use[[:space:]]/      {p=$2; sub(/^\.\//,"",p); sub(/\/+$/,"",p); if(p!="")print p}
' go.work)

# Module dirs to scan with the go toolchain. Workspace: the use-dirs (a non-
# module root can't run `go ./...`). Single-module: the root.
scan_dirs=""
if [ "$have_work" -eq 1 ]; then scan_dirs=$(printf '%s\n' "$uses")
elif [ "$have_mod" -eq 1 ]; then scan_dirs="."
fi

# 2. Build and vet, per module dir (diagnostics to stderr; verdict is the violation).
#    Module dirs containing zero .go files (asset-only modules) are skipped.
if [ "$run_go" -eq 1 ]; then
  for d in $scan_dirs; do
    [ -n "$(find "$d" \( -name vendor -o -name node_modules \) -prune -o -name '*.go' -print -quit 2>/dev/null)" ] || continue
    ( cd "$d" && go build ./... ) >/dev/null 2>&1 || add_v "go-build" "go build ./... failed in $d (rerun: cd $d && go build ./...)"
    ( cd "$d" && go vet ./...   ) >/dev/null 2>&1 || add_v "go-vet"   "go vet ./... failed in $d (rerun: cd $d && go vet ./...)"
  done
fi

# 3. Module topology: single root go.mod (A), or a go.work registering every
#    module (B). Multiple go.mod without a go.work = orphan modules (forbidden).
gomods=$(find . \( -path ./vendor -o -path ./.git -o -name node_modules \) -prune -o -name go.mod -print)
nmods=$(printf '%s\n' "$gomods" | grep -c .)
if [ "$have_work" -eq 1 ]; then
  # Every go.mod dir must be listed under `use` in go.work.
  while IFS= read -r gm; do
    [ -z "$gm" ] && continue
    d=$(dirname "$gm"); d=${d#./}; [ -z "$d" ] && d="."
    printf '%s\n' "$uses" | grep -qx "$d" || add_v "module-not-in-workspace" "$gm (dir '$d' absent from go.work use)"
  done <<EOF
$gomods
EOF
else
  [ "$nmods" -gt 1 ] && add_v "orphan-modules" "$nmods go.mod files but no root go.work — use one root go.mod (A) or a go.work (B)"
fi

# 4. Import invariants — `go list ./...` per module dir, analyzed by awk. Keyed
#    on each package's on-disk Dir (relative to repo root), so the checks are
#    identical under single-module (A) and multi-module workspace (B) topologies.
if [ "$run_go" -eq 1 ]; then
  root=$(pwd)
  dump=$(for d in $scan_dirs; do ( cd "$d" && go list -f '{{.ImportPath}}{{"\t"}}{{.Dir}}{{"\t"}}{{join .Imports " "}}' ./... 2>/dev/null ); done)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    check="${line%%$'\t'*}"; detail="${line#*$'\t'}"
    add_v "$check" "$detail"
  done < <(printf '%s\n' "$dump" | awk -F'\t' -v root="$root" '
    function svc(p,   s){ if (!match(p, /(^|\/)services\//)) return ""; s = substr(p, RSTART+RLENGTH); sub(/\/.*/, "", s); return s }
    function adapter(p,   a){ if(p !~ "/(api|consumer|cli|grpc|ws|sse|graphql|data_repositories|external_services|producer|storage)(/|$)") return ""; a=p; sub(".*/(internal/)?","",a); sub("/.*","",a); return a }   # known limitation: last-segment extraction treats promoted provider subfolders as the adapter identity
    {
      ip=$1; rel=$2; sub("^"root"/","",rel); sub("^"root"$","",rel)
      relOf[ip]=rel; impsOf[ip]=$3; order[++cnt]=ip
    }
    END {
      for(k=1;k<=cnt;k++){
        ip=order[k]; ipr=relOf[ip]; ips=svc(ipr); ipa=adapter(ipr)
        inner = (ipr ~ "/(domain|interactor|ports)(/|$)")
        n=split(impsOf[ip], imps, " ")
        for(i=1;i<=n;i++){
          im=imps[i]; if(!(im in relOf)) continue   # only in-repo packages are keys
          imr=relOf[im]; ims=svc(imr); ima=adapter(imr)
          if (inner && imr ~ "/(api|consumer|cli|grpc|ws|sse|graphql|data_repositories|external_services|producer|storage)(/|$)") print "layer-imports-adapter\t"ipr" -> "imr
          if (inner && imr ~ "(^|/)contracts/(.*/)?v[0-9]+(/|$)") print "inner-imports-contracts\t"ipr" -> "imr
          if (ips!="" && ims!="" && ips!=ims && imr ~ "/internal(/|$)") print "cross-service-internal\t"ipr" -> "imr
          if (ipr ~ "(^|/)internal/kernel(/|$)" && imr ~ "(^|/)internal/contracts(/|$)") print "kernel-imports-contracts\t"ipr" -> "imr
          if (ipr ~ "(^|/)internal/contracts(/|$)" && imr ~ "(^|/)internal/kernel(/|$)") print "contracts-imports-kernel\t"ipr" -> "imr
          if (ipr ~ "(^|/)internal/contracts(/|$)" && imr ~ "/(domain|interactor|ports|api|consumer|cli|data_repositories|external_services|producer|storage)(/|$)") print "contracts-imports-business\t"ipr" -> "imr
          if (ipr ~ "(^|/)go-pkgs/" && imr ~ "(^|/)(internal|services)(/|$)") print "go-pkgs-imports-internal\t"ipr" -> "imr
          if (ipa!="" && ima!="" && ips==ims && ipa!=ima) print "adapter-imports-adapter\t"ipr" -> "imr
          if (imr ~ "(^|/)cmd(/|$)") print "imports-cmd\t"ipr" -> "imr
        }
      }
    }')
fi

# 5. Exactly one main.go per service; it must live at cmd/main.go. Services
#    with zero non-test .go files (non-Go services) are skipped.
for svc in services/*/; do
  [ -d "$svc" ] || continue
  [ -n "$(find "$svc" \( -name vendor -o -name node_modules \) -prune -o \
            -name '*.go' ! -name '*_test.go' -print -quit 2>/dev/null)" ] || continue
  n=$(find "$svc" \( -name vendor -o -name node_modules \) -prune -o -name main.go -print | wc -l)
  if [ "$n" -ne 1 ] || [ ! -f "${svc}cmd/main.go" ]; then
    add_v "bad-main" "$svc expected exactly one main.go at cmd/main.go (found $n)"
  fi
done

# 6. No Go files under scripts/ (bash/python/sql only).
while IFS= read -r f; do [ -n "$f" ] && add_v "go-under-scripts" "$f"; done < <(
  find . \( -path ./vendor -o -path ./.git \) -prune -o -path '*/scripts/*' -name '*.go' -print)

# 7. Migration filename grammar (closed verb set).
verbs='(create|add|drop|alter|rename|backfill|fix|refactor|seed)'
sql_re="^[0-9]{3,}_([a-z][a-z0-9]*_)?${verbs}_[a-z0-9_]+\.(up|down)\.sql\$"
fwd_re="^[0-9]{3,}_([a-z][a-z0-9]*_)?${verbs}_[a-z0-9_]+\.[a-z0-9]+\$"
if [ -d migrations ]; then
  while IFS= read -r f; do
    base=$(basename "$f")
    case "$base" in
      *.up.sql|*.down.sql) echo "$base" | grep -Eq "$sql_re" || add_v "bad-migration-name" "$f" ;;
      *.sql)               add_v "bad-migration-name" "$f (bare .sql: missing .up/.down)" ;;
      *) # Grammar first: a name matching fwd_re is a valid forward-only
         # migration whatever its extension. Only grammar failures carrying a
         # script extension are misplaced scripts, not bad migration names.
         if ! echo "$base" | grep -Eq "$fwd_re"; then
           case "$base" in
             *.sh|*.bash|*.zsh|*.py|*.rb|*.pl|*.js|*.ts|*.mjs|*.cjs|*.ps1)
               add_v "misplaced-script" "$f (scripts do not live under migrations/)" ;;
             *) add_v "bad-migration-name" "$f" ;;
           esac
         fi ;;
    esac
  done < <(find migrations -type f)
  while IFS= read -r f; do
    case "$f" in
      *.up.sql)   [ -f "${f%.up.sql}.down.sql" ] || add_v "unpaired-migration" "$f (missing .down.sql)" ;;
      *.down.sql) [ -f "${f%.down.sql}.up.sql" ] || add_v "unpaired-migration" "$f (missing .up.sql)" ;;
    esac
  done < <(find migrations -name '*.up.sql' -o -name '*.down.sql')
fi

# 8. Promotion audit (report-only): per-(dir, context-stem) groups at/above the
#    >=10 threshold. SKILL.md's counting rule fixes the exclusions and the
#    thresholds but no grouping dimension, so the stem grouping is a labeled
#    heuristic: strip .go; strip a leading layer prefix (interactor_|
#    repository_|storage_|middleware_); strip a trailing role suffix (_port|
#    _handler[_vN]|_consumer|_producer|_command|_translation); the stem is the
#    first _-separated token of what remains.
while IFS= read -r d; do
  while IFS= read -r line; do [ -n "$line" ] && add_p "$line"; done < <(
    find "$d" -maxdepth 1 -name '*.go' \
        ! -name '*_test.go' ! -name '*.pb.go' ! -name '*_gen.go' 2>/dev/null \
    | awk -F/ -v dir="$d" '
        { b=$NF; sub(/\.go$/,"",b)
          sub(/^(interactor|repository|storage|middleware)_/,"",b)
          sub(/(_port|_handler(_v[0-9]+)?|_consumer|_producer|_command|_translation)$/,"",b)
          split(b, t, "_"); if(t[1]=="") next
          if(!(t[1] in c)) ord[++no]=t[1]
          c[t[1]]++ }
        END { for(i=1;i<=no;i++){ s=ord[i]; if(c[s]>=10)
                printf "%s context \047%s\047: %d countable files (heuristic — confirm context grouping before promoting)\n", dir, s, c[s] } }')
done < <(find services internal go-pkgs \( -name vendor -o -name node_modules \) -prune -o -type d -print 2>/dev/null)

# 8b. Streaming adapter LOC audit (report-only warning): one non-test,
#     non-generated file above the threshold means the stream adapter should
#     split by responsibility.
STREAM_LOC_MAX=400
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$(awk 'END{print NR+0}' "$f")
  [ "$n" -gt "$STREAM_LOC_MAX" ] && add_w "streaming-file-loc" "$f ($n lines > $STREAM_LOC_MAX — split by responsibility, see placement-rules streaming section)"
done < <(
  find . \( -path ./vendor -o -path ./.git -o -name node_modules \) -prune -o \
    -type f -name '*.go' ! -name '*_test.go' ! -name '*.pb.go' ! -name '*_gen.go' \
    \( -path '*/grpc/*' -o -path '*/ws/*' -o -path '*/sse/*' \) -print)

# 8c. Decorative state machine audit (report-only warning): an exported
#     Transition/CanTransitionTo declared in a domain/ dir needs a call site
#     that proves an enforcement locus — a non-test .go file outside that
#     domain dir, or a *_conformance_test.go anywhere (the sanctioned
#     conformance-oracle naming; ordinary _test.go files never count).
#     Zero such call sites → the table is decorative (placement-rules
#     "State machines: one enforcement locus").
dsm_dirs=""
while IFS= read -r dd; do
  [ -n "$dd" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if grep -Eq '^func (\([^)]*\) )?(Transition|CanTransitionTo)\(' "$f" 2>/dev/null; then
      dsm_dirs+="$dd"$'\n'
      break
    fi
  done < <(find "$dd" \( -name vendor -o -name node_modules \) -prune -o \
             -type f -name '*.go' ! -name '*_test.go' -print 2>/dev/null)
done < <(find . \( -name vendor -o -path ./.git -o -name node_modules \) -prune -o \
           -type d -name domain -print 2>/dev/null)
if [ -n "$dsm_dirs" ]; then
  # One repo walk for candidate call sites: a .Transition( / .CanTransitionTo(
  # occurrence on a non-comment line, in non-test .go files plus
  # *_conformance_test.go files.
  dsm_callers=$(find . \( -name vendor -o -path ./.git -o -name node_modules \) -prune -o \
      -type f -name '*.go' \( ! -name '*_test.go' -o -name '*_conformance_test.go' \) -print 2>/dev/null \
    | while IFS= read -r f; do
        grep -E '\.(Transition|CanTransitionTo)\(' "$f" 2>/dev/null \
          | grep -Evq '^[[:space:]]*//' && printf '%s\n' "$f"
      done)
  while IFS= read -r dd; do
    [ -n "$dd" ] || continue
    hit=""
    while IFS= read -r cf; do
      [ -n "$cf" ] || continue
      case "$cf" in
        *_conformance_test.go) hit=1; break ;;   # oracle counts anywhere, incl. inside a domain dir
        */domain/*) ;;                           # calls from ANY domain dir are self-validation, not an enforcement locus
        *) hit=1; break ;;
      esac
    done < <(printf '%s\n' "$dsm_callers")
    [ -n "$hit" ] || add_w "decorative-state-machine" "$dd defines Transition/CanTransitionTo with no non-test call sites outside domain/ (heuristic — declare one enforcement locus + conformance test, or delete; see placement-rules)"
  done < <(printf '%s\n' "$dsm_dirs")
fi

# 9. Ratchet (--baseline): partition current violations into NEW vs STANDING.
#    The baseline is a previous run's --json report; membership is the exact
#    check+detail pair, compared in the escaped form render_json emits (esc()
#    escapes only \ and ", so a value's closing quote is the first " after an
#    even number of backslashes). Every "check"/"detail" object in FILE counts
#    (violations and standing alike, so a ratcheted report re-baselines
#    faithfully); baseline pairs absent from the current run are simply gone.
#    Only NEW violations feed the failure verdict; promotions are unaffected.
standing=""
if [ -n "$BASELINE" ]; then
  part=$(printf '%s' "$violations" | awk -F'\t' -v basefile="$BASELINE" '
    function esc(s){gsub(/\\/,"\\\\",s);gsub(/"/,"\\\"",s);return s}
    # Scan the JSON string value starting at s[1], keeping escapes as written;
    # sets EP to the index of the closing quote.
    function jscan(s,   i,c,out){
      out=""; i=1
      while (i <= length(s)) {
        c=substr(s,i,1)
        if (c=="\\") { out=out c substr(s,i+1,1); i+=2; continue }
        if (c=="\"") { EP=i; return out }
        out=out c; i++
      }
      EP=i; return out
    }
    BEGIN{
      while ((getline l < basefile) > 0) buf=buf l "\n"
      close(basefile)
      s=buf
      while ((p=index(s, "{\"check\":\"")) > 0) {
        s=substr(s, p+10); ck=jscan(s); s=substr(s, EP+1)
        if (substr(s,1,11) != ",\"detail\":\"") continue
        s=substr(s,12); dt=jscan(s); s=substr(s, EP+1)
        base[ck "\t" dt]=1
      }
    }
    /./ { key=esc($1)"\t"esc($2); if (key in base) print "S\t"$0; else print "N\t"$0 }
  ')
  violations=$(printf '%s\n' "$part" | awk -F'\t' '$1=="N"{print substr($0,3)}')
  standing=$(printf '%s\n' "$part"  | awk -F'\t' '$1=="S"{print substr($0,3)}')
fi

# --- Render report -------------------------------------------------------------
vcount=$(printf '%s' "$violations" | grep -c . || true)
scount=$(printf '%s' "$standing"   | grep -c . || true)
wcount=$(printf '%s' "$warnings"   | grep -c . || true)
pcount=$(printf '%s' "$promotions" | grep -c . || true)
CAP=100

render_text() {
  echo "# go-modularization arch-checks"
  if [ -n "$BASELINE" ]; then
    echo "violations: $vcount (new)   standing (baseline): $scount   warnings: $wcount   promotion-candidates: $pcount"
  else
    echo "violations: $vcount   warnings: $wcount   promotion-candidates: $pcount"
  fi
  if [ "$vcount" -gt 0 ]; then
    echo
    echo "## Violations"
    printf '%s' "$violations" | grep . | head -n "$CAP" | awk -F'\t' '{printf "- %s: %s\n", $1, $2}'
    [ "$vcount" -gt "$CAP" ] && echo "- ... and $((vcount - CAP)) more (use --json --output FILE for the full list)"
  fi
  if [ "$scount" -gt 0 ]; then
    echo
    echo "## Standing violations (baseline)"
    printf '%s' "$standing" | grep . | head -n "$CAP" | awk -F'\t' '{printf "- %s: %s\n", $1, $2}'
    [ "$scount" -gt "$CAP" ] && echo "- ... and $((scount - CAP)) more"
  fi
  if [ "$wcount" -gt 0 ]; then
    echo
    echo "## Report-only findings"
    printf '%s' "$warnings" | grep . | head -n "$CAP" | awk -F'\t' '{printf "- %s: %s\n", $1, $2}'
    [ "$wcount" -gt "$CAP" ] && echo "- ... and $((wcount - CAP)) more"
  fi
  if [ "$pcount" -gt 0 ]; then
    echo
    echo "## Promotion candidates (report-only)"
    printf '%s' "$promotions" | grep . | head -n "$CAP" | awk '{printf "- %s\n", $0}'
    [ "$pcount" -gt "$CAP" ] && echo "- ... and $((pcount - CAP)) more"
  fi
}

render_json() {
  local vj pj sj wj trunc
  vj=$(printf '%s' "$violations" | grep . | head -n "$CAP" \
    | awk -F'\t' 'function esc(s){gsub(/\\/,"\\\\",s);gsub(/"/,"\\\"",s);return s}
        {printf "%s{\"check\":\"%s\",\"detail\":\"%s\"}", (NR>1?",":""), esc($1), esc($2)}')
  wj=$(printf '%s' "$warnings" | grep . | head -n "$CAP" \
    | awk -F'\t' 'function esc(s){gsub(/\\/,"\\\\",s);gsub(/"/,"\\\"",s);return s}
        {printf "%s{\"check\":\"%s\",\"detail\":\"%s\"}", (NR>1?",":""), esc($1), esc($2)}')
  pj=$(printf '%s' "$promotions" | grep . | head -n "$CAP" \
    | awk 'function esc(s){gsub(/\\/,"\\\\",s);gsub(/"/,"\\\"",s);return s}
        {printf "%s\"%s\"", (NR>1?",":""), esc($0)}')
  if [ -n "$BASELINE" ]; then
    # Additive schema: "standing" + summary.standing appear only with --baseline.
    sj=$(printf '%s' "$standing" | grep . | head -n "$CAP" \
      | awk -F'\t' 'function esc(s){gsub(/\\/,"\\\\",s);gsub(/"/,"\\\"",s);return s}
          {printf "%s{\"check\":\"%s\",\"detail\":\"%s\"}", (NR>1?",":""), esc($1), esc($2)}')
    if [ "$vcount" -gt "$CAP" ] || [ "$scount" -gt "$CAP" ] || [ "$wcount" -gt "$CAP" ] || [ "$pcount" -gt "$CAP" ]; then trunc=true; else trunc=false; fi
    printf '{"summary":{"violations":%d,"standing":%d,"warnings":%d,"promotion_candidates":%d,"truncated":%s},"violations":[%s],"standing":[%s],"warnings":[%s],"promotion_candidates":[%s]}\n' \
      "$vcount" "$scount" "$wcount" "$pcount" "$trunc" "$vj" "$sj" "$wj" "$pj"
  else
    if [ "$vcount" -gt "$CAP" ] || [ "$wcount" -gt "$CAP" ] || [ "$pcount" -gt "$CAP" ]; then trunc=true; else trunc=false; fi
    printf '{"summary":{"violations":%d,"warnings":%d,"promotion_candidates":%d,"truncated":%s},"violations":[%s],"warnings":[%s],"promotion_candidates":[%s]}\n' \
      "$vcount" "$wcount" "$pcount" "$trunc" "$vj" "$wj" "$pj"
  fi
}

if [ "$FORMAT" = json ]; then report=$(render_json); else report=$(render_text); fi
if [ "$OUT" = "-" ] || [ -z "$OUT" ]; then printf '%s\n' "$report"; else printf '%s\n' "$report" > "$OUT"; diag "report written to $OUT"; fi

[ "$vcount" -gt 0 ] && exit 1
exit 0
