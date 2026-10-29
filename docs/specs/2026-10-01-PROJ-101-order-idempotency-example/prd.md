# PRD: Order Creation Idempotency (`PROJ-101`)

## 1. Problem Statement
Clients retrying `POST /v1/orders` after network timeouts occasionally create duplicate orders when the initial request succeeded on the server.

## 2. Goals & Scope
- **In Scope (`orders-service`):** Support an `Idempotency-Key` HTTP header on `POST /v1/orders` with a 24-hour retention window.
- **Out of Scope:** Payment gateway settlement batching and historical duplicate order cleanup.

## 3. Functional Requirements
- **FR-1 (Idempotent Replay):** When `POST /v1/orders` receives an `Idempotency-Key` that already completed with the same request payload hash within 24 hours, return the stored HTTP status and response body without creating a new order.
- **FR-2 (Payload Conflict Detection):** When the same `Idempotency-Key` is reused with a different request payload hash, reject the request with `422 Unprocessable Entity` (`IDEMPOTENCY_PAYLOAD_MISMATCH`).
- **FR-3 (Concurrent In-Flight Protection):** When a second request arrives with the same `Idempotency-Key` while the first request is still in progress, return `409 Conflict` (`IDEMPOTENCY_IN_PROGRESS`).

## 4. Acceptance Criteria
- **AC-1:** Repeating `POST /v1/orders` with the same `Idempotency-Key` and payload returns `201 Created` (with `Idempotent-Replayed: true` header) and creates exactly one database record.
- **AC-2:** Repeating `POST /v1/orders` with the same `Idempotency-Key` and a modified `amount` returns `422 Unprocessable Entity`.
- **AC-3:** Requests without `Idempotency-Key` remain backward-compatible and process normally.

