# Response Examples

---

## 1. Notification webhook (ORDER_CONFIRMATION)

Payload que llega al endpoint cuando se realiza una venta. Incluye:
- `data.user` (`userId`, `username`) → identifica la cuenta vendedora que emitió la venta (ver `proceso.md` — Fase 1).
- `data.order.orderId` → se usa para consultar el detalle completo en la Fulfillment API.

Este ejemplo corresponde a la misma orden `13-14786-65872` del ejemplo de Fulfillment (Sección 2).

```json
{
  "type": "notification_received",
  "timestamp": "2026-06-19T14:15:24.269Z",
  "topic": "ORDER_CONFIRMATION",
  "notificationId": "e9569bb0-3dbd-40ee-8a26-d6a60f355096_64aa8d87-0afe-4666-98ea-175015f09678",
  "payload": {
    "metadata": {
      "topic": "ORDER_CONFIRMATION",
      "schemaVersion": "1.0",
      "deprecated": false
    },
    "notification": {
      "notificationId": "e9569bb0-3dbd-40ee-8a26-d6a60f355096_64aa8d87-0afe-4666-98ea-175015f09678",
      "eventDate": "2026-06-19T14:15:23.110Z",
      "publishDate": "2026-06-19T14:15:23.407Z",
      "publishAttemptCount": 1,
      "data": {
        "user": {
          "userId": "TFHVhLbkQtu",
          "username": "greenteksolutions"
        },
        "order": {
          "orderId": "13-14786-65872",
          "orderLineItems": [
            {
              "orderLineItemId": "10084048110913",
              "listingId": "287403994390",
              "quantity": 19
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

---

## 3. Ejemplos adicionales — órdenes con múltiples line items

Ejemplos reales del log para órdenes con **más de un line item** y para la cuenta `greenteksolutions-c`. Son órdenes de **prueba internas** (precios de $1, títulos "test"), pero útiles para ver la estructura.

> **Nota:** estos ejemplos muestran órdenes con **2 line items** en un mismo `orderId`. Revisar contra el supuesto de "un producto por orden" (ver `Mapeo de datos 1.md` — Nota 06).

### 3.1 Notificación — orden `19-14819-32278` · cuenta `greenteksolutions` (2 line items)

```json
{
  "type": "notification_received",
  "timestamp": "2026-06-29T22:20:47.461Z",
  "topic": "ORDER_CONFIRMATION",
  "notificationId": "b39d9a21-7ab2-47f8-842b-708e54a4d1cf_f0aaf42e-cc82-44dc-a277-78f45cec2d11",
  "payload": {
    "metadata": {
      "topic": "ORDER_CONFIRMATION",
      "schemaVersion": "1.0",
      "deprecated": false
    },
    "notification": {
      "notificationId": "b39d9a21-7ab2-47f8-842b-708e54a4d1cf_f0aaf42e-cc82-44dc-a277-78f45cec2d11",
      "eventDate": "2026-06-29T22:20:46.298Z",
      "publishDate": "2026-06-29T22:20:46.602Z",
      "publishAttemptCount": 1,
      "data": {
        "user": {
          "userId": "TFHVhLbkQtu",
          "username": "greenteksolutions"
        },
        "order": {
          "orderId": "19-14819-32278",
          "orderLineItems": [
            {
              "orderLineItemId": "10082935197219",
              "listingId": "267713109119",
              "quantity": 1
            },
            {
              "orderLineItemId": "10082935197319",
              "listingId": "257595143201",
              "quantity": 1
            }
          ]
        }
      }
    }
  }
}
```

### 3.2 Notificación — orden `25-14809-32185` · cuenta `greenteksolutions-c` (2 line items)

```json
{
  "type": "notification_received",
  "timestamp": "2026-06-29T22:24:04.062Z",
  "topic": "ORDER_CONFIRMATION",
  "notificationId": "07352d06-46dd-4017-9a3f-995643080e19_9101c34a-7435-43f0-842e-3a39dec983fb",
  "payload": {
    "metadata": {
      "topic": "ORDER_CONFIRMATION",
      "schemaVersion": "1.0",
      "deprecated": false
    },
    "notification": {
      "notificationId": "07352d06-46dd-4017-9a3f-995643080e19_9101c34a-7435-43f0-842e-3a39dec983fb",
      "eventDate": "2026-06-29T22:24:03.168Z",
      "publishDate": "2026-06-29T22:24:03.294Z",
      "publishAttemptCount": 1,
      "data": {
        "user": {
          "userId": "tF7soxK5TPG",
          "username": "greenteksolutions-c"
        },
        "order": {
          "orderId": "25-14809-32185",
          "orderLineItems": [
            {
              "orderLineItemId": "10081787034725",
              "listingId": "278138499036",
              "quantity": 1
            },
            {
              "orderLineItemId": "10081787034825",
              "listingId": "287427566676",
              "quantity": 1
            }
          ]
        }
      }
    }
  }
}
```

### 3.3 Fulfillment — orden `25-14809-32185` · cuenta `greenteksolutions-c`

```json
{
  "orderId": "25-14809-32185",
  "legacyOrderId": "25-14809-32185",
  "creationDate": "2026-06-29T22:24:02.000Z",
  "lastModifiedDate": "2026-06-29T22:30:27.000Z",
  "orderFulfillmentStatus": "NOT_STARTED",
  "orderPaymentStatus": "PAID",
  "sellerId": "greenteksolutions-c",
  "buyer": {
    "username": "greenteksolutions-d",
    "taxAddress": {
      "city": "Stafford",
      "stateOrProvince": "TX",
      "postalCode": "77477-2408",
      "countryCode": "US"
    },
    "buyerRegistrationAddress": {
      "fullName": "GreenTek Solutions, LLC",
      "contactAddress": {
        "addressLine1": "12315 Parc Crest Dr",
        "addressLine2": "Ste 160",
        "city": "Stafford",
        "stateOrProvince": "TX",
        "postalCode": "77477",
        "countryCode": "US"
      },
      "primaryPhone": {
        "phoneNumber": "8324039884"
      },
      "email": "008ed54fd106a325e05b@members.ebay.com"
    }
  },
  "pricingSummary": {
    "priceSubtotal": {
      "value": "2.0",
      "currency": "USD"
    },
    "deliveryCost": {
      "value": "0.0",
      "currency": "USD"
    },
    "total": {
      "value": "2.0",
      "currency": "USD"
    }
  },
  "cancelStatus": {
    "cancelState": "NONE_REQUESTED",
    "cancelRequests": []
  },
  "paymentSummary": {
    "totalDueSeller": {
      "value": "1.41",
      "currency": "USD"
    },
    "refunds": [],
    "payments": [
      {
        "paymentMethod": "EBAY",
        "paymentReferenceId": "420006_S",
        "paymentDate": "2026-06-29T22:24:03.072Z",
        "amount": {
          "value": "1.41",
          "currency": "USD"
        },
        "paymentStatus": "PAID"
      }
    ]
  },
  "fulfillmentStartInstructions": [
    {
      "fulfillmentInstructionsType": "SHIP_TO",
      "minEstimatedDeliveryDate": "2026-07-01T07:00:00.000Z",
      "maxEstimatedDeliveryDate": "2026-07-03T07:00:00.000Z",
      "ebaySupportedFulfillment": false,
      "shippingStep": {
        "shipTo": {
          "fullName": "Anuar Garcia",
          "contactAddress": {
            "addressLine1": "12315 Parc Crest Dr",
            "addressLine2": "STE 160",
            "city": "Stafford",
            "stateOrProvince": "TX",
            "postalCode": "77477-2408",
            "countryCode": "US"
          },
          "primaryPhone": {
            "phoneNumber": "7135909720"
          },
          "email": "008ed54fd106a325e05b@members.ebay.com"
        },
        "shippingCarrierCode": "UPS",
        "shippingServiceCode": "UPSGround"
      }
    }
  ],
  "fulfillmentHrefs": [],
  "lineItems": [
    {
      "lineItemId": "10081787034725",
      "legacyItemId": "278138499036",
      "sku": "AA-1782771735006",
      "title": "test 0 Cisco WS-C2960CX-8PC-L Cisco Catalyst 2960-CX 8 Port PoE",
      "lineItemCost": {
        "value": "1.0",
        "currency": "USD"
      },
      "quantity": 1,
      "soldFormat": "FIXED_PRICE",
      "listingMarketplaceId": "EBAY_US",
      "purchaseMarketplaceId": "EBAY_US",
      "lineItemFulfillmentStatus": "NOT_STARTED",
      "total": {
        "value": "1.0",
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
        "buyerProtection": true
      },
      "lineItemFulfillmentInstructions": {
        "minEstimatedDeliveryDate": "2026-07-01T07:00:00.000Z",
        "maxEstimatedDeliveryDate": "2026-07-03T07:00:00.000Z",
        "shipByDate": "2026-07-01T06:59:59.000Z",
        "guaranteedDelivery": false
      },
      "itemLocation": {
        "location": "Stafford, Texas",
        "countryCode": "US",
        "postalCode": "77477"
      }
    },
    {
      "lineItemId": "10081787034825",
      "legacyItemId": "287427566676",
      "sku": "AA-1782771017152",
      "title": "test 2Samsung 850 EVO 500GB 2.5\" SATA III SSD MZ-75E500 Solid State Drive Tested",
      "lineItemCost": {
        "value": "1.0",
        "currency": "USD"
      },
      "quantity": 1,
      "soldFormat": "FIXED_PRICE",
      "listingMarketplaceId": "EBAY_US",
      "purchaseMarketplaceId": "EBAY_US",
      "lineItemFulfillmentStatus": "NOT_STARTED",
      "total": {
        "value": "1.0",
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
        "buyerProtection": true
      },
      "lineItemFulfillmentInstructions": {
        "minEstimatedDeliveryDate": "2026-07-01T07:00:00.000Z",
        "maxEstimatedDeliveryDate": "2026-07-03T07:00:00.000Z",
        "shipByDate": "2026-07-01T06:59:59.000Z",
        "guaranteedDelivery": false
      },
      "itemLocation": {
        "location": "Stafford, Texas",
        "countryCode": "US",
        "postalCode": "77477"
      }
    }
  ],
  "salesRecordReference": "13488",
  "totalFeeBasisAmount": {
    "value": "2.0",
    "currency": "USD"
  },
  "totalMarketplaceFee": {
    "value": "0.59",
    "currency": "USD"
  }
}
```

### 3.4 Fulfillment — orden `19-14819-32278` · cuenta `greenteksolutions`

```json
{
  "orderId": "19-14819-32278",
  "legacyOrderId": "19-14819-32278",
  "creationDate": "2026-06-29T22:20:45.000Z",
  "lastModifiedDate": "2026-06-29T22:28:09.000Z",
  "orderFulfillmentStatus": "NOT_STARTED",
  "orderPaymentStatus": "PAID",
  "sellerId": "greenteksolutions",
  "buyer": {
    "username": "greenteksolutions-d",
    "taxAddress": {
      "city": "Stafford",
      "stateOrProvince": "TX",
      "postalCode": "77477-2408",
      "countryCode": "US"
    },
    "buyerRegistrationAddress": {
      "fullName": "GreenTek Solutions, LLC",
      "contactAddress": {
        "addressLine1": "12315 Parc Crest Dr",
        "addressLine2": "Ste 160",
        "city": "Stafford",
        "stateOrProvince": "TX",
        "postalCode": "77477",
        "countryCode": "US"
      },
      "primaryPhone": {
        "phoneNumber": "8324039884"
      },
      "email": "008ed5499b41b927c160@members.ebay.com"
    }
  },
  "pricingSummary": {
    "priceSubtotal": {
      "value": "2.0",
      "currency": "USD"
    },
    "deliveryCost": {
      "value": "0.0",
      "currency": "USD"
    },
    "total": {
      "value": "2.0",
      "currency": "USD"
    }
  },
  "cancelStatus": {
    "cancelState": "NONE_REQUESTED",
    "cancelRequests": []
  },
  "paymentSummary": {
    "totalDueSeller": {
      "value": "1.53",
      "currency": "USD"
    },
    "refunds": [],
    "payments": [
      {
        "paymentMethod": "EBAY",
        "paymentReferenceId": "420006_S",
        "paymentDate": "2026-06-29T22:20:44.905Z",
        "amount": {
          "value": "1.53",
          "currency": "USD"
        },
        "paymentStatus": "PAID"
      }
    ]
  },
  "fulfillmentStartInstructions": [
    {
      "fulfillmentInstructionsType": "SHIP_TO",
      "minEstimatedDeliveryDate": "2026-07-01T07:00:00.000Z",
      "maxEstimatedDeliveryDate": "2026-07-03T07:00:00.000Z",
      "ebaySupportedFulfillment": false,
      "shippingStep": {
        "shipTo": {
          "fullName": "Anuar Garcia",
          "contactAddress": {
            "addressLine1": "12315 Parc Crest Dr",
            "addressLine2": "STE 160",
            "city": "Stafford",
            "stateOrProvince": "TX",
            "postalCode": "77477-2408",
            "countryCode": "US"
          },
          "primaryPhone": {
            "phoneNumber": "7135909720"
          },
          "email": "008ed5499b41b927c160@members.ebay.com"
        },
        "shippingCarrierCode": "UPS",
        "shippingServiceCode": "UPSGround"
      }
    }
  ],
  "fulfillmentHrefs": [],
  "lineItems": [
    {
      "lineItemId": "10082935197219",
      "legacyItemId": "267713109119",
      "sku": "AA-1782771142607",
      "title": "test 1Cisco WS-C2960CX-8PC-L Cisco Catalyst 2960-CX 8 Port PoE",
      "lineItemCost": {
        "value": "1.0",
        "currency": "USD"
      },
      "quantity": 1,
      "soldFormat": "FIXED_PRICE",
      "listingMarketplaceId": "EBAY_US",
      "purchaseMarketplaceId": "EBAY_US",
      "lineItemFulfillmentStatus": "NOT_STARTED",
      "total": {
        "value": "1.0",
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
        "buyerProtection": true
      },
      "lineItemFulfillmentInstructions": {
        "minEstimatedDeliveryDate": "2026-07-01T07:00:00.000Z",
        "maxEstimatedDeliveryDate": "2026-07-03T07:00:00.000Z",
        "shipByDate": "2026-07-01T04:59:59.000Z",
        "guaranteedDelivery": false
      },
      "itemLocation": {
        "location": "Stafford, Texas",
        "countryCode": "US",
        "postalCode": "77477"
      }
    },
    {
      "lineItemId": "10082935197319",
      "legacyItemId": "257595143201",
      "sku": "AA-1782771147718",
      "title": "test 2Cisco WS-C2960CX-8PC-L Cisco Catalyst 2960-CX 8 Port PoE",
      "lineItemCost": {
        "value": "1.0",
        "currency": "USD"
      },
      "quantity": 1,
      "soldFormat": "FIXED_PRICE",
      "listingMarketplaceId": "EBAY_US",
      "purchaseMarketplaceId": "EBAY_US",
      "lineItemFulfillmentStatus": "NOT_STARTED",
      "total": {
        "value": "1.0",
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
        "buyerProtection": true
      },
      "lineItemFulfillmentInstructions": {
        "minEstimatedDeliveryDate": "2026-07-01T07:00:00.000Z",
        "maxEstimatedDeliveryDate": "2026-07-03T07:00:00.000Z",
        "shipByDate": "2026-07-01T04:59:59.000Z",
        "guaranteedDelivery": false
      },
      "itemLocation": {
        "location": "Stafford, Texas",
        "countryCode": "US",
        "postalCode": "77477"
      }
    }
  ],
  "salesRecordReference": "17637",
  "totalFeeBasisAmount": {
    "value": "2.0",
    "currency": "USD"
  },
  "totalMarketplaceFee": {
    "value": "0.47",
    "currency": "USD"
  }
}
```
