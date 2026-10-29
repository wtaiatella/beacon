# Tasks: Order Creation Idempotency (`PROJ-101`)

### Phase 1: Storage & Core Interceptor
- [x] **T-1** `[dev:orders-service]` Implement `IdempotencyStore` repository with atomic `acquireLock`, `saveResult`, and 24-hour TTL lookup *(covers FR-1, FR-3)*.
- [x] **T-2** `[dev:orders-service]` Implement `IdempotencyInterceptor` with SHA-256 request payload hashing, `409 Conflict` in-flight response, and `422 Unprocessable Entity` mismatch detection *(covers FR-1, FR-2, FR-3)*.

### Phase 2: Controller Wiring & Verification
- [x] **T-3** `[dev:orders-service]` Wire `IdempotencyInterceptor` onto `POST /v1/orders` and emit `Idempotent-Replayed: true` on cached responses *(covers AC-1, AC-3)*.
- [x] **T-4** `[dev:orders-service]` Add unit and integration tests for replay, payload mismatch, concurrent lock, and backward compatibility *(covers AC-1, AC-2, AC-3)*.

