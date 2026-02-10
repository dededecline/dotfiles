---
name: generate_api_docs
description: "Generate api_design.md documenting API architecture, patterns, and usage context for AI agents working in this codebase."
model: opus
permissionMode: acceptEdits
color: blue
---

# API Reference Documentation

Generate docs/api_design.md documenting THIS REPOSITORY's API architecture, patterns, and usage context.

## Scope

CRITICAL: Repository-Specific Focus**

This document focuses on **APIs defined in THIS REPOSITORY ONLY**. Do not document:

- APIs from other repositories or services (only mention them when this repo interacts with them)
- The entire system's API architecture (only this repo's contribution)
- APIs this repo consumes (unless critical to understanding this repo's API design)

**Before writing, you MUST**:

1. Identify what APIs THIS repo exposes (REST endpoints, GraphQL schema, gRPC services, SDK methods, etc.)
2. Understand if this is a backend API service, a frontend making API calls, or a library exposing programmatic APIs
3. If this repo has no APIs, clearly state that and skip the documentation

**Note:** Swagger/OpenAPI docs already provide exhaustive endpoint specifications. This document should provide the **conceptual framework** and **patterns** for THIS REPO's APIs specifically.

## Required Sections

### 1. API Overview for This Repo

- **Repository Role**: What APIs does THIS repo provide? (e.g., "This repo exposes a REST API for user management", "This repo is a GraphQL gateway", "This repo provides an SDK library")
- **Base URL(s)**: URLs where THIS repo's APIs are accessed (if applicable)
- **Versioning Strategy**: How THIS repo versions its APIs
- **Authentication/Authorization**: How THIS repo handles auth (implements it, validates tokens, passes through, etc.)
- **Middleware Chain**: Middleware specific to THIS repo's API layer
- **Response Patterns**: Response format and status codes THIS repo uses
- **Error Format**: Error response structure THIS repo returns

### 2. Architectural Patterns

**Error Handling & Validation:**

- Common validation patterns across endpoints
- Where validation occurs (middleware, controller, service layer)
- Standard error codes and what triggers them
- How validation errors vs. business logic errors are distinguished

**Data Flow Patterns:**

- Typical request lifecycle: `Request → Middleware → Controller → Service → Repository → Database`
- Where transformations happen (DTOs, serializers, etc.)
- Authentication/authorization check points in the flow

### 3. Endpoint Organization by Domain in This Repo

Group endpoints **that THIS REPO exposes** by feature/resource and document:

**For each domain/resource group in THIS repo:**

```md
### User Management API

**Endpoints**: `/api/v1/users/*`
**Source**: User input via forms, admin actions
**Sinks**: PostgreSQL `users` table, Redis cache, email service
**Authentication**: Bearer token required
**Key Patterns**:
- All mutations publish `user.updated` events to message queue
- Soft deletes used throughout
**Common Validations**:
- Email format validation
- Password strength requirements (see src/validators/password.ts)
**Related Docs**: See data_model.md for User entity schema
```

### 4. Sources and Sinks Mapping for This Repo

Create a table showing data flow patterns **for THIS REPO's APIs**:

| Endpoint Group | Primary Inputs | Primary Outputs | Side Effects |
| --------------- | --------------- | ----------------- | -------------- |
| `/auth/*` | User credentials | JWT tokens | Session creation in Redis |
| `/users/*` | Form data, admin updates | User records | DB writes, cache invalidation, events |
| `/webhooks/*` | External service payloads | Acknowledgments | Queue jobs, DB updates |

### 5. Async Patterns

**Webhooks & Events:**

- Inbound webhooks (if any): signature verification, retry logic
- Outbound webhooks: delivery guarantees, failure handling
- Event publications: what events are emitted, where they go
- Background job triggers: which endpoints queue jobs vs. process synchronously

**Example:**

```txt
POST /api/v1/orders → Synchronous DB write + Async event emission
  → Event: "order.created" published to RabbitMQ
  → Consumed by: inventory-service, email-service
```

### 6. SDK/Client Integration

- Official client libraries (languages, repositories)
- Client-specific considerations (rate limiting, retry strategies)
- Code examples if clients have unique patterns

### 7. Security & Rate Limiting

- Rate limit tiers by authentication level
- CORS policies
- Request size limits
- Security headers
- Sensitive endpoints and extra protections

### 8. Development & Testing

- How to authenticate in local/dev environments
- Test data fixtures or seeding
- Mock endpoints or test modes
- Swagger UI location for interactive testing

## Formatting Guidelines

- Use Mermaid sequence diagrams for complex flows
- Link to related documentation (architecture.md, data_model.md)
- Include file paths to relevant code (controllers, middleware, validators)
- Provide minimal but illustrative code examples
- Use tables for organized pattern comparisons

## What NOT to Include

- **APIs from other repositories**: Only document APIs THIS repo exposes
- **Complete system API architecture**: Focus only on this repo's API layer
- Exhaustive listing of every endpoint (that's Swagger's job)
- Complete request/response schemas for each endpoint
- Detailed field-by-field parameter descriptions
- APIs this repo consumes (unless explaining how this repo's APIs integrate with them)

## Output

Write the complete document to `docs/api_design.md` following this structure, **focusing specifically on APIs defined in THIS REPOSITORY**.

**Key Principles**:

1. **Repo-specific focus**: Only document APIs THIS repo exposes
2. **Clear boundaries**: When mentioning external APIs, clarify they're not part of this repo
3. **Concrete examples**: Use actual endpoints and file paths from THIS repo
4. **Skip if N/A**: If this repo doesn't expose APIs, state that clearly and skip the doc

**Before you start writing**:

- Explore the codebase to identify what APIs this repo exposes (REST, GraphQL, gRPC, SDK, etc.)
- Determine if this repo even has APIs to document
- Only document API patterns and endpoints defined in THIS repository

**IMPORTANT - Last Updated Header:**

Before writing the document, run the following bash command to get the current date:

```bash
date +"%B %d, %Y"
```

Add a "Last Updated" header at the very top of the document using the date from the bash command:

```md
# API Reference Documentation

**Last Updated:** [Date from bash command]

[Rest of document content...]
```
