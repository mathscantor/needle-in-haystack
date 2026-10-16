# needle-in-haystack

An agent skill for security bug hunting, based on [Needle in the haystack: LLMs for vulnerability research](https://devansh.bearblog.dev/needle-in-the-haystack/) by Devansh.

Instead of "find all vulnerabilities in this codebase", the skill has the agent:

1. Fix a scope and an explicit attacker model.
2. Mine prior advisories and fix commits for variants and bypasses.
3. Write a one-page threat model with testable invariants (`.needle/THREAT_MODEL.md`).
4. Map one thin slice's entry points to its sensitive sinks, with exact call chains.
5. Audit that slice with adversarial prompt frames (assert the bug exists, ask for the exploit, violate invariants, "what else?").
6. Verify every candidate with a test, PoC, sanitizer, or fuzzer before reporting it.
7. Write findings to `.needle/findings/` and move to the next slice.

The skill follows its own advice about context: `SKILL.md` is short, and the templates, prompt frames and slice playbook in `references/` load only when needed.

## Install

### With `npx skills` (any supported agent)

```bash
npx skills add https://github.com/mathscantor/needle-in-haystack.git
```

### With the bundled installer

```bash
git clone https://github.com/mathscantor/needle-in-haystack.git
cd needle-in-haystack
./install.sh                       # auto-detect installed agents, user-wide
./install.sh --tools all           # every supported agent
./install.sh --tools claude,cursor # specific agents
```

Without a local checkout:

```bash
curl -fsSL https://raw.githubusercontent.com/mathscantor/needle-in-haystack/main/install.sh | bash
```

That clones [the repo](https://github.com/mathscantor/needle-in-haystack) and installs from it. `NEEDLE_REPO_URL` overrides the clone URL. `--link` still needs a local checkout.

### Where it installs

| Agent | `--tools` | Global | Project |
|-------|-----------|--------|---------|
| Claude Code | `claude` | `~/.claude/skills` | `.claude/skills` |
| OpenAI Codex | `codex` | `~/.agents/skills` | `.agents/skills` |
| OpenCode | `opencode` | `~/.agents/skills` | `.agents/skills` |
| DeepSeek Harness (dsh) | `deepseek` | `~/.agents/skills` (or `$DSH_AGENTS_HOME/skills`) | `.agents/skills` |
| Cursor | `cursor` | `~/.cursor/skills` | `.cursor/skills` |
| Trae (IDE, CN build, CLI) | `trae` | `~/.trae/skills`, plus `~/.trae-cn/skills` and `~/.traecli/skills` if present | `.trae/skills` |

Codex, OpenCode and DeepSeek Harness all scan `.agents/skills`, so the installer writes there once to avoid the skill showing up twice.

For any other agent that supports the [Agent Skills](https://agentskills.io) format, copy `skills/needle-in-haystack/` into its skills directory.

## Use

Start a new agent session in the target repository, then either invoke the skill directly or describe the task:

```text
/needle-in-haystack audit the JWT middleware as a remote unauthenticated attacker
```

```text
Hunt for authorization bypasses where the read-only API key can reach write operations.
```

```text
Look for bypasses of the fixes for our past CVEs.
```

The agent asks for a target and an attacker model if you don't give them.

Optional advisory lookup, run inside the target repo:

```bash
bash ~/.agents/skills/needle-in-haystack/scripts/prior-advisories.sh owner/repo --ecosystem npm --package some-package
```

## Layout

```
skills/needle-in-haystack/
├── SKILL.md                         # workflow and rules (always loaded)
├── references/
│   ├── threat-model-template.md     # one-page .needle/THREAT_MODEL.md template
│   ├── prompt-frames.md             # adversarial prompt frames
│   ├── slice-playbook.md            # per-slice probing questions + real bug anchors
│   └── verification.md              # verifier per bug class + finding template
└── scripts/
    └── prior-advisories.sh          # GHSA/OSV advisories + security-looking commits
```

## Responsible use

Only audit code you own or are authorized to test. Run PoCs only against local instances, and report findings through the project's security policy.
