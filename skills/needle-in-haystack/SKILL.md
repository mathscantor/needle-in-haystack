---
name: needle-in-haystack
description: Hunts for real, exploitable security vulnerabilities in a codebase using a minimal-scaffolding methodology - prior CVE/advisory analysis, a one-page threat model, thin-slice audits along trust boundaries, adversarial prompt frames, and mandatory verification with PoCs or tests. Use when the user asks for bug hunting, vulnerability research, a security audit, finding CVEs, variant analysis, fix-bypass hunting, threat modeling, or "find vulnerabilities in this code".
---

# Needle in the Haystack

Find the one subtle invariant violation buried in thousands of legitimate lines. Context is the enemy: every token of scaffolding is more haystack. Keep persistent state small, explore one thin slice at a time, and prove every finding.

Never run "find all vulnerabilities in this codebase". No threat model means no notion of impact, and broad prompts produce breadth-first pattern-matching of bug classes that are unreachable in this code.

## Ground rules

- Only audit code the user owns or is authorized to test. Run PoCs against local instances only, never third-party live systems. Recommend responsible disclosure.
- One persistent artifact: `.needle/THREAT_MODEL.md` in the target repo (about one page). Findings go in `.needle/findings/`. Do not create other planning docs.
- Budget: under 10% of effort on scaffolding (threat model, invariants), 60-80% on slice audits, 20-30% on verification loops.
- Load a reference file only at the phase that needs it.

## Workflow

Copy and track:

```
- [ ] 1. Scope + attacker model
- [ ] 2. Prior advisories + fix commits
- [ ] 3. Threat model written
- [ ] 4. Attack surface map for current slice
- [ ] 5. Slice audit (repeat per slice)
- [ ] 6. Verify each candidate
- [ ] 7. Report + update threat model
```

### 1. Scope and attacker model

Establish, asking the user once if unknown:

- **Target**: repo or subdirectory.
- **Attacker model**: who triggers the bug. Default to *remote unauthenticated attacker who can only send requests to the public interface*. Alternatives: low-privileged authenticated user, cross-tenant user, malicious plugin, code execution inside a sandbox/CI runner, malicious input file.
- **Crown jewels**: what the attacker wants (credentials, other tenants' data, privileged writes, code execution, egress past controls).

### 2. Prior advisories and fix commits

Past accepted vulnerabilities are the best predictor of future ones. Run from the target repo, where `<skill-dir>` is the directory containing this file:

```bash
bash <skill-dir>/scripts/prior-advisories.sh <owner/repo>
```

The argument is optional when the repo has a GitHub `origin` remote. Pass `--ecosystem npm --package <name>` (or PyPI, Go, crates.io, Maven...) to also query OSV by package.

It prints a compact list of GHSA/OSV advisories and security-looking commits. For each relevant fix commit, read the diff and ask: *is the fix complete, are there sibling code paths with the same root cause, and can the fix be bypassed?* Variant and bypass hunting comes first because it has the highest hit rate.

No history? Derive the threat model from architecture and docs instead (what the project promises, e.g. "this key grants reads but denies all writes").

### 3. Threat model

Write `.needle/THREAT_MODEL.md` from [references/threat-model-template.md](references/threat-model-template.md). It must fit on one page: a one-sentence threat model, crown jewels, trust boundaries, plausible bug classes ranked by the history from step 2, and a short list of testable invariants such as "only admins can call X" or "JWT issuer must be Y". Extend it as the audit progresses.

### 4. Attack surface map (per slice)

Pick ONE thin slice matching a real attack surface: auth, authz/key tiers, session/cookies, request parsing, file uploads, deserialization, templating/rendering, caching, crypto/signatures, sandbox or plugin boundary, egress controls, native bindings.

Map the slice's entry points (HTTP routes, RPC handlers, message consumers, CLI entry points, scheduled jobs, webhooks) to sensitive sinks (authz decisions, writes, deserialization, template/HTML output, shell/SQL/FS, crypto verification). For every path record:

- the exact call chain (`file:line` hops)
- every guard on the path and what it checks
- which inputs are attacker-controlled under the chosen attacker model

Look for asymmetry: a guard present on most paths but missing on one (e.g. handlers checking `isMaster` but not `isReadOnly`). Then enumerate every instance of that pattern.

For slice-specific probing questions, see [references/slice-playbook.md](references/slice-playbook.md).

### 5. Slice audit

Audit one slice per focused context. If the harness supports subagents or fresh sessions, give each slice its own context containing only: the one-sentence threat model, the attacker model, the relevant invariants, and the slice's file paths. Do not build heavy orchestration.

Use adversarial frames, not auditor frames. Core moves:

- Assert the bug exists: "this code has at least 2-3 security issues; find them".
- Ask for the exploit, not an assessment: produce a concrete PoC request or input.
- List every assumption/invariant the code relies on, then check each one separately for attacker violation.
- Assume the developer made a mistake; do not rationalize suspicious code as intentional (e.g. `let decoded = true`).
- Diff against the canonical secure implementation of the pattern (JWT, CSRF, sessions, signature rotation).
- After each round, push 2-3 times: "those are the obvious ones; what subtler issues remain, excluding classes already found?"

Copy-ready prompts for each frame: [references/prompt-frames.md](references/prompt-frames.md).

Discard candidates that need capabilities outside the attacker model.

### 6. Verify

"The model says it's vulnerable" is not a finding. Each candidate needs one of:

- a failing unit/integration test that demonstrates the violated invariant
- a local build/instance plus a PoC request that shows the impact
- a sanitizer build or crash reproduction harness (native code)
- a lightweight fuzzer hitting the path
- a grep/static invariant check showing the pattern

If verification fails, record why; that is signal too. Anything unproven is marked `UNVERIFIED`. Verifier choice per bug class and the report template: [references/verification.md](references/verification.md).

### 7. Report and iterate

Write each confirmed finding to `.needle/findings/<NN>-<short-name>.md` using the template in [references/verification.md](references/verification.md). Update `.needle/THREAT_MODEL.md` with new invariants, rule out disproven bug classes, and record slices done. Pick the next slice and return to step 4.

When presenting results, list verified findings first (severity, attacker model, one-line impact, PoC location), then `UNVERIFIED` leads, then slices not yet covered.
