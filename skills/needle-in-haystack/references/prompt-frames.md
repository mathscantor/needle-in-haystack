# Prompt frames

Use these on yourself, or as the task prompt for a slice subagent. Placeholders: `{slice}` (files/functions), `{attacker}` (attacker model), `{invariant}`, `{class}` (bug class already found). Combine 2-3 frames per prompt; do not paste all of them.

## Adversary, not auditor

> You are a red team operator paid to break {slice}. You only get paid for real, exploitable bugs reachable by {attacker}. Theoretical issues and hardening suggestions are worthless to you.

An auditor frame produces long lists of low-signal observations. The adversary frame biases toward impact and exploitability, and toward stating that a mechanism is fundamentally broken instead of "could be improved".

## Assert the vulnerability exists

> {slice} is definitely vulnerable and contains at least 2-3 security issues. Find them. For each, give the exact call chain and the attacker-controlled input.

Use this instead of "is this vulnerable?". The agreeable default is "looks generally secure"; asserting existence flips the search target.

## False anchor

> I already found one vulnerability in {slice}, but there are others I have not found yet. What are they?

This works best when the anchor is real (after a confirmed finding) and you want variants from the same module.

## Ask for the exploit

> Write a proof-of-concept request/input that bypasses {guard} in {slice} as {attacker}. Trace step by step what the code does with your payload.

If the guard is sound, the attempt to build a payload tends to fail midway, and that failure is useful signal. If it is broken, you get a PoC instead of "might be insufficient".

## Invert the question

> How would you break {slice}? List concrete attack strategies, most promising first.

Use this instead of "is this secure?". A yes/no question defaults to yes; a "how would you break it" question has no easy default.

## Invariants, then violations (two steps)

Step 1:
> List every assumption {slice} makes about its inputs, environment, configuration, call order, and caller. Only list them; do not evaluate yet.

Step 2 (one assumption at a time):
> Assumption: "{invariant}". Can {attacker} violate it? Show the input or state that breaks it, or the exact code that enforces it.

Separating enumeration from evaluation avoids shallow, satisficed answers.

## Assume a developer mistake

> Assume the developer introduced a bug in {slice}. What is it? Point at the line that does not make sense, not the lines that do.

This stops the model from rationalizing suspicious code as intentional (wrong initial value, inverted condition, early `return true`, missing `await`, default fallback).

## Compare to the canonical secure pattern

> How does {slice} differ from the standard secure implementation of {pattern: JWT verification | JWKS key selection | CSRF | session fixation defense | signed-cookie rotation | HTML sanitization | path normalization}? List every deviation and whether {attacker} can use it.

This is strongest for crypto and auth code, where there is one right way and many wrong ones.

## Constrain the attacker

> You are {attacker}. You can only {capabilities}. You cannot {exclusions}. Find every way to escalate access or cause harm through {interface} alone.

A narrow attacker model removes false positives and forces creative paths, which are the ones defenders overlook.

## Escalate: "what else?" (2-3 rounds, then stop)

> Those are the obvious ones. Set aside everything related to {class}. What subtler issues are easy to miss here: config-dependent defaults, partial/missing configuration, error paths, multi-message/multi-item inputs, races, encoding/normalization differences?

The first answers are the highest-probability, most obvious completions. Interesting bugs live in the tail. After about 3 rounds the signal degrades, so move to the next slice.

## Evidence demand (append to any frame)

> For each finding give: call chain with file:line, every guard on the path and why it fails, the attacker-controlled input, preconditions/config required, and a minimal PoC. Drop anything that requires capabilities outside {attacker}.
