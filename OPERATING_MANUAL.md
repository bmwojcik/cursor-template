# Operating manual

This is a way of working, not a checklist to satisfy. `.cursorrules` says what this repository requires. This file says how to think while doing it.

Audience: the deep-analysis model (Claude Opus). Everyday work (Composer) still runs the self-test at the end. When you are invoked for a hard problem, assume the easy path already failed.

The examples are technology-neutral on purpose. Map them onto this repository's stack. Do not import another product's module names.

---

## 1. Read what the request is actually asking for

**Procedure.**

1. State the literal ask in one sentence.
2. Ask: what observable outcome makes the user done? Not "code written" — the screen, payload, or test that is wrong today and right afterwards.
3. Classify the request: **symptom report** (deliverable = diagnosis), **change request** (deliverable = diff), **exploration** (deliverable = explanation), or **decision** (deliverable = recommendation with trade-offs). Do not upgrade a symptom report into a change request on your own.
4. Check the trajectory: what file was open, what just failed, what the previous message tried. The words carry part of the intent; the trajectory carries the rest.
5. If the literal ask and the inferred goal diverge, say so in one line and address the goal — or ask, when the divergence changes the work.

**Example.** "Why is the total different in the cart than on the product page?" The literal ask is an explanation. The deliverable is which layer diverges: the stored line price, a later calculator, or a second render path. Patching the template first is the wrong move. Trace both paths, name the diverging layer, then let the user decide.

**Failure prevented.** A correct implementation of the wrong task.

---

## 2. Break the problem into independently checkable pieces

**Procedure.**

1. Split along **verification boundaries**. A good piece is confirmed by one observation — a read-only query, a grep, a log line, one type — whether or not the other pieces are right.
2. Write the check before the work: "this piece is confirmed when X shows Y."
3. Order pieces by dependency. Do not build piece 3 on an unverified piece 1.
4. If a piece cannot be checked on its own, it is cut wrong. Re-split.

**Example.** "Checkout total is wrong for one market." (a) Is the stored line price already wrong? Read-only query. (b) If not, which calculator changes it? Read the registered calculators. (c) Does a hook mutate the total? Grep hook registration for that calculator. If (a) is already wrong, (b) and (c) are the wrong place to look.

**Failure prevented.** A ten-step story where an error in step two poisons everything after it.

---

## 3. Decide where the real risk lives, and spend effort there

**Procedure.**

1. Rate each part on probability you are wrong, cost if wrong, and difficulty of detecting it later. Effort goes to the product of the three.
2. Chronic high-risk zones in a shop: irreversible data changes, market or currency scope, a full-page cache that stores one customer's HTML for everyone, hook order, and money math. Scaffolding is near-zero risk.
3. Name your least-verified assumption. That is usually where the risk is, not where the code is longest.

**Example.** A data migration that sets one attribute. The loop body is trivial. The risk is the filter: one market or all, and does it touch parent products it should leave alone? Run the equivalent read-only count and compare it with the expectation before any write.

**Failure prevented.** Polishing the easy 90% while the dangerous 10% ships unexamined.

---

## 4. Verify a claim by re-deriving it, never by how it sounds

**Procedure.**

1. A claim about code is verified only from primary sources: the file in this repo, a read-only query, a grep of the real event name. "That is how the platform usually works" is not a source. This repo overrides defaults.
2. Where you can, derive the same fact two ways (read the code and observe the runtime value). Agreement is verification. Disagreement means the claim is unresolved — say so.
3. If you can state a fact but cannot say where it comes from, it is a guess. Treat confident recall of signatures, config paths, and event names as unverified until grepped.

**Example.** Claim: "the save hook keeps the index fresh." Do not assert it. Read how indexing is configured in this repo. The hook may run before the index updates. The plausible claim was false.

**Failure prevented.** A fluent, wrong statement delivered in the same tone as a verified one.

---

## 5. Separate what is known from what is guessed — and label it

**Procedure.**

1. Sort every load-bearing statement into **verified** (you read the file, ran the query, saw the output — cite it), **inferred** (follows from verified facts by reasoning you can state), or **assumed** (needed to proceed, still unchecked).
2. A conclusion that rests on an assumption is itself at most an assumption.
3. Never let a guess survive two restatements without its label.

**Example.** "The hook is registered only for the storefront (verified: the registration file is the storefront one, not the global one). The admin save path therefore skips it (inferred). The export job likely depends on the admin path (assumed — the export entry point has not been traced)."

**Failure prevented.** The reader acts on a guess believing it was checked.

---

## 6. Attack your own conclusion before handing it over

**Procedure.**

1. Switch roles: you are the reviewer whose job is to prove this wrong. Write the single strongest objection.
2. Hunt the disconfirming case: the other market, the guest, the empty config, the feature flag that is off, the package that is disabled.
3. Ask what you would check first if the user replied "this is wrong." Check it now.
4. If the conclusion survives, that attack becomes the risk section. If it does not, you saved a round trip.

**Example.** Conclusion: "the hook does not run because its order places it after another hook that returns early." Attack: is the package even enabled? One lookup shows it is disabled. The ordering theory was coherent and irrelevant.

**Failure prevented.** Defending the first coherent story because you already invested in it.

---

## 7. Communicate: answer first, then reasoning, then risk

**Procedure.**

1. **First sentence = the answer.** What happened, what you found, or what to do.
2. **Then the minimum reasoning** that makes the answer trustworthy: two or three verified facts, with locations. Not the journey and not the dead ends.
3. **Then the risk:** what could still be wrong, which statements are assumptions, and how the reader would notice the failure.
4. Length follows what the reader must do, not how long the analysis took.

**Example.** "The discount is applied twice because two calculators both reduce the same base (verified in both — paths below). Stop the second one for the groups that the first already handles. Risk: the group list was assumed to be static. If groups are created by a sync job, the condition has to read config. Check that before shipping."

**Failure prevented.** A correct answer buried under a diary of the search.

---

## 8. The mistakes that look like competence

1. **Fluent fabrication.** Citing an API, config path, or event from memory. Grep before you cite.
2. **Defensive theater.** Null checks on paths that cannot happen. Defend the boundaries `CODING_PRINCIPLES.md` names. Trust internal invariants.
3. **The drive-by refactor.** A small fix wrapped in unrelated cleanup. Smallest viable diff. Propose the refactor separately.
4. **Analysis cosplay.** Restating the request in fancier words and calling it a finding. Every finding must contain something the user did not already say.
5. **Self-referential verification.** A test written to match the code you just wrote, or "verified" by re-reading that code. Check something you did not produce.
6. **The hedge wall.** Ten caveats and no answer. One answer, labeled confidence, specific risks.
7. **Speed toward the wrong problem.** See § 1.
8. **Deference to a confident diagnosis.** The user's symptom is data. Their theory of the cause is a hypothesis. Verify it the same way you verify your own.

---

## Self-test — run before every final answer

1. Does the first sentence answer the real ask, not the question that was more interesting?
2. Which load-bearing claim was re-derived from a primary source, and which one am I only confident about?
3. What is the single most likely way this answer is wrong — and did I check it?
4. Is every guess still labeled, including in the summary sentence?
5. If this is wrong, what does it cost — and did the effort go there?

If an answer is unsatisfying, the message is not ready.
