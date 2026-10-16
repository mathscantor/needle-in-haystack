# Verification and reporting

A candidate becomes a finding only after a verifier demonstrates it. Prefer the cheapest verifier that proves impact under the stated attacker model.

## Choosing a verifier

| Bug class | Preferred verifier |
|-----------|--------------------|
| Authz / authn / logic | Integration test using the project's own test harness: act as the attacker, assert the forbidden effect happens |
| JWT / signature / crypto | Unit test that forges the token/cookie (e.g. HS256 signed with the public key) and asserts it is accepted |
| Web (XSS, redirect, cache) | Local instance + PoC request (`curl`) or a headless browser script; show the payload executing or the leaked data |
| Parsing / input handling | Lightweight fuzzer or property test around the parser; keep the minimized crashing/bypassing input |
| Memory safety (C/C++/unsafe Rust) | Sanitizer build (ASan/UBSan) + reproduction harness; attach the sanitizer report |
| Egress / sandbox | Script run inside the restricted environment that demonstrates the out-of-policy effect, with a local listener as the receiver |
| Pattern-wide issues | grep/semgrep/ast-grep invariant check listing every violating site, plus one site proven dynamically |

## Loop

1. Build/run the project locally (read its CONTRIBUTING/test docs; use its existing test runner).
2. Write the smallest test or PoC that shows the violated invariant. Put it in `.needle/poc/` or as a test file in the project's test directory, named clearly as a security repro.
3. Run it. If it passes (the bug is real), reduce it to a minimal reproduction.
4. If it fails, note why in the threat model's "Ruled out" section; a sound guard is useful signal.
5. Optionally draft a patch and show that the repro then fails.

Never run PoCs against systems the user does not own or is not authorized to test.

## Finding report template

Write to `.needle/findings/<NN>-<short-name>.md`:

```markdown
# <Title: component + bug class + impact>

- Status: VERIFIED | UNVERIFIED
- Severity: Critical | High | Moderate | Low (with CVSS vector if known)
- Attacker model: <who, which capabilities>
- Preconditions / config: <defaults? specific options?>
- Affected: <versions / commit>, <file:line>

## Summary
<2-3 sentences: what breaks, why, impact.>

## Root cause
<Call chain with file:line hops, the guard that fails, and why.>

## Proof of concept
<Exact request/input/test, and how to run it. Expected vs observed result.>

## Impact
<What the attacker gains under the attacker model.>

## Suggested fix
<Minimal patch or approach. Note sibling paths with the same root cause.>
```
