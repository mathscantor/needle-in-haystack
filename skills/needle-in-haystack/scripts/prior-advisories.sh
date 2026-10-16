#!/usr/bin/env bash
# Compact summary of prior security advisories and security-looking commits
# for the repository in the current directory.
#
# Usage: prior-advisories.sh [owner/repo] [--ecosystem ECO --package NAME] [--limit N]
#   owner/repo   GitHub repo; defaults to the `origin` remote of the cwd repo.
#   --ecosystem  OSV ecosystem (npm, PyPI, Go, crates.io, Maven, RubyGems, NuGet, Packagist, ...)
#   --package    Package name in that ecosystem.
#   --limit      Max lines per section (default 40).
#
# Needs bash, curl, git. Uses `gh` (authenticated) when present, and jq or python3 for JSON.
set -uo pipefail

repo=""
ecosystem=""
package=""
limit=40

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ecosystem) ecosystem="${2:-}"; shift 2 ;;
    --package) package="${2:-}"; shift 2 ;;
    --limit) limit="${2:-40}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) repo="$1"; shift ;;
  esac
done

if [[ -z "$repo" ]] && git rev-parse --git-dir >/dev/null 2>&1; then
  url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/]+)$ ]]; then
    repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
  fi
fi

json_tool=""
if command -v jq >/dev/null 2>&1; then json_tool="jq"
elif command -v python3 >/dev/null 2>&1; then json_tool="python3"
fi

# Prints "ID | severity | CVE | summary | patched: versions" per advisory from a GitHub advisories JSON array.
format_ghsa() {
  case "$json_tool" in
    jq)
      jq -r '
        if type == "array" then .[] else empty end
        | [ .ghsa_id,
            (.severity // "?"),
            (.cve_id // "-"),
            ((.summary // "") | gsub("[\r\n]+"; " ")),
            ("patched: " + ([.vulnerabilities[]?.patched_versions // empty] | unique | join(", ")))
          ] | join(" | ")' ;;
    python3)
      python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(data, list):
    sys.exit(0)
for a in data:
    patched = sorted({v.get("patched_versions") for v in a.get("vulnerabilities") or [] if v.get("patched_versions")})
    summary = " ".join((a.get("summary") or "").split())
    print(" | ".join([a.get("ghsa_id", "?"), a.get("severity") or "?", a.get("cve_id") or "-", summary, "patched: " + ", ".join(patched)]))
' ;;
    *) grep -oE '"(ghsa_id|cve_id|summary)": *"[^"]*"' ;;
  esac
}

# Prints "ID | aliases | summary" per vuln from an OSV query response.
format_osv() {
  case "$json_tool" in
    jq)
      jq -r '.vulns[]? | [ .id, ((.aliases // []) | join(",")), ((.summary // .details // "") | gsub("[\r\n]+"; " ") | .[0:160]) ] | join(" | ")' ;;
    python3)
      python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for v in data.get("vulns") or []:
    text = " ".join((v.get("summary") or v.get("details") or "").split())[:160]
    print(" | ".join([v.get("id", "?"), ",".join(v.get("aliases") or []), text]))
' ;;
    *) grep -oE '"(id|summary)": *"[^"]*"' ;;
  esac
}

fetch_ghsa() {
  local endpoint="repos/$repo/security-advisories?per_page=100&state=published"
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh api "$endpoint" 2>/dev/null && return 0
  fi
  local auth=()
  [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  curl -fsSL ${auth[@]+"${auth[@]}"} -H "Accept: application/vnd.github+json" "https://api.github.com/$endpoint" 2>/dev/null
}

echo "## GitHub security advisories${repo:+ ($repo)}"
if [[ -z "$repo" ]]; then
  echo "(skipped: pass owner/repo or run inside a repo with a GitHub origin remote)"
else
  out="$(fetch_ghsa | format_ghsa | head -n "$limit")"
  if [[ -n "$out" ]]; then echo "$out"; else echo "(none found or API unavailable)"; fi
fi
echo

if [[ -n "$ecosystem" && -n "$package" ]]; then
  echo "## OSV advisories ($ecosystem/$package)"
  body="{\"package\":{\"name\":\"$package\",\"ecosystem\":\"$ecosystem\"}}"
  out="$(curl -fsSL -X POST -H 'Content-Type: application/json' -d "$body" https://api.osv.dev/v1/query 2>/dev/null | format_osv | head -n "$limit")"
  if [[ -n "$out" ]]; then echo "$out"; else echo "(none found or API unavailable)"; fi
  echo
fi

echo "## Security-looking commits"
if git rev-parse --git-dir >/dev/null 2>&1; then
  pattern='CVE-[0-9]|GHSA-|security|vulnerab|exploit|bypass|xss|csrf|ssrf|injection|travers|overflow|use.after.free|sanitiz|escap|privilege|authori[sz]|authenticat|bounds'
  out="$(git log --all -i -E --grep="$pattern" --format='%h %ad %s' --date=short 2>/dev/null | head -n "$limit")"
  if [[ -n "$out" ]]; then echo "$out"; else echo "(none)"; fi
  echo
  echo "Next: for each relevant advisory or commit, read the fix (git show <hash>) and hunt for incomplete fixes, sibling paths with the same root cause, and bypasses."
else
  echo "(skipped: not inside a git repository)"
fi
