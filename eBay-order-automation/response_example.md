
{
  "orderId": "03-14798-73169",
  "legacyOrderId": "03-14798-73169",
  "creationDate": "2026-06-18T13:27:24.000Z",
  "lastModifiedDate": "2026-06-18T13:28:24.000Z",
  "orderFulfillmentStatus": "NOT_STARTED",
  "orderPaymentStatus": "PAID",
  "sellerId": "greenteksolutions",
  "buyer": {
    "username": "banana-pudding",
    "taxAddress": {
      "city": "Denver",
      "stateOrProvince": "CO",
      "postalCode": "80221-3767",
      "countryCode": "US"
    },
    "buyerRegistrationAddress": {
      "fullName": "My Tran",
      "contactAddress": {
        "addressLine1": "1346 Elmwood Ln",
        "city": "Denver",
        "stateOrProvince": "CO",
        "postalCode": "80221",
        "countryCode": "US"
      },
      "primaryPhone": {
        "phoneNumber": "2482526986"
      },
      "email": "472bc0dab0c10a88bf38@members.ebay.com"
    }
  },
  "pricingSummary": {
    "priceSubtotal": {
      "value": "120.0",
      "currency": "USD"
    },
    "deliveryCost": {
      "value": "0.0",
      "currency": "USD"
    },
    "total": {
      "value": "120.0",
      "currency": "USD"
    }
  },
  "cancelStatus": {
    "cancelState": "NONE_REQUESTED",
    "cancelRequests": []
  },
  "paymentSummary": {
    "totalDueSeller": {
      "value": "108.73",
      "currency": "USD"
    },
    "refunds": [],
    "payments": [
      {
        "paymentMethod": "EBAY",
        "paymentReferenceId": "420004_S",
        "paymentDate": "2026-06-18T13:27:24.746Z",
        "amount": {
          "value": "108.73",
          "currency": "USD"
        },
        "paymentStatus": "PAID"
      }
    ]
  },
  "fulfillmentStartInstructions": [
    {
      "fulfillmentInstructionsType": "SHIP_TO",
      "minEstimatedDeliveryDate": "2026-06-22T07:00:00.000Z",
      "maxEstimatedDeliveryDate": "2026-06-25T07:00:00.000Z",
      "ebaySupportedFulfillment": false,
      "shippingStep": {
        "shipTo": {
          "fullName": "Chris Tran",
          "contactAddress": {
            "addressLine1": "1346 Elmwood Ln",
            "city": "Denver",
            "stateOrProvince": "CO",
            "postalCode": "80221-3767",
            "countryCode": "US"
          },
          "primaryPhone": {
            "phoneNumber": "2488434153"
          },
          "email": "472bc0dab0c10a88bf38@members.ebay.com"
        },
        "shippingCarrierCode": "UPS",
        "shippingServiceCode": "UPSGround"
      }
    }
  ],
  "fulfillmentHrefs": [],
  "lineItems": [
    {
      "lineItemId": "10082609613103",
      "legacyItemId": "267452304881",
      "sku": "WB 9321-72/73 10.25",
      "title": "IBM 46X2478 LTO Ultrium 5-H SAS Internal Tape Drive",
      "lineItemCost": {
        "value": "120.0",
        "currency": "USD"
      },
      "quantity": 1,
      "soldFormat": "FIXED_PRICE",
      "listingMarketplaceId": "EBAY_US",
      "purchaseMarketplaceId": "EBAY_US",
      "lineItemFulfillmentStatus": "NOT_STARTED",
      "total": {
        "value": "120.0",
        "currency": "USD"
      },
      "deliveryCost": {
        "shippingCost": {
          "value": "0.0",
          "currency": "USD"
        }
      },
      "appliedPromotions": [],
      "taxes": [],
      "ebayCollectAndRemitTaxes": [
        {
          "taxType": "STATE_SALES_TAX",
          "amount": {
            "value": "5.98",
            "currency": "USD"
          },
          "collectionMethod": "NET"
        }
      ],
      "properties": {
        "fromBestOffer": true,
        "buyerProtection": true,
        "soldViaAdCampaign": true
      },
      "lineItemFulfillmentInstructions": {
        "minEstimatedDeliveryDate": "2026-06-22T07:00:00.000Z",
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
  "ebayCollectAndRemitTax": true,
  "salesRecordReference": "17600",
  "totalFeeBasisAmount": {
    "value": "125.98",
    "currency": "USD"
  },
  "totalMarketplaceFee": {
    "value": "11.27",
    "currency": "USD"
  }
}

---

// Ejemplo con addressLine2 presente en buyer y shipTo

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
