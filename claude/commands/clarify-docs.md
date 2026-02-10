---
name: clarify-docs
description: Analyzes documentation files in the docs directory to identify inconsistencies, gaps, and unclear information. Automatically investigates the codebase to answer questions, and only prompts the user for clarifications that can't be resolved from code. Updates documentation with improved, clarified information.
argument-hint: [docs-directory-path]
---

# Documentation Clarification Assistant

This command helps improve documentation quality by:

1. Reading all documentation files in the specified directory (defaults to `docs/`)
2. Analyzing content for inconsistencies, gaps, and unclear information
3. **Investigating the codebase** to answer questions automatically
4. Asking the user only high-priority questions that couldn't be answered from code
5. Updating documentation files with improved, clarified information

## How It Works

### Phase 1: Documentation Discovery and Analysis

1. **Scan the docs directory** - Find all markdown files in `$ARGUMENTS` (defaults to `docs/`)
2. **Read all documentation files** - Load content from each file
3. **Analyze for issues** including:
   - Missing or incomplete sections
   - Inconsistent terminology across files
   - Vague or ambiguous descriptions
   - Outdated examples or information
   - Broken internal cross-references
   - Conflicting information between files
   - Missing code examples or unclear instructions
   - Undefined acronyms or technical terms

### Phase 2: Code Investigation

For each clarification question identified in Phase 1, **automatically investigate the codebase** to find answers:

1. **Spawn subtask agents** (using Task tool with subagent_type=Explore or general-purpose):
   - One subtask per question or group of related questions
   - Each subtask investigates the codebase to answer its assigned question
   - Subtasks search for relevant code, configurations, and implementations

2. **Confidence assessment** for each answer:
   - **High confidence (>80%)** - Clear, unambiguous answer found in code
   - **Medium confidence (50-80%)** - Likely answer found, but some ambiguity
   - **Low confidence (<50%)** - No clear answer or conflicting information found

3. **Categorize results**:
   - **Auto-resolved** - High confidence answers that can update docs directly
   - **Needs user review** - Medium confidence answers to present as options
   - **Needs user input** - Low confidence or no answer found, must ask user

4. **Run subtasks in parallel** when possible to maximize efficiency

### Phase 3: User Clarification

**Only for questions that couldn't be auto-resolved from the codebase:**

1. **Compile remaining questions** organized by:
   - File location and section
   - Type of issue (inconsistency, missing info, ambiguity)
   - Priority (critical vs. nice-to-have)
   - Include findings from code investigation (medium confidence answers as options)

2. **Present questions to user** using AskUserQuestion tool:
   - Ask up to 4 questions at a time
   - Group related questions together
   - Provide context: file location, current text, what was found in code (if anything)
   - For medium confidence answers, present them as suggested options

3. **Collect user responses** for questions that require human judgment

### Phase 4: Documentation Updates

1. **Update each file** with clarified information:
   - Incorporate answers from code investigation (high confidence)
   - Incorporate user answers for questions asked
   - Fix inconsistencies across files
   - Add missing sections or details
   - Improve clarity and precision
   - Ensure consistent terminology
2. **Verify cross-references** are accurate
3. **Add any necessary examples** or clarifications from code

## Usage

```bash
# Clarify docs in the default docs/ directory
/clarify-docs

# Clarify docs in a specific directory
/clarify-docs documentation/

# Clarify docs in a subdirectory
/clarify-docs docs/api/
```

## Expected Output

After running this command, you will:

1. See a summary of files analyzed and issues found
2. See a report of questions automatically answered from code investigation
3. Be prompted with **only** clarification questions that couldn't be auto-resolved (in batches of up to 4)
4. Receive a summary of changes made to each file, including:
   - Auto-resolved updates from code
   - User-clarified updates
5. Have updated documentation files with improved clarity and consistency

## Best Practices

- **Be specific in answers** - Provide concrete details rather than vague descriptions
- **Consider consistency** - Ensure terminology matches across all documentation
- **Provide examples** - When asked, real code examples help clarify concepts
- **Review changes** - Check the updated files to ensure accuracy

## Common Clarification Areas

This command typically identifies questions about:

- **Architecture decisions** - Why certain approaches were chosen
- **API specifications** - Exact parameter types, return values, error codes
- **Setup instructions** - Missing prerequisites or configuration steps
- **Feature usage** - Unclear workflows or use case examples
- **Terminology** - Inconsistent or undefined technical terms
- **Version information** - Which versions features were added/deprecated
- **Security considerations** - Authentication, authorization, data protection
- **Performance guidelines** - Expected latency, scaling limits, optimization tips

## Example Questions You Might Be Asked

These are questions that **couldn't be automatically resolved** from the codebase:

- "The architecture docs mention a 'queue service' but don't specify which technology. Is this RabbitMQ, AWS SQS, or something else?"
- "The API docs show a parameter called 'userId' in one place and 'user_id' in another. Which is correct?"
- "The setup guide says 'configure the database' but doesn't specify connection string format. What's the expected format?"
- "The feature docs mention 'real-time updates' but don't explain the mechanism. Is this WebSockets, Server-Sent Events, or polling?"

## Code Investigation Examples

**These questions would be AUTO-RESOLVED without asking you:**

### Example 1: Technology Stack

**Documentation Issue:** "Architecture docs mention 'cache layer' without specifying technology"

**Code Investigation:**

- Searches `package.json` → finds `redis` dependency
- Searches for imports → finds `import Redis from 'ioredis'` in multiple files
- Searches config files → finds Redis connection settings

**Result:** HIGH confidence (>80%) → Auto-updates docs: "Cache layer using Redis (ioredis client)"

### Example 2: API Parameter Naming

**Documentation Issue:** "Inconsistent user identifier naming: 'userId' vs 'user_id'"

**Code Investigation:**

- Searches TypeScript types → finds `interface User { userId: string }`
- Searches API routes → finds all endpoints use `userId` in JSON
- Searches database schema → finds `user_id` column in PostgreSQL

**Result:** MEDIUM confidence (50-80%) → Asks you: "Code uses 'userId' in TypeScript/API but 'user_id' in database. Which should docs use?" with both as options

### Example 3: Authentication Method

**Documentation Issue:** "Setup docs say 'configure authentication' with no details"

**Code Investigation:**

- Searches for auth imports → finds `@auth0/auth0-react`, `jsonwebtoken`
- Searches environment variables → finds `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`
- Searches middleware → finds JWT token validation

**Result:** HIGH confidence (>80%) → Auto-updates docs: "Authentication using Auth0 with JWT tokens (see src/middleware/auth.ts:23)"

### Example 4: Missing Architecture Decision

**Documentation Issue:** "Why was microservices architecture chosen over monolith?"

**Code Investigation:**

- Searches codebase → finds multiple service directories
- Searches docs → finds no architectural decision records
- Searches comments → finds no explanation

**Result:** LOW confidence (<50%) → Asks you: "Could not determine why microservices architecture was chosen. What was the reasoning?"

## Implementation Notes

**For Claude:** When executing this command:

### 1. Read Phase

- Use Glob tool to find all .md files: `docs/**/*.md` (or path from $ARGUMENTS)
- Use Read tool to load each file's content
- Keep track of file paths and their content

### 2. Analysis Phase

- Look for common documentation issues:
  - Placeholder text like "TODO", "TBD", "[Add details here]"
  - Inconsistent naming/terminology across files
  - Missing sections in standard docs (e.g., API docs without error codes)
  - Vague language: "might", "possibly", "usually"
  - Unexplained acronyms or technical terms
  - Conflicting information between files
  - Broken or missing cross-references
- Prioritize issues that affect user understanding
- **Create a structured list of questions**, each with:
  - Question text
  - File location and section
  - Type of issue
  - Why it matters
  - Priority level

### 3. Code Investigation Phase (NEW - CRITICAL)

**For each question identified, spawn a subtask to investigate the codebase:**

1. **Use Task tool to spawn investigation agents:**

   ```
   For questions about:
   - Architecture/technology choices → subagent_type=Explore
   - API specifications/implementations → subagent_type=Explore
   - Configuration/setup → subagent_type=Explore
   - Code examples/patterns → subagent_type=general-purpose
   ```

2. **Spawn multiple agents in parallel** for efficiency:
   - Group related questions if beneficial
   - Use a single message with multiple Task tool calls
   - Each agent gets a clear investigation prompt

3. **Example agent prompts:**

   ```
   "Investigate what queue technology is used in this codebase. Look for:
   - Import statements or dependencies (RabbitMQ, AWS SQS, Redis, etc.)
   - Queue configuration files
   - Service definitions that mention queuing
   Report findings with file locations and confidence level."
   ```

   ```
   "Find all API parameter naming conventions for user identifiers. Search for:
   - API route handlers and their parameter names
   - Database models/schemas with user ID fields
   - TypeScript types or schemas
   Determine if 'userId', 'user_id', or both are used, and where."
   ```

4. **Process agent results:**
   - Parse each agent's response
   - **Assess confidence level** based on:
     - Clarity of findings (explicit vs. inferred)
     - Consistency across codebase
     - Number of examples found
     - Any conflicting information
   - **Categorize each question:**
     - HIGH (>80%): Clear answer with multiple consistent examples
     - MEDIUM (50-80%): Likely answer but some ambiguity or few examples
     - LOW (<50%): No clear answer or conflicting information

5. **Track results:**

   ```
   Auto-resolved (HIGH confidence):
   - Question → Answer with code references

   Needs review (MEDIUM confidence):
   - Question → Suggested answer(s) with caveats

   Needs user input (LOW confidence):
   - Question → What was searched, why no clear answer
   ```

### 4. User Question Phase

**Only ask about questions NOT auto-resolved:**

1. **Compile remaining questions:**
   - Skip HIGH confidence questions (already answered)
   - For MEDIUM confidence: Present findings as suggested options in AskUserQuestion
   - For LOW confidence: Ask directly with context about what was searched

2. **Use AskUserQuestion tool:**
   - Ask up to 4 questions per batch
   - Provide full context:
     - File location and current text
     - Why clarification is needed
     - What was found in code investigation (if MEDIUM confidence)
   - For MEDIUM confidence answers: Include as options with "(Found in code)" suffix
   - Use multiSelect when appropriate (e.g., for feature lists)
   - Continue until all critical issues are addressed

3. **Example question with code findings:**

   ```json
   {
     "question": "The docs mention a 'queue service' but don't specify the technology. Based on code investigation, RabbitMQ was found in several places. Is this correct?",
     "header": "Queue Tech",
     "options": [
       {
         "label": "RabbitMQ (Found in code)",
         "description": "Found in src/services/queue.ts and package.json"
       },
       {
         "label": "AWS SQS",
         "description": "Use AWS Simple Queue Service instead"
       },
       {
         "label": "Redis",
         "description": "Use Redis as message queue"
       }
     ]
   }
   ```

### 5. Update Phase

**IMPORTANT - Update Last Updated Header:**

Before updating each documentation file, run the following bash command to get the current date:

```bash
date +"%B %d, %Y"
```

When updating a file:

1. If it already has a "**Last Updated:**" line near the top (after the title), update it with the new date
2. If it doesn't have this line, add it right after the main title heading:

```md
# Document Title

**Last Updated:** [Date from bash command]

[Rest of document content...]
```

Then proceed with content updates:

- Use Edit tool to update files with:
  - HIGH confidence answers from code investigation
  - User answers for questions asked (MEDIUM/LOW confidence)
- Maintain markdown formatting and structure
- Ensure consistency across all updated files
- Update cross-references if needed
- Preserve code blocks, links, and formatting
- **Add code references** from investigation (e.g., "See src/services/queue.ts:45")

### 6. Summary

- List all files updated
- Separate summary:
  - Auto-resolved: X questions answered from code
  - User-resolved: Y questions answered by user
- Summarize key improvements made
- Note any remaining issues that need future attention

## Key Principles

1. **Maximize automation** - Only ask users what truly requires human judgment
2. **Provide evidence** - Always cite code locations when auto-resolving
3. **Parallel processing** - Spawn investigation agents in parallel for speed
4. **Confidence-based routing** - HIGH → auto-update, MEDIUM → suggest to user, LOW → ask user
5. **Thorough investigation** - Search broadly (configs, code, tests, types) before asking
