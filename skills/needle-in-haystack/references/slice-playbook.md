# Slice playbook

Probing questions per slice. Use only the section for the current slice. Each section ends with real bugs found with this method, as pattern anchors.

## Authorization / privilege tiers

- What credential/role tiers exist, and which is meant to be strictly weaker than another?
- Where is each tier checked? List every handler that gates on the stronger tier's flag; does each also check the weaker tier's restriction?
- Can the weaker credential reach any write, state change, config change, or secret read via batch endpoints, hooks, file/schema/config routes, or indirect calls?
- Are checks done once in middleware, or re-done per handler (and are any skipped)?

Anchor: Parse Server handlers gated on `isMaster` but never consulted `isReadOnly`, so `readOnlyMasterKey` could perform writes (3 CVEs, one root cause).

## Authentication adapters / token validation

- Which claims are validated (`iss`, `aud`, `exp`, `nbf`, `sub`, nonce)? Which only when configured?
- What happens when configuration is partial or missing: skip the check, or fail closed?
- Are tokens from one provider/app accepted by another?

Anchor: Parse Server social auth adapter silently skipped the `aud` check when configuration was incomplete.

## JWT / JWKS / signatures

- Is the algorithm pinned server-side? What is the default when the developer does not pin it?
- Is `header.alg`, `kid`, `jku`, or `x5u` from the token ever trusted for verification decisions?
- With JWKS: what if the JWK lacks `alg`? Is the key type bound to the algorithm (RSA key cannot verify HS256)?
- Can a public key be used as an HMAC secret? Is `none` rejected in all casings?

Anchor: HonoJS JWT middleware defaulted to HS256 when unpinned; the JWKS middleware fell back to the token's `header.alg` when the JWK lacked `alg`.

## Signed cookies / secret rotation

- Trace the verification loop over multiple secrets: what is the initial state of the "valid" flag, and what happens when no secret matches?
- Are comparisons constant-time? Are unsigned values accepted when signing is enabled?

Anchor: ElysiaJS used `let decoded = true` instead of `false`, so with rotation enabled signature validation could never fail.

## Egress control / sandbox / CI runners

- Enumerate every OS mechanism that sends data out (e.g. Linux `connect`, `sendto`, `sendmsg`, `sendmmsg`, `io_uring`, raw sockets, DNS, ICMP). Diff against what is actually hooked/filtered, per mode (audit vs block).
- DNS-aware filtering: does the parser handle multiple messages per TCP segment, pipelining, compression pointers, and EDNS?
- Is each allowed IP bound to the domain that triggered it, or is it globally whitelisted? What about shared IPs (CDNs)?
- Privilege restrictions: besides sudo, what else grants root (docker group, setuid binaries, writable service files, capabilities)?

Anchors: harden-runner missed UDP send-family syscalls in audit mode; BullFrog parsed only the first DNS message in a TCP segment, whitelisted IPs without domain binding, and docker group membership survived sudoers removal.

## Rendering / XSS / content in a privileged origin

- Trace untrusted content (Markdown, HTML, SVG, user files) from source to DOM: every transform and sanitizer, and its config.
- What does the sanitizer allow (raw HTML, `javascript:` / `data:` URLs, SVG, attributes, iframes)? Are there post-sanitize transforms that reintroduce markup?
- What sits in the same origin (tokens in storage/cookies, privileged APIs)?

Anchor: Better-Hub rendered GitHub Markdown unsanitized in an origin holding OAuth tokens, giving 6 XSS variants from one pipeline.

## Caching / authorization context

- Is the cache key aware of the user, auth state, and permissions? Is private content cached in a shared cache?
- Can a path/extension trick make an authenticated response cacheable (cache deception)?

Anchor: Better-Hub served cached private repository content to unauthenticated users.

## Tokens / secrets handling

- Where are tokens stored and with what scope? Are they reachable from client-side JS, logs, error pages, or URLs?
- What is the token lifecycle: rotation, revocation, logout?
- Redirect parameters: is the allow-list exact-match, or does it use prefix/regex checks?

Anchors: Better-Hub client-side OAuth token exposure and an open redirect.

## Request parsing / deserialization / uploads

- Parser differentials between a proxy, the framework, and the app (duplicate keys, encodings, content-type confusion, path normalization).
- Prototype pollution or mass assignment through nested keys (`__proto__`, `constructor`, dotted paths).
- Uploads: filename/path traversal, content-type trust, archive extraction (zip slip), size and recursion limits.
- Deserialization of attacker data into typed objects or gadgets.

## Native code / memory safety

- Integer arithmetic on attacker-controlled lengths before allocation or copy.
- Lifetime: objects freed in callbacks/re-entrancy and then reused (use-after-free); JIT/GC assumptions.
- Prefer sanitizer (ASan/UBSan/MSan) builds plus a reproduction harness for every candidate.
