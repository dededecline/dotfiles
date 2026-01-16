# Claude Code Agents

Think of CC Agents like subdirectories in a larger repo. They let us isolate specific tools, prompts, and context into a single chain of thought.

## Available Agents

### 🟢 linear-refiner

**Purpose**: Analyzes Linear tickets and creates detailed implementation plans  
**When to use**: Need to break down complex tickets into actionable development steps  
**Specializes in**: Requirement analysis, task prioritization, implementation planning  
**Output**: Structured plan.md files with clear acceptance criteria. NOTE: Requires linear MCP install & auth.

### 🟡 web-docs-researcher

**Purpose**: Searches for official documentation and authoritative technical information  
**When to use**: Need current, official information about frameworks, libraries, or technologies  
**Specializes in**: Finding official docs, recent updates, migration guides  
**Output**: Synthesized information from authoritative sources with citations

## Contributing

When adding new agents:

1. [RTFM](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
2. Include examples in the description.
3. Define specific responsibilities and workflows. "An agent that works on implementing features" doesn't need to be an agent, that's just using claude code.
4. Use least-privlige access to tools and capabilities; staying focused will improve usefulness.
