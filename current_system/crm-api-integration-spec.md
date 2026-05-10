# CRM API Integration Spec — E-Commerce Auth Module

**For:** Legacy CRM Backend Team (Symfony4)
**From:** E-Commerce Backend Team (NestJS)
**Date:** 2026-05-09
**Version:** 1.0

---

## Overview

The new GTS e-commerce platform (NestJS) needs the legacy CRM (Symfony4) to expose three REST API endpoints. These are required to support two distinct flows:

1. **Admin authentication** — CRM staff log into the e-commerce backoffice using their existing CRM credentials. The e-commerce system does not store admin passwords; it delegates validation entirely to the CRM.
2. **Customer CRM account linking** — Registered e-commerce customers can optionally link their store account to their CRM customer record. This enables personalized pricing and order history visibility in future versions.

These endpoints do not exist in the current CRM API. This document specifies exactly what the e-commerce system expects so the CRM team can implement them.

---

## Authentication

All requests from the e-commerce system to the CRM include a static API key header:

```
x-api-key: <CRM_API_KEY>
```

The key value is agreed out-of-band and set as an environment variable on the e-commerce side (`CRM_API_KEY`). Requests without this header, or with an invalid key, must return `401 Unauthorized`.

---

## Base URL

The e-commerce system is configured via the `CRM_API_URL` environment variable. All paths below are relative to that base URL.

Example: if `CRM_API_URL = https://crm.greentek.internal`, then the full URL for endpoint 1 is:
```
POST https://crm.greentek.internal/api/auth/login
```

---

## Endpoints

### 1. Admin Login

**Purpose:** Validate CRM staff credentials and return their identity and roles.

```
POST /api/auth/login
Content-Type: application/json
x-api-key: <CRM_API_KEY>
```

**Request body:**

```json
{
  "email": "admin@greentek.com",
  "password": "their-crm-password"
}
```

**Success response — `200 OK`:**

```json
{
  "id": 42,
  "email": "admin@greentek.com",
  "firstName": "Carlos",
  "lastName": "Mendoza",
  "roles": ["ADMINISTRATOR"]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | `integer` | Unique CRM user ID. Used as the `sub` claim in the JWT issued by the e-commerce system. |
| `email` | `string` | Must match the email sent in the request. |
| `firstName` | `string` | Used for display in the backoffice UI. |
| `lastName` | `string` | Used for display in the backoffice UI. |
| `roles` | `string[]` | One or more roles. See valid values below. |

**Valid role values:**

| Value | Description |
|-------|-------------|
| `ADMINISTRATOR` | Full access to all backoffice modules |
| `MANAGER` | Access to orders, listings, inventory |
| `PURCHASINGREP` | Access to purchasing and inventory modules |
| `SALESREP` | Access to orders and customer modules |

> Role strings are **case-sensitive**. The e-commerce system compares them exactly as returned. Use the uppercase values above.

**Error responses:**

| HTTP Status | When |
|-------------|------|
| `401 Unauthorized` | Credentials are invalid (wrong password or email not found) |
| `401 Unauthorized` | Missing or invalid `x-api-key` |
| `5xx` | Any server-side error (e-commerce will display "service unavailable" to the user) |

**Notes:**
- Do **not** return `200` with an error payload on failed login. The e-commerce system only checks HTTP status codes.
- The e-commerce system does **not** create sessions on the CRM side. This is a stateless credential check.
- The e-commerce system issues its own JWT after this call succeeds. Subsequent requests from the admin go directly to the e-commerce API with that JWT — no further CRM calls are made per request.

---

### 2. Initiate Customer CRM Link

**Purpose:** Start the account-linking flow. The CRM sends a verification code to the customer's email address that is registered in the CRM.

```
POST /api/customers/link/initiate
Content-Type: application/json
x-api-key: <CRM_API_KEY>
```

**Request body:**

```json
{
  "email": "customer@example.com"
}
```

This is the email the customer used to register on the e-commerce store. The CRM should look up whether a customer record exists with this email and send a short-lived verification code to it.

**Success response — `200 OK` or `202 Accepted`:**

Empty body or any body — the e-commerce system ignores the response body on success. Only the HTTP status matters.

**Error responses:**

| HTTP Status | When |
|-------------|------|
| `401 Unauthorized` | Missing or invalid `x-api-key` |
| `404 Not Found` | *(Optional)* No CRM customer found with that email |
| `5xx` | Any server-side error |

**Notes:**
- The e-commerce system does **not** surface a `404` differently to the user. From the customer's perspective, if no code arrives, they simply don't proceed. You may choose to silently return `200` even if the email is not found (to avoid leaking CRM customer existence).
- The verification code should expire within **10–15 minutes**.
- The code delivery mechanism (email template, sender) is owned by the CRM team.

---

### 3. Verify Customer CRM Link

**Purpose:** Validate the code the customer received and return their CRM reference ID so the e-commerce system can store the association.

```
POST /api/customers/link/verify
Content-Type: application/json
x-api-key: <CRM_API_KEY>
```

**Request body:**

```json
{
  "email": "customer@example.com",
  "code": "483920"
}
```

**Success response — `200 OK`:**

```json
{
  "crmReferenceId": "CUST-00042"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `crmReferenceId` | `string` | The CRM's internal identifier for this customer. Stored in the e-commerce DB as a reference — not interpreted, not used to make further CRM calls in V1. |

**Error responses:**

| HTTP Status | When |
|-------------|------|
| `400 Bad Request` | Code is wrong, expired, or already used |
| `422 Unprocessable Entity` | Alternative for invalid/expired code |
| `401 Unauthorized` | Missing or invalid `x-api-key` |
| `5xx` | Any server-side error |

**Notes:**
- The e-commerce system treats both `400` and `422` as "invalid code" and returns an `UnauthorizedException` to the customer.
- After a successful verification, the code must be invalidated (single-use).

---

## Summary Table

| # | Endpoint | Method | Trigger |
|---|----------|--------|---------|
| 1 | `/api/auth/login` | `POST` | Admin clicks "Login" in the backoffice |
| 2 | `/api/customers/link/initiate` | `POST` | Customer clicks "Link my CRM account" |
| 3 | `/api/customers/link/verify` | `POST` | Customer submits the verification code |

---

## Non-Functional Requirements

| Requirement | Value |
|-------------|-------|
| **Timeout** | The e-commerce system times out after **5 seconds**. The CRM must respond within that window or the e-commerce will return `503 Service Unavailable` to the user. |
| **Content-Type** | All responses must be `application/json`. |
| **HTTPS** | Required in production. The CRM URL configured in e-commerce will use `https://`. |
| **Availability** | Endpoint 1 (admin login) is on the critical path for every admin session. Endpoint 2 and 3 are user-initiated and less frequent. |

---

## Questions for the CRM Team

Before implementation, please confirm:

1. **Roles** — Are `ADMINISTRATOR`, `MANAGER`, `PURCHASINGREP`, `SALESREP` the exact role identifiers used in the CRM, or do they differ in casing or naming?
2. **Multi-role users** — Can a CRM user have more than one role simultaneously? If yes, should all roles be returned in the `roles` array?
3. **`crmReferenceId` format** — What is the format of the customer identifier the CRM will return in endpoint 3? (integer, string, prefixed code?) The e-commerce stores it as `varchar(100)`.
4. **Customer email match** — For endpoint 2, should the CRM match on the email field in `so_info`, the `customers` table, or another table?
5. **Sandbox environment** — Is there a CRM staging URL available for integration testing before production?

---

## Contact

E-Commerce Backend Team — for questions about this spec, reach out before implementation to avoid misalignment.
