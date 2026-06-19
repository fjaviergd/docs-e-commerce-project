# Response Examples

---

## 1. Notification webhook (ORDER_CONFIRMATION)

Payload que llega al endpoint cuando se realiza una venta. Contiene el `orderId` que se usa para consultar el detalle completo en Fulfillment API.

```json
{
  "type": "notification_received",
  "timestamp": "2026-06-18T22:07:02.370Z",
  "topic": "ORDER_CONFIRMATION",
  "notificationId": "2164dd73-bb14-443a-b0a1-a048384ef13c_e1a34a5e-fe2e-4568-896a-e701a75b9fba",
  "payload": {
    "metadata": {
      "topic": "ORDER_CONFIRMATION",
      "schemaVersion": "1.0",
      "deprecated": false
    },
    "notification": {
      "notificationId": "2164dd73-bb14-443a-b0a1-a048384ef13c_e1a34a5e-fe2e-4568-896a-e701a75b9fba",
      "eventDate": "2026-06-18T22:07:01.137Z",
      "publishDate": "2026-06-18T22:07:01.411Z",
      "publishAttemptCount": 1,
      "data": {
        "order": {
          "orderId": "123-123-4435",
          "orderLineItems": [
            {
              "orderLineItemId": "123455",
              "listingId": "123566",
              "quantity": 1
            }
          ]
        }
      }
    }
  }
}
```

---

## 2. Fulfillment API — GET /order/{orderId}

Response completa con todos los datos de la orden. Incluye `addressLine2` en buyer y shipTo.

```json
{
  "type": "fulfillment_response",
  "timestamp": "2026-06-19T19:53:29.853Z",
  "orderId": "13-14786-65872",
  "data": {
    "orderId": "13-14786-65872",
    "legacyOrderId": "13-14786-65872",
    "creationDate": "2026-06-19T14:15:22.000Z",
    "lastModifiedDate": "2026-06-19T14:16:58.000Z",
    "orderFulfillmentStatus": "NOT_STARTED",
    "orderPaymentStatus": "PAID",
    "sellerId": "greenteksolutions",
    "buyer": {
      "username": "hoodsgoodscellular",
      "taxAddress": {
        "city": "Springdale",
        "stateOrProvince": "AR",
        "postalCode": "72764-8719",
        "countryCode": "US"
      },
      "buyerRegistrationAddress": {
        "fullName": "Hoods Goods LLC",
        "contactAddress": {
          "addressLine1": "1712 W Sunset Ave",
          "addressLine2": "Ste A",
          "city": "Springdale",
          "stateOrProvince": "AR",
          "postalCode": "72762",
          "countryCode": "US"
        },
        "primaryPhone": {
          "phoneNumber": "4793182700"
        },
        "email": "008e6042952ceb5c3e7e@members.ebay.com"
      }
    },
    "pricingSummary": {
      "priceSubtotal": {
        "value": "4085.0",
        "currency": "USD"
      },
      "deliveryCost": {
        "value": "0.0",
        "currency": "USD"
      },
      "total": {
        "value": "4085.0",
        "currency": "USD"
      }
    },
    "cancelStatus": {
      "cancelState": "NONE_REQUESTED",
      "cancelRequests": []
    },
    "paymentSummary": {
      "totalDueSeller": {
        "value": "3807.77",
        "currency": "USD"
      },
      "refunds": [],
      "payments": [
        {
          "paymentMethod": "EBAY",
          "paymentReferenceId": "420004_S",
          "paymentDate": "2026-06-19T14:15:22.915Z",
          "amount": {
            "value": "3807.77",
            "currency": "USD"
          },
          "paymentStatus": "PAID"
        }
      ]
    },
    "fulfillmentStartInstructions": [
      {
        "fulfillmentInstructionsType": "SHIP_TO",
        "minEstimatedDeliveryDate": "2026-06-23T07:00:00.000Z",
        "maxEstimatedDeliveryDate": "2026-06-25T07:00:00.000Z",
        "ebaySupportedFulfillment": false,
        "shippingStep": {
          "shipTo": {
            "fullName": "Cody Hood",
            "contactAddress": {
              "addressLine1": "2200 S Old Missouri Rd",
              "addressLine2": "Ste N",
              "city": "Springdale",
              "stateOrProvince": "AR",
              "postalCode": "72764-8719",
              "countryCode": "US"
            },
            "primaryPhone": {
              "phoneNumber": "4794267518"
            },
            "email": "008e6042952ceb5c3e7e@members.ebay.com"
          },
          "shippingCarrierCode": "UPS",
          "shippingServiceCode": "UPSGround"
        }
      }
    ],
    "fulfillmentHrefs": [],
    "lineItems": [
      {
        "lineItemId": "10084048110913",
        "legacyItemId": "287403994390",
        "sku": "UO-1781808648556",
        "title": "Apple iPad 10th Gen A2757 64GB Silver Unlocked",
        "lineItemCost": {
          "value": "4085.0",
          "currency": "USD"
        },
        "quantity": 19,
        "soldFormat": "FIXED_PRICE",
        "listingMarketplaceId": "EBAY_US",
        "purchaseMarketplaceId": "EBAY_US",
        "lineItemFulfillmentStatus": "NOT_STARTED",
        "total": {
          "value": "4085.0",
          "currency": "USD"
        },
        "deliveryCost": {
          "shippingCost": {
            "value": "0.0",
            "currency": "USD"
          }
        },
        "appliedPromotions": [],
        "taxes": [
          {
            "amount": {
              "value": "0.0",
              "currency": "USD"
            }
          }
        ],
        "properties": {
          "fromBestOffer": true,
          "buyerProtection": true,
          "soldViaAdCampaign": true
        },
        "lineItemFulfillmentInstructions": {
          "minEstimatedDeliveryDate": "2026-06-23T07:00:00.000Z",
          "maxEstimatedDeliveryDate": "2026-06-25T07:00:00.000Z",
          "shipByDate": "2026-06-23T04:59:59.000Z",
          "guaranteedDelivery": false
        },
        "itemLocation": {
          "location": "Stafford, Texas",
          "countryCode": "US",
          "postalCode": "77477"
        }
      }
    ],
    "salesRecordReference": "17602",
    "totalFeeBasisAmount": {
      "value": "4085.0",
      "currency": "USD"
    },
    "totalMarketplaceFee": {
      "value": "277.23",
      "currency": "USD"
    }
  }
}
```
