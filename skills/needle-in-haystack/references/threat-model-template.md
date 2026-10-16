# Threat model template

Write to `.needle/THREAT_MODEL.md` in the target repo. Hard limit: one page. Short bullets, no prose padding. Edit in place as the audit progresses.

```markdown
# Threat model: <project> (<slice or whole target>)

## One sentence
<Can [attacker] achieve [crown jewel] by [abusing what]?>
e.g. "Can an attacker with code execution on a CI runner exfiltrate data past the egress controls?"

## Attacker model
- Who: <remote unauthenticated | low-priv authenticated | cross-tenant | malicious plugin | sandboxed code>
- Can: <send HTTP to public API, supply files, control DNS answers, ...>
- Cannot: <filesystem, DB, internal services, admin console, ...>

## Crown jewels
- <credentials / tokens / other tenants' data / privileged writes / RCE / egress>

## Trust boundaries
- <browser -> server | service -> service | plugin -> host | sandbox -> privileged | runner -> network>

## Security promises (from docs/README/config)
- <"readOnlyMasterKey grants master reads but denies all writes">

## Prior advisories (from prior-advisories.sh)
- <ID>: <one line root cause> -> fix <commit> -> variant/bypass checked? <yes/no>

## Plausible bug classes (ranked)
1. <class> - why: <history / architecture>
2. ...

## Invariants to test
- [ ] <only admins can call X>
- [ ] <JWT alg is pinned server-side, never taken from header>
- [ ] <every rotated secret mismatch => reject>

## Slices
| Slice | Status | Findings |
|-------|--------|----------|
| <auth adapters> | todo / in progress / done | <ids> |

## Ruled out
- <class or path> - <why, with evidence>
```
