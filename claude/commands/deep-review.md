---
description: Parallel security + code quality review of changes across one or more repos using dual Opus agents
argument-hint: <repo-path...> [--uncommitted] [--fix]
model: opus
effort: high
allowed-tools: Agent Bash Read Grep Glob
disable-model-invocation: true
---

# Deep Review

Run a parallel security review and code quality review across one or more repositories. Each repo gets two dedicated Opus agents working simultaneously.

## Argument Parsing

Parse `$ARGUMENTS` into:
- **Repo paths**: every argument that does NOT start with `--`
- **`--uncommitted`** flag: if present, diff only unstaged + staged changes; otherwise diff the full branch against the default branch (all PR changes)
- **`--fix`** flag: if present, apply fixes after review; otherwise report-only (no edits)

If no repo paths are provided, print usage and stop:
```
Usage: /deep-review <repo-path...> [--uncommitted] [--fix]
```

## Step 1: Gather Diffs

For each repo path, run git commands to determine the scope of changes:

**Default (branch diff — full PR scope):**
```bash
git -C <repo> diff --merge-base origin/HEAD
git -C <repo> diff --merge-base origin/HEAD --name-only
```
If `origin/HEAD` is unset, fall back to `main` or `master`.

**With `--uncommitted`:**
```bash
git -C <repo> diff
git -C <repo> diff --cached
git -C <repo> status --short
```

If a repo has no changes, skip it and note that in the output.

## Step 2: Launch Parallel Agents

For each repo with changes, launch **two agents in a single message** (parallel). Both must use `model: "opus"`.

If `--fix` is NOT set, both agents must be told: **Do NOT modify any files. Analysis and reporting only.**

If `--fix` IS set, both agents should: report findings first, then apply fixes and run any available linters/tests to validate.

---

### Agent 1: Security Review

Prompt each security agent with the repo path, the list of changed files, and these instructions:

> You are a security reviewer analyzing changes in `<repo-path>`. Your working directory for all commands is `<repo-path>`.
>
> **Objective**: Identify HIGH-CONFIDENCE security vulnerabilities with real exploitation potential. This is not a general code review — focus ONLY on security implications.
>
> **Gather context** by reading changed files and surrounding code to understand security frameworks, sanitization patterns, and the project's threat model.
>
> **Categories to examine**:
> - Input validation: SQL injection, command injection, XXE, template injection, NoSQL injection, path traversal
> - Auth & authz: authentication bypass, privilege escalation, session flaws, JWT issues
> - Crypto & secrets: hardcoded credentials, weak algorithms, improper key storage
> - Injection & RCE: deserialization, pickle/YAML injection, eval injection, XSS (reflected/stored/DOM)
> - Data exposure: sensitive data logging, PII violations, API data leakage, debug info exposure
>
> **Methodology**:
> 1. Research repository context — identify existing security patterns and frameworks
> 2. Comparative analysis — compare new code against established secure practices
> 3. Vulnerability assessment — trace data flow from user inputs to sensitive operations
>
> **Confidence threshold**: Only report findings with confidence >= 8/10. Skip anything speculative.
>
> **Hard exclusions** (do NOT report these):
> - DOS/resource exhaustion
> - Secrets stored on disk
> - Rate limiting concerns
> - Memory safety in memory-safe languages
> - Test-only files
> - Log spoofing
> - SSRF controlling only the path (not host/protocol)
> - AI prompt injection
> - Regex injection/DOS
> - Findings in documentation files
> - Lack of audit logs or hardening measures
> - Race conditions without concrete exploitation path
> - Outdated dependency vulnerabilities
>
> **Precedents**:
> - Logging URLs is safe; logging secrets/PII is not
> - UUIDs are unguessable
> - Environment variables and CLI flags are trusted
> - React/Angular are XSS-safe unless using unsafe innerHTML methods (e.g. React's dangerouslySetInnerHTML or Angular's bypassSecurityTrustHtml)
> - Client-side code doesn't need auth checks — that's the server's job
> - Shell script command injection is only valid with untrusted input paths
>
> **Output format** — for each finding:
> ```
> ## [SEVERITY] Category: file:line
> - Description: ...
> - Exploit scenario: ...
> - Confidence: X/10
> - Recommendation: ...
> ```
>
> Report only HIGH and MEDIUM severity findings. If nothing meets the threshold, state: "No high-confidence security issues found."
>
> [If --fix]: After reporting, apply all recommended fixes. Run linters/tests if available. Report what was fixed and validation results.

---

### Agent 2: Code Quality Review

Prompt each code quality agent with the repo path, the list of changed files, and these instructions:

> You are a principal engineer reviewing changes in `<repo-path>`. Your working directory for all commands is `<repo-path>`.
>
> **Phase 1 — Code Quality & Internal Alignment**:
> 1. Read all changed files and understand the context (CLAUDE.md, README, plan docs)
> 2. Review each change for:
>    - Code correctness and logic errors
>    - Type mismatches and interface contracts
>    - Error handling and edge cases
>    - Resource lifecycle management (leaks, dangling handles)
>    - Naming conventions and consistency with codebase patterns
>    - Missing or incorrect configuration
>    - Dead code or unused imports introduced by the changes
> 3. Validate implementation matches any documented plan or requirements
>
> **Phase 2 — External Documentation Validation**:
> 1. Identify all frameworks, APIs, and services used in the changes
> 2. Validate against official documentation:
>    - Required vs optional parameters
>    - Default values and their implications
>    - Correct syntax, structure, and version-specific behavior
>    - Security and performance best practices
> 3. Cross-reference the implementation against docs for correctness
>
> **Output format** — for each finding:
> ```
> ## [SEVERITY] Category: file:line
> - Issue: ...
> - Fix: concrete code change required
> ```
>
> Severity levels: Critical / High / Medium / Low. Focus on Critical, High, and Medium.
>
> If no issues found, state: "No significant code quality issues found."
>
> [If --fix]: After reporting, apply all fixes. Run linters, type checkers, and tests if available. Summarize what was fixed and validation results.

---

## Step 3: Collate Findings

After all agents complete, combine their results into a single report:

1. **Deduplicate**: if both agents flagged the same issue (e.g., both found an injection vulnerability), merge into one entry noting both perspectives
2. **Sort by severity**: Critical > High > Medium > Low
3. **Group by repo** if multiple repos were reviewed

## Output Format

```markdown
# Deep Review Report

## <repo-name> (N findings)

### Critical
- ...

### High
- ...

### Medium
- ...

---
[If --fix]: ## Fixes Applied
- ...
## Validation Results
- ...
```

If all repos are clean: **"All reviews passed — no significant issues found."**
