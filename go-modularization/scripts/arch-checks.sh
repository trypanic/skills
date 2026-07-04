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
imports-cmd) — inner-imports-contracts details are grouped per service and
name the guilty layer (service <svc> layer <ports|interactor|domain>: edge);
one cmd/main.go per service (services with no non-test .go
files — non-Go services — are skipped); no Go under scripts/; serialization
struct tags (db:"/bson:") in non-test .go files under ports/ or domain/
(tags-in-inner-layers — the tagged row/DTO type belongs in the owning
adapter); migration
filename grammar + up/down pairing (a grammar-failing file with a script
extension under migrations/ is flagged misplaced-script instead);
promotion-threshold counts grouped per context stem (report-only heuristic
grouping — confirm the context before promoting; never fails the run);
streaming adapter files over ~400 LOC (`streaming-file-loc`, report-only);
exported Transition/CanTransitionTo under a domain/ dir with no non-test
call site outside it and no *_conformance_test.go exercising it
(`decorative-state-machine`, report-only); cross-service boundary review
(`boundary-review`, report-only heuristics — see
references/service-boundaries.md): the same datastore-identifier string
constant (const name matching table|collection|bucket|queue|topic|index,
case-insensitive) declared in two or more services, and env struct-tag
names (env:"...") sharing an identical suffix after the first _-separated
token across two or more services (possible silent config mirror);
root internal/ occupancy (root-internal-occupancy — any directory child of
root internal/ other than contracts/ and kernel/ is a violation; see
references/shared-code.md); stdlib-shadow names in shared tiers
(stdlib-shadow-name — a directory directly under root internal/ or go-pkgs/,
or a go-pkgs/infra/ child, whose basename equals a Go stdlib package
basename from an embedded representative list; use <name>x / <name>kit);
shared-tier importer count (shared-tier-importer-count, report-only, needs
the go toolchain — each in-repo package under root internal/ or go-pkgs/
with fewer than two distinct importing services, or with no in-repo
importers at all, is warned; shared tiers require >=2 verified importers).

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

# 1c. Root internal/ occupancy: exactly two directory children allowed —
#     contracts/ and kernel/ (shared-code.md "Root internal/"). Files at the
#     internal/ top level (go.mod, go.sum, doc files) never count; only
#     directories violate. vendor/node_modules pruned.
if [ -d internal ]; then
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    case "$(basename "$d")" in contracts|kernel|vendor|node_modules) continue ;; esac
    add_v "root-internal-occupancy" "$d (root internal/ admits only contracts/ and kernel/ — route to go-pkgs/, kernel/, or the owning service)"
  done < <(find internal -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
fi

# 1d. Stdlib-shadow names in shared tiers: a package directory directly under
#     root internal/ or go-pkgs/ (plus go-pkgs/infra/ children) must not take
#     a Go stdlib package's basename — shadowing reads as stdlib at call
#     sites; use <name>x / <name>kit instead (shared-code.md). The embedded
#     list is representative, not exhaustive.
GO_STDLIB_NAMES="slices maps strings errors time context sync io os net http sort math rand fmt log testing bytes bufio path filepath url json xml sql regexp reflect hash crypto tls big list heap ring embed unicode utf8 atomic signal exec user mail smtp template html image color png jpeg gif zip tar gzip zlib flate bzip2 csv base64 hex binary gob pem asn1 aes des rsa sha1 sha256 sha512 md5 hmac rc4 dsa ecdsa ed25519 elliptic x509 pkix bits cmplx iter cmp"
while IFS= read -r d; do
  [ -n "$d" ] || continue
  b=$(basename "$d")
  case " $GO_STDLIB_NAMES " in
    *" $b "*) add_v "stdlib-shadow-name" "$d shadows Go stdlib package \"$b\" — use ${b}x / ${b}kit naming" ;;
  esac
done < <({
  [ -d internal ]      && find internal      -mindepth 1 -maxdepth 1 -type d 2>/dev/null
  [ -d go-pkgs ]       && find go-pkgs       -mindepth 1 -maxdepth 1 -type d 2>/dev/null
  [ -d go-pkgs/infra ] && find go-pkgs/infra -mindepth 1 -maxdepth 1 -type d 2>/dev/null
  true
})

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
#    The awk block emits "check<TAB>detail" violation lines; report-only
#    findings computed from the same import graph (shared-tier-importer-count)
#    are prefixed "W<TAB>" and routed to the warnings channel by the reader.
if [ "$run_go" -eq 1 ]; then
  root=$(pwd)
  dump=$(for d in $scan_dirs; do ( cd "$d" && go list -f '{{.ImportPath}}{{"\t"}}{{.Dir}}{{"\t"}}{{join .Imports " "}}' ./... 2>/dev/null ); done)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      W$'\t'*) rest="${line#W$'\t'}"; add_w "${rest%%$'\t'*}" "${rest#*$'\t'}" ;;
      *)       add_v "${line%%$'\t'*}" "${line#*$'\t'}" ;;
    esac
  done < <(printf '%s\n' "$dump" | awk -F'\t' -v root="$root" '
    function svc(p,   s){ if (!match(p, /(^|\/)services\//)) return ""; s = substr(p, RSTART+RLENGTH); sub(/\/.*/, "", s); return s }
    function layer(p){ if (p ~ "/domain(/|$)") return "domain"; if (p ~ "/interactor(/|$)") return "interactor"; if (p ~ "/ports(/|$)") return "ports"; return "inner" }
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
          if (inner && imr ~ "(^|/)contracts/(.*/)?v[0-9]+(/|$)") { sname=(ips!="" ? ips : "(root)"); iic[++niic]="inner-imports-contracts\tservice " sname " layer " layer(ipr) ": " ipr " -> " imr }
          if (ips!="" && ims!="" && ips!=ims && imr ~ "/internal(/|$)") print "cross-service-internal\t"ipr" -> "imr
          if (ipr ~ "(^|/)internal/kernel(/|$)" && imr ~ "(^|/)internal/contracts(/|$)") print "kernel-imports-contracts\t"ipr" -> "imr
          if (ipr ~ "(^|/)internal/contracts(/|$)" && imr ~ "(^|/)internal/kernel(/|$)") print "contracts-imports-kernel\t"ipr" -> "imr
          if (ipr ~ "(^|/)internal/contracts(/|$)" && imr ~ "/(domain|interactor|ports|api|consumer|cli|data_repositories|external_services|producer|storage)(/|$)") print "contracts-imports-business\t"ipr" -> "imr
          if (ipr ~ "(^|/)go-pkgs/" && imr ~ "(^|/)(internal|services)(/|$)") print "go-pkgs-imports-internal\t"ipr" -> "imr
          if (ipa!="" && ima!="" && ips==ims && ipa!=ima) print "adapter-imports-adapter\t"ipr" -> "imr
          if (imr ~ "(^|/)cmd(/|$)") print "imports-cmd\t"ipr" -> "imr
        }
      }
      # inner-imports-contracts is emitted last, sorted (insertion sort — POSIX
      # awk has no builtin), so each service'\''s edges are adjacent in the
      # report. One line per import edge; only the detail text is grouped.
      for(a=2;a<=niic;a++){ t=iic[a]; b=a-1; while(b>=1 && iic[b]>t){ iic[b+1]=iic[b]; b-- } iic[b+1]=t }
      for(a=1;a<=niic;a++) print iic[a]
      # Shared-tier importer count (report-only; "W\t"-prefixed lines go to
      # the warnings channel). Reuses the same in-repo import graph: for each
      # package under ROOT internal/ or go-pkgs/, count distinct consumer
      # classes — one per importing service, plus "root" for any importer
      # outside services/. Fewer than two classes means the shared-tier
      # admission bar (>=2 verified importing services) is not met.
      for(k=1;k<=cnt;k++){
        jp=order[k]; jpr=relOf[jp]
        n=split(impsOf[jp], imps, " ")
        for(i=1;i<=n;i++){
          im=imps[i]; if(!(im in relOf)) continue
          imr=relOf[im]
          if (imr !~ /^internal(\/|$)/ && imr !~ /^go-pkgs(\/|$)/) continue
          cls=svc(jpr); if(cls=="") cls="root"
          nimp[im]++
          if(!((im SUBSEP cls) in seenc)){ seenc[im,cls]=1; ncls[im]++; if(!(im in firstc)) firstc[im]=cls }
        }
      }
      for(k=1;k<=cnt;k++){
        ip=order[k]; ipr=relOf[ip]
        if (ipr !~ /^internal(\/|$)/ && ipr !~ /^go-pkgs(\/|$)/) continue
        if (nimp[ip]+0 == 0)
          print "W\tshared-tier-importer-count\t" ipr " has no in-repo importers (heuristic — dead shared code or external-only; verify)"
        else if (ncls[ip]+0 < 2)
          print "W\tshared-tier-importer-count\t" ipr " has a single importing service (" firstc[ip] ") (heuristic — shared tier requires >=2 verified importers; move into its consumer)"
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

# 6b. No serialization tags in inner layers: a non-test .go file under any
#     ports/ or domain/ path component carrying a db:"/bson:" struct tag holds
#     an adapter row/DTO promoted inward (placement-rules "Port quality").
#     One violation per offending file. json: tags are not flagged (permitted
#     in adapter-local DTOs and contracts/ packages).
while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -Eq '`([^`]*[^[:alnum:]_])?(db|bson):"[^`]*`' "$f" 2>/dev/null \
    && add_v "tags-in-inner-layers" "$f: serialization tag in inner layer (move the tagged row/DTO type to the owning adapter)"
done < <(find . \( -path ./vendor -o -path ./.git -o -name node_modules \) -prune -o \
           -type f -name '*.go' ! -name '*_test.go' \
           \( -path '*/ports/*' -o -path '*/domain/*' \) -print 2>/dev/null)

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

# 8d. Service-boundary review (report-only warnings, both emitted as
#     `boundary-review`; heuristics — see references/service-boundaries.md).
#     Only meaningful with 2+ services, so scoped to services/.
if [ -d services ]; then
  # (a) Cross-service duplicate datastore-identifier constants: a string
  #     constant whose NAME matches table|collection|bucket|queue|topic|index
  #     (case-insensitive) declared with an IDENTICAL literal value in non-test
  #     .go files of two or more services — likely two services reaching into
  #     one datastore (durable-state privacy, service-boundaries rule 1).
  #     Covers single-line `const NAME = "lit"` and names inside const blocks.
  while IFS= read -r line; do
    [ -n "$line" ] && add_w "boundary-review" "$line"
  done < <(
    find services \( -name vendor -o -name node_modules \) -prune -o \
        -type f -name '*.go' ! -name '*_test.go' \
        -exec awk '
          FNR==1 { inblk=0; s=FILENAME; sub(/^(\.\/)?services\//,"",s); sub(/\/.*/,"",s); svc=s }
          /^[[:space:]]*const[[:space:]]*\(/ { inblk=1; next }
          inblk && /^[[:space:]]*\)/ { inblk=0; next }
          {
            if (svc=="") next
            line=$0; ok=0
            if (line ~ /^[[:space:]]*const[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(string[[:space:]]*)?=[[:space:]]*"/) { sub(/^[[:space:]]*const[[:space:]]+/,"",line); ok=1 }
            else if (inblk && line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(string[[:space:]]*)?=[[:space:]]*"/) { sub(/^[[:space:]]*/,"",line); ok=1 }
            if (!ok) next
            name=line; sub(/[[:space:]=].*/,"",name)
            if (tolower(name) !~ /(table|collection|bucket|queue|topic|index)/) next
            val=line; sub(/^[^"]*"/,"",val); sub(/".*/,"",val)
            if (val=="") next
            print val "\t" svc
          }' {} + 2>/dev/null \
    | LC_ALL=C sort -u \
    | awk -F'\t' '
        function flush() { if (cur!="" && n>=2) printf "datastore identifier \"%s\" declared in services %s (heuristic — declare one owner or move to the contract tier; see references/service-boundaries.md)\n", cur, svcs }
        $1!=cur { flush(); cur=$1; n=0; svcs="" }
        { n++; svcs=(svcs=="" ? $2 : svcs " and " $2) }
        END { flush() }'
  )

  # (b) Identically-suffixed env-tag names under different service prefixes:
  #     env:"NAME" struct-tag values whose trailing token sequence after the
  #     first _-separated token is identical across 2+ services — a possible
  #     silent config mirror (service-boundaries rule 2). One warning per
  #     suffix, one example value per service.
  while IFS= read -r line; do
    [ -n "$line" ] && add_w "boundary-review" "$line"
  done < <(
    find services \( -name vendor -o -name node_modules \) -prune -o \
        -type f -name '*.go' ! -name '*_test.go' \
        -exec awk '
          FNR==1 { s=FILENAME; sub(/^(\.\/)?services\//,"",s); sub(/\/.*/,"",s); svc=s }
          {
            if (svc=="") next
            line=$0
            while (match(line, /env:"[^"]+"/)) {
              v=substr(line, RSTART+5, RLENGTH-6)
              print v "\t" svc
              line=substr(line, RSTART+RLENGTH)
            }
          }' {} + 2>/dev/null \
    | LC_ALL=C sort -u \
    | awk -F'\t' '
        {
          full=$1; svc=$2
          p=index(full,"_"); if (p==0) next
          sfx=substr(full,p+1); if (sfx=="") next
          if (!((sfx SUBSEP svc) in seen)) {
            seen[sfx SUBSEP svc]=1; nsvc[sfx]++
            det[sfx]=(det[sfx]=="" ? "" : det[sfx] ", ") svc ": " full
            if (!(sfx in ord)) { ord[sfx]=1; osfx[++no]=sfx }
          }
        }
        END {
          for (i=1;i<=no;i++) { s=osfx[i]; if (nsvc[s]>=2)
            printf "env tag suffix \"%s\" appears under different service prefixes (%s) (heuristic — silent config mirror? declare one owner; see references/service-boundaries.md)\n", s, det[s] }
        }'
  )
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
