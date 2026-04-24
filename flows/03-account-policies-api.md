# 03 — eBay Sell Account API (Policies)

**Orden en el flujo de listing:** Paso 3 — Antes de crear el offer, se necesitan los IDs de las políticas del vendedor (devolución, envío, pago) para incluirlos en el campo `listingPolicies` del offer.

## Información general

| Campo | Valor |
|-------|-------|
| eBay API Name | **Sell Account API** |
| Base URL | `https://api.ebay.com` / `https://api.sandbox.ebay.com` |
| Base Path | `/sell/account/v1/` |
| Auth requerida | User token (`getValidToken`) |
| Servicio en CRM | `EbayPoliciesService` |
| Archivo | `src/ecommerce/modules/ebay-policies/ebay-policies.service.ts` |

---

## Endpoints — Return Policies

### 1. `getReturnPolicies`
**Usado en el flujo de listing: SÍ**

Devuelve todas las políticas de devolución configuradas en la cuenta del vendedor de eBay.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/account/v1/return_policy` |

**Query params:**
| Parámetro | Descripción | Default |
|-----------|-------------|---------|
| `marketplace_id` | Marketplace | `EBAY_US` |

**Response (simplificado):**
```json
{
  "total": 1,
  "returnPolicies": [
    {
      "returnPolicyId": "6196XXX",
      "name": "30 Days Free Returns",
      "returnsAccepted": true,
      "returnPeriod": { "value": 30, "unit": "DAY" }
    }
  ]
}
```

---

### 2. `getReturnPolicyById`
**Usado en el flujo de listing: No (consulta específica)**

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/account/v1/return_policy/{returnPolicyId}` |

---

## Endpoints — Fulfillment Policies (Envío)

### 3. `getFulfillmentPolicies`
**Usado en el flujo de listing: SÍ**

Devuelve todas las políticas de envío/fulfillment configuradas en la cuenta.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/account/v1/fulfillment_policy` |

**Query params:**
| Parámetro | Descripción | Default |
|-----------|-------------|---------|
| `marketplace_id` | Marketplace | `EBAY_US` |

---

### 4. `getFulfillmentPolicyById`
**Usado en el flujo de listing: No (consulta específica)**

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/account/v1/fulfillment_policy/{fulfillmentPolicyId}` |

---

## Endpoints — Payment Policies

### 5. `getPaymentPolicies`
**Usado en el flujo de listing: SÍ**

Devuelve todas las políticas de pago de la cuenta.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/account/v1/payment_policy` |

**Query params:**
| Parámetro | Descripción | Default |
|-----------|-------------|---------|
| `marketplace_id` | Marketplace | `EBAY_US` |

---

### 6. `getPaymentPolicyById`
**Usado en el flujo de listing: No (consulta específica)**

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/account/v1/payment_policy/{paymentPolicyId}` |

---

## Endpoints — Custom Policies

### 7. `getCustomPolicies`
**Usado en el flujo de listing: No (feature adicional)**

Políticas personalizadas del vendedor (exclusiones de garantía, términos especiales, etc.).

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/account/v1/custom_policy` |

---

### 8. `getCustomPolicyById`
**Usado en el flujo de listing: No**

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/account/v1/custom_policy/{customPolicyId}` |

---

## Cómo se usan los policy IDs en el offer

Los IDs obtenidos se pasan en el campo `listingPolicies` al crear el offer (ver `05-offer-api.md`):

```json
{
  "listingPolicies": {
    "fulfillmentPolicyId": "6XXX",
    "paymentPolicyId": "6XXX",
    "returnPolicyId": "6XXX"
  }
}
```

---

## Notas para v2

- Las políticas raramente cambian — en v2 considerar cachearlas en DB por cuenta de eBay en lugar de consultarlas en cada creación de listing.
- Una cuenta de eBay puede tener múltiples políticas. El CRM debe permitir al usuario elegir cuál aplicar a cada listing (o tener una política "default" por cuenta).
- El scope OAuth requerido para este API es `https://api.ebay.com/oauth/api_scope/sell.account`.
