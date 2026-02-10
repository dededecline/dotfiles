---
name: generate_docs
description: "Generate all documentation (api_design, architecture, features, data_model, product) in parallel, then review for consistency."
model: opus
permissionMode: acceptEdits
color: blue
---

# Generate All Documentation

Generate comprehensive documentation suite for THIS SPECIFIC REPOSITORY.

CRITICAL: Repository-Specific Focus**

Each documentation file will focus on THIS repository's specific contributions, not the overall product or system. Before generating docs, you MUST understand:

- What this repository's purpose is
- What user-facing or system capabilities it enables
- What type of component it is (frontend, backend, library, service, etc.)

## Execution Plan

### Phase 1: Parallel Documentation Generation

Launch 5 specialized agents in parallel to generate documentation:

1. **API Reference Agent**: Generate docs/api_design.md
   - Use Task tool with subagent_type="generate_api_docs"

2. **Architecture Agent**: Generate docs/architecture.md
   - Use Task tool with subagent_type="generate_architecture_docs"

3. **Features Agent**: Generate docs/features.md
   - Use Task tool with subagent_type="generate_code_feature_docs"

4. **Data Model Agent**: Generate docs/data_model.md
   - Use Task tool with subagent_type="generate_data_model_docs"

5. **Product Agent**: Generate docs/product.md
   - Use Task tool with subagent_type="generate_product_docs"

**IMPORTANT**: Launch all 5 agents in a SINGLE message using 5 separate Task tool calls to maximize parallelization.

### Phase 2: Consistency Review

After all 5 agents complete, launch a review agent using the Task tool with subagent_type="general-purpose":

**Review Agent Task:**

```txt
Read all 5 generated documentation files:
- docs/api_design.md
- docs/architecture.md
- docs/features.md
- docs/data_model.md
- docs/product.md

Review for consistency issues and fix:

1. **Cross-References**: Ensure all cross-references between docs are accurate
   - api_design mentions → architecture, data_model, features, product
   - architecture mentions → api_design, data_model, features, product
   - features mentions → api_design, architecture, data_model, product
   - data_model mentions → api_design, architecture, features, product
   - product mentions → api_design, architecture, features, data_model

2. **Terminology Consistency**:
   - Entity/table/collection names match across docs
   - Component names match across docs
   - Feature names match across docs
   - Technology stack names consistent

3. **File Path References**:
   - File paths mentioned are consistent across docs
   - Directory structures align

4. **Naming Conventions**:
   - API endpoint naming consistent between api_design and features
   - Database entity names consistent between data_model and other docs
   - Service/component names consistent across all docs

5. **Missing Cross-References**:
   - Add "See data_model.md for User schema" where User entity mentioned
   - Add "See api_design.md for /auth/* endpoints" where auth mentioned
   - Add "See features.md for feature details" where features mentioned
   - Add "See architecture.md for component details" where architecture mentioned
   - Add "See product.md for user-facing impact" where UX concerns mentioned

Make minimal edits using the Edit tool to fix any inconsistencies found.
Only fix actual inconsistencies - do not rewrite or restructure content.

Report summary of changes made.
```

## Expected Output

After completion, the docs/ directory should contain:

- docs/api_design.md
- docs/architecture.md
- docs/features.md
- docs/data_model.md
- docs/product.md

All documents should be internally consistent with accurate cross-references.

## Instructions

When this skill is invoked:

1. **Inform the user** that you're generating all 5 documentation files in parallel
2. **Launch all 5 Task tool calls in parallel** in a single message
3. **Wait for all 5 to complete**
4. **Inform the user** that you're now reviewing for consistency
5. **Launch the review agent** using Task tool with the review task above
6. **Report completion** with links to all generated files
