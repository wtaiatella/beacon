---
profile: lean
ticket: PROJ-101
repos:
  - orders-service
---

# Technical Specification: Order Creation Idempotency (`PROJ-101`)

## 1. Architecture Overview
Add an idempotency middleware and storage adapter around `OrderController.createOrder` in `orders-service`.

| Component | Responsibility |
|-----------|----------------|
| `IdempotencyInterceptor` | Extracts `Idempotency-Key` (max 128 ASCII chars), computes SHA-256 canonical body hash, and coordinates lock/replay lifecycle. |
| `IdempotencyStore` | Persists key state (`IN_PROGRESS`, `COMPLETED`) with `request_hash`, `status_code`, `response_body`, and `expires_at` (TTL 24h). |

## 2. Data Model & Contract
- Header: `Idempotency-Key: <string, 1..128 chars>`
- Response header on replay: `Idempotent-Replayed: true`
- Error codes:
  - `409 Conflict` (`IDEMPOTENCY_IN_PROGRESS`)
  - `422 Unprocessable Entity` (`IDEMPOTENCY_PAYLOAD_MISMATCH`)

## 3. Testing Strategy
- Unit tests for `IdempotencyInterceptor` hash comparison and TTL expiry.
- Integration test for `POST /v1/orders` covering replay (`AC-1`), payload mismatch (`AC-2`), in-flight lock (`FR-3`), and missing header (`AC-3`).

