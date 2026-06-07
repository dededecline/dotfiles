---
description: Deep-review an open PR, present findings, draft inline comments in my voice, post the approved ones to specific lines on the PR
argument-hint: [repo-path | pr-url | owner/repo#N]
model: claude-opus-4-7
effort: xhigh
allowed-tools: Skill Bash Read Grep Glob AskUserQuestion mcp__plugin_Laurel_linear-server__*
disable-model-invocation: true
---

# PR Review

Run a deep review on an open PR, then turn the findings the user picks into inline review comments written in the user's voice and posted to the exact lines they reference.

## Argument resolution

Parse `$ARGUMENTS`. Resolve to two values: `REPO_PATH` (a local checkout) and `PR_NUMBER` (an open PR on the remote that matches that checkout).

1. **No argument**: `REPO_PATH = cwd`. Read the current branch with `git -C "$REPO_PATH" branch --show-current`. Find the open PR for that branch with `gh pr view --json number,headRefName,baseRefName,url --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner -R "$REPO_PATH")"`. If no open PR, stop and tell the user.
2. **Argument is a directory path** (exists on disk): same as above but with that path.
3. **Argument is a PR ref** (`https://github.com/owner/repo/pull/N`, `owner/repo#N`, or bare `N` when cwd is a repo): parse it. If the corresponding branch is checked out somewhere reachable (cwd or the path of that repo under `~/Documents/Repos/`), use it. Otherwise ask the user to `gh pr checkout` first; do not check out branches yourself.

Stop with a clear message if any of these fail. Never silently fall through.

## Step 1: Read attached Linear tickets for context

Before reviewing, always pull context from any Linear tickets attached to the PR. The ticket explains intent, acceptance criteria, and constraints that the diff alone doesn't show, and grounds the review in what the PR is supposed to accomplish.

Sources to check for ticket references, in order:
1. PR title and body: `gh pr view <PR_NUMBER> --json title,body --repo <owner>/<repo>`. Pinginc repos follow `type: LINEAR-ID: description`, so the title usually contains the primary ticket.
2. PR branch name: `gh pr view <PR_NUMBER> --json headRefName`. Branch names often embed the ticket ID (`eng-123-add-foo`).
3. Linked development items in the PR sidebar: `gh api repos/<owner>/<repo>/issues/<PR_NUMBER>/timeline` (filter for cross-referenced links to Linear).
4. Commit messages on the branch: `gh pr view <PR_NUMBER> --json commits --jq '.commits[].messageHeadline'`.

Extract every unique ticket ID matching `[A-Z]+-\d+`. For each ticket, fetch it via the Linear MCP server (`mcp__plugin_Laurel_linear-server__*`). Read the title, description, acceptance criteria, comments, and any linked sub-issues or parent. If multiple tickets are attached, read all of them; if none are found, note that explicitly and continue without ticket context (don't block the review).

Hold this context in mind for the rest of the run. Use it to:
- Calibrate severity (something that looks risky in the diff may be intentional per the ticket; something that looks fine may miss an explicit acceptance criterion).
- Spot scope drift (changes outside what the ticket asked for) and missing scope (acceptance criteria the diff doesn't satisfy).
- Sharpen comment framing in Step 3, where referencing the ticket's intent makes a flag land harder ("the ticket calls out X explicitly, and this path bypasses it").

Don't paste ticket bodies into PR comments verbatim, and don't post a comment that just says "this contradicts ENG-123". Use ticket context to decide what to flag and how to frame it; the comment itself stays grounded in the code.

## Step 2: Run deep-review

Invoke the existing `/deep-review` command on `REPO_PATH` via the Skill tool. Use the default mode (full branch diff against `origin/HEAD`), no `--fix`. Capture its findings.

If deep-review returns "All reviews passed", stop and tell the user there is nothing to comment on.

## Step 3: Present findings to the user

Re-format deep-review's output as a numbered list, one finding per line, sorted by severity (Critical, High, Medium). Each entry shows: number, severity tag, file:line, one-sentence summary.

Example:
```
1. [HIGH] sec  .github/workflows/changed-apps.yml:42 ... `$BEFORE_SHA` unquoted with set -u aborts on any non-CI run
2. [HIGH] qual scripts/diff-paths.sh:88 ... silent under-trigger when en.json nets identical at HEAD
3. [MED]  qual scripts/diff-paths.sh:101 ... plain `sort` honors LC_ALL, breaks comm -3 under non-C locales
...
```

Then ask the user (via AskUserQuestion or plain prompt, whichever fits) which numbers to turn into PR comments. Accept ranges (`1-3`), comma-separated lists (`1,4,7`), or `all`. If the user says none / cancels, stop.

## Step 4: Draft each selected comment in the user's voice

For each finding the user picked, draft a single inline comment.

**Voice (this is the important part. Do not deviate, do not "improve" it):**

The user writes PR comments like a helpful forensic engineer giving succinct, friendly field notes. The tone is collegial, not adversarial: light framing on the way in, concrete mechanism in the middle, constructive fix on the way out. Comments are 2 to 5 sentences, multiple paragraphs if necessary for readability, no headers, no bullet lists, no emojis. Structure each one in three beats:

1. **Open with a soft, friendly framing of what's missing or worth flagging**, then a period. The opener names the issue without scolding. Patterns the user has actually written: `Worth narrowing this in prd.`, `Worth adding a lifecycle policy here.`, `One gotcha with this secret payload.`, `One subtle drift case worth flagging.`, `Quick note on the `is_writer` keys here.`, `Versioning's missing on this one.`, `Access logging's missing here too.`, `Silent under-trigger here.`, `Tangentially related to this fallback.`. Do not open with "I noticed", "It looks like", "Consider", "This could", "You may want to", "Just a thought", "nit:", or any greeting.
2. **Then explain the mechanism in present tense**, concretely. Trace what actually happens: "If X, then Y silently breaks because Z." Name the conditions ("after a force-push", "under a non-C UTF-8 locale", "outside CI without exporting BEFORE_SHA", "on first apply"). Use backticks for every code identifier, file name, env var, command, or path. Use casual contractions (`isn't`, `doesn't`, `we're`, `versioning's`).
3. **End with a remediation**, framed as concrete code or a specific guard. Friendly closers the user uses: `Easiest is ...`, `Easiest call is to ...`, `Cleanest paths are ...`, `Two clean ways out: ...`, `Cheap fix: ...`, `Worth gating ... on ...`, `Pinning ... makes this robust`, `Safe to drop them; if X matters, Y is the supported knob.`. Offer the path forward, not a paragraph of guidance. Multiple options are fine when there's a real tradeoff (`Either ..., or ...`).

Tone rules, hard:
- Friendly framing on the opener is encouraged (`Worth flagging`, `One gotcha`, `Quick note`, `One subtle ... case`); the substance underneath stays direct and concrete.
- No hedge words inside the mechanism or fix: drop `maybe`, `perhaps`, `I think`, `it seems`, `arguably`, `possibly`, `might want to`, `should probably`. The opener can be light; the claim and the fix should not be.
- No moralizing: don't say "this is bad practice" or "this violates DRY". Say what fails, when it fails, and how to fix it.
- No flattery, no apologies, no "great work but". Open with the soft framing of the issue, not a compliment.
- No exclamation marks. No emoji. No "Thanks!" sign-off.
- **Never use em dashes or en dashes anywhere.** Use a period, comma, parens, colon, or semicolon. This applies even when quoting prior comments. If a sample on disk contains one, rewrite around it before reusing the phrasing.
- Lowercase continuations after a colon are fine (`Cheap fix: \`[ -n "${BEFORE_SHA:-}" ]\``).
- Reference precedent from the diff when relevant ("while every other env read in this block uses `${VAR:-}`", "Every sibling in `s3-regional.tf` sets `aws_s3_bucket_versioning` to `Enabled`"). Comparing against existing code in the same repo lands harder than abstract advice.
- For pinginc terraform/opentofu PRs, cite the specific underlying module and version when the wrapper's behavior is the load-bearing detail (e.g. `spacelift.io/laurel/v2-aws-aurora` v4.4.0). Read the module source at `/Users/<current user>/Documents/Repos/infra` before claiming an input is or isn't passed through.
- Severity calibration is in the framing word, not in `**HIGH**` tags. "Silently breaks", "aborts the moment", "balloons on every rebased push", "apps reading the secret start hitting `FATAL: password authentication failed`" carry the weight. Don't add severity prefixes to the comment body.

Reference samples the user has actually posted (read these before drafting; mirror cadence and shape):

> Worth narrowing this in prd. `apply_immediately = true` on a shared OLTP cluster means instance class changes and `pending-reboot` parameter updates land the moment terraform applies, not during the configured maintenance window. For an Aurora primary that's a writer failover (or full instance restart) inside business hours, on user-facing traffic. Easiest call is to flip to `false` here and on the `lhr`/`syd`/`yul` modules below, and keep `true` in `dev` and `stg` for fast iteration.

> One gotcha with this secret payload. `spacelift.io/laurel/v2-aws-aurora` v4.4.0 never passes `database_name` through to `terraform-aws-modules/rds-aurora`, so on first apply the cluster only has `postgres`, `template0`, and `template1`. The secret says `database = "application_oltp"` but the first app that connects with that DSN gets `FATAL: database "application_oltp" does not exist`. Cleanest paths are a one-shot `CREATE DATABASE` bootstrap (or a `postgresql_database` resource pointed at the cluster), or extending the wrapper to expose `database_name` so the cluster creates it on initial apply.

> Quick note on the `is_writer` keys here. `terraform-aws-modules/rds-aurora` v10 only reads keys like `identifier`, `instance_class`, `publicly_accessible`, and `promotion_tier` off each instance object; `is_writer` isn't one of them, because Aurora elects the writer automatically and you steer failover order via `promotion_tier`. The wrapper iterates `for k, v in var.instances`, so passing a list works (the `identifier` field overrides the default `${db_name}-${k}` naming), but the `is_writer = true/false` flags don't do anything downstream. Safe to drop them; if a fixed failover order matters, `promotion_tier = 0` on the intended primary and `1+` on the rest is the supported knob.

> One subtle drift case worth flagging. The wrapper sets `master_password_wo = var.db_password` with `master_password_wo_version = var.db_password_version`, and write-only attrs only re-apply to RDS when the version increments. `db_password_version` isn't passed here, so it stays at the module default `1`. If `random_password.application_oltp_iad` ever regenerates (taint, replacement, future code change that triggers a rebuild), the secret picks up the new value but the cluster keeps the old master password, and apps reading the secret start hitting `FATAL: password authentication failed`. Two clean ways out: pass `db_password_version` and bump it on every intended rotation, or pin `keepers` on the `random_password` so its lifecycle is deliberate.

> Versioning's missing on this one. Every sibling in `s3-regional.tf` (`gd_bucket_iad`, `gd_bucket_lhr`, etc.) sets `aws_s3_bucket_versioning` to `Enabled`, so a stray `s3:DeleteObject` or overwrite still leaves a recoverable version. StrongDM session logs are the same threat model and probably want the same treatment. Easiest is `versioning = { enabled = true }` on the module, or an `aws_s3_bucket_versioning.strongdm` resource matching the others.

> `$BEFORE_SHA` here isn't quoted with `:-`, while every other env read in this block uses `${VAR:-}`. With `set -u`, this aborts the moment anyone runs the script outside CI without exporting `BEFORE_SHA` (local repro, ad-hoc dispatch). Cheap fix: `[ -n "${BEFORE_SHA:-}" ]`.

> Silent under-trigger here. If en.json is touched mid-range but nets identical at HEAD (e.g. a merge brings `main`'s state back), `git diff --name-only` still lists the file but `comm -3` produces no diff_paths. We then `return` with no scope emitted, the outer loop reads zero lines, and no app gets added even though something actually flowed through this file in the range. Either return `__shared__` here as the conservative default, or leave the diff-style detection but document explicitly that we're trusting net-effect-at-HEAD.

For each draft, you also need a `path` (file path relative to repo root) and a `line` (the exact line in the new version of the diff that the comment attaches to). Pull these from the deep-review finding's `file:line` reference, validating against the diff with `gh api repos/<owner>/<repo>/pulls/<N>/files --jq '.[] | {filename, patch}'` if the line number is ambiguous (e.g. a finding that spans a range, in which case anchor on the most load-bearing line).

## Step 5: Show drafts and collect approvals

Print every drafted comment in a single block, numbered, each prefixed with `path:line` so the user can see where it will land. Example:

```
[1] .github/workflows/changed-apps.yml:42
    `$BEFORE_SHA` here isn't quoted with `:-`, while every other env read in this block uses `${VAR:-}`. With `set -u`, this aborts the moment anyone runs the script outside CI without exporting `BEFORE_SHA` (local repro, ad-hoc dispatch). Cheap fix: `[ -n "${BEFORE_SHA:-}" ]`.

[2] scripts/diff-paths.sh:88
    Silent under-trigger here. ...
```

Ask the user, in one prompt, what to do with each draft. Accept any of:
- `post all`: post every draft as written
- `post 1,3`: post only the listed numbers
- `skip 4`: drop a draft
- `revise 2: <new wording>`: replace the body of draft 2 verbatim
- `tweak 2: shorter, no second sentence`: apply the user's edit instruction to draft 2 and re-show
- `cancel`: abort without posting anything

Loop until the user gives a terminal instruction (`post ...`, `cancel`, or only `skip`/`revise` with no `post`). When revising via instruction, regenerate that single draft and re-show only the changed entry. Never post until the user explicitly says `post` (or equivalent).

## Step 6: Post the approved comments as a "Request changes" review

Bundle all approved drafts into a single PR review submitted with `event: REQUEST_CHANGES`. This produces one cohesive review on the PR (state: "Changes requested") with every approved draft attached as an inline comment, rather than N standalone comments.

Cache the head SHA once: `commit_id="$(gh api repos/<owner>/<repo>/pulls/<PR_NUMBER> --jq .head.sha)"`.

Build a JSON payload of the form:

```json
{
  "commit_id": "<head sha>",
  "event": "REQUEST_CHANGES",
  "body": "",
  "comments": [
    { "path": "<file>", "line": <n>, "side": "RIGHT", "body": "<draft body>" },
    ...
  ]
}
```

Leave the top-level `body` empty (`""`); the substance lives in the inline comments. Do not summarize, restate, or moralize in the review body. Build the JSON in a temp file (use a heredoc piped through `jq -n` with `--argjson comments` or write the file directly) and submit it:

```bash
gh api "repos/<owner>/<repo>/pulls/<PR_NUMBER>/reviews" \
  --method POST \
  --input /tmp/pr-review-payload.json
```

Submitting via `--input` (not individual `-f` flags) is required because the `comments` field is a JSON array; `gh api` flag forms can't express it cleanly.

Failure handling:
- If GitHub returns 422 with "Pull request review thread line must be part of the diff" for one or more `comments` entries, the whole review submission fails. Identify the offending entries by re-validating each `path:line` against `gh api .../pulls/N/files --jq '.[] | {filename, patch}'`, convert any anchor that doesn't land on a `+` line in the patch to its diff-hunk `position` (drop `line`/`side`, add `"position": <n>` to that entry), and resubmit.
- If a single comment is irretrievably unanchorable, surface it to the user, drop it from the payload, and resubmit the rest. Don't silently discard.

Delete the temp payload file after a successful submission.

## Step 7: Summary

After the review submits, print:
- the review URL (the API response's `html_url`) and its state (`Changes requested`)
- count of inline comments included in the review
- count of drafts skipped, canceled, or dropped due to anchoring failures (with paths)
- the PR URL

Stop after the summary.

## Hard constraints

- Always submit posted comments as a single `REQUEST_CHANGES` review, never as standalone line comments and never as `APPROVE` or `COMMENT`. If the user only ran `/pr-review` and approved drafts, requesting changes is the correct outcome.
- Never run `gh pr checkout`, `git checkout`, or any branch-switching command. The user picks the working tree.
- Never use `--no-verify` or any hook-skip flag.
- Never post a comment the user has not explicitly approved this turn.
- Never edit local files outside of a temporary review-payload file under `/tmp` that gets deleted on success. This command is read-only on the working tree and write-only on GitHub.
- Never use em dashes anywhere, including in user-facing output and comment drafts.
