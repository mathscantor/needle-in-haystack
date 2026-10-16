#!/usr/bin/env bash
# Install the needle-in-haystack skill into one or more AI coding agents.
#
# Usage: ./install.sh [options]
#   --tools LIST       auto (default) | all | comma list of:
#                      claude, codex, opencode, cursor, deepseek, trae
#   --scope SCOPE      global (default, user-wide) | project
#   --project-dir DIR  project root for --scope project (default: cwd)
#   --link             symlink instead of copy (updates with `git pull`)
#   --force            overwrite an existing directory not created by this installer
#   --uninstall        remove the skill from the selected tools
#   --dry-run          print what would happen without changing anything
#   -h, --help         show this help
#
# Remote (no checkout):
#   curl -fsSL https://raw.githubusercontent.com/mathscantor/needle-in-haystack/main/install.sh | bash
# Env: NEEDLE_REPO_URL  optional git URL override for that remote install.
set -euo pipefail

SKILL_NAME="needle-in-haystack"
DEFAULT_REPO_URL="https://github.com/mathscantor/needle-in-haystack.git"
ALL_TOOLS="claude codex opencode cursor deepseek trae"

tools_arg="auto"
scope="global"
project_dir="$PWD"
mode="copy"
force=0
action="install"
dry_run=0

usage() { sed -n '2,17p' "${BASH_SOURCE[0]:-$0}" | sed 's/^# \{0,1\}//'; }
die() { echo "error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tools) tools_arg="${2:-}"; shift 2 ;;
    --tools=*) tools_arg="${1#*=}"; shift ;;
    --scope) scope="${2:-}"; shift 2 ;;
    --scope=*) scope="${1#*=}"; shift ;;
    --project-dir) project_dir="${2:-}"; shift 2 ;;
    --project-dir=*) project_dir="${1#*=}"; shift ;;
    --link) mode="link"; shift ;;
    --force) force=1; shift ;;
    --uninstall) action="uninstall"; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
done

[[ "$scope" == "global" || "$scope" == "project" ]] || die "--scope must be global or project"

run() {
  if [[ $dry_run -eq 1 ]]; then echo "  [dry-run] $*"; else "$@"; fi
}

# Locate the skill source: this checkout, or a shallow clone of the GitHub repo.
script_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
src="${script_dir:+$script_dir/skills/$SKILL_NAME}"
if [[ "$action" == "install" && ( -z "$src" || ! -f "$src/SKILL.md" ) ]]; then
  [[ "$mode" == "copy" ]] || die "--link needs a local checkout"
  repo_url="${NEEDLE_REPO_URL:-$DEFAULT_REPO_URL}"
  command -v git >/dev/null 2>&1 || die "git is required to install from a URL"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  # stdin is the script when invoked via `curl | bash`; keep git off it.
  git clone --depth 1 --quiet "$repo_url" "$tmp/repo" </dev/null || die "clone failed: $repo_url"
  src="$tmp/repo/skills/$SKILL_NAME"
  [[ -f "$src/SKILL.md" ]] || die "skills/$SKILL_NAME/SKILL.md not found in $repo_url"
fi

has_cmd() { command -v "$1" >/dev/null 2>&1; }

detect_tools() {
  local found=()
  { [[ -d "$HOME/.claude" ]] || has_cmd claude; } && found+=(claude)
  { [[ -d "$HOME/.codex" ]] || has_cmd codex; } && found+=(codex)
  { [[ -d "$HOME/.config/opencode" ]] || has_cmd opencode; } && found+=(opencode)
  { [[ -d "$HOME/.cursor" ]] || has_cmd cursor || has_cmd cursor-agent; } && found+=(cursor)
  { [[ -d "$HOME/.dsh" ]] || has_cmd dsh; } && found+=(deepseek)
  { [[ -d "$HOME/.trae" || -d "$HOME/.trae-cn" || -d "$HOME/.traecli" ]] || has_cmd trae || has_cmd traecli; } && found+=(trae)
  echo "${found[*]:-}"
}

case "$tools_arg" in
  auto)
    tools="$(detect_tools)"
    if [[ -z "$tools" ]]; then
      echo "No supported agents detected; installing to the shared .agents/skills location."
      tools="codex"
    fi ;;
  all) tools="$ALL_TOOLS" ;;
  *) tools="${tools_arg//,/ }" ;;
esac

for t in $tools; do
  [[ " $ALL_TOOLS " == *" $t "* ]] || die "unknown tool '$t' (valid: ${ALL_TOOLS// /, })"
done

# Skills directories each tool scans. Codex, OpenCode and DeepSeek Harness all read
# .agents/skills, so they share one target and the skill is not listed twice.
dirs_for() {
  local tool="$1"
  if [[ "$scope" == "global" ]]; then
    case "$tool" in
      claude) echo "$HOME/.claude/skills" ;;
      codex|opencode) echo "$HOME/.agents/skills" ;;
      deepseek) echo "${DSH_AGENTS_HOME:-$HOME/.agents}/skills" ;;
      cursor) echo "$HOME/.cursor/skills" ;;
      trae)
        echo "$HOME/.trae/skills"
        [[ -d "$HOME/.trae-cn" ]] && echo "$HOME/.trae-cn/skills"
        [[ -d "$HOME/.traecli" ]] && echo "$HOME/.traecli/skills"
        ;;
    esac
  else
    case "$tool" in
      claude) echo "$project_dir/.claude/skills" ;;
      codex|opencode|deepseek) echo "$project_dir/.agents/skills" ;;
      cursor) echo "$project_dir/.cursor/skills" ;;
      trae) echo "$project_dir/.trae/skills" ;;
    esac
  fi
  return 0
}

targets=()
for t in $tools; do
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    [[ " ${targets[*]:-} " == *" $d "* ]] || targets+=("$d")
  done < <(dirs_for "$t")
done

# True if $1 is safe to replace: a symlink, or a directory holding this skill.
is_ours() {
  [[ -L "$1" ]] && return 0
  [[ -f "$1/SKILL.md" ]] && grep -q "^name: $SKILL_NAME\$" "$1/SKILL.md"
}

echo "Tools: $tools"
echo "Scope: $scope"
[[ "$scope" == "project" ]] && echo "Project: $project_dir"

status=0
for dir in "${targets[@]}"; do
  dest="$dir/$SKILL_NAME"
  if [[ "$action" == "uninstall" ]]; then
    if [[ -e "$dest" || -L "$dest" ]]; then
      if is_ours "$dest" || [[ $force -eq 1 ]]; then
        echo "- removing $dest"
        run rm -rf "$dest"
      else
        echo "! skipping $dest (not created by this installer; use --force)" >&2
        status=1
      fi
    else
      echo "- not installed: $dest"
    fi
    continue
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    if is_ours "$dest" || [[ $force -eq 1 ]]; then
      run rm -rf "$dest"
    else
      echo "! skipping $dest (exists and was not created by this installer; use --force)" >&2
      status=1
      continue
    fi
  fi
  run mkdir -p "$dir"
  if [[ "$mode" == "link" ]]; then
    echo "+ linking $dest -> $src"
    run ln -s "$src" "$dest"
  else
    echo "+ copying to $dest"
    run cp -R "$src" "$dest"
    run chmod +x "$dest/scripts/prior-advisories.sh"
  fi
done

if [[ "$action" == "install" && $status -eq 0 ]]; then
  echo
  echo "Done. Restart your agent (or start a new session), then ask e.g.:"
  echo "  /$SKILL_NAME hunt for authorization bugs in src/auth as a remote unauthenticated attacker"
fi
exit $status
