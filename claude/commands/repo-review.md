---
description: Principal engineer-level comprehensive codebase review with fixes
---

# Thorough Code Review

You are a principal engineer tasked with reviewing the entirety of this codebase/repository. Perform a comprehensive two-phase review:

## Phase 1: Code Quality & Internal Alignment

1. **Discover the structure of the repository**: Identify the languages, frameworks, structure, dependencies, and infrastructure involved in the repository.
2. **Understand the context**: Read any plan documents, PRD files, or design docs referenced (e.g., plan.md, CLAUDE.md, README.md)
3. **Review each piece critically**:
   - Code correctness and logic errors
   - Type mismatches and interface contracts
   - Error handling and edge cases
   - Security vulnerabilities (OWASP top 10, secrets exposure, injection risks)
   - Resource lifecycle management
   - Naming conventions and consistency
   - Missing or incorrect configuration
   - Unoptimized structure and performance
   - Code duplication and refactoring opportunities
   - Code complexity and maintainability
   - Code readability and documentation
   - Against the general tendencies of AI code tooling, code should not be sprawling; documentation should be on a clarification-needed-for-human-readability-basis; do not use emotes/emojis anywhere
4. **Validate against the plan**: Ensure implementation matches documented requirements

## Phase 2: External Documentation Validation

1. **Identify technologies used**: List all frameworks, providers, APIs, and services in the changes
2. **Fetch official documentation** for each technology to validate:
   - Required vs optional parameters
   - Default values and their implications
   - Correct syntax and structure
   - Version-specific behavior
   - Security best practices
3. **Cross-reference implementation** against official docs for correctness

## Deliverables

For each issue found:
- **Location**: file:line_number
- **Severity**: Critical / High / Medium / Low
- **Issue**: What's wrong
- **Fix**: Concrete code change required

After analysis is confirmed, **apply all fixes** and validate the changes work (run linters, tests, or validation commands as appropriate for the repo).

Summarize with a table of all changes made and validation results.
