---
name: spectech-analyzer
description: "Codebase analyzer that proposes testing patterns and architecture style aligned with existing project. Combines test-harness-analyzer + architecture-detailer."
---

# Spectech Analyzer

## When to Use

- At the **start** of `/spectech` before generating spectech.md
- To analyze existing codebase and propose design aligned with project patterns
- To ensure consistency with how this team tests and architects

Output: Analysis report with recommended patterns + guidelines

## Two-Phase Analysis

### Phase 1: Test Harness Analysis

Scans codebase to understand existing testing patterns:

**What it finds:**

1. **Test Framework Stack**
   - Unit test framework (Jest, pytest, RSpec, etc)
   - Integration test framework (if different)
   - E2E test framework (Cypress, Playwright, Selenium, etc)
   - Mocking libraries (jest.mock, Sinon, unittest.mock, etc)

2. **Test Organization**
   - Where tests live (same dir as code? separate __tests__? tests/ folder?)
   - Naming convention (*.test.js? *.spec.js? _test.go?)
   - Test data fixtures (in code? separate files? factories?)

3. **Testing Patterns by Layer**
   - **Unit tests:** What gets tested? Individual functions? Classes? Modules?
   - **Integration tests:** Which systems tested together? Database? APIs?
   - **E2E tests:** Which user flows? Happy path? Error flows?
   - **Patterns:** TDD? AAA (Arrange-Act-Assert)? BDD?

4. **Test Coverage Standards**
   - Minimum coverage % enforced?
   - Critical paths require 100%?
   - Optional coverage?
   - Coverage tools used (Istanbul, coverage.py, etc)?

5. **CI/CD Test Integration**
   - Tests run on every commit?
   - Required to pass for merge?
   - Performance test gates?
   - Coverage gates?

### Phase 2: Architecture Pattern Analysis

Scans codebase for architectural patterns to inform design:

**What it finds:**

1. **Layering / Separation of Concerns**
   - MVC? MVVM? Clean Architecture?
   - Service layer? Repository pattern?
   - Domain-driven design elements?
   - Dependency injection?

2. **API Design Patterns**
   - REST conventions (GET /users/:id)?
   - GraphQL (if present)?
   - gRPC (if present)?
   - Versioning (v1/ in path)? (in header)?
   - Error response format?
   - Pagination standard?

3. **Database Patterns**
   - ORM used (ActiveRecord, Sequelize, SQLAlchemy)?
   - Migration framework?
   - Transaction handling?
   - Indexing patterns?

4. **Error Handling Convention**
   - Custom error classes?
   - Error codes / error strings?
   - Stacktrace handling?
   - Logging of errors?

5. **Configuration Management**
   - Environment variables (.env)?
   - Config files (yaml, toml)?
   - Secrets handling?

6. **Observability Patterns**
   - Logging library + format (JSON? structured logs)?
   - Metrics collection (Prometheus, StatsD)?
   - Tracing (OpenTelemetry)?
   - Log levels convention?

## Analysis Output

### Phase 1: Test Patterns Report

```markdown
## Test Harness Analysis

### Testing Stack Detected

**Unit Tests:** Jest + ts-jest
- Location: `src/**/__tests__/*.test.ts`
- Naming: `*.test.ts`
- Coverage tool: Istanbul (configured in jest.config.js)
- Target coverage: 80% (enforced in CI)

**Integration Tests:** Jest + test containers
- Tests database interactions
- Location: `src/__tests__/integration/`
- Naming: `*.integration.test.ts`
- Runs against real PostgreSQL (testcontainers)

**E2E Tests:** Cypress
- Location: `e2e/specs/*.cy.ts`
- Focuses on user critical paths
- Runs in CI before deploy

### Testing Patterns Observed

**Unit Test Structure:** AAA (Arrange-Act-Assert)
```typescript
describe('calculateTrialExpiration', () => {
  it('should return 14 days from now', () => {
    // Arrange
    const today = new Date('2026-07-11');
    
    // Act
    const expiration = calculateTrialExpiration(today);
    
    // Assert
    expect(expiration).toEqual(new Date('2026-07-25'));
  });
});
```

**Integration Test Pattern:** Database setup + teardown
- Uses transactions to rollback after each test
- Fixtures for user/account setup
- Database state asserted after operations

**E2E Test Focus:** User critical paths
- Login → Start trial → View status → Cancel
- NOT all edge cases (those are unit tested)
- Focus on happy path + one error case per flow

### Recommendations for This Feature

**For Unit Tests:**
- Follow AAA structure
- Test each acceptance criterion with a unit test
- Mock external services (Stripe API)
- Aim for 85%+ coverage on trial logic

**For Integration Tests:**
- Test trial creation end-to-end with DB
- Test trial status queries
- Validate constraints (unique trial per email)

**For E2E Tests:**
- Test user signup → trial active flow
- Test trial expiration flow
- NOT needed: detailed error cases (unit tested)

### Coverage Gates to Implement

```
jest --coverage --threshold 85
```

All payment-related code should hit 85%+ coverage.
```

### Summary

**Consistency:** ✅ Follows project patterns  
**Coverage:** ✅ Propose 85%+ for trial logic  
**Patterns:** ✅ Use AAA for units, DB transactions for integration, critical paths for E2E
```

### Phase 2: Architecture Patterns Report

```markdown
## Architecture Pattern Analysis

### Detected Patterns

**Layering:** Clean Architecture (Domain → Service → Route)
```
src/
├── domain/                    # Business logic (no DB/API deps)
│   └── trial.ts               # Trial calculation, validation
├── service/                   # Use cases (domain + persistence)
│   └── trial-service.ts       # Create trial, fetch status
├── persistence/               # Database access
│   └── trial-repository.ts    # Trial CRUD
└── routes/                    # HTTP handlers
    └── trial-routes.ts        # GET/POST endpoints
```

**API Design:** RESTful with standard conventions
- Endpoints: `POST /api/trials`, `GET /api/trials/:id`
- Status codes: 200 (success), 400 (validation), 409 (conflict), 500 (error)
- Error format: `{ error: "message", code: "ERROR_CODE" }`
- Pagination: `?skip=0&limit=20`

**Database Access:** Repository Pattern
- `TrialRepository` (CRUD operations)
- ORM: Sequelize (with migrations)
- Transactions: Automatic in service layer

**Error Handling:** Custom error classes
```typescript
class TrialAlreadyExistsError extends ApplicationError {
  constructor(email: string) {
    super(`Trial already exists for ${email}`, 'TRIAL_ALREADY_EXISTS');
  }
}
```

**Observability:** Structured logging (Winston)
```typescript
logger.info('trial_created', {
  trialId: trial.id,
  email: trial.email,
  expiresAt: trial.expiresAt
});
```

### Recommendations for This Feature

**Domain Layer (trial.ts):**
- `calculateExpiration(startDate) → Date`
- `isExpired(trial) → boolean`
- Validation functions (email, duration)

**Service Layer (trial-service.ts):**
- `createTrial(email, durationDays)`
- `getTrialStatus(trialId)`
- Error handling for Stripe integration

**Repository Layer (trial-repository.ts):**
- Standard CRUD
- Unique index on (user_id, email)

**Routes Layer (trial-routes.ts):**
- `POST /api/trials` → calls service
- `GET /api/trials/:id` → calls service
- Error responses follow format

**Database:**
- Use migration framework
- Transactions in service layer
- Constraints at DB level

**Observability:**
- Log trial creation/deletion
- Log Stripe integration calls
- Structured JSON format

### Summary

**Consistency:** ✅ Aligns with project architecture  
**Patterns:** ✅ Clean Architecture + Repository + Custom Errors  
**Observability:** ✅ Structured logging, follow Winston conventions
```

## Integration with /spectech

When `/spectech` starts:

1. Run this analyzer on the codebase
2. Generate analysis report (test patterns + arch patterns)
3. Present findings to agent
4. Agent uses findings to structure spectech.md with:
   - Testing strategy aligned with existing patterns
   - Architecture aligned with existing patterns
   - Code examples following project conventions
5. Output: spectech.md that is **solid, consistent, implementable**

## Notes

- **Not prescriptive** — doesn't dictate patterns, analyzes what exists
- **Consistency-focused** — proposes following what the team already does
- **Implementable** — designs that match how the codebase is structured
- **Clear contracts** — patterns spelled out so implementers know exactly what's expected

## Tool Requirements

- `Bash` — to run grep/find over codebase
- `Read` — to examine code files
- `Glob` — to find test files, config files

## Output Files

1. `analysis.md` — Full report (patterns found + recommendations)
2. Returned to agent as context for generating spectech.md

No files written to the project; output is guidance only.
