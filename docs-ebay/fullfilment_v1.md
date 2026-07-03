---
title: Fulfillment
description: "The outcome of a buyer's eBay checkout process is an _order_. The **Fulfillment API** enables sellers to manage the completion of an order in accordance with the payment method and timing specified at checkout. The line items in the order are grouped into one or more packages. As the seller addresses, handles, and ships each package, the set of specifications for this process is known as a _fulfillment_. Use the Fulfillment API to facilitate and monitor these activities from the order to completion. Sellers' status on eBay depend partly on their record of timely fulfillment. **Note:** The **Fulfillment API** includes only transactions that have completed checkout. Specifically, the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) method does not include pending-payment purchases that require upfront payment before shipment."
api_version: v1.20.6
api_name: fulfillment_api
api_type: REST
api_group: sell/fulfillment_api
source_url:
  html: https://developer.ebay.com/develop/api/sell/fulfillment_api
  md: https://developer.ebay.com/develop/api/sell/fulfillment_api.md
---

# Fulfillment API

The outcome of a buyer's eBay checkout process is an _order_. The **Fulfillment API** enables sellers to manage the completion of an order in accordance with the payment method and timing specified at checkout. The line items in the order are grouped into one or more packages. As the seller addresses, handles, and ships each package, the set of specifications for this process is known as a _fulfillment_. Use the Fulfillment API to facilitate and monitor these activities from the order to completion. Sellers' status on eBay depend partly on their record of timely fulfillment.

**Note:** The **Fulfillment API** includes only transactions that have completed checkout. Specifically, the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) method does not include pending-payment purchases that require upfront payment before shipment.

## API Information

**Title:** Fulfillment API
**Version:** v1.20.6
**Description:** Use the Fulfillment API to complete the process of packaging, addressing, handling, and shipping each order on behalf of the seller, in accordance with the payment method and timing specified at checkout.
**Base Path:** /sell/fulfillment/v1

## API Methods

The following API methods are available:

### getOrder

#### GET /order/{orderId}
**Description:** Use this call to retrieve the contents of an order based on its unique identifier, _orderId_. This value is returned in the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) call's **orders.orderId** field when you search for orders by creation date, modification date, or fulfillment status. Include the optional **fieldGroups** query parameter set to `TAX_BREAKDOWN` to return a breakdown of the taxes and fees.

The returned **Order** object contains information you can use to create and process fulfillments, including the following:

*   Information about the buyer and seller
*   Information about the order's line items
*   The plans for packaging, addressing, and shipping the order
*   The status of payment, packaging, addressing, and shipping the order
*   A summary of monetary amounts specific to the order such as pricing, payments, and shipping costs
*   A summary of applied taxes and fees and, optionally, a breakdown of each
**Parameters:**
- **fieldGroups** (string)
  - This parameter lets you control what is returned in the response.

**Note:** The only presently supported value is `TAX_BREAKDOWN`. This field group adds addition fields to the response that return a breakdown of taxes and fees.
- **orderId** (string) *required*
  - This path parameter is used to specify the unique identifier of the order being retrieved.

Use the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) method to retrieve order IDs. Order ID values are also shown in My eBay/Seller Hub.

**Note:** [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) can return orders up to two years old. Do not provide the **orderId** for an order created more than two years in the past.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.fulfillment`
- `https://api.ebay.com/oauth/api_scope/sell.fulfillment.readonly`


### getOrders

#### GET /order
**Description:** Use this method to search for and retrieve one or more orders based on their creation date, last modification date, or fulfillment status using the **filter** parameter. You can alternatively specify a list of orders using the **orderIds** parameter. Include the optional **fieldGroups** query parameter set to `TAX_BREAKDOWN` to return a breakdown of the taxes and fees. By default, when no filters are used this call returns all orders created within the last 90 days.

The returned **Order** objects contain information you can use to create and process fulfillments, including:

*   Information about the buyer and seller
*   Information about the order's line items
*   The plans for packaging, addressing and shipping the order
*   The status of payment, packaging, addressing, and shipping the order
*   A summary of monetary amounts specific to the order such as pricing, payments, and shipping costs
*   A summary of applied taxes and fees, and optionally a breakdown of each


**Important:** In this call, the **cancelStatus.cancelRequests** array is returned but is always empty. Use the [getOrder](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder) call instead, which returns this array fully populated with information about any cancellation requests.
**Parameters:**
- **fieldGroups** (string)
  - This parameter lets you control what is returned in the response.

**Note:** The only presently supported value is `TAX_BREAKDOWN`. This field group adds addition fields to the response that return a breakdown of taxes and fees.
- **filter** (string)
  - One or more comma-separated criteria for narrowing down the collection of orders returned by this call. These criteria correspond to specific fields in the response payload. Multiple filter criteria combine to further restrict the results.

**Note:** [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) can return orders up to two years old. Do not set the `creationdate` filter to a date beyond two years in the past.
**Note:** If the **orderIds** parameter is included in the request, the **filter** parameter will be ignored.
The available criteria are as follows:

`**creationdate**`

The time period during which qualifying orders were created (the **orders.creationDate** field). In the URI, this is expressed as a starting timestamp, with or without an ending timestamp (in brackets). The timestamps are in [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock.For example:

*   `creationdate:[2016-02-21T08:25:43.511Z..]` identifies orders created on or after the given timestamp.
*   `creationdate:[2016-02-21T08:25:43.511Z..2016-04-21T08:25:43.511Z]` identifies orders created between the given timestamps, inclusive.

`**lastmodifieddate**`

The time period during which qualifying orders were last modified (the **orders.modifiedDate** field). In the URI, this is expressed as a starting timestamp, with or without an ending timestamp (in brackets). The timestamps are in [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock.For example:

*   `lastmodifieddate:[2016-05-15T08:25:43.511Z..]` identifies orders modified on or after the given timestamp.
*   `lastmodifieddate:[2016-05-15T08:25:43.511Z..2016-05-31T08:25:43.511Z]` identifies orders modified between the given timestamps, inclusive.

**Note:** If **creationdate** and **lastmodifieddate** are both included, only **creationdate** is used.

`**orderfulfillmentstatus**`

The degree to which qualifying orders have been shipped (the **orders.orderFulfillmentStatus** field). In the URI, this is expressed as one of the following value combinations:

*   `orderfulfillmentstatus:{NOT_STARTED|IN_PROGRESS}` specifies orders for which no shipping fulfillments have been started, plus orders for which at least one shipping fulfillment has been started but not completed.
*   `orderfulfillmentstatus:{FULFILLED|IN_PROGRESS}` specifies orders for which all shipping fulfillments have been completed, plus orders for which at least one shipping fulfillment has been started but not completed.

**Note:** The values `NOT_STARTED`, `IN_PROGRESS`, and `FULFILLED` can be used in various combinations, but only the combinations shown here are currently supported.

Here is an example of a **getOrders** call using all of these filters:

GET https://api.ebay.com/sell/v1/order?
filter=**creationdate**:%5B2016-03-21T08:25:43.511Z..2016-04-21T08:25:43.511Z%5D,
**lastmodifieddate**:%5B2016-05-15T08:25:43.511Z..%5D,
**orderfulfillmentstatus**:%7BNOT\_STARTED%7CIN\_PROGRESS%7D

**Note:** This call requires that certain special characters in the URI query string be percent-encoded:
    `[` = `%5B`       `]` = `%5D`       `{` = `%7B`       `|` = `%7C`       `}` = `%7D`
This query filter example uses these codes.
- **limit** (string)
  - The number of orders to return per page of the result set. Use this parameter in conjunction with the **offset** parameter to control the pagination of the output.

For example, if **offset** is set to `10` and **limit** is set to `10`, the call retrieves orders 11 through 20 from the result set.

If a limit is not set, the **limit** defaults to 50 and returns up to 50 orders. If a requested limit is more than 200, the call fails and returns an error.

**Note:** This feature employs a zero-based list, where the first item in the list has an offset of `0`. If the **orderIds** parameter is included in the request, this parameter will be ignored.
**Maximum:** `200`
**Default:** `50`
- **offset** (string)
  - Specifies the number of orders to skip in the result set before returning the first order in the paginated response.

Combine **offset** with the **limit** query parameter to control the items returned in the response. For example, if you supply an **offset** of `0` and a **limit** of `10`, the first page of the response contains the first 10 items from the complete list of items retrieved by the call. If **offset** is `10` and **limit** is `20`, the first page of the response contains items 11-30 from the complete result set.

**Default:** 0
- **orderIds** (string)
  - A comma-separated list of the unique identifiers of the orders to retrieve (maximum 50). If one or more order ID values are specified through the **orderIds** query parameter, all other query parameters will be ignored.

**Note:** [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) can return orders up to two years old. Do not provide the **orderId** for an order created more than two years in the past.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.fulfillment`
- `https://api.ebay.com/oauth/api_scope/sell.fulfillment.readonly`


### issueRefund

#### POST /order/{order_id}/issue_refund
**Description:** **Important!** Due to EU & UK Payments regulatory requirements, an additional security verification via Digital Signatures is required for certain API calls that are made on behalf of EU/UK sellers, including **issueRefund**. Please refer to [Digital Signatures for APIs](</develop/guides/digital-signatures-for-apis >) to learn more on the impacted APIs and the process to create signatures to be included in the HTTP payload.


This method allows a seller to issue a full or partial refund to a buyer for an order. Full or partial refunds can be issued at the order level or line item level.

The refunds issued through this method are processed asynchronously, so the refund will not show as 'Refunded' right away. A seller will have to make a subsequent [getOrder](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder) call to check the status of the refund. The status of an order refund can be found in the [paymentSummary.refunds.refundStatus](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder.orderrefund.refundstatus) field of the [getOrder](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder) response.
**Parameters:**
- **order_id** (string) *required*
  - This path parameter is used to specify the unique identifier of the order associated with a refund.

Use the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) method to retrieve order IDs.
- **Content-Type** (string) *required*
  - This header indicates the format of the request body provided by the client. Its value should be set to **application/json**.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.finances`


### getShippingFulfillments

#### GET /order/{orderId}/shipping_fulfillment
**Description:** Use this call to retrieve the contents of all fulfillments currently defined for a specified order based on the order's unique identifier, **orderId**. This value is returned in the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) call's **members.orderId** field when you search for orders by creation date or shipment status.
**Parameters:**
- **orderId** (string) *required*
  - This path parameter is used to specify the unique identifier of the order associated with the shipping fulfillments being retrieved.

Use the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) method to retrieve order IDs. Order ID values are also shown in My eBay/Seller Hub.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.fulfillment`
- `https://api.ebay.com/oauth/api_scope/sell.fulfillment.readonly`


### createShippingFulfillment

#### POST /order/{orderId}/shipping_fulfillment
**Description:** When you group an order's line items into one or more packages, each package requires a corresponding plan for handling, addressing, and shipping; this is _shipping fulfillment_. For each package, execute this call once to generate the shipping fulfillment associated with that package.

**Note:** A single line item in an order can consist of multiple units of a purchased item, and one unit can consist of multiple parts or components. Although these components might be provided by the manufacturer in separate packaging, the seller must include all components of a given line item in the same package.
Before using this call for a given package, you must determine which line items are in the package. If the package has been shipped, you should provide the date of shipment in the request. If not provided, it will default to the current date and time.

This method can also be used to provide proof of delivery for contested payment disputes. To do so, use this method to create a shipping fulfillment and provide shipment tracking information for all line items involved in the dispute. EBay will then pick up this information for the dispute directly.
**Parameters:**
- **orderId** (string) *required*
  - This path parameter is used to specify the unique identifier of the order associated with the shipping fulfillment being created.

Use the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) method to retrieve order IDs.
- **Content-Type** (string) *required*
  - This header indicates the format of the request body provided by the client. Its value should be set to **application/json**.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.fulfillment`


### getShippingFulfillment

#### GET /order/{orderId}/shipping_fulfillment/{fulfillmentId}
**Description:** Use this call to retrieve the contents of a fulfillment based on its unique identifier, **fulfillmentId** (combined with the associated order's **orderId**). The **fulfillmentId** value was originally generated by the **createShippingFulfillment** call and is returned by the [getShippingFulfillments](/develop/api/sell/fulfillment_api#sell-fulfillment_api-shipping_fulfillment-getshippingfulfillments) call in the **members.fulfillmentId** field.
**Parameters:**
- **fulfillmentId** (string) *required*
  - This path parameter is used to specify the unique identifier of the shipping fulfillment being retrieved.

Use the [getShippingFulfillments](/develop/api/sell/fulfillment_api#sell-fulfillment_api-shipping_fulfillment-getshippingfulfillments) method to retrieve fulfillment IDs.
- **orderId** (string) *required*
  - This path parameter is used to specify the unique identifier of the order associated with the shipping fulfillment being retrieved.

Use the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) method to retrieve order IDs. Order ID values are also shown in My eBay/Seller Hub.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.fulfillment`
- `https://api.ebay.com/oauth/api_scope/sell.fulfillment.readonly`


### getPaymentDispute

#### GET /payment_dispute/{payment_dispute_id}
**Description:** This method retrieves detailed information on a specific payment dispute. The payment dispute identifier is passed in as path parameter at the end of the call URI.

Below is a summary of the information that is retrieved:

*   Current status of payment dispute
*   Amount of the payment dispute
*   Reason the payment dispute was opened
*   Order and line items associated with the payment dispute
*   Seller response options if an action is currently required on the payment dispute
*   Details on the results of the payment dispute if it has been closed
*   Details on any evidence that was provided by the seller to fight the payment dispute
**Parameters:**
- **payment_dispute_id** (string) *required*
  - This parameter is used to specify the unique identifier of the payment dispute being retrieved.

Use the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method to retrieve payment dispute IDs.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.payment.dispute`


### fetchEvidenceContent

#### GET /payment_dispute/{payment_dispute_id}/fetch_evidence_content
**Description:** This call retrieves a specific evidence file for a payment dispute. The following three identifying parameters are needed in the call URI:

*   **payment\_dispute\_id**: the identifier of the payment dispute. The identifier of each payment dispute is returned in the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) response.
*   **evidence\_id**: the identifier of the evidential file set. The identifier of an evidential file set for a payment dispute is returned under the **evidence** array in the [getPaymentDispute](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdispute) response.
*   **file\_id**: the identifier of an evidential file. This file must belong to the evidential file set identified through the **evidence\_id** query parameter. The identifier of each evidential file is returned under the **evidence.files** array in the [getPaymentDispute](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdispute) response.

An actual binary file is returned if the call is successful. An error will occur if any of three identifiers are invalid.
**Parameters:**
- **payment_dispute_id** (string) *required*
  - This path parameter is used to specify the unique identifier of the payment dispute associated with the evidence file being retrieved.

Use the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method to retrieve payment dispute IDs.
- **evidence_id** (string) *required*
  - This query parameter is used to specify the unique identifier of the evidential file set.

The identifier of an evidential file set for a payment dispute is returned under the **evidence** array in the [getPaymentDispute](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdispute) response.
- **file_id** (string) *required*
  - This query parameter is used to specify the unique identifier of an evidential file. This file must belong to the evidential file set identified through the **evidence\_id** query parameter.

The identifier of each evidential file is returned under the **evidence.files** array in the [getPaymentDispute](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdispute) response.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.payment.dispute`


### getActivities

#### GET /payment_dispute/{payment_dispute_id}/activity
**Description:** This method retrieves the activity log for a payment dispute. The identifier of the payment dispute is passed in as a path parameter. The output includes a timestamp for each action of the payment dispute, from creation to resolution, and all steps in between.
**Parameters:**
- **payment_dispute_id** (string) *required*
  - This parameter is used to specify the unique identifier of the payment dispute associated with the activity log being retrieved.

Use the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method to retrieve payment dispute IDs.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.payment.dispute`


### getPaymentDisputeSummaries

#### GET /payment_dispute_summary
**Description:** This method is used retrieve one or more payment disputes filed against the seller. These payment disputes can be open or recently closed. The following filter types are available in the request payload to control the payment disputes that are returned:

*   Dispute filed against a specific order (**order\_id** parameter is used)
*   Dispute(s) filed by a specific buyer (**buyer\_username** parameter is used)
*   Dispute(s) filed within a specific date range (**open\_date\_from** and/or **open\_date\_to** parameters are used)
*   Disputes in a specific state (**payment\_dispute\_status** parameter is used)

More than one of these filter types can be used together. See the request payload request fields for more information about how each filter is used.

If none of the filters are used, all open and recently closed payment disputes are returned.

Pagination is also available. See the **limit** and **offset** fields for more information on how pagination is used for this method.
**Parameters:**
- **order_id** (string)
  - This filter is used if the seller wishes to retrieve one or more payment disputes filed against a specific order. It is possible that there can be more than one dispute filed against an order if the order has multiple line items. If this filter is used, any other filters are ignored.

Use the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) method to retrieve order IDs. Order ID values are also shown in My eBay/Seller Hub.
- **buyer_username** (string)
  - This filter is used if the seller wishes to retrieve one or more payment disputes opened by a specific buyer. The string that is passed in to this query parameter is the eBay user ID of the buyer.
- **open_date_from** (string)
  - The **open\_date\_from** and/or **open\_date\_to** date filters are used if the seller wishes to retrieve payment disputes opened within a specific date range. A maximum date range that may be set with the **open\_date\_from** and/or **open\_date\_to** filters is 90 days. These date filters use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu.

The **open\_date\_from** field sets the beginning date of the date range, and can be set as far back as 18 months from the present time. If a **open\_date\_from** field is used, but a **open\_date\_to** field is not used, the **open\_date\_to** value will default to 90 days after the date specified in the **open\_date\_from** field, or to the present time if less than 90 days in the past.

The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **open_date_to** (string)
  - The **open\_date\_from** and/or **open\_date\_to** date filters are used if the seller wishes to retrieve payment disputes opened within a specific date range. A maximum date range that may be set with the **open\_date\_from** and/or **open\_date\_to** filters is 90 days. These date filters use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu.

The **open\_date\_to** field sets the ending date of the date range, and can be set up to 90 days from the date set in the **open\_date\_from** field.

The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **payment_dispute_status** (string)
  - This filter is used if the seller wishes to only retrieve payment disputes in one or more specific states. To filter by more than one status value, a separate **payment\_dispute\_status** filter must be used for each value, as shown below:

_https://apiz.ebay.com/sell/fulfillment/v1/payment\_dispute\_summary?payment\_dispute\_status=OPEN&payment\_dispute\_status=ACTION\_NEEDED_

If no **payment\_dispute\_status** filter is used, payment disputes in all states are returned in the response.

See [DisputeStateEnum](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdispute.disputestateenum) type for supported values.
- **limit** (string)
  - The value passed in this query parameter sets the maximum number of payment disputes to return per page of data. The value passed in this field should be an integer from 1 to 200. If this query parameter is not set, up to 200 records will be returned on each page of results.

**Min**: 1

**Max**: 200

**Default**: 200
- **offset** (string)
  - This field is used to specify the number of records to skip in the result set before returning the first payment dispute in the paginated response. A zero-based index is used, so if you set the **offset** value to `0` (default value), the first payment dispute in the result set appears at the top of the response.

Combine **offset** with the **limit** parameter to control the payment disputes returned in the response. For example, if you supply an **offset** value of `0` and a **limit** value of `10`, the response will contain the first 10 payment disputes from the result set that matches the input criteria. If you supply an **offset** value of `10` and a **limit** value of `20`, the response will contain payment disputes 11-30 from the result set that matches the input criteria.

**Min**: 0

**Default**: 0
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.payment.dispute`


### contestPaymentDispute

#### POST /payment_dispute/{payment_dispute_id}/contest
**Description:** This method is used if the seller wishes to contest a payment dispute initiated by the buyer. The unique identifier of the payment dispute is passed in as a path parameter, and unique identifiers for payment disputes can be retrieved with the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method.

**Note:** Before contesting a payment dispute, the seller must upload all supporting files using the **addEvidence** and **updateEvidence** methods. Once the seller has officially contested the dispute (using **contestPaymentDispute**), the **addEvidence** and **updateEvidence** methods can no longer be used. In the **evidenceRequests** array of the **getPaymentDispute** response, eBay prompts the seller with the type of supporting file(s) that will be needed to contest the payment dispute.
If a seller decides to contest a payment dispute, that seller should be prepared to provide supporting documents such as proof of delivery, proof of authentication, or other documents. The type of supporting documents that the seller will provide will depend on why the buyer filed the payment dispute.

The **revision** field in the request payload is required, and the **returnAddress** field should be supplied if the seller is expecting the buyer to return the item. See the Request Payload section for more information on these fields.
**Parameters:**
- **payment_dispute_id** (string) *required*
  - This parameter is used to specify the unique identifier of the payment dispute being contested.

Use the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method to retrieve payment dispute IDs.
- **Content-Type** (string) *required*
  - This header indicates the format of the request body provided by the client. Its value should be set to **application/json**.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.payment.dispute`


### acceptPaymentDispute

#### POST /payment_dispute/{payment_dispute_id}/accept
**Description:** This method is used if the seller wishes to accept a payment dispute. The unique identifier of the payment dispute is passed in as a path parameter, and unique identifiers for payment disputes can be retrieved with the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method.

The **revision** field in the request payload is required, and the **returnAddress** field should be supplied if the seller is expecting the buyer to return the item. See the Request Payload section for more information on theste fields.
**Parameters:**
- **payment_dispute_id** (string) *required*
  - This parameter is used to specify the unique identifier of the payment dispute being accepted.

Use the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method to retrieve payment dispute IDs.
- **Content-Type** (string) *required*
  - This header indicates the format of the request body provided by the client. Its value should be set to **application/json**.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.payment.dispute`


### uploadEvidenceFile

#### POST /payment_dispute/{payment_dispute_id}/upload_evidence_file
**Description:** This method is used to upload an evidence file for a contested payment dispute. The unique identifier of the payment dispute is passed in as a path parameter, and unique identifiers for payment disputes can be retrieved with the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method.

**Note:** The **uploadEvidenceFile** only uploads an encrypted, binary image file (using **multipart/form-data** HTTP request header), and does not have a JSON-based request payload.

Use 'file' as the name of the key that you use to upload the image file. The upload will not be successful if a different key name is used.

The three image formats supported at this time are **.JPEG**, **.JPG**, and **.PNG**.
After the file is successfully uploaded, the seller will need to grab the **fileId** value in the response payload to add this file to a new evidence set using the **addEvidence** method, or to add this file to an existing evidence set using the **updateEvidence** method.


**Important!** This method only supports file upload. If `PROOF_OF_DELIVERY` is requested when contesting a payment dispute, do **not** upload shipment tracking information for proof of order delivery using this method. Instead, use the [createShippingFulfillment](/develop/api/sell/fulfillment_api#sell-fulfillment_api-shipping_fulfillment-createshippingfulfillment) to provide tracking information evidence for a dispute.
**Parameters:**
- **payment_dispute_id** (string) *required*
  - This parameter is used to specify the unique identifier of the contested payment dispute for which the user intends to upload an evidence file.

Use the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method to retrieve payment dispute IDs.
- **Content-Type** (string) *required*
  - This header indicates the format of the request body provided by the client. Its value should be set to **multipart/form-data**.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.payment.dispute`


### addEvidence

#### POST /payment_dispute/{payment_dispute_id}/add_evidence
**Description:** This method is used by the seller to add one or more evidence files to address a payment dispute initiated by the buyer. The unique identifier of the payment dispute is passed in as a path parameter, and unique identifiers for payment disputes can be retrieved with the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method.

**Note:** All evidence files should be uploaded using **addEvidence** and **updateEvidence** before the seller decides to contest the payment dispute. Once the seller has officially contested the dispute (using **contestPaymentDispute** or through My eBay), the **addEvidence** and **updateEvidence** methods can no longer be used. In the **evidenceRequests** array of the **getPaymentDispute** response, eBay prompts the seller with the type of evidence file(s) that will be needed to contest the payment dispute.

The file(s) to add are identified through the **files** array in the request payload. Adding one or more new evidence files for a payment dispute triggers the creation of an evidence file, and the unique identifier for the new evidence file is automatically generated and returned in the **evidenceId** field of the **addEvidence** response payload upon a successful call.

The type of evidence being added should be specified in the **evidenceType** field. All files being added (if more than one) should correspond to this evidence type.

Upon a successful call, an **evidenceId** value is returned in the response. This indicates that a new evidence set has been created for the payment dispute, and this evidence set includes the evidence file(s) that were passed in to the **fileId** array. The **evidenceId** value will be needed if the seller wishes to add to the evidence set by using the **updateEvidence** method, or if they want to retrieve a specific evidence file within the evidence set by using the [fetchEvidenceContent](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-fetchevidencecontent) method.
**Parameters:**
- **payment_dispute_id** (string) *required*
  - This parameter is used to specify the unique identifier of the contested payment dispute for which the seller wishes to add evidence files.

Use the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method to retrieve payment dispute IDs.
- **Content-Type** (string) *required*
  - This header indicates the format of the request body provided by the client. Its value should be set to **application/json**.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.payment.dispute`


### updateEvidence

#### POST /payment_dispute/{payment_dispute_id}/update_evidence
**Description:** This method is used by the seller to update an existing evidence set for a payment dispute with one or more evidence files. The unique identifier of the payment dispute is passed in as a path parameter, and unique identifiers for payment disputes can be retrieved with the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method.

**Note:** All evidence files should be uploaded using **addEvidence** and **updateEvidence** before the seller decides to contest the payment dispute. Once the seller has officially contested the dispute (using **contestPaymentDispute** or through My eBay), the **addEvidence** and **updateEvidence** methods can no longer be used. In the **evidenceRequests** array of the **getPaymentDispute** response, eBay prompts the seller with the type of evidence file(s) that will be needed to contest the payment dispute.
The unique identifier of the evidence set to update is specified through the **evidenceId** field, and the file(s) to add are identified through the **files** array in the request payload. The unique identifier for an evidence file is automatically generated and returned in the **fileId** field of the **uploadEvidence** response payload upon a successful call. Sellers must make sure to capture the **fileId** value for each evidence file that is uploaded with the **uploadEvidence** method.

The type of evidence being added should be specified in the **evidenceType** field. All files being added (if more than one) should correspond to this evidence type.

Upon a successful call, an http status code of `204 Success` is returned. There is no response payload unless an error occurs. To verify that a new file is a part of the evidence set, the seller can use the [fetchEvidenceContent](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-fetchevidencecontent) method, passing in the proper **evidenceId** and **fileId** values.
**Parameters:**
- **payment_dispute_id** (string) *required*
  - This parameter is used to specify the unique identifier of the contested payment dispute for which the user plans to update the evidence set.

Use the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method to retrieve payment dispute IDs.
- **Content-Type** (string) *required*
  - This header indicates the format of the request body provided by the client. Its value should be set to **application/json**.
**OAuth scope**

This request requires an access token created with the **Client Credentials Grant** flow, using one or more scopes from the following list (please check your Application Keys page for a list of OAuth scopes available to your application):

**Required Scopes:**

**Client Credentials Grant:**

- `https://api.ebay.com/oauth/api_scope/sell.payment.dispute`


## Error Codes

The following error codes may be returned by this API:

### REQUEST Errors

#### 32100 - API_FULFILLMENT
**Description:** Invalid order ID: {orderId}

#### 32800 - API_FULFILLMENT
**Description:** Invalid field group: {fieldGroup}

#### 30700 - API_FULFILLMENT
**Description:** Invalid filter name: {fieldname}

#### 30800 - API_FULFILLMENT
**Description:** Invalid filter value {fieldvalue} for filter {fieldname}

#### 30810 - API_FULFILLMENT
**Description:** Invalid date format

#### 30820 - API_FULFILLMENT
**Description:** Start date is missing

#### 30830 - API_FULFILLMENT
**Description:** Time range between start date and end date must be within '{allowedTime}' years.

#### 30840 - API_FULFILLMENT
**Description:** Start date should be before end date

#### 30850 - API_FULFILLMENT
**Description:** Start and end dates can't be in the future

#### 30900 - API_FULFILLMENT
**Description:** Exceeded maximum number of order IDs (the current limit is `50`)

#### 31000 - API_FULFILLMENT
**Description:** Invalid offset: {offsetvalue}

#### 31100 - API_FULFILLMENT
**Description:** Invalid limit: {limitvalue}

#### 34901 - API_FULFILLMENT
**Description:** Order ID can't be null or empty.

#### 34902 - API_FULFILLMENT
**Description:** Request can't be empty.

#### 34903 - API_FULFILLMENT
**Description:** The refund reason must be specified.

#### 34905 - API_FULFILLMENT
**Description:** Either **orderLevelRefundAmount** or **refundItems** must be specified.

#### 34906 - API_FULFILLMENT
**Description:** The amount value must be specified.

#### 34907 - API_FULFILLMENT
**Description:** The amount value must be positive and within two decimals.

#### 34908 - API_FULFILLMENT
**Description:** The amount currency must be specified.

#### 34909 - API_FULFILLMENT
**Description:** The amount currency isn't correct.

#### 34910 - API_FULFILLMENT
**Description:** Either **legacyReference** or **lineItemId** must be specified for item level refund.

#### 34911 - API_FULFILLMENT
**Description:** Legacy item ID must be specified for item level refund if you use **legacyReference**.****

#### 34912 - API_FULFILLMENT
**Description:** Legacy transaction id must be specified for item level refund if you use **legacyReference**.

#### 34914 - API_FULFILLMENT
**Description:** Can't find the item in the order.

#### 34915 - API_FULFILLMENT
**Description:** The refund amount exceeds order amount.

#### 34921 - API_FULFILLMENT
**Description:** The comment exceeds the length limit, please make sure it doesn't exceed 1000 characters.

#### 34922 - API_FULFILLMENT
**Description:** Refund cannot be issued while previous refund is processing.

#### 34923 - API_FULFILLMENT
**Description:** Refund cannot be issued for this type of order.

#### 34913 - API_FULFILLMENT
**Description:** Can not find the order.

#### 34919 - API_FULFILLMENT
**Description:** Unauthorized access.

#### 34929 - API_FULFILLMENT
**Description:** You cannot refund this order yet since the buyer payment has not been processed. Please try again later.

#### 34930 - API_FULFILLMENT
**Description:** Default payment method limit exceeded. Please use a different payment option or try again later.

#### 32200 - API_FULFILLMENT
**Description:** Invalid line item id: {lineItemId}

#### 32210 - API_FULFILLMENT
**Description:** Duplicate line item in the request

#### 32300 - API_FULFILLMENT
**Description:** Invalid shipment tracking number or carrier

#### 32400 - API_FULFILLMENT
**Description:** Requested user is suspended

#### 32500 - API_FULFILLMENT
**Description:** Invalid shipped date

#### 32600 - API_FULFILLMENT
**Description:** Invalid input data

#### 34100 - API_FULFILLMENT
**Description:** Maximum tracking number for order is exceeded

#### 34200 - API_FULFILLMENT
**Description:** Line Items contain Global Shipping Program and non-Global Shipping Program orders

#### 34300 - API_FULFILLMENT
**Description:** Mark As Shipped for multiple Global Shipping Program line items is not supported

#### 34500 - API_FULFILLMENT
**Description:** Please use PUT operation for updating shipping fulfillment

#### 32110 - API_FULFILLMENT
**Description:** Invalid shipping fulfillment ID: {fulfillmentId}

#### 33001 - API_FULFILLMENT
**Description:** Invalid Payment Dispute Id

#### 33002 - API_FULFILLMENT
**Description:** Invalid Evidence Id

#### 33003 - API_FULFILLMENT
**Description:** Invalid Evidence File Id

#### 33100 - API_FULFILLMENT
**Description:** Invalid input request

#### 33011 - API_FULFILLMENT
**Description:** There was a change in payment dispute attributes. Please use get payment dispute api to get latest details.

#### 33101 - API_FULFILLMENT
**Description:** Invalid payment dispute state

#### 33102 - API_FULFILLMENT
**Description:** No evidence available for contest

#### 33005 - API_FULFILLMENT
**Description:** File type is invalid.

#### 33006 - API_FULFILLMENT
**Description:** File size should be 1.5 MB or less.

#### 33106 - API_FULFILLMENT
**Description:** The file name should not be empty and should not exceed 255 characters.

#### 33107 - API_FULFILLMENT
**Description:** Only one file can be uploaded per request.

#### 33004 - API_FULFILLMENT
**Description:** Upload file for evidence is not permitted for given payment dispute state.

#### 33105 - API_FULFILLMENT
**Description:** You reached the maximum number of files you can upload.

#### 33007 - API_FULFILLMENT
**Description:** Invalid line items.

#### 33008 - API_FULFILLMENT
**Description:** Invalid evidence type.

#### 33009 - API_FULFILLMENT
**Description:** User did not echo back the evidence metadata correctly.

#### 33103 - API_FULFILLMENT
**Description:** Exceed allowed file count

#### 33104 - API_FULFILLMENT
**Description:** The combined size of attached files should be 1.5MB or less.

#### 33010 - API_FULFILLMENT
**Description:** Evidence Id is invalid

### APPLICATION Errors

#### 30500 - API_FULFILLMENT
**Description:** System error

#### 34900 - API_FULFILLMENT
**Description:** There was a problem with an eBay internal system or process. Contact eBay developer support for assistance.

#### 33000 - API_FULFILLMENT
**Description:** There was a problem with an eBay internal system or process. Contact eBay developer support for assistance.

### BUSINESS Errors

#### 34916 - API_FULFILLMENT
**Description:** A post-transaction case exists on this order, seller refund can't be triggered.

#### 34917 - API_FULFILLMENT
**Description:** This order was already refunded.

#### 34920 - API_FULFILLMENT
**Description:** It's too late to issue a refund for this order.

#### 34918 - API_FULFILLMENT
**Description:** This is not an eBay managed payments order.

#### 34924 - API_FULFILLMENT
**Description:** The item refund amount exceeds the item remaining amount.

#### 34925 - API_FULFILLMENT
**Description:** The refund operation could not be completed with any of the payment methods saved to the seller's account.

#### 34926 - API_FULFILLMENT
**Description:** A suitable payment method could not be found for the refund operation. Please resolve in Seller Hub.

#### 34927 - API_FULFILLMENT
**Description:** The selected payment method for the refund operation was invalid or declined.

#### 34928 - API_FULFILLMENT
**Description:** Your refund did not go through because we could not verify your payment option. Please change your payment option and try again.

## Types

### AcceptPaymentDisputeRequest
**Description:** This type is used by base request of the **acceptPaymentDispute** method.
**Type:** object

**Properties:**
- **returnAddress** (ReturnAddress)
  - This container is used if the seller wishes to provide a return address to the buyer. This container should be used if the seller is requesting that the buyer return the item.
- **revision** (integer)
  - This integer value indicates the revision number of the payment dispute. This field is required. The current **revision** number for a payment dispute can be retrieved with the **getPaymentDispute** method. Each time an action is taken against a payment dispute, this integer value increases by 1.

### ActivityEnum
**Description:** This enumerated type defines the different activities that can occur with a payment dispute. Different actors perform different activities.

**Note:** Presently, there is not an API method for the seller to appeal a dispute decision. [How to appeal a decision](<https://www.ebay.com/help/selling/managing-returns-refunds/appeal-ebays-decision-return-missing-item-sellers?id=4369#section2 >) contains the process for starting an appeal. | - **DISPUTE_OPENED**: This enumeration value indicates that the buyer opened up a payment dispute against the seller. - **ADDITIONAL_EVIDENCE_REQUEST**: This enumeration value indicates that eBay requested additional evidence from the seller to help settle the payment dispute. - **EVIDENCE_PROVIDED**: EVIDENCE_PROVIDED - **EVIDENCE_REQUEST_OVERDUE**: This enumeration value indicates that the seller's response to an evidence request from eBay is overdue. - **DEFENCE_EXECUTED**: This enumeration value indicates that eBay has provided the seller's submitted evidence to the payment processor. - **DISPUTE_CLOSED**: This enumeration value indicates that the payment dispute has been closed. The seller would use a getPaymentDispute call and look for the resolution.reasonForClosure value in the response to see the outcome. - **SELLER_ACCEPT**: This enumeration value indicates that the seller accepted the payment dispute and agrees to issue a refund to buyer. - **SELLER_ACCEPT_WITH_RETURN**: SELLER_ACCEPT_WITH_RETURN - **SELLER_CONTEST**: This enumeration value indicates that the seller is contesting the payment dispute. - **DISPUTE_UPDATED**: This enumeration value indicates that the payment dispute has been updated. - **SELLER_RESPONSE_OVERDUE**: This enumeration value indicates that the seller's response to the payment dispute is overdue. - **DISPUTE_REOPENED**: This enumeration value indicates that a previously closed payment dispute has been reopened. - **DISPUTE_REVERSED**: This enumeration value indicates that in the case of a dispute that was previously closed as Seller Lost, the decision has been reversed to Seller Won. eBay will credit back to the seller the amount that was recouped by eBay when the dispute was originally closed as Seller Lost. - **APPEAL_DENIED**: This enumeration value indicates eBay has declined the seller's appeal and upheld the original decision. - **APPEAL_GRANTED**: This enumeration value indicates eBay has granted the seller's appeal.
**Type:** object

### ActorEnum
**Description:** This enumerated type defines the possible actors that may perform an action on a payment dispute. | - **SELLER**: This enumeration value indicates that the seller was the actor that performed the corresponding activity on the payment dispute. - **BUYER**: This enumeration value indicates that the buyer was the actor that performed the corresponding activity on the payment dispute. - **CS_AGENT**: This enumeration value indicates that eBay customer service was the actor that performed the corresponding activity on the payment dispute. - **SYSTEM**: This enumeration value indicates that the system was the actor that performed the corresponding activity on the payment dispute.
**Type:** object

### AddEvidencePaymentDisputeRequest
**Description:** This type is used by the request payload of the **addEvidence** method. The **addEvidence** method is used to create a new evidence set against a payment dispute with one or more evidence files.
**Type:** object

**Properties:**
- **evidenceType** (EvidenceTypeEnum)
  - This field is used to indicate the type of evidence being provided through one or more evidence files. All evidence files (if more than one) should be associated with the evidence type passed in this field.

See the [EvidenceTypeEnum](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-addevidence.evidencetypeenum) type for the supported evidence types.
- **files** (array)
  - This array is used to specify one or more evidence files that will become part of a new evidence set associated with a payment dispute. At least one evidence file must be specified in the **files** array.
- **lineItems** (array)
  - This array identifies the order line item(s) for which the evidence file(s) will be applicable.

These values are returned under the **evidenceRequests.lineItems** array in the [getPaymentDispute](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdispute) response.

### AddEvidencePaymentDisputeResponse
**Description:** This type is used by the response payload of the **addEvidence** method. Its only field is an unique identifier of an evidence set.
**Type:** object

**Properties:**
- **evidenceId** (string)
  - The value returned in this field is the unique identifier of the newly-created evidence set. Upon a successful call, this value is automatically genererated. This new evidence set for the payment dispute includes the evidence file(s) that were passed in to the **fileId** array in the request payload. The **evidenceId** value will be needed if the seller wishes to add to the evidence set by using the **updateEvidence** method, or if they want to retrieve a specific evidence file within the evidence set by using the [fetchEvidenceContent](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-fetchevidencecontent) method.

### Address
**Description:** This type contains the details of a geographical address.
**Type:** object

**Properties:**
- **addressLine1** (string)
  - The first line of the street address.

**Note:** **addressLine1** will not be returned for any order that is more than 90 days old.
- **addressLine2** (string)
  - The second line of the street address. This field can be used for additional address information, such as a suite or apartment number. This field will be returned if defined for the shipping address.

**Note:** **addressLine2** will not be returned for any order that is more than 90 days old.
- **city** (string)
  - The city of the shipping destination.
- **countryCode** (CountryCodeEnum)
  - The country of the shipping destination, represented as a two-letter ISO 3166‑1 alpha‑2 country code. For example, `US` represents the United States, and `DE` represents Germany.
- **county** (string)
  - The county of the shipping destination. Counties typically, but not always, contain multiple cities or towns. This field is returned if known/available.
- **postalCode** (string)
  - The postal code of the shipping destination. This is usually referred to as ZIP codes in the US. Most countries have postal codes, but not all. The postal code will be returned, if applicable.
- **stateOrProvince** (string)
  - The state or province of the shipping destination. Most countries have states or provinces, but not all. The state or province will be returned if applicable.

### Amount
**Description:** This type defines the monetary value of an amount. It can provide the amount in both the currency used on the eBay site where an item is being offered and the conversion of that value into another currency, if applicable.
**Type:** object

**Properties:**
- **convertedFromCurrency** (CurrencyCodeEnum)
  - A three-letter [ISO 4217](https://www.iso.org/iso-4217-currency-codes.html "https://www.iso.org ") code that indicates the currency of the amount in the **convertedFromValue** field. This value is required or returned only if currency conversion/localization is required and represents the pre-conversion currency.
- **convertedFromValue** (string)
  - The monetary amount, before any conversion is performed, in the currency specified by the **convertedFromCurrency** field. This value is required or returned only if currency conversion/localization is required. The **value** field contains the converted amount of this value in the currency specified by the **currency** field.
- **currency** (CurrencyCodeEnum)
  - A three-letter [ISO 4217](https://www.iso.org/iso-4217-currency-codes.html "https://www.iso.org ") code that indicates the currency of the amount in the **value** field. If currency conversion/localization is required, this is the post-conversion currency of the amount in the **value** field.

**Default:** The default currency with be that of the eBay marketplace that hosts the listing.
- **value** (string)
  - The monetary amount in the currency specified by the **currency** field. If currency conversion/localization is required, this value is the converted amount, and the **convertedFromValue** field contains the amount in the original currency.

_Required_ in the **amount** type.

### AppliedPromotion
**Description:** This type contains information about a sales promotion that is applied to a line item.
**Type:** object

**Properties:**
- **description** (string)
  - A description of the applied sales promotion.
- **discountAmount** (Amount)
  - The monetary amount of the sales promotion.
- **promotionId** (string)
  - An eBay-generated unique identifier of the sales promotion.

Multiple types of sales promotions are available to eBay Store owners, including order size/volume discounts, shipping discounts, special coupons, and price markdowns. Sales promotions can be managed through the Marketing tab of Seller Hub in My eBay or by using the Marketing API's **createItemPromotion** method.

### AppointmentDetails
**Description:** This type contains information used by the installation provider concerning appointment details selected by the buyer.
**Type:** object

**Properties:**
- **appointmentEndTime** (string)
  - The date and time the appointment ends, formatted as an [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") string, which is based on the 24-hour Coordinated Universal Time (UTC) clock. Required for tire installation.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2022-10-28T00:00:00.000Z`
- **appointmentStartTime** (string)
  - The date and time the appointment begins, formatted as an [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") string, which is based on the 24-hour Coordinated Universal Time (UTC) clock.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2022-10-28T00:10:00.000Z`
- **appointmentStatus** (AppointmentStatusEnum)
  - The status of the appointment.
- **appointmentType** (AppointmentTypeEnum)
  - The type of appointment. `MACRO` appointments only have a start time (not bounded with end time). `TIME_SLOT` appointments have a period (both start time and end time). Required for tire installation.
- **appointmentWindow** (AppointmentWindowEnum)
  - Appointment window for `MACRO` appointments.
- **serviceProviderAppointmentDate** (string)
  - Service provider date of the appointment (no time stamp). Returned only for `MACRO` appointment types.

### AppointmentStatusEnum
**Description:** An enumerated type for the appointment status of tire installation values. | - **ON_HOLD**: The appointment is on hold. - **CONFIRMED**: The appointment has been confirmed. - **CANCELLED**: The appointment has been canceled by the customer. - **FULFILLED**: The appointment has been completed.
**Type:** object

### AppointmentTypeEnum
**Description:** An enumerated type for appointment values. | - **TIME_SLOT**: Indicates this appointment has both start and end date-times. - **MACRO**: Indicates this appointment has both start date-time (**appointmentStartTime**) and may have a service provider appointment date (**serviceProviderAppointmentDate**).
**Type:** object

### AppointmentWindowEnum
**Description:** An enumerated type for window slot values. | - **MORNING**: Appointment window starts before noon. - **EVENING**: Appointment window starts after noon.
**Type:** object

### AuthenticityVerificationReasonEnum
**Description:** This enumerated type lists the possible outcomes of an authentication verification inspection on an order line item. | - **NOT_AUTHENTIC**: This enumerated value indicates that the order line item could not be authenticated. This means that the order line item has failed the authenticity verification inspection. - **NOT_AS_DESCRIBED**: This enumeration value indicates that the order line item is not as described. This means that the order line item has failed the authenticity verification inspection because the order line item does not match the order line item's description. - **CUSTOMIZED**: This enumeration value indicates that the order line item is customized and will be sent to the buyer. This means that the order line item has been altered or customized and cannot be labeled as authentic. - **MISCATEGORIZED**: This enumeration value indicates that the order line item is miscategorized and will be sent to the buyer. This means that the item was in the wrong eBay category, and cannot be labeled as authentic. - **NOT_AUTHENTIC_NO_RETURN**: This enumeration value indicates that the order line item was found as counterfeit and cannot be returned to the seller because of legal constraints.
**Type:** object

### AuthenticityVerificationStatusEnum
**Description:** This enumerated type defines all possible statuses of an order line item going through an authenticity verification inspection. | - **PENDING**: This enumerated value indicates that the authentication status is PENDING. The item's authenticity is still unknown. - **PASSED**: This enumerated value indicates that the authentication status has PASSED. The item is authentic. - **FAILED**: This enumerated value indicates that the authentication has FAILED. The item's authenticity could not be verified. - **PASSED_WITH_EXCEPTION**: This enumerated value indicates that the authentication status has PASSED\_WITH\_EXCEPTION. There may be legal reasons or requirements such that the item cannot be labeled authentic.
**Type:** object

### Buyer
**Description:** This type contains information about the order's buyer.
**Type:** object

**Properties:**
- **buyerRegistrationAddress** (ExtendedContact)
  - This container is the buyer's contact information that includes the buyer's name, email, phone number, and address.
- **taxAddress** (TaxAddress)
  - This container consists of address information that can be used by sellers for tax purpose.

**Note:** When using the eBay vault program, if an item is shipped to a vault, the tax address will be the vault address.
- **taxIdentifier** (TaxIdentifier)
  - This container consists of taxpayer identification information for buyers from Italy, Spain, or Guatemala. It is currently only returned for orders occurring on the eBay Italy or eBay Spain marketplaces.

**Note:** Currently, the **taxIdentifier** container is only returned in [getOrder](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder) and not in [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders). So, if a seller wants to view a buyer's tax information for a particular order returned in **getOrders**, that seller would need to use the **orderId** value for that particular order and then run a **getOrder** call against that order ID.
- **username** (string)
  - The buyer's eBay user ID.

**Note:** Effective September 26, 2025, select developers will no longer receive username data for U.S. users through this field. Instead, an immutable user ID will be returned in its place. For more information, please refer to [Data Handling Compliance](/api-docs/static/data-handling-update.html).

### CancelRequest
**Description:** This type contains information about a buyer request to cancel an order.
**Type:** object

**Properties:**
- **cancelCompletedDate** (string)
  - This string is the date and time that the order cancellation was completed, if applicable. This timestamp is in [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock. This field is not returned until the cancellation request has actually been approved by the seller.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **cancelInitiator** (string)
  - This string value indicates the party who made the initial cancellation request. This is typically, either the 'Buyer' or 'Seller'. If a cancellation request has been made, this field should be returned.
- **cancelReason** (string)
  - This string indicates the reason why the **cancelInitiator** initiated the cancellation request. Cancellation reasons for a buyer might include 'order placed by mistake' or 'order won't arrive in time'. For a seller, a typical cancellation reason is 'out of stock'. If a cancellation request has been made, this field should be returned.
- **cancelRequestedDate** (string)
  - This string is the date and time that the order cancellation was requested. This timestamp is in [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock. This field is returned for each cancellation request.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **cancelRequestId** (string)
  - This string vlaue is the unique identifier of the order cancellation request. This field is returned for each cancellation request.
- **cancelRequestState** (CancelRequestStateEnum)
  - The current stage or condition of the cancellation request. This field is returned for each cancellation request.

### CancelRequestStateEnum
**Description:** This enumeration type defines the possible status of an order cancellation request. | - **COMPLETED**: This value indicates that the order cancellation request was successfully processed and completed. - **REJECTED**: This value indicates that the buyer's request to cancel the order has been rejected by the seller. - **REQUESTED**: This value indicates that the buyer has requested that a particular order be cancelled, but the seller has yet to accept or reject the cancellation request.
**Type:** object

### CancelStateEnum
**Description:** This enumerated type contains a list of the states that can apply to an order with regard to cancellation. | - **CANCELED**: This value indicates the order has been cancelled. - **IN_PROGRESS**: This value indicated that one or more cancellation requests have been made against the order. - **NONE_REQUESTED**: This value indicates that no cancellation requests have been made against the order.
**Type:** object

### CancelStatus
**Description:** This type contains information about any requests that have been made to cancel an order.
**Type:** object

**Properties:**
- **cancelledDate** (string)
  - The date and time the order was cancelled, if applicable. This timestamp is in [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **cancelRequests** (array)
  - This array contains details of one or more buyer requests to cancel the order.

**For the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) call:** This array is returned but is always empty.

**For the [getOrder](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder) call:** This array is returned fully populated with information about any cancellation requests.
- **cancelState** (CancelStateEnum)
  - The state of the order with regard to cancellation. This field is always returned, and if there are no cancellation requests, a value of `NONE_REQUESTED` is returned.

### Charge
**Description:** This type is used to display the charge type and the amount of the charge against the buyer.
**Type:** object

**Properties:**
- **amount** (Amount)
  - This container shows the amount and currency of the charge.
- **chargeType** (ChargeTypeEnum)
  - This field shows the type of buyer charge.

**Note:** Currently, the only supported charge type is `BUYER_PROTECTION`.

### ChargeTypeEnum
**Description:** This enumeration type contains the type of charges that may be returned under the **charges** array. | - **BUYER_PROTECTION**: This enumeration value indicates that the buyer was charged a Buyer Protection fee. This fee applies only when a buyer purchases an item from a private seller on the eBay UK marketplace and includes both the fee and applicable tax against the fee.
**Type:** object

### CollectionMethodEnum
**Description:** This enumerated type defines the collection methods that are used to collect either 'Collect and Remit' sales tax in the US, or 'Good and Services' tax in Australia and New Zealand.

**Note:** Although the **collectionMethod** field is returned for all orders subject to 'Collect and Remit' tax, the **collectionMethod** field and the **CollectionMethodEnum** type are not currently of any practical use, although this field may have use in the future. If and when the logic of this field is changed, this note will be updated and a note will also be added to the Release Notes. | - **INVOICE**: This enumeration value is for future use only and will not currently be returned in the **collectionMethod** field. - **NET**: This enumeration value is always returned in the **collectionMethod** field for 'Collect and Remit' taxes, but the **collectionMethod** field is currently for future use.
**Type:** object

### ContestPaymentDisputeRequest
**Description:** This type is used by the request payload of the **contestPaymentDispute** method.
**Type:** object

**Properties:**
- **note** (string)
  - This field shows information that the seller provides about the dispute, such as the basis for the dispute, any relevant evidence, tracking numbers, and so forth.

**Max Length:** 1000 characters.
- **returnAddress** (ReturnAddress)
  - This container is needed if the seller is requesting that the buyer return the item. If this container is used, all relevant fields must be included, including **fullName** and **primaryPhone**.

**Note:** If the [Dispute Reason](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdispute.disputereasonenum) is `SIGNIFICANTLY_NOT_AS_DESCRIBED`, **returnAddress** is required.
- **revision** (integer)
  - This integer value indicates the revision number of the payment dispute. This field is required. The current **revision** number for a payment dispute can be retrieved with the **getPaymentDispute** method. Each time an action is taken against a payment dispute, this integer value increases by 1.

### CountryCodeEnum
**Description:** This enumerated type lists the two-letter [ISO 3166‑1 Alpha‑2](https://www.iso.org/iso/country_codes) code representing a country. | - **AD**: Andorra - **AE**: United Arab Emirates - **AF**: Afghanistan - **AG**: Antigua and Barbuda - **AI**: Anguilla - **AL**: Albania - **AM**: Armenia - **AN**: Netherlands Antilles - **AO**: Angola - **AQ**: Antarctica - **AR**: Argentina - **AS**: American Samoa - **AT**: Austria - **AU**: Australia - **AW**: Aruba - **AX**: Aland Islands - **AZ**: Azerbaijan - **BA**: Bosnia and Herzegovina - **BB**: Barbados - **BD**: Bangladesh - **BE**: Belgium - **BF**: Burkina Faso - **BG**: Bulgaria - **BH**: Bahrain - **BI**: Burundi - **BJ**: Benin - **BL**: Saint Barthelemy - **BM**: Bermuda - **BN**: Brunei Darussalam - **BO**: Bolivia - **BQ**: Bonaire, Sint Eustatius, and Saba - **BR**: Brazil - **BS**: Bahamas - **BT**: Bhutan - **BV**: Bouvet Island - **BW**: Botswana - **BY**: Belarus - **BZ**: Belize - **CA**: Canada - **CC**: Cocos (Keeling) Islands - **CD**: The Democratic Republic of the Congo - **CF**: Central African Republic - **CG**: Congo - **CH**: Switzerland - **CI**: Cote d'Ivoire - **CK**: Cook Islands - **CL**: Chile - **CM**: Cameroon - **CN**: China - **CO**: Colombia - **CR**: Costa Rica - **CU**: Cuba - **CV**: Cape Verde - **CW**: Curacao - **CX**: Christmas Island - **CY**: Cyprus - **CZ**: Czech Republic - **DE**: Germany - **DJ**: Djibouti - **DK**: Denmark - **DM**: Dominica - **DO**: Dominican Republic - **DZ**: Algeria - **EC**: Ecuador - **EE**: Estonia - **EG**: Egypt - **EH**: Western Sahara - **ER**: Eritrea - **ES**: Spain - **ET**: Ethiopia - **FI**: Finland - **FJ**: Fiji - **FK**: Falkland Islands (Malvinas) - **FM**: Federated States of Micronesia - **FO**: Faroe Islands - **FR**: France - **GA**: Gabon - **GB**: United Kingdom - **GD**: Grenada - **GE**: Georgia - **GF**: French Guiana - **GG**: Guernsey - **GH**: Ghana - **GI**: Gibraltar - **GL**: Greenland - **GM**: Gambia - **GN**: Guinea - **GP**: Guadeloupe - **GQ**: Equatorial Guinea - **GR**: Greece - **GS**: South Georgia and the South Sandwich Islands - **GT**: Guatemala - **GU**: Guam - **GW**: Guinea-Bissau - **GY**: Guyana - **HK**: Hong Kong - **HM**: Heard Island and McDonald Islands - **HN**: Honduras - **HR**: Croatia - **HT**: Haiti - **HU**: Hungary - **ID**: Indonesia - **IE**: Ireland - **IL**: Israel - **IM**: Isle of Man - **IN**: India - **IO**: British Indian Ocean Territory - **IQ**: Iraq - **IR**: Islamic Republic of Iran - **IS**: Iceland - **IT**: Italy - **JE**: Jersey - **JM**: Jamaica - **JO**: Jordan - **JP**: Japan - **KE**: Kenya - **KG**: Kyrgyzstan - **KH**: Cambodia - **KI**: Kiribati - **KM**: Comoros - **KN**: Saint Kitts and Nevis - **KP**: Democratic People's Republic of Korea - **KR**: Republic of Korea - **KW**: Kuwait - **KY**: Cayman Islands - **KZ**: Kazakhstan - **LA**: Lao People's Democratic Republic - **LB**: Lebanon - **LC**: Saint Lucia - **LI**: Liechtenstein - **LK**: Sri Lanka - **LR**: Liberia - **LS**: Lesotho - **LT**: Lithuania - **LU**: Luxembourg - **LV**: Latvia - **LY**: Libyan Arab Jamahiriya - **MA**: Morocco - **MC**: Monaco - **MD**: Republic of Moldova - **ME**: Montenegro - **MF**: Saint Martin (French part) - **MG**: Madagascar - **MH**: Marshall Islands - **MK**: The Former Yugoslav Republic of Macedonia - **ML**: Mali - **MM**: Myanmar - **MN**: Mongolia - **MO**: Macao - **MP**: Northern Mariana Islands - **MQ**: Martinique - **MR**: Mauritania - **MS**: Montserrat - **MT**: Malta - **MU**: Mauritius - **MV**: Maldives - **MW**: Malawi - **MX**: Mexico - **MY**: Malaysia - **MZ**: Mozambique - **NA**: Namibia - **NC**: New Caledonia - **NE**: Niger - **NF**: Norfolk Island - **NG**: Nigeria - **NI**: Nicaragua - **NL**: Netherlands - **NO**: Norway - **NP**: Nepal - **NR**: Nauru - **NU**: Niue - **NZ**: New Zealand - **OM**: Oman - **PA**: Panama - **PE**: Peru - **PF**: French Polynesia. Includes Tahiti - **PG**: Papua New Guinea - **PH**: Philippines - **PK**: Pakistan - **PL**: Poland - **PM**: Saint Pierre and Miquelon - **PN**: Pitcairn - **PR**: Puerto Rico - **PS**: Palestinian territory Occupied - **PT**: Portugal - **PW**: Palau - **PY**: Paraguay - **QA**: Qatar - **RE**: Reunion - **RO**: Romania - **RS**: Serbia - **RU**: Russian Federation - **RW**: Rwanda - **SA**: Saudi Arabia - **SB**: Solomon Islands - **SC**: Seychelles - **SD**: Sudan - **SE**: Sweden - **SG**: Singapore - **SH**: Saint Helena - **SI**: Slovenia - **SJ**: Svalbard and Jan Mayen - **SK**: Slovakia - **SL**: Sierra Leone - **SM**: San Marino - **SN**: Senegal - **SO**: Somalia - **SR**: Suriname - **ST**: Sao Tome and Principe - **SV**: El Salvador - **SX**: Sint Maarten (Dutch part) - **SY**: Syrian Arab Republic - **SZ**: Swaziland - **TC**: Turks and Caicos Islands - **TD**: Chad - **TF**: French Southern Territories - **TG**: Togo - **TH**: Thailand - **TJ**: Tajikistan - **TK**: Tokelau - **TL**: Timor-Leste - **TM**: Turkmenistan - **TN**: Tunisia - **TO**: Tonga - **TR**: Turkey - **TT**: Trinidad and Tobago - **TV**: Tuvalu - **TW**: Taiwan - **TZ**: Tanzania - **UA**: Ukraine - **UG**: Uganda - **UM**: United States Minor Outlying Islands - **US**: United States - **UY**: Uruguay - **UZ**: Uzbekistan - **VA**: Holy See (Vatican City state) - **VC**: Saint Vincent and the Grenadines - **VE**: Venezuela - **VG**: British Virgin Islands - **VI**: the U.S. Virgin Islands - **VN**: Vietnam - **VU**: Vanuatu - **WF**: Wallis and Futuna - **WS**: Samoa - **YE**: Yemen - **YT**: Mayotte - **ZA**: South Africa - **ZM**: Zambia - **ZW**: Zimbabwe
**Type:** object

### CurrencyCodeEnum
**Description:** This enumerated type lists the three-letter [ISO 4217](<https://www.iso.org/iso-4217-currency-codes.html > "https://www.iso.org ") code representing the supported world currencies. | - **AED**: United Arab Emirates dirham - **AFN**: Afghan afghani - **ALL**: Albanian lek - **AMD**: Armenian dram - **AOA**: Angolan kwanza - **ARS**: Argentine peso - **AWG**: Aruban florin - **AZN**: Azerbaijani manat - **BAM**: Bosnia and Herzegovina convertible mark - **BBD**: Barbados dollar - **BDT**: Bangladeshi taka - **BGN**: Bulgarian lev - **BHD**: Bahraini dinar - **BIF**: Burundian franc - **BMD**: Bermudian dollar - **BND**: Brunei dollar - **BOB**: Bolivian Boliviano - **BRL**: Brazilian real - **BSD**: Bahamian dollar - **BTN**: Bhutanese ngultrum - **BWP**: Botswana pula - **BYR**: Belarusian ruble - **BZD**: Belize dollar - **CAD**: Canadian dollar - **CDF**: Congolese franc - **CLP**: Chilean peso - **CNY**: Chinese yuan renminbi - **COP**: Colombian peso - **CRC**: Costa Rican colon - **CUP**: Cuban peso - **CVE**: Cape Verde escudo - **CZK**: Czech koruna - **DJF**: Djiboutian franc - **DOP**: Dominican peso - **DZD**: Algerian dinar - **EGP**: Egyptian pound - **ERN**: Eritrean nakfa - **ETB**: Ethiopian birr - **FJD**: Fiji dollar - **FKP**: Falkland Islands pound - **GEL**: Georgian lari - **GHS**: Ghanaian cedi - **GIP**: Gibraltar pound - **DKK**: Danish krone - **GMD**: Gambian dalasi - **GNF**: Guinean franc - **GTQ**: Guatemalan quetzal - **GYD**: Guyanese dollar - **HKD**: Hong Kong dollar - **HNL**: Honduran lempira - **HRK**: Croatian kuna - **HTG**: Haitian gourde - **HUF**: Hungarian forint - **IDR**: Indonesian rupiah - **INR**: Indian rupee - **IQD**: Iraqi dinar - **IRR**: Iranian rial - **ISK**: Icelandic krona - **GBP**: British pound sterling - **JMD**: Jamaican dollar - **JOD**: Jordanian dinar - **JPY**: Japanese yen - **KES**: Kenyan shilling - **KGS**: Kyrgyzstani som - **KHR**: Cambodian riel - **KMF**: Comoro franc - **KPW**: North Korean won - **KRW**: South Korean won - **KWD**: Kuwaiti dinar - **KYD**: Cayman Islands dollar - **KZT**: Kazakhstani tenge - **LAK**: Lao kip - **LBP**: Lebanese pound - **CHF**: Swiss franc - **LKR**: Sri Lankan rupee - **LRD**: Liberian dollar - **LSL**: Lesotho loti - **LTL**: Lithuanian litas - **LYD**: Libyan dinar - **MAD**: Moroccan dirham - **MDL**: Moldovan leu - **MGA**: Malagasy ariary - **MKD**: Macedonian denar - **MMK**: Myanmar kyat - **MNT**: Mongolian tugrik - **MOP**: Macanese pataca - **MRO**: Mauritanian ouguiya - **XCD**: East Caribbean dollar - **MUR**: Mauritian rupee - **MVR**: Maldivian rufiyaa - **MWK**: Malawian kwacha - **MXN**: Mexican peso - **MYR**: Malaysian ringgit - **MZN**: Mozambican metical - **NAD**: Namibian dollar - **NGN**: Nigerian naira - **NIO**: Nicaraguan cordoba oro - **NPR**: Nepalese rupee - **OMR**: Omani rial - **PAB**: Panamanian balboa - **PEN**: Peruvian sol - **XPF**: CFP franc - **PGK**: Papua New Guinean kina - **PHP**: Philippine peso - **PKR**: Pakistani rupee - **PLN**: Polish zloty - **ILS**: Israeli new shekel - **PYG**: Paraguayan guarani - **QAR**: Qatari riyal - **RON**: Romanian leu - **RSD**: Serbian dinar - **RUB**: Russian ruble - **RWF**: Rwandan franc - **SAR**: Saudi riyal - **SBD**: Solomon Islands dollar - **SCR**: Seychelles rupee - **SDG**: Sudanese pound - **SEK**: Swedish krona - **SGD**: Singapore dollar - **SHP**: Saint Helena pound - **NOK**: Norwegian krone - **SLL**: Sierra Leonean leone - **SOS**: Somali shilling - **SRD**: Surinamese dollar - **STD**: Sao Tome and Principe dobra - **ANG**: Netherlands Antillean guilder - **SYP**: Syrian pound - **SZL**: Swazi lilangeni - **XAF**: CFA franc BEAC - **XOF**: CFA franc BCEAO - **THB**: Thai baht - **TJS**: Tajikistani somoni - **NZD**: New Zealand dollar - **TMT**: Turkmenistani manat - **TND**: Tunisian dinar - **TOP**: Tongan pa'anga - **TRY**: Turkish lira - **TTD**: Trinidad and Tobago dollar - **AUD**: Australian dollar - **TWD**: New Taiwan dollar - **TZS**: Tanzanian shilling - **UAH**: Ukrainian hryvnia - **UGX**: Ugandan shilling - **USD**: United States dollar - **UYU**: Uruguayan peso - **UZS**: Uzbekistani som - **VEF**: Venezuelan bolivar - **VND**: Vietnamese dong - **VUV**: Vanuatu vatu - **WST**: Samoan tala - **YER**: Yemeni rial - **EUR**: European Union euro - **ZAR**: South African rand - **ZMW**: Zambian kwacha - **ZWL**: Zimbabwean dollar
**Type:** object

### DeliveryCost
**Description:** This type contains a breakdown of all costs associated with the fulfillment of a line item.
**Type:** object

**Properties:**
- **discountAmount** (Amount)
  - The amount of any shipping discount that has been applied to the line item. This container is returned only if a shipping discount applies to the line item.
- **handlingCost** (Amount)
  - The amount of any handing cost that has been applied to the line item. This container is returned only if a handling cost applies to the line item.
- **importCharges** (Amount)
  - The amount of any import charges applied to international shipping of the line item. This container is only returned if import charges apply to the line item.
- **shippingCost** (Amount)
  - The total cost of shipping all units of the line item. This container is always returned even when the shipping cost is free, in which case the **value** field will show `0.0` (dollars).
- **shippingIntermediationFee** (Amount)
  - This field shows the fee due to eBay's international shipping provider for a line item that is being shipped through the Global Shipping Program.

This container is only returned for line items being shipped internationally through the Global Shipping Program, which is currently only supported in the US and UK marketplaces.

**Note:** The value returned for this field will always be `0.0` for line items sold in the UK marketplace.

### DisputeAmount
**Description:** This type defines the monetary value of an amount. It can provide the amount in both the currency used on the eBay site where an item is being offered and the conversion of that value into another currency, if applicable.
**Type:** object

**Properties:**
- **convertedFromCurrency** (CurrencyCodeEnum)
  - The three-letter [ISO 4217](https://www.iso.org/iso-4217-currency-codes.html) code representing the currency of the amount in the **convertedFromValue** field. This value is the pre-conversion currency.

This field is only returned if/when currency conversion was applied by eBay.
- **convertedFromValue** (string)
  - The monetary amount before any conversion is performed, in the currency specified by the **convertedFromCurrency** field. This value is the pre-conversion amount. The **value** field contains the converted amount of this value, in the currency specified by the **currency** field.

This field is only returned if/when currency conversion was applied by eBay.
- **currency** (CurrencyCodeEnum)
  - A three-letter [ISO 4217](https://www.iso.org/iso-4217-currency-codes.html "https://www.iso.org ") code that indicates the currency of the amount in the **value** field. This field is always returned with any container using **Amount** type.

**Default**: The currency of the authenticated user's country.
- **exchangeRate** (string)
  - The exchange rate used for the monetary conversion. This field shows the exchange rate used to convert the dollar value in the **value** field from the dollar value in the **convertedFromValue** field.

This field is only returned if/when currency conversion was applied by eBay.
- **value** (string)
  - The monetary amount, in the currency specified by the **currency** field. This field is always returned with any container using **Amount** type.

### DisputeEvidence
**Description:** This type is used by the **evidence** array that is returned in the **getPaymentDispute** response if one or more evidential documents are associated with the payment dispute.
**Type:** object

**Properties:**
- **evidenceId** (string)
  - Unique identifier for the evidential file set. Each file set may contain multiple files, which is why there is a file set identifier and a separate identifier for each individual file within the set.
- **evidenceType** (EvidenceTypeEnum)
  - This enumeration value shows the type of evidential file provided.
- **files** (array)
  - This array shows the name, ID, file type, and upload date for each provided file.
- **lineItems** (array)
  - This array shows one or more order line items associated with the evidential document that has been provided.
- **providedDate** (string)
  - The timestamp in this field shows the date/time when the seller provided a requested evidential document to eBay.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **requestDate** (string)
  - The timestamp in this field shows the date/time when eBay requested the evidential document from the seller in response to a payment dispute.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **respondByDate** (string)
  - The timestamp in this field shows the date/time when the seller was expected to provide a requested evidential document to eBay.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **shipmentTracking** (array)
  - This array shows the shipping carrier and shipment tracking number associated with each shipment package of the order. This array is returned under the **evidence** container if the seller has provided shipment tracking information as evidence to support `PROOF_OF_DELIVERY` for an INR-related payment dispute.

### DisputeReasonEnum
**Description:** This enumerated type defines the possible reasons why a buyer may open up a payment dispute against a seller. | - **TRANSACTION_ISSUE**: This enumeration value may be returned if a buyer opened a payment dispute against the seller, but eBay cannot determine the exact reason why the payment dispute was opened. - **FRAUD**: This enumeration value indicates that the payment dispute was opened because the buyer did not recognize the transaction. - **ITEM_NOT_RECEIVED**: This enumeration value indicates that the payment dispute was opened because the buyer has paid for the order, but has yet to recieve the item. - **SIGNIFICANTLY_NOT_AS_DESCRIBED**: This enumeration value indicates that the payment dispute was opened because the buyer claims that the received item is 'Significantly Not As Described' (aka SNAD case). Note: If the Dispute Reason is SIGNIFICANTLY\_NOT\_AS\_DESCRIBED, returnAddress is required when contesting a payment dispute. - **CREDIT_NOT_PROCESSED**: This enumeration value indicates that the payment dispute was opened because the buyer has yet to receive the expected refund. - **COUNTERFEIT**: This enumeration value indicates that the payment dispute was opened due to a possible counterfeit or inauthentic item. - **DUPLICATE_AMOUNT**: This enumeration value indicates that the payment dispute was opened because the buyer was charged twice. - **INCORRECT_AMOUNT**: This enumeration value indicates that the payment dispute was opened due to the buyer being charged an incorrect amount. - **CANCELLATION**: This enumeration value indicates that the payment dispute was opened because the order was cancelled but a refund has yet to be issued. - **RETURN_REFUND_NOT_PROCESSED**: This enumeration value indicates that the payment dispute was opened because the buyer returned an item, but the seller has yet to issue a refund. - **AUTHORIZATION_FAILED**: This enumeration value indicates that the payment dispute was opened because the required authorization for the payment failed.
**Type:** object

### DisputeStateEnum
**Description:** This enumeration type defines the different states of a payment dispute. | - **OPEN**: This enumeration value indicates the payment dispute is open, but there is no action required by the seller at the present time. - **ACTION_NEEDED**: This enumeration value indicates the payment dispute is open, and the seller is required to take action at the present time. The seller's choices for action are returned in the **availableChoices** array of the **getPaymentDispute** response. The seller should respond by the date/time specified in the **respondByDate** field in the **getPaymentDispute** response. - **CLOSED**: This enumeration value indicates the payment dispute is closed. The reason for the closure of the payment dispute can be viewed in the **resolution.reasonForClosure** field of the **getPaymentDispute** response, and closure date can be found in the **closedDate/ **field of the** getPaymentDispute **response.****
**Type:** object

### DisputeSummaryResponse
**Description:** This type defines the base response payload of the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method. Each payment dispute that matches the input criteria is returned under the **paymentDisputeSummaries** array.
**Type:** object

**Properties:**
- **href** (string)
  - The URI of the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) call request that produced the current page of the result set.
- **limit** (integer)
  - This value shows the maximum number of payment disputes that will appear on one page of the result set. The **limit** value can be passed in as a query parameter in the request, or if it is not used, it defaults to `200`. If the value in the **total** field exceeds this **limit** value, there are multiple pages in the current result set.

**Min**: 1; **Max**: 200; **Default**: 200
- **next** (string)
  - The [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) call URI to use if you wish to view the next page of the result set. For example, the following URI returns records 11 through 20 from the collection of payment disputes:

`path/payment_dispute_summary?limit=10&offset=10`

This field is only returned if there is a next page of results to view based on the current input criteria.
- **offset** (integer)
  - This integer value indicates the number of payment disputes skipped before listing the first payment dispute from the result set. The **offset** value can be passed in as a query parameter in the request, or if it is not used, it defaults to `0` and the first payment dispute of the result set is shown at the top of the response.
- **paymentDisputeSummaries** (array)
  - Each payment dispute that matches the input criteria is returned under this array. If no payment disputes are found, an empty array is returned.
- **prev** (string)
  - The [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) call URI to use if you wish to view the previous page of the result set. For example, the following URI returns records 1 through 10 from the collection of payment disputes:

`path/payment_dispute_summary?limit=10&offset=0`

This field is only returned if there is a previous page of results to view based on the current input criteria.
- **total** (integer)
  - This integer value is the total number of payment disputes that matched the input criteria. If the total number of entries exceeds the value that was set for **limit** in the request payload, you will have to make multiple API calls to see all pages of the results set. This field is returned even if it is `0`.

### EbayCollectAndRemitTax
**Description:** This type contains information about the type and amount of tax that eBay will collect and remit to the state, province, country, or other taxing authority in the buyer's location, as required by that taxing authority.

'Collect and Remit' tax includes:

*   US state-mandated sales tax
*   Federal and Provincial Sales Tax in Canada
*   'Goods and Services' tax in Canada, Australia, and New Zealand
*   VAT collected for the UK and EU countries
**Type:** object

**Properties:**
- **amount** (Amount)
  - The monetary amount of the 'Collect and Remit' tax. This currently includes the following:

*   US state-mandated sales tax
*   Federal and Provincial Sales Tax in Canada
*   'Goods and Services' tax in Canada, Australia, New Zealand, and Jersey
*   VAT collected for the UK, EU countries, Kazakhstan, and Belarus
*   Sales & Service Tax (SST) in Malaysia


**Note:** If the corresponding **taxType** is `STATE_SALES_TAX`, `PROVINCE_SALES_TAX`, `GST`, `VAT`, or `SST` and the **lineItems.taxes** container also appears for this line item with the same tax amount, the order is subject to 'eBay Collect and Remit' tax. For orders that are subject to 'eBay Collect and Remit' tax, the tax amount in this field will be included in the **lineItems.total**, **paymentSummary.payments.amount**, **paymentSummary.totalDueSeller**, and **pricingSummary.total** fields.
- **ebayReference** (EbayTaxReference)
  - This container field describes the line-item level VAT tax details.
- **taxType** (TaxTypeEnum)
  - The type of tax and fees that eBay will collect and remit to the taxing or fee authority. See the **TaxTypeEnum** type definition for more information about each tax or fee type.
- **collectionMethod** (CollectionMethodEnum)
  - This field indicates the collection method used to collect the 'Collect and Remit' tax for the order. This field is always returned for orders subject to 'Collect and Remit' tax, and its value is always `NET`.

**Note:** Although the **collectionMethod** field is returned for all orders subject to 'Collect and Remit' tax, the **collectionMethod** field and the **CollectionMethodEnum** type are not currently of any practical use, although this field may have use in the future. If and when the logic of this field is changed, this note will be updated and a note will also be added to the Release Notes.

### EbayCollectedCharges
**Description:** This type contains the breakdown of costs that are collected by eBay from the buyer.
**Type:** object

**Properties:**
- **ebayShipping** (Amount)
  - This container consists of costs related to eBay Shipping collected by eBay from the buyer of this order.
- **charges** (array)
  - This array shows any charges that eBay collects from the buyer.

**Note:** Currently, the only supported charge type is `BUYER_PROTECTION`.

### EbayFulfillmentProgram
**Description:** This type is used to provide details about an order line item being fulfilled by eBay or an eBay fulfillment partner.
**Type:** object

**Properties:**
- **fulfilledBy** (string)
  - The value returned in this field indicates the party that is handling fulfillment of the order line item.

**Valid value**: `EBAY`

### EbayInternationalShipping
**Description:** This type is used to provide details about an order line item being managed through eBay International Shipping.
**Type:** object

**Properties:**
- **returnsManagedBy** (string)
  - The value returned in this field indicates the party that is responsible for managing returns of the order line item.

Valid value: `EBAY`

### EbayShipping
**Description:** This type contains information about the management of the shipping for the order.
**Type:** object

**Properties:**
- **shippingLabelProvidedBy** (string)
  - This field contains the shipping label provider. If `EBAY`, this order is managed by eBay shipping and a free shipping label created by eBay is downloadable by the seller via the eBay website.

### EbayTaxReference
**Description:** This type describes the VAT tax details. The eBay VAT tax type and the eBay VAT identifier number will be returned if a VAT tax is applicable for the order.
**Type:** object

**Properties:**
- **name** (string)
  - This field value is returned to indicate the VAT tax type, which will vary by country/region. This string value will be one of the following:

*   `ABN`: If this string is returned, the ID in the **value** field is an Australia tax ID.
*   `DDG`: If this string is returned, it indicates that tax has been collected and remitted for Digitally Delivered Goods (DDG).
*   `IOSS`: If this string is returned, the ID in the **value** field is an eBay EU or UK IOSS number.
*   `IRD`: If this string is returned, the ID in the **value** field is an eBay New Zealand tax ID.
*   `SST`: If this string is returned, the ID in the **value** field is an eBay Malaysia taxNumber.
*   `OSS`: If this string is returned, the ID in the **value** field is an eBay Germany VAT ID.
*   `VOEC`: If this string is returned, the ID in the **value** field is an eBay Norway tax ID.
- **value** (string)
  - The value returned in this field is the VAT identifier number (VATIN), which will vary by country/region. This field will be returned if VAT tax is applicable for the order. The **name** field indicates the VAT tax type, which will vary by country/region:

*   **ABN**: eBay AU tax ID
*   **IOSS**: eBay EU IOSS number/eBay UK IOSS number
*   **IRD**: eBay NZ tax ID
*   **OSS**: eBay DE VAT ID
*   **SST**: eBay MY taxNumber
*   **VOEC**: eBay NO number

### EbayVaultFulfillmentTypeEnum
**Description:** This enumeration type specifies which **EbayVaultProgram** has been selected for an order. | - **SELLER_TO_VAULT**: This enumeration type indicates that the seller will ship the order to an authenticator. When using this program, **fulfillmentInstructionsType** will be set to `SHIP_TO` and the order will be shipped to the authenticator's shipping address. - **VAULT_TO_VAULT**: This enumeration type indicates that eBay will ship the order from an eBay vault to the buyer's vault. - **VAULT_TO_BUYER**: This enumeration type indicates that eBay will ship the order from an eBay vault to the shipping address provided by the buyer.
**Type:** object

### EbayVaultProgram
**Description:** This type contains details on the fulfillment type.
**Type:** object

**Properties:**
- **fulfillmentType** (EbayVaultFulfillmentTypeEnum)
  - This field specifies how an eBay vault order will be fulfilled. Supported options are:

*   **Seller to Vault**: The order will be shipped by the seller to an authenticator.
*   **Vault to Vault**: The order will be shipped from an eBay vault to the buyer's vault.
*   **Vault to Buyer**: The order will be shipped from an eBay vault to the buyer's shipping address.

### ErrorDetailV3
**Description:** This type contains an error or warning related to a call request.
**Type:** object

**Properties:**
- **category** (string)
  - The context or source of this error or warning.
- **domain** (string)
  - The name of the domain containing the service or application. For example, `sell` is a domain.
- **errorId** (integer)
  - A positive integer that uniquely identifies the specific error condition that occurred. Your application can use these values as error code identifiers in your customized error-handling algorithms.
- **inputRefIds** (array)
  - A list of one or more specific request elements (if any) associated with the error or warning. The format of these strings depends on the request payload format. For JSON, use JSONPath notation.
- **longMessage** (string)
  - An expanded version of the **message** field.

**Maximum length:** 200 characters
- **message** (string)
  - A message about the error or warning which is device agnostic and readable by end users and application developers. It explains what the error or warning is, and how to fix it (in a general sense). If applicable, the value is localized to the end user's requested locale.

**Maximum length:** 50 characters
- **outputRefIds** (array)
  - A list of one or more specific response elements (if any) associated with the error or warning. The format of these strings depends on the request payload format. For JSON, use JSONPath notation.
- **parameters** (array)
  - Contains a list of name-value pairs that provide additional information concerning this error or warning. Each item in the list is an input parameter that contributed to the error or warning condition.
- **subdomain** (string)
  - The name of the domain's subsystem or subdivision. For example, `fulfillment` is a subdomain in the `sell` domain.

### ErrorParameterV3
**Description:** This type contains the name and value of an input parameter that contributed to a specific error or warning condition.
**Type:** object

**Properties:**
- **name** (string)
  - This is the name of input field that caused an issue with the call request.
- **value** (string)
  - This is the actual value that was passed in for the element specified in the **name** field.

### EvidenceRequest
**Description:** This type is used by the **evidenceRequests** array that is returned in the **getPaymentDispute** response if one or more evidential documents are being requested to help resolve the payment dispute.
**Type:** object

**Properties:**
- **evidenceId** (string)
  - Unique identifier of the evidential file set. Potentially, each evidential file set can have more than one file, that is why there is this file set identifier, and then an identifier for each file within this file set.
- **evidenceType** (EvidenceTypeEnum)
  - This enumeration value shows the type of evidential document provided.
- **lineItems** (array)
  - This array shows one or more order line items associated with the evidential document that has been provided.
- **requestDate** (string)
  - The timestamp in this field shows the date/time when eBay requested the evidential document from the seller in response to a payment dispute.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **respondByDate** (string)
  - The timestamp in this field shows the date/time when the seller is expected to provide a requested evidential document to eBay.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.

### EvidenceTypeEnum
**Description:** This enumeration type defines the different types of evidential documentation. | - **PROOF_OF_DELIVERY**: **Important!** This enum value is currently not supported for adding shipment tracking information for proof of delivery. Instead, use the createShippingFulfillment method to provide shipment tracking information evidence for a dispute.
This enumeration value indicates that the evidential documentation is for proof of order delivery. An example is shipment tracking information from a shipping carrier. A PROOF\_OF\_DELIVERY document might be needed if the buyer initiated the payment dispute for not receiving the item. - **PROOF_OF_AUTHENTICITY**: This enumeration value indicates that the evidential documentation is for proof of item authenticity. A PROOF\_OF\_AUTHENTICITY document/image might be needed if the buyer initiated the payment dispute due to suspecting that the item may be counterfeit. - **PROOF_OF_ITEM_AS_DESCRIBED**: This enumeration value indicates that the evidential documentation is to show that the item is as described. This document may be a photo. A PROOF\_OF\_ITEM\_AS\_DESCRIBED document might be needed if the buyer initiated the payment dispute because they thought the item was not as subscribed. - **PROOF_OF_CREDIT_NOT_DUE**: This enumeration value indicates that the evidential documentation is for proof of credit not due. A PROOF\_OF\_CREDIT\_NOT\_DUE document/image might be needed if the buyer initiated the payment dispute due to expecting a credit. - **PROOF_OF_RETURN_NOT_RECEIVED**: This enumeration value indicates that the evidential documentation is for proof that a return item has not been received by the seller, so a refund has not yet been issued. - **PROOF_OF_DELIVERY_AS_FILE**: This enumeration value indicates that the evidential documentation is a file that is proof of order delivery. - **PROOF_OF_DELIVERY_SIGNATURE**: This enumeration value indicates that the evidential documentation is a delivery signature file. - **PROOF_OF_PICKUP**: This enumeration value indicates that the evidential documentation is for buy online, pick up in store. - **OPTIONAL_SUPPORTING_DOCUMENTS**: This enumeration value indicates that the evidential documentation is optional.
**Type:** object

### ExtendedContact
**Description:** This type contains shipping and contact information for a buyer or an eBay shipping partner.
**Type:** object

**Properties:**
- **companyName** (string)
  - The company name associated with the buyer or eBay shipping partner. This field is only returned if defined/applicable to the buyer or eBay shipping partner.
- **contactAddress** (Address)
  - This container shows the shipping address of the buyer or eBay shipping partner.
- **email** (string)
  - This field contains the email address of the buyer. This address will be returned for up to 14 days from order creation. If an order is more than 14 days old, no address is returned.

**Note:** If returned, this field contains the email address of the buyer, even for Global Shipping Program shipments.

The **email** will not be returned for any order that is more than 90 days old.
- **fullName** (string)
  - The full name of the buyer or eBay shipping partner.

**Note:** The **fullName** will not be returned for any order that is more than 90 days old.
- **primaryPhone** (PhoneNumber)
  - The primary telephone number of the buyer or eBay shipping partner.

**Note:** The **primaryPhone** will not be returned for any order that is more than 90 days old.

### FileEvidence
**Description:** This type is used to store the unique identifier of an evidence file. Evidence files are used by seller to contest a payment dispute.
**Type:** object

**Properties:**
- **fileId** (string)
  - This field is used to identify the evidence file to be uploaded to the evidence set.

This file is created with the [uploadEvidenceFile](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-uploadevidencefile) method and can be retrieved using the [getPaymentDispute](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdispute) method.

### FileInfo
**Description:** This type is used by the **files** array, which shows the name, ID, file type, and upload date for each provided evidential file.
**Type:** object

**Properties:**
- **fileId** (string)
  - The unique identifier of the evidence file.
- **fileType** (string)
  - The type of file uploaded. Supported file extensions are .JPEG, .JPG, and .PNG., and maximum file size allowed is 1.5 MB.
- **name** (string)
  - The seller-provided name of the evidence file.
- **uploadedDate** (string)
  - The timestamp in this field shows the date/time when the seller uploaded the evidential document to eBay.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.

### FulfillmentInstructionsType
**Description:** This enumerated type lists the available methods of fulfillment for a set of line items. | - **DIGITAL**: This enumeration value indicates the order contains one or more digital gift card line items that are sent to the recipient by email. - **PREPARE_FOR_PICKUP**: This enumeration value indicates that the order is an In-Store Pickup order or a Click and Collect order. If this value is returned for an In-Store Pickup order, the seller can look at the pickupStep container to see the specific store where the buyer will pick up the order. If this value is returned for a Click and Collect order, the seller will look at the **shippingStep** container to see which store the buyer will pick up the item. The seller is then responsible for shipping the order to that store location. - **SELLER_DEFINED**: This enumeration value indicates that the seller will determine how to deliver these line items to the buyer. - **SHIP_TO**: This enumeration value indicates that the seller will package and ship these line items. If this value is returned, the seller can look at the **shippingStep** container to see the specific shipping details, including the shipping address and the shipping service option that will be used. - **FULFILLED_BY_EBAY**: This enumeration value indicates that eBay will package and ship an order as specified by **fulfillmentType**.
**Type:** object

### FulfillmentStartInstruction
**Description:** This type contains a set of specifications for processing a fulfillment of an order, including the type of fulfillment, shipping carrier and service, addressing details, and estimated delivery window. These instructions are derived from the buyer's and seller's eBay account preferences, the listing parameters, and the buyer's checkout selections. The seller can use them as a starting point for packaging, addressing, and shipping the order.
**Type:** object

**Properties:**
- **appointment** (AppointmentDetails)
  - This container provides information used by the installation provider concerning appointment details selected by the buyer.
- **destinationTimeZone** (string)
  - This field is reserved for internal or future use.
- **ebaySupportedFulfillment** (boolean)
  - This field is only returned if its value is `true` and indicates that the fulfillment will be shipped via eBay's Global Shipping Program, eBay International Shipping, or the Authenticity Guarantee service program.

For more information, see the [Global Shipping Program](<https://www.ebay.com/help/selling/shipping-items/setting-shipping-options/global-shipping-program?id=4646 >) help topic.
- **finalDestinationAddress** (Address)
  - This container is only returned if the value of **ebaySupportedFulfillment** field is `true`.

This is the final destination address for a Global Shipping Program shipment or an eBay International Shipping shipment, which is usually the recipient's home. Sellers should not ship directly to this address; instead they should ship this package to their international shipping provider's domestic warehouse. The international shipping provider is responsible for delivery to the final destination address.

For more information, see [Addressing Shipments](/api-docs/user-guides/static/trading-user-guide/global-shipping-addressing.html).

**Note:** For Authenticity Guarantee program shipment, this is the address of the authenticator's warehouse. The authenticator is responsible for delivery to the buyer shipping address.
- **fulfillmentInstructionsType** (FulfillmentInstructionsType)
  - The enumeration value returned in this field indicates the method of fulfillment that will be used to deliver this set of line items (this package) to the buyer. This field will have a value of `SHIP_TO` if the **ebaySupportedFulfillment** field is returned with a value of `true`. See the **FulfillmentInstructionsType** definition for more information about different fulfillment types.
- **maxEstimatedDeliveryDate** (string)
  - This is the estimated latest date that the fulfillment will be completed. This timestamp is in [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock. This field is not returned ifthe value of the **fulfillmentInstructionsType** field is `DIGITAL` or `PREPARE_FOR_PICKUP`.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **minEstimatedDeliveryDate** (string)
  - This is the estimated earliest date that the fulfillment will be completed. This timestamp is in [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock. This field is not returned if the value of the **fulfillmentInstructionsType** field is `DIGITAL` or `PREPARE_FOR_PICKUP`.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **pickupStep** (PickupStep)
  - This container is only returned for In-Store Pickup orders, and it indicates the specific merchant's store where the buyer will pick up the order. The In-Store Pickup feature is supported in the US, Canada, UK, Germany, and Australia marketplaces.
- **shippingStep** (ShippingStep)
  - This container consists of shipping information for this fulfillment, including the shipping carrier, the shipping service option, and the shipment destination. This container is not returned if the value of the **fulfillmentInstructionsType** field is `DIGITAL`, or for In-Store Pickup orders.

For Click and Collect orders, the shipping destination will be a brick-and-mortar store where the buyer will pick up the order.

### GiftDetails
**Description:** This type contains information about a digital gift card line item that was purchased as a gift and sent to the recipient by email.

**Note:** **GiftDetails** will not be returned for any order that is more than 90 days old.
**Type:** object

**Properties:**
- **message** (string)
  - This field contains the gift message from the buyer to the gift recipient. This field is only returned if the buyer of the gift included a message for the gift.

**Note:** The **message** will not be returned for any order that is more than 90 days old.
- **recipientEmail** (string)
  - The email address of the gift recipient. The seller will send the digital gift card to this email address.

**Note:** The **recipientEmail** will not be returned for any order that is more than 90 days old.
- **senderName** (string)
  - The name of the buyer, which will appear on the email that is sent to the gift recipient.

**Note:** The **senderName** will not be returned for any order that is more than 90 days old.

### InfoFromBuyer
**Description:** This container is returned if the buyer is returning one or more line items in an order that is associated with the payment dispute, and that buyer has provided return shipping tracking information and/or a note about the return.
**Type:** object

**Properties:**
- **contentOnHold** (boolean)
  - When the value of this field is `true` it indicates that the buyer's note regarding the payment dispute (i.e., the **buyerProvided.note** field,) is on hold. When this is the case, the **buyerProvided.note** field will not be returned.

When the value of this field is `false`, it is not returned.
- **note** (string)
  - This field shows any note that was left by the buyer in regard to the dispute.
- **returnShipmentTracking** (array)
  - This array shows shipment tracking information for one or more shipping packages being returned to the buyer after a payment dispute.

### IssueRefundRequest
**Description:** The base type used by the request payload of the **issueRefund** method.
**Type:** object

**Properties:**
- **reasonForRefund** (ReasonForRefundEnum)
  - The enumeration value passed in this field indicates the reason for the refund. One of the defined enumeration values in the **ReasonForRefundEnum** type must be used.

This field is required, and it is highly recommended that sellers use the correct refund reason, especially in the case of a buyer-requested cancellation or 'buyer remorse' return to indicate that there was nothing wrong with the item(s) or with the shipment of the order.

**Note:** If issuing refunds for more than one order line item, keep in mind that the refund reason must be the same for each of the order line items. If the refund reason is different for one or more order line items in an order, the seller would need to make separate **issueRefund** calls, one for each refund reason.
- **comment** (string)
  - This free-text field allows the seller to clarify why the refund is being issued to the buyer.

**Max Length**: 100
- **refundItems** (array)
  - The **refundItems** array is only required if the seller is issuing a refund for one or more individual order line items in a multiple line item order. Otherwise, the seller just uses the **orderLevelRefundAmount** container to specify the amount of the refund for the entire order.
- **orderLevelRefundAmount** (SimpleAmount)
  - This container is used to specify the amount of the refund for the entire order. If a seller wants to issue a refund for an individual line item within a multiple line item order, the seller would use the **refundItems** array instead.

### ItemLocation
**Description:** This type describes the physical location of an order.
**Type:** object

**Properties:**
- **countryCode** (CountryCodeEnum)
  - The two-letter [ISO 3166](https://www.iso.org/iso-3166-country-codes.html "https://www.iso.org") code representing the country of the address.
- **location** (string)
  - Indicates the geographical location of the item (along with the values in the **countryCode** and **postalCode** fields).

This field provides city, province, state, or similar information.

**Note:** If the item is shipped from a fulfillment center location through the Multi-Warehouse Program, this field will return the geographical location of the fulfillment center closest to the buyer.
- **postalCode** (string)
  - The postal code of the address.

### LegacyReference
**Description:** Type defining the **legacyReference** container. This container is needed if the seller is issuing a refund for an individual order line item, and wishes to use an item ID and transaction ID to identify the order line item.
**Type:** object

**Properties:**
- **legacyItemId** (string)
  - The unique identifier of a listing.

This value can be found in the **Transaction** container in the response of the [GetOrders call of the **Trading API**.

**Note:** Both **legacyItemId** and **legacyTransactionId** are needed to identify an order line item.](https://developer.ebay.com/devzone/xml/docs/reference/ebay/getorders.html)
- **legacyTransactionId** (string)
  - The unique identifier of a sale/transaction in legacy/Trading API format. A 'transaction ID' is created once a buyer purchases a 'Buy It Now' item or if an auction listing ends with a winning bidder.

This value can be found in the **Transaction** container in the response of the **getOrder** call of the **Trading API**.

**Note:** Both **legacyItemId** and **legacyTransactionId** are needed to identify an order line item.

### LineItem
**Description:** This type contains the details of each line item in an order.
**Type:** object

**Properties:**
- **appliedPromotions** (array)
  - This array contains information about one or more sales promotions or discounts applied to the line item. It is always returned, but will be returned as an empty array if no special sales promotions or discounts apply to the order line item.
- **compatibilityProperties** (array)
  - This array is only returned for a Parts & Accessory item and identifies the buyer's motor vehicle that is compatible with the part or accessory.
- **deliveryCost** (DeliveryCost)
  - This container consists of a breakdown of all costs associated with the fulfillment of the line item.
- **discountedLineItemCost** (Amount)
  - The cost of the line item after applying any discounts. This container is only returned if the order line item was discounted through a promotion.
- **ebayCollectAndRemitTaxes** (array)
  - This container will be returned if the order line item is subject to a 'Collect and Remit' tax that eBay will collect and remit to the proper taxing authority on the buyer's behalf.

'Collect and Remit' tax includes:

*   US state-mandated sales tax
*   Federal and Provincial Sales Tax in Canada
*   'Goods and Services' tax in Canada, Australia, New Zealand, and Jersey
*   VAT collected for the UK, EU countries, Kazakhstan, and Belarus
*   Sales & Service Tax (SST) in Malaysia

The amount of this tax is shown in the **amount** field, and the type of tax is shown in the **taxType** field.

EBay will display the tax type and amount during checkout in accordance with the buyer's address, and handle collection and remittance of the tax without requiring the seller to take any action.
- **ebayCollectedCharges** (EbayCollectedCharges)
  - This container consists of a breakdown of costs that are collected by eBay from the buyer for this order.

**Note:** Currently, this container is returned only if eBay is directly charging the buyer for eBay shipping.
- **giftDetails** (GiftDetails)
  - This container consists of information that is needed by the seller to send a digital gift card to the buyer or recipient of the digital gift card. This container is only returned and applicable for digital gift card line items.
- **itemLocation** (ItemLocation)
  - This container field describes the physical location of the order line item.

**Note:** If the item is shipped from a fulfillment center location through the Multi‑Warehouse Program, this container will return the location details of the fulfillment center closest to the buyer.
- **legacyItemId** (string)
  - The eBay-generated legacy listing item ID of the listing. Note that the unique identifier of a listing in REST-based APIs is called the **listingId** instead.
- **legacyVariationId** (string)
  - The unique identifier of a single variation within a multiple-variation listing. This field is only returned if the line item purchased was from a multiple-variation listing.
- **lineItemCost** (Amount)
  - The selling price of the line item before applying any discounts. The value of this field is calculated by multiplying the single unit price by the number of units purchased (value of the **quantity** field).
- **lineItemFulfillmentInstructions** (LineItemFulfillmentInstructions)
  - This container consists of information related to shipping dates and expectations, including the 'ship-by date' and expected delivery windows that are based on the seller's stated handling time and the shipping service option that will be used. These fields provide guidance on making sure expected delivery dates are made, whether the order is an _eBay Guaranteed Delivery_ order or a non-guaranteed delivery order.
- **lineItemFulfillmentStatus** (LineItemFulfillmentStatusEnum)
  - This enumeration value indicates the current fulfillment status of the line item.
- **lineItemId** (string)
  - This is the unique identifier of an eBay order line item. This field is created as soon as there is a commitment to buy from the seller.
- **linkedOrderLineItems** (array)
  - An array of one or more line items related to the corresponding order, but not a part of that order. Details include the order ID, line item ID and title of the linked line item, the seller of that item, item specifics, estimated delivery times, and shipment tracking (if available).
- **listingMarketplaceId** (MarketplaceIdEnum)
  - The unique identifier of the eBay marketplace where the line item was listed.
- **properties** (LineItemProperties)
  - Contains information about the eBay programs, if any, under which the line item was listed.
- **purchaseMarketplaceId** (MarketplaceIdEnum)
  - The unique identifier of the eBay marketplace where the line item was listed. Often, the **listingMarketplaceId** and the **purchaseMarketplaceId** identifier are the same, but there are occasions when an item will surface on multiple eBay marketplaces.
- **quantity** (integer)
  - The number of units of the line item in the order. These are represented as a group by a single **lineItemId**.
- **refunds** (array)
  - This array is always returned, but it is returned as an empty array unless the seller has submitted a partial or full refund to the buyer for the order. If a refund has occurred, the refund amount and refund date will be shown for each refund.
- **sku** (string)
  - Seller-defined Stock-Keeping Unit (SKU). This inventory identifier must be unique within the seller's eBay inventory. SKUs are optional when listing in the legacy Trading API system, but SKUs are required when listing items through the Inventory API model.
- **soldFormat** (SoldFormatEnum)
  - The eBay listing type of the line item. The most common listing types are `AUCTION` and `FIXED_PRICE`.
- **taxes** (array)
  - Contains a list of taxes applied to the line item, if any. This array is always returned, but will be returned as empty if no taxes are applicable to the line item.
- **title** (string)
  - The title of the listing.

**Note:** The Item ID value for the listing will be returned in this field instead of the actual title if this particular listing is on-hold due to an eBay policy violation.
- **total** (Amount)
  - This is the total price that the buyer must pay for the line item after all costs (item cost, delivery cost, taxes) are added, minus any discounts and/or promotions.

**Note:** For orders that are subject to eBay 'Collect and Remit' tax, the 'Collect and Remit' tax amount for the order will be included in this **total** value only when the **fieldGroups** query parameter is set to `TAX_BREAKDOWN`. If the **fieldGroups** query parameter is not set to `TAX_BREAKDOWN`, 'Collect and Remit' will not be added into this **total** value.

To determine if 'Collect and Remit' taxes were added into this **total** value, the user can check for the corresponding **lineItems.ebayCollectAndRemitTaxes** and the **lineItems.taxes** containers in the response. If both of these containers appear for one or more line items in the response with the following **taxType** values, the 'Collect and Remit' tax amount that the buyer paid is in this amount:

*   `STATE_SALES_TAX`: US state-mandated sales tax
*   `PROVINCE_SALES_TAX`: Provincial Sales Tax in Canada
*   `GST`: 'Goods and Services' tax in Canada, Australia, and New Zealand
*   `VAT`: VAT collected for UK and EU countries
- **variationAspects** (array)
  - An array of aspect name-value pairs that identifies the specific variation of a multi-variation listing. This array can contain multiple name-value pairs, such as `color:blue` and `size:large`, and will only be returned for orders created from a multiple-variation listing.

### LineItemFulfillmentInstructions
**Description:** This type contains the specifications for processing the fulfillment of a line item, including the handling window and the delivery window. These fields provide guidance for _eBay Guaranteed Delivery_ as well as for non-guaranteed delivery.
**Type:** object

**Properties:**
- **destinationTimeZone** (string)
  - This field is reserved for internal or future use.
- **guaranteedDelivery** (boolean)
  - Although this field is still returned, it can be ignored since eBay Guaranteed Delivery is no longer a supported feature on any marketplace. This field may get removed from the schema in the future.
- **maxEstimatedDeliveryDate** (string)
  - The estimated latest date and time that the buyer can expect to receive the line item based on the seller's stated handling time and the transit times of the available shipping service options. The seller must pay extra attention to this date, as a failure to deliver by this date/time can result in a 'Late shipment' seller defect, and can affect seller level and Top-Rated Seller status. In addition to the seller defect, buyers will be eligible for a shipping cost refund, and will also be eligible to return the item for a full refund (with no return shipping charge) if they choose.

**Note:** This timestamp is in [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **minEstimatedDeliveryDate** (string)
  - The estimated earliest date and time that the buyer can expect to receive the line item based on the seller's stated handling time and the transit times of the available shipping service options.

**Note:** This timestamp is in [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **shipByDate** (string)
  - The latest date and time by which the seller should ship line item in order to meet the expected delivery window. This timestamp will be set by eBay based on time of purchase and the seller's stated handling time. The seller must pay extra attention to this date, as a failure to physically ship the line item by this date/time can result in a 'Late shipment' seller defect, and can affect seller level and Top-Rated Seller status. In addition to the seller defect, buyers will be eligible for a shipping cost refund, and will also be eligible to return the item for a full refund (with no return shipping charge) if they choose.

**Note:** This timestamp is in [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **sourceTimeZone** (string)
  - This field is reserved for internal or future use.

### LineItemFulfillmentStatusEnum
**Description:** The current status of all activity required to complete fulfillment of a line item. | - **FULFILLED**: The line item has been processed, packaged, and shipped. **Note**: A line item is considered fulfilled as soon as any one unit or component of the line item is assigned to a fulfillment. - **IN_PROGRESS**: Applies only to orders with more than one line item. Indicates the seller has begun packaging and shipping one or more line items from the order, but not all line items have been shipped. - **NOT_STARTED**: The seller has not yet begun packaging the line item.
**Type:** object

### LineItemProperties
**Description:** This type contains information about the eBay programs under which a line item was listed and sold.
**Type:** object

**Properties:**
- **buyerProtection** (boolean)
  - A value of `true` indicates that the line item is covered by eBay's Buyer Protection program.
- **fromBestOffer** (boolean)
  - This field is only returned if `true` and indicates that the purchase occurred by the buyer and seller mutually agreeing on a Best Offer amount. The Best Offer feature can be set up for any listing type, but if this feature is set up for an auction listing, it will no longer be available once a bid has been placed on the listing.
- **soldViaAdCampaign** (boolean)
  - This field is only returned if `true` and indicates that the line item was sold as a result of a seller's ad campaign.

### LineItemReference
**Description:** This type identifies the line item and quantity of that line item that comprises one fulfillment, such as a shipping package.
**Type:** object

**Properties:**
- **lineItemId** (string)
  - This is the unique identifier of the eBay order line item that is part of the shipping fulfillment.

Line item Ids can be found in the **lineItems.lineItemId** field of the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) response.
- **quantity** (integer)
  - This is the number of lineItems associated with the [trackingNumber](/develop/api/sell/fulfillment_api#sell-fulfillment_api-shipping_fulfillment-createshippingfulfillment.shippingfulfillmentdetails.trackingnumber) specified by the seller. This must be a whole number greater than zero (0).

**Default:** 1

### LineItemRefund
**Description:** This type contains refund information for a line item.
**Type:** object

**Properties:**
- **amount** (Amount)
  - This field shows the refund amount for a line item. This field is only returned if the buyer is due a refund for the line item.

**Note:** The refund amount shown is the seller's _net amount_ received from the sale/transaction. EBay-collected tax will not be included in this amount, so the actual amount of the buyer's refund may be higher than this value.
- **refundDate** (string)
  - The date and time that the refund was issued for the line item. This timestamp is in [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock. This field is not returned until the refund has been issued.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **refundId** (string)
  - Unique identifier of a refund that was initiated for an order's line item through the **issueRefund** method. If the **issueRefund** method was used to issue a refund at the order level, this identifier is returned at the order level instead (**paymentSummary.refunds.refundId** field).

A **refundId** value is returned in the response of the **issueRefund** method, and this same value will be returned in the [getOrder](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder) and [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) responses for pending and completed refunds.
- **refundReferenceId** (string)
  - This field is reserved for internal or future use.

### LinkedOrderLineItem
**Description:** This type contains data on a line item that is related to, but not a part of, the order.
**Type:** object

**Properties:**
- **lineItemAspects** (array)
  - This array contains the complete set of item aspects for the linked line item. For example:

"lineItemAspects": \[
    {
        "name": "Tire Type",
        "value": "All Season"
    },

    ...

    {
        "name": "Car Type",
        "value": "Performance"
    }
\]

**Note:** All item specifics for the listing are returned. The name/value pairs returned are in the language of the linked line item's listing site, which may vary from the seller's language.
- **lineItemId** (string)
  - The unique identifier of the linked order line item.
- **maxEstimatedDeliveryDate** (string)
  - The end of the date range in which the linked line item is expected to be delivered to the shipping address.
- **minEstimatedDeliveryDate** (string)
  - The beginning of the date range in which the linked line item is expected to be delivered to the shipping address.
- **orderId** (string)
  - The unique identifier of the order to which the linked line item belongs.
- **sellerId** (string)
  - The eBay user ID of the seller who sold the linked line item. For example, the user ID of the tire seller.

**Note:** Effective September 26, 2025, select developers will no longer receive username data for U.S. users through this field. Instead, an immutable user ID will be returned in its place. For more information, please refer to [Data Handling Compliance](/api-docs/static/data-handling-update.html).
- **shipments** (array)
  - An array containing any shipment tracking information available for the linked line item.
- **title** (string)
  - The listing title of the linked line item.

**Note:** The Item ID value for the listing will be returned in this field instead of the actual title if this particular listing is on-hold due to an eBay policy violation.

### MarketplaceIdEnum
**Description:** This enumerated type contains a list of the standard codes that represent each of the eBay marketplaces. | - **EBAY_AT**: eBay Austria (ebay.at) - **EBAY_AU**: eBay Australia (ebay.com/au) - **EBAY_BE**: eBay Belgium (ebay.com/sch/Belgium) - **EBAY_CA**: eBay Canada (English) (ebay.ca) - **EBAY_CH**: eBay Switzerland (ebay.ch) - **EBAY_CN**: eBay China (ebay.com/sch/China) - **EBAY_CZ**: eBay Czech Republic (ebay.com/sch/Czech-Republic) - **EBAY_DE**: eBay Germany (ebay.de) - **EBAY_DK**: eBay Denmark (ebay.com/sch/Denmark) - **EBAY_ES**: eBay Spain (ebay.es) - **EBAY_FI**: eBay Finland (ebay.com/sch/Finland) - **EBAY_FR**: eBay France (ebay.fr) - **EBAY_GB**: eBay UK (ebay.co.uk) - **EBAY_GR**: eBay Greece (ebay.com/sch/Greece) - **EBAY_HK**: eBay Hong Kong (ebay.com.hk) - **EBAY_HU**: eBay Hungary (ebay.com/sch/Hungary) - **EBAY_ID**: eBay Indonesia (id.ebay.com) - **EBAY_IE**: eBay Ireland (ebay.ie) - **EBAY_IL**: eBay Israel (ebay.com/sch/Israel) - **EBAY_IN**: eBay India (ebay.in)
**Note:** eBay India is no longer a functioning eBay marketplace. - **EBAY_IT**: eBay Italy (ebay.it) - **EBAY_JP**: eBay Japan (ebay.co.jp) - **EBAY_MY**: eBay Malaysia (ebay.com/my) - **EBAY_NL**: eBay Netherlands (ebay.nl) - **EBAY_NO**: eBay Norway (ebay.com/sch/Norway) - **EBAY_NZ**: eBay New Zealand (ebay.com/sch/New-Zealand) - **EBAY_PE**: eBay Peru (ebay.com/sch/Peru) - **EBAY_PH**: eBay Philippines (ebay.ph) - **EBAY_PL**: eBay Poland (ebay.pl) - **EBAY_PR**: eBay Puerto Rico (ebay.com/sch/Puerto-Rico) - **EBAY_PT**: eBay Portugal (ebay.com/sch/Portugal) - **EBAY_RU**: eBay Russia (ebay.com/sch/Russia) - **EBAY_SE**: eBay Sweden (ebay.com/sch/Sweden) - **EBAY_SG**: eBay Singapore (ebay.com/sg) - **EBAY_TH**: eBay Thailand (export.ebay.co.th) - **EBAY_TW**: eBay Taiwan (ebay.com/tw) - **EBAY_US**: eBay US (ebay.com) - **EBAY_VN**: eBay Vietnam (ebay.vn) - **EBAY_ZA**: eBay South Africa (ebay.com/sch/South-Africa) - **EBAY_HALF_US**: This enumeration value is no longer applicable as the Half.com site no longer exists. - **EBAY_MOTORS_US**: eBay Motors US (ebay.com/motors)
**Type:** object

### MonetaryTransaction
**Description:** This type is used to provide details about one or more monetary transactions that occur as part of a payment dispute.
**Type:** object

**Properties:**
- **date** (string)
  - This timestamp indicates when the monetary transaction occurred. A date is returned for all monetary transactions.

The following format is used: `YYYY-MM-DDTHH:MM:SS.SSSZ`. For example, `2015-08-04T19:09:02.768Z`.
- **type** (MonetaryTransactionTypeEnum)
  - This enumeration value indicates whether the monetary transaction is a charge or a credit to the seller.
- **reason** (MonetaryTransactionReasonEnum)
  - This enumeration value indicates the reason for the monetary transaction.
- **amount** (DisputeAmount)
  - The amount involved in the monetary transaction. For active cross-border trade orders, the currency conversion and **exchangeRate** fields will be displayed as well.

### MonetaryTransactionReasonEnum
**Description:** This enumeration type is a list of reasons why monetary transactions occur with payment disputes. | - **DISPUTE_FEE**: This enumeration value indicates that the monetary transaction was a dispute fee charged to the seller. eBay charges the seller a dispute fee if the seller contests, but loses a payment dispute. - **RECOUP_AMOUNT**: This enumeration value indicates that the monetary transaction involved eBay recouping money from the seller for an amount that was not protected under eBay's seller protection policy after a buyer wins a dispute.
**Type:** object

### MonetaryTransactionTypeEnum
**Description:** This enumeration type indicates if the monetary transaction was a charge or a credit to the seller. | - **CHARGE**: This enumeration value indicates that the monetary transaction involves eBay recouping money from the Seller. Generally, this is the amount that the seller is liable to pay to eBay after a dispute is lost. - **CREDIT**: This enumeration value indicates that the monetary transaction is a credit to the seller. Generally, a credit may be due back to the seller after a disputed outcome reversal or an appeal.
**Type:** object

### NameValuePair
**Description:** This type contains the name-value specifics of a multi-variation listing (**variationAspects**) or the name-value specifics for all item aspects of a linked line item (**linkedOrderLineItems**).
**Type:** object

**Properties:**
- **name** (string)
  - The text representing the name of the aspect for the name-value pair. For example, `color` or `Tire Type`.
- **value** (string)
  - The value of the aspect for the name-value pair. For example, `red` or `All Season`.

### Order
**Description:** This type contains the details of an order, including information about the buyer, order history, shipping fulfillments, line items, costs, payments, and order fulfillment status.
**Type:** object

**Properties:**
- **buyer** (Buyer)
  - This container consists of information about the order's buyer. At this time, only the buyer's eBay user ID is returned, but it's possible that more buyer information can be added to this container in the future.

**Note:** Effective September 26, 2025, select developers will no longer receive username data for U.S. users through this field. Instead, an immutable user ID will be returned in its place. For more information, please refer to [Data Handling Compliance](/api-docs/static/data-handling-update.html).
- **buyerCheckoutNotes** (string)
  - This field contains any comments that the buyer left for the seller about the order during the checkout process. This field is only returned if a buyer left comments at checkout time.
- **cancelStatus** (CancelStatus)
  - This container consists of order cancellation information if a cancel request has been made. This container is always returned, and if no cancel request has been made, the **cancelState** field is returned with a value of `NONE_REQUESTED`, and an empty **cancelRequests** array is also returned.
- **creationDate** (string)
  - The date and time that the order was created. This timestamp is in [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **ebayCollectAndRemitTax** (boolean)
  - This field is only returned if `true` and indicates that eBay will collect tax (US state-mandated sales tax, Federal and Provincial Sales Tax in Canada, 'Goods and Services' tax in Canada, Australia, and New Zealand, and VAT collected for UK and EU countries,) for at least one line item in the order, and remit the tax to the taxing authority of the buyer's residence. If this field is returned, the seller should search for one or more **ebayCollectAndRemitTaxes** containers at the line item level to get more information about the type of tax and the amount.
- **fulfillmentHrefs** (array)
  - This array contains a list of one or more [getShippingFulfillment](/develop/api/sell/fulfillment_api#sell-fulfillment_api-shipping_fulfillment-getshippingfulfillment) call URIs that can be used to retrieve shipping fulfillments that have been set up for the order.
- **fulfillmentStartInstructions** (array)
  - This container consists of a set of specifications for fulfilling the order, including the type of fulfillment, shipping carrier and service, shipping address, and estimated delivery window. These instructions are derived from the buyer's and seller's eBay account preferences, the listing parameters, and the buyer's checkout selections. The seller can use them as a starting point for packaging, addressing, and shipping the order.

**Note:** Although this container is presented as an array, it currently returns only one set of fulfillment specifications. Additional array members will be supported in future functionality.
- **lastModifiedDate** (string)
  - The date and time that the order was last modified. This timestamp is in [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **lineItems** (array)
  - This array contains the details for all line items that comprise the order.
- **orderFulfillmentStatus** (OrderFulfillmentStatus)
  - The degree to which fulfillment of the order is complete. See the **OrderFulfillmentStatus** type definition for more information about each possible fulfillment state.
- **orderId** (string)
  - The unique identifier of the order. This field is always returned.
- **orderPaymentStatus** (OrderPaymentStatusEnum)
  - The enumeration value returned in this field indicates the current payment status of an order, or in case of a refund request, the current status of the refund. See the **OrderPaymentStatusEnum** type definition for more information about each possible payment/refund state.
- **paymentSummary** (PaymentSummary)
  - This container consists of detailed payment information for the order, including buyer payment for the order, refund information (if applicable), and seller payment holds (if applicable).
- **pricingSummary** (PricingSummary)
  - This container consists of a summary of cumulative costs and charges for all line items of an order, including item price, price adjustments, sales taxes, delivery costs, and order discounts.
- **program** (Program)
  - This container is returned for orders that are eligible for eBay's Authenticity Guarantee service. The seller ships Authenticity Guarantee service items to the authentication partner instead of the buyer. The authenticator address is found in the `fulfillmentStartInstructions.shippingStep.shipTo` container. If the item is successfully authenticated, the authenticator will ship the item to the buyer.
- **salesRecordReference** (string)
  - An eBay-generated identifier that is used to identify and manage orders through the Selling Manager and Selling Manager Pro tools. This order identifier can also be found on the Orders grid page and in the Sales Record pages in Seller Hub. A **salesRecordReference** number is only generated and returned at the order level, and not at the order line item level.

In cases where the seller does not have a Selling Manager or Selling Manager Pro subscription nor access to Seller Hub, this field may not be returned.
- **sellerId** (string)
  - The unique eBay user ID of the seller who sold the order.

**Note:** Effective September 26, 2025, select developers will no longer receive username data for U.S. users through this field. Instead, an immutable user ID will be returned in its place. For more information, please refer to [Data Handling Compliance](/api-docs/static/data-handling-update.html).
- **totalFeeBasisAmount** (Amount)
  - This is the cumulative base amount used to calculate the final value fees for each order. The final value fees are deducted from the seller payout associated with the order. Final value fees are calculated as a percentage of order cost (item cost + shipping cost) and the percentage rate can vary by eBay category.
- **totalMarketplaceFee** (Amount)
  - This is the cumulative fees accrued for the order and deducted from the seller payout.

### OrderFulfillmentStatus
**Description:** The current status of all activity required to complete fulfillment of an order. | - **FULFILLED**: The entire order has been shipped. **Note**: When any quantity of a line item is assigned to a fulfillment, that line item is marked as FULFILLED, even if the total quantity of the line item has not yet shipped. - **IN_PROGRESS**: Applies only to orders with more than one line item. Indicates the seller has begun packaging and shipping line items from the order, but not all line items have been shipped. - **NOT_STARTED**: The seller has not yet begun packaging any line items from the order.
**Type:** object

### OrderLineItems
**Description:** This type is used by the **lineItems** array that is used to identify one or more line items in the order with the payment dispute.
**Type:** object

**Properties:**
- **itemId** (string)
  - The unique identifier of the eBay listing associated with the order.
- **lineItemId** (string)
  - The unique identifier of the line item within the order.

### OrderPaymentStatusEnum
**Description:** This enumeration type contains the possible payment states of an order, or in case of a refund request, the possible states of a buyer refund. | - **FAILED**: This enumeration value indicates that buyer payment or refund has failed. - **FULLY_REFUNDED**: This enumeration value indicates that the full amount of the order has been refunded to the buyer. This value is only applicable to return requests or order cancellations. - **PAID**: This enumeration value indicates that the order has been paid in full. Once this PAID value is returned in an order management call, it is safe for the seller to ship the order to the buyer. - **PARTIALLY_REFUNDED**: This enumeration value indicates that a partial amount of the order has been refunded to the buyer. - **PENDING**: This enumeration value indicates that buyer payment or a refund from the seller is in the pending state.
**Type:** object

### OrderRefund
**Description:** This type contains information about a refund issued for an order. This does not include line item level refunds.
**Type:** object

**Properties:**
- **amount** (Amount)
  - This field shows the refund amount for an order. This container is always returned for each refund.

**Note:** The refund amount shown is the seller's _net amount_ received from the sale/transaction. eBay-collected tax will not be included in this amount, so the actual amount of the buyer's refund may be higher than this value.
- **refundDate** (string)
  - The date and time that the refund was issued. This timestamp is in [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock. This field is not returned until the refund has been issued.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **refundId** (string)
  - Unique identifier of a refund that was initiated for an order through the **issueRefund** method. If the **issueRefund** method was used to issue one or more refunds at the line item level, these refund identifiers are returned at the line item level instead (**lineItems.refunds.refundId** field).

A **refundId** value is returned in the response of the **issueRefund** method, and this same value will be returned in the [getOrder](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder) and [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) responses for pending and completed refunds. For other refunds, see the **refundReferenceId** field.
- **refundReferenceId** (string)
  - The eBay-generated unique identifier for the refund. This field is not returned until the refund has been issued.
- **refundStatus** (RefundStatusEnum)
  - This enumeration value indicates the current status of the refund to the buyer. This container is always returned for each refund.

### OrderSearchPagedCollection
**Description:** This type contains the specifications for the collection of orders that match the search or filter criteria of a [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) call. The collection is grouped into a result set, and based on the query parameters that are set (including the **limit** and **offset** parameters), the result set may included multiple pages, but only one page of the result set can be viewed at a time.
**Type:** object

**Properties:**
- **href** (string)
  - The URI of the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) call request that produced the current page of the result set.
- **limit** (integer)
  - The maximum number of orders returned per page of the result set. The **limit** value can be passed in as a query parameter, or if omitted, its value defaults to `50`.

**Note:** If this is the last or only page of the result set, the page may contain fewer orders than the **limit** value. To determine the number of pages in a result set, divide the **total** value (total number of orders matching input criteria) by this **limit** value, and then round up to the next integer. For example, if the **total** value was `120` (120 total orders) and the **limit** value was `50` (show 50 orders per page), the total number of pages in the result set is three, so the seller would have to make three separate [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) calls to view all orders matching the input criteria. **Default:** `50`
- **next** (string)
  - The [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) call URI to use if you wish to view the next page of the result set. For example, the following URI returns records 41 through 50 from the collection of orders:

`_path_/order?limit=10&offset=40`

This field is only returned if there is a next page of results to view based on the current input criteria.
- **offset** (integer)
  - The number of results skipped in the result set before listing the first returned result. This value can be set in the request with the **offset** query parameter.

**Note:** The items in a paginated result set use a zero-based list where the first item in the list has an offset of `0`.
- **orders** (array)
  - This array contains one or more orders that are part of the current result set, that is controlled by the input criteria. The details of each order include information about the buyer, order history, shipping fulfillments, line items, costs, payments, and order fulfillment status.

By default, orders are returned according to creation date (oldest to newest), but the order will vary according to any filter that is set in request.
- **prev** (string)
  - The [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) call URI for the previous result set. For example, the following URI returns orders 21 through 30 from the collection of orders:

`_path_/order?limit=10&offset=20`

This field is only returned if there is a previous page of results to view based on the current input criteria.
- **total** (integer)
  - The total number of orders in the results set based on the current input criteria.

**Note:** If no orders are found, this field is returned with a value of `0`.
- **warnings** (array)
  - This array is returned if one or more errors or warnings occur with the call request.

### OutcomeEnum
**Description:** This enumerated type defines the possible outcomes of a payment dispute. | - **SELLER_LOST**: This enumeration value indicates that the seller contested the payment dispute, but lost to the buyer. - **SELLER_WON**: This enumeration value indicates that the seller contested the payment dispute and won the dispute over the buyer. - **SELLER_ACCEPT**: This enumeration value indicates that the seller accepted the payment dispute, so the dispute never went through an evidence collecting/resolution process.
**Type:** object

### Payment
**Description:** This type is used to provide details about the seller payments for an order.
**Type:** object

**Properties:**
- **amount** (Amount)
  - The amount that seller receives for the order via the payment method mentioned in **Payment.paymentMethod**.

**Note:** For orders that are subject to eBay 'Collect and Remit' tax, which includes US state-mandated sales tax, Federal and Provincial Sales Tax in Canada, 'Good and Services' tax in Canada, Australia, and New Zealand, and VAT collected for UK or EU, the 'Collect and Remit' tax amount for the order will be included in this **amount.value** field (and in the **amount.convertedFromValue** field if currency conversion is applicable).

To determine if 'Collect and Remit' taxes were added into this **totalDueSeller** value, the user can check for the corresponding **lineItems.ebayCollectAndRemitTaxes** and the **lineItems.taxes** containers in the response. If both of these containers appear for one or more line items in the response with the following **taxType** values, the 'Collect and Remit' tax amount that the buyer paid is included in this amount:

*   `STATE_SALES_TAX`: US
*   `PROVINCE_SALES_TAX`: Provincial Sales Tax in Canada
*   `GST`: Canada, Australia, and New Zealand
*   `VAT`: UK and EU countries
- **paymentDate** (string)
  - The date and time that the payment was received by the seller. This field will not be returned if buyer has yet to pay for the order. This timestamp is in [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **paymentHolds** (array)
  - This container is only returned if eBay is temporarily holding the seller's funds for the order. If a payment hold has been placed on the order, this container includes the reason for the payment hold, the expected release date of the funds into the seller's account, the current state of the hold, and as soon as the payment hold has been released, the actual release date.
- **paymentMethod** (PaymentMethodTypeEnum)
  - The payment method used to pay for the order. See the **PaymentMethodTypeEnum** type for more information on the payment methods.

**Note:** Effective September 26, 2025, access to buyer payment details for U.S. users will be limited to select developers. All other developers will receive a value of "CustomCode" in place of buyer payment details. For more information, please refer to [Data Handling Compliance](/api-docs/static/data-handling-update.html).
- **paymentReferenceId** (string)
  - This field is only returned if payment has been made by the buyer, and the **paymentMethod** is `ESCROW`. This field contains a special ID for ESCROW.
- **paymentStatus** (PaymentStatusEnum)
  - The enumeration value returned in this field indicates the status of the payment for the order. See the **PaymentStatusEnum** type definition for more information on the possible payment states.

### PaymentDispute
**Description:** This type is used by the base response of the **getPaymentDispute** method. The **getPaymentDispute** method retrieves detailed information on a specific payment dispute.
**Type:** object

**Properties:**
- **amount** (SimpleAmount)
  - This container shows the dollar value associated with the payment dispute in the currency used by the seller's marketplace.
- **availableChoices** (array)
  - The value(s) returned in this array indicate the choices that the seller has when responding to the payment dispute. Once the seller has responded to the payment dispute, this field will no longer be shown, and instead, the **sellerResponse** field will show the decision that the seller made.
- **buyerProvided** (InfoFromBuyer)
  - This container is returned if the buyer is returning one or more line items in an order that is associated with the payment dispute, and that buyer has provided return shipping tracking information and/or a note about the return.
- **buyerUsername** (string)
  - This is the eBay user ID of the buyer that initiated the payment dispute.

**Note:** Effective September 26, 2025, select developers will no longer receive username data for U.S. users through this field. Instead, an immutable user ID will be returned in its place. For more information, please refer to [Data Handling Compliance](/api-docs/static/data-handling-update.html).
- **closedDate** (string)
  - The timestamp in this field shows the date/time when the payment dispute was closed, so this field is only returned for payment disputes in the `CLOSED` state.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **evidence** (array)
  - This container shows any evidence that has been provided by the seller to contest the payment dispute. Evidence may include shipment tracking information, proof of authentication documentation, image(s) to proof that an item is as described, or financial documentation/invoice.

This container is only returned if the seller has provided at least one document used as evidence against the payment dispute.
- **evidenceRequests** (array)
  - This container is returned if one or more evidence documents are being requested from the seller.
- **lineItems** (array)
  - This array is used to identify one or more order line items associated with the payment dispute. There will always be at least one **itemId**/**lineItemId** pair returned in this array.
- **monetaryTransactions** (array)
  - This array provide details about one or more monetary transactions that occur as part of a payment dispute. This array is only returned once one or more monetary transacations occur with a payment dispute.
- **note** (string)
  - This field shows information that the seller provides about the dispute, such as the basis for the dispute, any relevant evidence, tracking numbers, and so forth.

This field is limited to 1000 characters.
- **openDate** (string)
  - The timestamp in this field shows the date/time when the payment dispute was opened. This field is returned for payment disputes in all states.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **orderId** (string)
  - This is the unique identifier of the order involved in the payment dispute.
- **paymentDisputeId** (string)
  - This is the unique identifier of the payment dispute. This is the same identifier that is passed in to the call URI. This identifier is automatically created by eBay once the payment dispute comes into the eBay system.
- **paymentDisputeStatus** (DisputeStateEnum)
  - The enumeration value in this field gives the current status of the payment dispute. The status of a payment dispute partially determines other fields that are returned in the response.
- **reason** (DisputeReasonEnum)
  - The enumeration value in this field gives the reason why the buyer initiated the payment dispute. See **DisputeReasonEnum** type for a description of the supported reasons that buyers can give for initiating a payment dispute.
- **resolution** (PaymentDisputeOutcomeDetail)
  - This container gives details about a payment dispute that has been resolved. This container is only returned for resolved/closed payment disputes.
- **respondByDate** (string)
  - The timestamp in this field shows the date/time when the seller must response to a payment dispute, so this field is only returned for payment disputes in the `ACTION_NEEDED` state. For payment disputes that currently require action by the seller, that same seller should look at the **availableChoices** array to see the available actions.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **returnAddress** (ReturnAddress)
  - This container gives the address where the order will be returned to. This container is returned if the seller is accepting the payment dispute and will issue a refund to the buyer once the item is returned to this address.
- **revision** (integer)
  - This integer value indicates the revision number of the payment dispute. Each time an action is taken against a payment dispute, this integer value increases by 1.
- **sellerResponse** (SellerResponseEnum)
  - The enumeration value returned in this field indicates how the seller has responded to the payment dispute. The seller has the option of accepting the payment dispute and agreeing to issue a refund, accepting the payment dispute and agreeing to issue a refund as long as the buyer returns the item, or contesting the payment dispute. This field is returned as soon as the seller makes an initial decision on the payment dispute.

### PaymentDisputeActivity
**Description:** This type is used by each recorded activity on a payment dispute, from creation to resolution.
**Type:** object

**Properties:**
- **activityDate** (string)
  - The timestamp in this field shows the date/time of the payment dispute activity.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **activityType** (ActivityEnum)
  - This enumeration value indicates the type of activity that occured on the payment dispute. For example, a value of `DISPUTE_OPENED` is returned when a payment disute is first created, a value indicating the seller's decision on the dispute, such as `SELLER_CONTEST`, is returned when seller makes a decision to accept or contest dispute, and a value of `DISPUTE_CLOSED` is returned when a payment disute is resolved. See **ActivityEnum** for an explanation of each of the values that may be returned here.
- **actor** (ActorEnum)
  - This enumeration value indicates the actor that performed the action. Possible values include the `BUYER`, `SELLER`, `CS_AGENT` (eBay customer service), or `SYSTEM`.

### PaymentDisputeActivityHistory
**Description:** This type is used by the base response of the **getActivities** method, and includes a log of all activities of a payment dispute, from creation to resolution.
**Type:** object

**Properties:**
- **activity** (array)
  - This array holds all activities of a payment dispute, from creation to resolution. For each activity, the activity type, the actor, and a timestamp is shown. The **getActivities** response is dynamic, and grows with each recorded activity.

### PaymentDisputeOutcomeDetail
**Description:** This type is used by the **resolution** container that is returned for payment disputes that have been resolved.
**Type:** object

**Properties:**
- **fees** (SimpleAmount)
  - This container will show the dollar value of any fees associated with the payment dispute. This container is only returned if there are fees associated with the payment dispute.
- **protectedAmount** (SimpleAmount)
  - This container shows the amount of money that the seller is protected against in a payment dispute under eBay's seller protection policy.
- **protectionStatus** (ProtectionStatusEnum)
  - This enumeration value indicates if the seller is fully protected, partially protected, or not protected by eBay for the payment dispute. This field is always returned once the payment dispute is resolved.
- **reasonForClosure** (OutcomeEnum)
  - The enumeration value returned in this field indicates the outcome of the payment dispute for the seller. This field is always returned once the payment dispute is resolved.
- **recoupAmount** (SimpleAmount)
  - This container shows the dollar amount being recouped from the seller. This container is empty if the seller wins the payment dispute or if the seller is fully protected by eBay's seller protection policy.
- **totalFeeCredit** (SimpleAmount)
  - This container shows the amount of money in selling fee credits due back to the seller after a payment dispute is settled.

### PaymentDisputeSummary
**Description:** This type is used by each payment dispute that is returned with the [getPaymentDisputeSummaries](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdisputesummaries) method.
**Type:** object

**Properties:**
- **amount** (SimpleAmount)
  - This container shows the dollar value associated with the payment dispute in the currency used by the seller's marketplace. This container is returned for all payment disputes returned in the response.
- **buyerUsername** (string)
  - This is the buyer's eBay user ID. This field is returned for all payment disputes returned in the response.

**Note:** Effective September 26, 2025, select developers will no longer receive username data for U.S. users through this field. Instead, an immutable user ID will be returned in its place. For more information, please refer to [Data Handling Compliance](/api-docs/static/data-handling-update.html).
- **closedDate** (string)
  - The timestamp in this field shows the date/time when the payment dispute was closed, so this field is only returned for payment disputes in the `CLOSED` state.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **openDate** (string)
  - The timestamp in this field shows the date/time when the payment dispute was opened. This field is returned for payment disputes in all states.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.
- **orderId** (string)
  - This is the unique identifier of the order involved in the payment dispute.
- **paymentDisputeId** (string)
  - This is the unique identifier of the payment dispute. This identifier is automatically created by eBay once the payment dispute comes into the eBay system. This identifier is passed in at the end of the **getPaymentDispute** call URI to retrieve a specific payment dispute. The **getPaymentDispute** method returns more details about a payment dispute than the **getPaymentDisputeSummaries** method.
- **paymentDisputeStatus** (DisputeStateEnum)
  - The enumeration value in this field gives the current status of the payment dispute.
- **reason** (DisputeReasonEnum)
  - The enumeration value in this field gives the reason why the buyer initiated the payment dispute. See **DisputeReasonEnum** type for a description of the supported reasons that buyers can give for initiating a payment dispute.
- **respondByDate** (string)
  - The timestamp in this field shows the date/time when the seller must response to a payment dispute, so this field is only returned for payment disputes in the `ACTION_NEEDED` state. For payment disputes that require action by the seller, that same seller must call **getPaymentDispute** to see the next action(s) that they can take against the payment dispute.

The timestamps returned here use the [ISO 8601](https://www.iso.org/iso-8601-date-and-time-format.html "https://www.iso.org ") 24-hour date and time format, and the time zone used is Universal Coordinated Time (UTC), also known as Greenwich Mean Time (GMT), or Zulu. The ISO 8601 format looks like this: _yyyy-MM-ddThh:mm.ss.sssZ_. An example would be `2019-08-04T19:09:02.768Z`.

### PaymentHold
**Description:** This type contains information about a hold placed on a payment to a seller for an order, including the reason why the buyer's payment for the order is being held, the expected release date of the funds into the seller's account, the current state of the hold, the actual release date if the payment has been released, and possible actions the seller can take to expedite the payout of funds into their account.
**Type:** object

**Properties:**
- **expectedReleaseDate** (string)
  - The date and time that the payment being held is expected to be released to the seller. This timestamp is in [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock. This field will be returned if known by eBay.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **holdAmount** (Amount)
  - The monetary amount of the payment being held. This field is always returned with the **paymentHolds** array.
- **holdReason** (string)
  - The reason that the payment is being held. A seller's payment may be held for a number of reasons, including when the seller is new, the seller's level is below standard, or if a return case or 'Significantly not as described' case is pending against the seller. This field is always returned with the **paymentHolds** array.
- **holdState** (string)
  - The current stage or condition of the hold. This field is always returned with the **paymentHolds** array.

**Applicable values:**

*   `HELD`
*   `HELD_PENDING`
*   `NOT_HELD`
*   `RELEASE_CONFIRMED`
*   `RELEASE_FAILED`
*   `RELEASE_PENDING`
*   `RELEASED`
- **releaseDate** (string)
  - The date and time that the payment being held was actually released to the seller. This timestamp is in [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock. This field is not returned until the seller's payment is actually released into the seller's account.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **sellerActionsToRelease** (array)
  - A list of one or more possible actions that the seller can take to expedite the release of the payment hold.

### PaymentMethodTypeEnum
**Description:** This enumerated type contains the payment methods that a buyer may use for order payment. | - **CREDIT_CARD**: This enumeration value indicates that the buyer used a credit card to pay for the order. - **PAYPAL**: This enumeration value indicates that the buyer used PayPal to pay for the order. **Note**: This value should no longer be returned, as eBay manages all online payments from buyers. When eBay does handle the online payment from the buyer, the `EBAY` value will be returned instead. - **CASHIER_CHECK**: This enumeration value indicates that the buyer used a cashier's check to pay for the order. This form of payment can only be used for payment transactions off of eBay's platform, and this value will only appear if the seller updates the completed order with the payment details. - **PERSONAL_CHECK**: This enumeration value indicates that the buyer used a personal check to pay for the order. This form of payment can only be used for payment transactions off of eBay's platform, and this value will only appear if the seller updates the completed order with the payment details. - **CASH_ON_PICKUP**: This enumeration value indicates that the buyer used cash to pay for the order. This form of payment can only be used for payment transactions off of eBay's platform, and this value will only appear if the seller updates the completed order with the payment details. - **EFT**: This enumeration value indicates that the buyer used an Electronic Funds Transfer (EFT) to pay for the order. This form of payment can only be used for payment transactions off of eBay's platform, and this vaue will only appear if the seller updates the completed order with the payment details. - **EBAY**: This enumeration value is returned whenever eBay handles the online payment from the buyer. - **ESCROW**: This enumeration value indicates that the buyer used Escrow to pay for the order. This form of payment is used for high-value orders.
**Type:** object

### PaymentStatusEnum
**Description:** This enumerated type defines all possible order payment states. | - **FAILED**: This enumeration value indicates that the buyer attempted to pay for the order, but the payment has failed. - **PAID**: This enumeration value indicates that the item has been paid in full. Once this PAID value is returned in an order management call, it is safe for the seller to ship the item to the buyer. - **PENDING**: This enumeration value indicates that payment on the order is still in the pending state and has not completed.
**Type:** object

### PaymentSummary
**Description:** This type contains information about the various monetary exchanges that apply to the net balance due for the order.
**Type:** object

**Properties:**
- **payments** (array)
  - This array consists of payment information for the order, including payment status, payment method, payment amount, and payment date. This array is always returned, although some of the fields under this container will not be returned until payment has been made.
- **refunds** (array)
  - This array is always returned, but it is returned as an empty array unless the seller has submitted a partial or full refund to the buyer for the order. If a refund has occurred, the refund amount and refund date will be shown for each refund.
- **totalDueSeller** (Amount)
  - This is the total price that the seller receives for the entire order after all costs (item cost, delivery cost, taxes) are added for all line items, minus any discounts and/or promotions for any of the line items. Note that this value is subject to change before payment is actually made by the buyer (if the **paymentStatus** value was `PENDING` or `FAILED`), or if a partial or full refund occurs with the order.

**Note:** For orders that are subject to eBay 'Collect and Remit' tax, the 'Collect and Remit' tax amount for the order will be included in this **totalDueSeller** value.

To determine if 'Collect and Remit' taxes were added into this **totalDueSeller** value, the user can check for the corresponding **lineItems.ebayCollectAndRemitTaxes** and the **lineItems.taxes** containers in the response. If both of these containers appear for one or more line items in the response with the following **taxType** values, the 'Collect and Remit' tax amount that the buyer paid is included in this amount:

*   `STATE_SALES_TAX`: US
*   `PROVINCE_SALES_TAX`: Provincial Sales Tax in Canada
*   `GST`: Canada, Australia, and New Zealand
*   `VAT`: VAT collected for UK and EU countries

### Phone
**Description:** This type is used by the **returnAddress**
**Type:** object

**Properties:**
- **countryCode** (string)
  - The two-letter, [ISO 3166](https://www.iso.org/iso-3166-country-codes.html) code associated with the seller's phone number. This field is needed if the buyer is located in a different country than the seller. It is also OK to provide if the buyer and seller are both located in the same country

See [CountryCodeEnum](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-acceptpaymentdispute.countrycodeenum) for a list of supported values.
- **number** (string)
  - The seller's primary phone number associated with the return address. When this number is provided in a **contestPaymentDispute** or **contestPaymentDispute** method, it is provided as one continuous numeric string, including the area code. So, if the phone number's area code was '408', a number in this field may look something like this:

`"number" : "4088084356"`

If the buyer is located in a different country than the seller, the seller's country code will need to be specified in the **countryCode** field.

### PhoneNumber
**Description:** This type contains a string field representing a telephone number.
**Type:** object

**Properties:**
- **phoneNumber** (string)
  - The primary telephone number for the shipping recipient.

### PickupStep
**Description:** This type is used to indicate the merchant's store where the buyer will pickup their In-Store Pickup order. The **pickupStep** container is only returned for In-Store Pickup orders. The In-Store Pickup feature is supported in the US, Canada, UK, Germany, and Australia marketplaces.
**Type:** object

**Properties:**
- **merchantLocationKey** (string)
  - A merchant-defined unique identifier of the merchant's store where the buyer will pick up their In-Store Pickup order.

This field is always returned with the **pickupStep** container.

### PostSaleAuthenticationProgram
**Description:** This type is used to provide the status and outcome of an order line item going through the Authenticity Guarantee verification process.
**Type:** object

**Properties:**
- **outcomeReason** (AuthenticityVerificationReasonEnum)
  - This field indicates the result of the authenticity verification inspection on an order line item. This field is not returned when the status value of the order line item is `PENDING` or `PASSED`. The possible values returned here are `NOT_AUTHENTIC`, `NOT_AS_DESCRIBED`, `CUSTOMIZED`, `MISCATEGORIZED`, or `NOT_AUTHENTIC_NO_RETURN`.
- **status** (AuthenticityVerificationStatusEnum)
  - The value in this field indicates whether the order line item has passed or failed the authenticity verification inspection, or if the inspection and/or results are still pending. The possible values returned here are `PENDING`, `PASSED`, `FAILED`, or `PASSED_WITH_EXCEPTION`.

### PricingSummary
**Description:** This type contains a summary of cumulative costs and charges for all line items of an order, including item price, price adjustments, sales taxes, delivery costs, and order discounts.
**Type:** object

**Properties:**
- **adjustment** (Amount)
  - This container shows the total amount of any adjustments that were applied to the cost of the item(s) in the order. This amount does not include shipping, discounts, fixed fees, or taxes.

This container is only returned if price adjustments were made to the order after the initial transaction/commitment to buy occurred.
- **deliveryCost** (Amount)
  - This container shows the total cost of delivering the order to the buyer before any shipping/delivery discount is applied.
- **deliveryDiscount** (Amount)
  - This container shows the total amount of delivery discounts (including shipping discounts) that apply to the order. This should be a negative real number.

This container is only returned if delivery discounts are being applied to the order.
- **fee** (Amount)
  - This container shows the total amount of any special fees applied to the order, such as a tire recycling fee or an electronic waste fee.

This container is returned if special fees are being applied to the order and if the **fieldGroups** is set to `TAX_BREAKDOWN`.
- **priceDiscount** (Amount)
  - This container shows the total amount of all item price discounts (including promotions) that apply to the order and reduce its cost to the buyer. This should be a negative real number.

This container is only returned if special discounts are being applied to the order.
- **priceSubtotal** (Amount)
  - This container shows the cumulative costs of of all units of all line items in the order before any discount is applied.
- **tax** (Amount)
  - This container shows the total amount of tax for the order. To calculate the tax percentage rate, divide this value by the value of the **total** field.

This container is only returned if any type of tax (sales tax, tax on shipping, tax on handling, import tax, etc.) is applied to the order.
- **total** (Amount)
  - The total cost of the order after adding all line item costs, delivery costs, sales tax, and special fees and then subtracting all special discounts and price adjustments.

**Note:** For orders that are subject to eBay 'Collect and Remit' tax, the 'Collect and Remit' tax amount for the order will be included in this **total** value only when the **fieldGroups** query parameter is set to `TAX_BREAKDOWN`. If the **fieldGroups** query parameter is not set to `TAX_BREAKDOWN`, 'Collect and Remit' will not be added into this **total** value.

To determine if 'Collect and Remit' taxes were added into this **total** value, the user can check for the corresponding **lineItems.ebayCollectAndRemitTaxes** and the **lineItems.taxes** containers in the response. If both of these containers appear for one or more line items in the response with the following **taxType** values, the 'Collect and Remit' tax amount that the buyer paid is included in this amount:

*   `STATE_SALES_TAX`: US state-mandated sales tax
*   `PROVINCE_SALES_TAX`: Provincial Sales Tax in Canada
*   `GST`: 'Good and Services' tax in Canada, Australia, and New Zealand
*   `VAT`: VAT collected for UK and EU countries

### Program
**Description:** This type is returned for order line items eligible for the Authenticity Guarantee service and/or for order line items fulfilled by the eBay Fulfillment program or eBay shipping.
**Type:** object

**Properties:**
- **authenticityVerification** (PostSaleAuthenticationProgram)
  - This field is returned when the third-party authenticator performs the authentication verification inspection on the order line item. Different values will be returned based on whether the item passed or failed the authentication verification inspection.
- **ebayShipping** (EbayShipping)
  - This container is returned only if the order is an eBay shipping order. It consists of a field that indicates the provider of a shipping label for this order.
- **ebayVault** (EbayVaultProgram)
  - This field provides information about the eBay vault program that has been selected for an order. This is returned only for those items that are eligible for the eBay Vault Program.
- **ebayInternationalShipping** (EbayInternationalShipping)
  - This container is returned if the order is being fulfilled through eBay International Shipping.
- **fulfillmentProgram** (EbayFulfillmentProgram)
  - This field provides details about an order line item being handled by eBay fulfillment. It is only returned for paid orders being fulfilled by eBay or an eBay fulfillment partner.

### Property
**Description:** This type defines the property name and value for an order.
**Type:** object

**Properties:**
- **propertyDisplayName** (string)
  - The display name of the motor vehicle aspect. This is the localized name of the compatibility property.
- **propertyName** (string)
  - The name of the motor vehicle aspect.

For example, typical vehicle property names are 'Make', 'Model', 'Year', 'Engine', and 'Trim', but will vary based on the eBay marketplace and the eBay category.
- **propertyValue** (string)
  - The value of the property specified in the **propertyName** field.

For example, if the **propertyName** is `Make`, then the **propertyValue** will be the specific make of the vehicle, such as `Toyota`.

### ProtectionStatusEnum
**Description:** This enumerated type defines the values that indicate the level of protection for a seller for an eBay order. Whether or not a seller is fully protected, partially protected, or not protected at all by eBay depends on the eBay category and actions of the buyer and seller. | - **FULLY_PROTECTED**: This enumeration value indicates that the seller is fully protected by eBay for the buyer-initiated payment dispute. - **PARTIALLY_PROTECTED**: This enumeration value indicates that the seller is partially protected by eBay for the buyer-initiated payment dispute. - **NOT_PROTECTED**: This enumeration value indicates that the seller is not protected by eBay for the buyer-initiated payment dispute. - **MANUAL_REVIEW**: This enumeration value indicates that eBay will have to do a manual review to see if the seller is eligible for protection against the buyer-initiated payment dispute.
**Type:** object

### ReasonForRefundEnum
**Description:** This type defines the enumeration values that can be used in the **reasonForRefund** field to identify the reason why a buyer refund is being issued for the order. | - **BUYER_CANCEL**: This enumeration value is used if a full refund is being issued because the buyer initiated the cancellation of an order. - **SELLER_CANCEL**: This enumeration value is used if a full refund is being issued because the seller initiated the cancellation of an order. A seller might cancel an order if an item is out of stock, or perhaps has become damaged since the creation of the listing. - **ITEM_NOT_RECEIVED**: This enumeration value is used if a full refund is being issued because the buyer never received the item. - **BUYER_RETURN**: This enumeration value is used if a full refund is being issued because the buyer has returned the buyer returned the item due to buyer remorse or another reason besides 'Not as Described'. - **ITEM_NOT_AS_DESCRIBED**: This enumeration value is used if a partial or full refund is being issued because the buyer has stated that the item is 'Not as Described'. - **OTHER_ADJUSTMENT**: This enumeration value should be used if a partial or full refund is being issued for no specific reason. - **SHIPPING_DISCOUNT**: This enumeration value is used if a partial refund is being issued due to the seller wanting to pass on a shipping discount to the buyer.
**Type:** object

### Refund
**Description:** This is the base type of the **issueRefund** response payload. As long as the **issueRefund** method does not trigger an error, a response payload will be returned.
**Type:** object

**Properties:**
- **refundId** (string)
  - The unique identifier of the order refund. This value is returned unless the refund operation fails (**refundStatus** value shows `FAILED`). This identifier can be used to track the status of the refund through a [getOrder](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder) or [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) call. For order-level refunds, check the **paymentSummary.refunds.refundId** field in the **getOrder**/**getOrders** response, and for line item level refunds, check the **lineItems.refunds.refundId** field(s) in the **getOrder**/**getOrders** response.
- **refundStatus** (RefundStatusEnum)
  - The value returned in this field indicates the success or failure of the refund operation. A successful **issueRefund** operation should result in a value of `PENDING`. A failed **issueRefund** operation should result in a value of `FAILED`, and an HTTP status code and/or API error code may also get returned to possibly indicate the issue.

The refunds issued through this method are processed asynchronously, so the refund will not show as 'Refunded' right away. A seller will have to make a subsequent **getOrder** call to check the status of the refund. The status of an order refund can be found in the [paymentSummary.refunds.refundStatus](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder.orderrefund.refundstatus) field of the [getOrder](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder) response.

### RefundItem
**Description:** This type is used if the seller is issuing a refund for one or more individual order line items in a multiple line item order. Otherwise, the seller just uses the **orderLevelRefundAmount** container to specify the amount of the refund for the entire order.
**Type:** object

**Properties:**
- **refundAmount** (SimpleAmount)
  - This container is used to specify the amount of the refund for the corresponding order line item. If a seller wants to issue a refund for an entire order, the seller would use the **orderLevelRefundAmount** container instead.
- **lineItemId** (string)
  - The unique identifier of an order line item. This identifier is created once a buyer purchases a 'Buy It Now' item or if an auction listing ends with a winning bidder.

Either this field or the **legacyReference** container is needed to identify an individual order line item that will receive a refund.

This value is returned using the [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders) method.
- **legacyReference** (LegacyReference)
  - This container is needed if the seller is issuing a refund for an individual order line item, and wishes to use an item ID/transaction ID pair to identify the order line item.

Either this container or the **lineItemId** field is needed to identify an individual order line item that will receive a refund.

**Note:** This container should **only** be used if a seller is using the[getOrders](https://developer.ebay.com/devzone/xml/docs/reference/ebay/getorders.html) method of the **Trading API**.

### RefundStatusEnum
**Description:** This enumerated type indicates the degree of completion of a refund being made to the buyer. | - **FAILED**: This enumeration value indicates that the refund process was initiated by the seller, but was not successful. If this value is returned in the **issueRefund** response, it indicates that the **issueRefund** operation was not successful at issuing the buyer refund. Any returned error codes may give more insight on why the operation failed. - **PENDING**: This enumeration value indicates that the refund process has been initiated by the seller, but not yet completed. This value is returned in the **issueRefund** response if the issueRefund operation was successful. Buyer refunds initiated through the **issueRefund** operation are processed asynchronously, so the seller can track the status of the refund by using the getOrder operation. - **REFUNDED**: This enumeration value indicates that the refund has been successfully submitted to the buyer. This value should never be returned in the **issueRefund** response since buyer refunds initiated through the **issueRefund** operation are processed asynchronously.
**Type:** object

### ReturnAddress
**Description:** This type is used by the payment dispute methods, and is relevant if the buyer will be returning the item to the seller.
**Type:** object

**Properties:**
- **addressLine1** (string)
  - The first line of the street address.
- **addressLine2** (string)
  - The second line of the street address. This line is not always necessarily, but is often used for apartment number or suite number, or other relevant information that can not fit on the first line.
- **city** (string)
  - The city of the return address.
- **country** (CountryCodeEnum)
  - The country's two-letter, ISO 3166-1 country code. See the enumeration type for a country's value.
- **county** (string)
  - The county of the return address. Counties are not applicable to all countries.
- **fullName** (string)
  - The full name of return address owner.
- **postalCode** (string)
  - The postal code of the return address.
- **primaryPhone** (Phone)
  - This container shows the seller's primary phone number associated with the return address.
- **stateOrProvince** (string)
  - The state or province of the return address.

### SellerActionsToRelease
**Description:** This type is used to state possible action(s) that a seller can take to release a payment hold placed against an order.
**Type:** object

**Properties:**
- **sellerActionToRelease** (string)
  - A possible action that the seller can take to expedite the release of a payment hold. A **sellerActionToRelease** field is returned for each possible action that a seller may take. Possible actions may include providing shipping/tracking information, issuing a refund, providing refund information, contacting customer support, etc.

### SellerResponseEnum
**Description:** This enumeration type defines the different options that a seller has taken against a payment dispute initiated by a buyer. | - **SELLER_ACCEPT**: This enumeration value indicates that the seller has accepted the payment dispute and agrees to issue a refund to buyer. - **SELLER_ACCEPT_WITH_RETURN**: This enumeration value indicates that the seller has accepted the payment dispute and agrees to issue a refund to buyer as soon as the item is returned to the seller. - **SELLER_CONTEST**: This enumeration value indicates that the seller is contesting the payment dispute. - **SELLER_RESPONSE_OVERDUE**: This enumeration value indicates that the seller has yet to respond to the payment dispute, and the response is now overdue. The seller should respond the payment dispute as soon as possible.
**Type:** object

### ShippingFulfillment
**Description:** This type contains the complete details of an existing fulfillment for an order.
**Type:** object

**Properties:**
- **fulfillmentId** (string)
  - The unique identifier of the fulfillment; for example, `9405509699937003457459`. This eBay-generated value is created with a successful **createShippingFulfillment** call.
- **lineItems** (array)
  - This array contains a list of one or more line items (and purchased quantity) to which the fulfillment applies.
- **shipmentTrackingNumber** (string)
  - The tracking number provided by the shipping carrier for the package shipped in this fulfillment. This field is returned if available.
- **shippedDate** (string)
  - The date and time that the fulfillment package was shipped. This timestamp is in [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock. This field should only be returned if the package has been shipped.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`
- **shippingCarrierCode** (string)
  - The eBay code identifying the shipping carrier for this fulfillment. This field is returned if available.

**Note:** The Trading API's **ShippingCarrierCodeType** enumeration type contains the most current list of eBay shipping carrier codes and the countries served by each carrier. See [ShippingCarrierCodeType](<https://developer.ebay.com/Devzone/XML/docs/Reference/eBay/types/ShippingCarrierCodeType.html >).

### ShippingFulfillmentDetails
**Description:** This type contains the details for creating a fulfillment for an order.
**Type:** object

**Properties:**
- **lineItems** (array)
  - This array contains a list of or more line items and the quantity that will be shipped in the same package.
- **shippedDate** (string)
  - This is the actual date and time that the fulfillment package was shipped. This timestamp is in [ISO 8601](<https://www.iso.org/iso-8601-date-and-time-format.html > "https://www.iso.org ") format, which uses the 24-hour Universal Coordinated Time (UTC) clock. The seller should use the actual date/time that the package was shipped, but if this field is omitted, it will default to the current date/time.

**Format:** `[YYYY]-[MM]-[DD]T[hh]:[mm]:[ss].[sss]Z`
**Example:** `2015-08-04T19:09:02.768Z`

**Default:** The current date and time.
- **shippingCarrierCode** (string)
  - The unique identifier of the shipping carrier being used to ship the line item(s). Technically, the **shippingCarrierCode** and **trackingNumber** fields are optional, but generally these fields will be provided if the shipping carrier and tracking number are known.

**Note:** Use the Trading API's **GeteBayDetails** call to retrieve the latest shipping carrier enumeration values. When making the [GeteBayDetails](https://developer.ebay.com/devzone/xml/docs/reference/ebay/GeteBayDetails.html) call, include the **DetailName** field in the request payload and set its value to `ShippingCarrierDetails`. Each valid shipping carrier enumeration value is returned in a **ShippingCarrierDetails.ShippingCarrier** field in the response payload.
- **trackingNumber** (string)
  - The tracking number provided by the shipping carrier for this fulfillment. The seller should be careful that this tracking number is accurate since the buyer will use this tracking number to track shipment, and eBay has no way to verify the accuracy of this number.

This field and the **shippingCarrierCode** field are mutually dependent. If you include one, you must also include the other.

**Note:** If you include **trackingNumber** (and **shippingCarrierCode**) in the request, the resulting fulfillment's ID (returned in the HTTP location response header) is the tracking number. If you do not include shipment tracking information, the resulting fulfillment ID will default to an arbitrary number such as `999`.
**Note:** Only alphanumeric characters are supported for shipment tracking numbers. Spaces, hyphens, and all other special characters are not supported. Do not include a space in the tracking number even if a space appears in the tracking number on the shipping label.

### ShippingFulfillmentPagedCollection
**Description:** This type contains the specifications for the entire collection of shipping fulfillments that are associated with the order specified by a [getShippingFulfillments](/develop/api/sell/fulfillment_api#sell-fulfillment_api-shipping_fulfillment-getshippingfulfillments) call. The **fulfillments** container returns an array of all the fulfillments in the collection.
**Type:** object

**Properties:**
- **fulfillments** (array)
  - This array contains one or more fulfillments required for the order that was specified in method endpoint.
- **total** (integer)
  - The total number of fulfillments in the specified order.

**Note:** If no fulfillments are found for the order, this field is returned with a value of `0`.
- **warnings** (array)
  - This array is only returned if one or more errors or warnings occur with the call request.

### ShippingStep
**Description:** This type contains shipping information for a fulfillment, including the shipping carrier, the shipping service option, the shipment destination, and the Global Shipping Program reference ID.
**Type:** object

**Properties:**
- **shippingCarrierCode** (string)
  - The unique identifier of the shipping carrier being used to ship the line item.

**Note:** The Trading API's [GeteBayDetails](<https://developer.ebay.com/devzone/XML/docs/Reference/eBay/GeteBayDetails.html >) call can be used to retrieve the latest shipping carrier and shipping service option enumeration values.
- **shippingServiceCode** (string)
  - The unique identifier of the shipping service option being used to ship the line item.

**Note:** Use the Trading API's **GeteBayDetails** call to retrieve the latest shipping carrier and shipping service option enumeration values. When making the [GeteBayDetails](</devzone/XML/docs/Reference/eBay/GeteBayDetails.html >) call, include the **DetailName** field in the request payload and set its value to `ShippingServiceDetails`. Each valid shipping service option (returned in **ShippingServiceDetails.ShippingService** field) and corresponding shipping carrier (returned in **ShippingServiceDetails.ShippingCarrier** field) is returned in response payload.
- **shipTo** (ExtendedContact)
  - This container consists of shipping and contact information about the individual or organization to whom the fulfillment package will be shipped.
**Note:** When **FulfillmentInstructionsType** is `FULFILLED_BY_EBAY`, there will be no **shipTo** address displayed.
**Note:** For Digitally Delivered Goods (DDG), this address is the same as the Buyer's Registration Address.
**Note:** For a Global Shipping Program shipment, this is the address of the international shipping provider's domestic warehouse. The international shipping provider is responsible for delivery to the final destination address. For more information, see [Addressing Shipments](/api-docs/user-guides/static/trading-user-guide/global-shipping-addressing.html).
- **shipToReferenceId** (string)
  - This is the unique identifer of the Global Shipping Program (GSP) shipment. This field is only returned if the line item is being shipped via GSP (the value of the **fulfillmentStartInstructions.ebaySupportedFulfillment** field will be `true`. The international shipping provider uses the **shipToReferenceId** value as the primary reference number to retrieve the relevant details about the buyer, the order, and the fulfillment, so the shipment can be completed.

Sellers must include this value on the shipping label immediately above the street address of the international shipping provider.

Example: "Reference #1234567890123456"

**Note:** This value is the same as the **ShipToAddress.ReferenceID** value returned by the Trading API's GetOrders call.

### SimpleAmount
**Description:** This type defines the monetary value of the payment dispute, and the currency used.
**Type:** object

**Properties:**
- **currency** (CurrencyCodeEnum)
  - A three-letter [ISO 4217](https://www.iso.org/iso-4217-currency-codes.html "https://www.iso.org ") code (such as `USD` for US site) that indicates the currency of the amount in the **value** field. Both the **value** and **currency** fields are always returned with the **amount** container.
- **value** (string)
  - The monetary amount of the payment dispute. Both the **value** and **currency** fields are always returned with the **amount** container.

### SoldFormatEnum
**Description:** This enumerated type defines the listing formats for which a line item may be sold. | - **AUCTION**: This enumeration value indicates that the line item was purchased through an auction listing. Note that this value will be returned even if the buyer purchases the item through the 'Buy it Now' feature or if the buyer proposes and the seller accepts a 'Best Offer' for the auction item. Both the 'Buy it Now' and 'Best Offer' features get turned off on the listing as soon as the active auction listing has at least one qualifying bid. - **FIXED_PRICE**: This enumeration value indicates that the line item was purchased through a fixed-price listing. Note that this value will be returned whether the buyer purchases the item at the 'Fixed Price' or if the buyer proposes and the seller accepts a 'Best Offer' price. The 'Buy it Now' feature is not applicable to fixed-price listings. With fixed-price listings, buyer may purchase multiple units of the same line item if inventory is available. - **OTHER**: This enumeration value may be returned if the listing type cannot be determined by eBay. - **SECOND_CHANCE_OFFER**: This enumeration value indicates that the line item was purchased through a 'Second Chance Offer'. Sellers can propose a 'Second Chance Offer' to a non-winning bidder on an ended auction listing when either the winning bidder has failed to pay for an item or if the seller has more inventory of the auction item. A seller can create a 'Second Chance Offer' immediately after a listing ends, all the way up to 60 days after the end of the listing. A 'Second Chance Offer' can be proposed through the eBay UI, or the seller also can use the **AddSecondChanceItem** call of the Trading API. Based on the seller's preference, a prospective buyer can have up to seven days to make a decision on purchasing the item.
**Type:** object

### Tax
**Description:** This type contains information about any sales tax applied to a line item.
**Type:** object

**Properties:**
- **amount** (Amount)
  - The monetary amount of the tax. The **taxes** array is always returned for each line item in the order, but this **amount** will only be returned when the line item is subject to any type of sales tax.
- **taxType** (TaxTypeEnum)
  - Tax type. This field is only available when **fieldGroups** is set to `TAX_BREAKDOWN`. If the order has fees, a breakdown of the fees is also provided.

### TaxAddress
**Description:** This container consists of address information that can be used by sellers for tax purposes.
**Type:** object

**Properties:**
- **city** (string)
  - The city name that can be used by sellers for tax purposes.
- **countryCode** (CountryCodeEnum)
  - The country code that can be used by sellers for tax purposes, represented as a two-letter ISO 3166‑1 alpha‑2 country code. For example, **US** represents the United States, and **DE** represents Germany.
- **postalCode** (string)
  - The postal code that can be used by sellers for tax purposes. Usually referred to as ZIP codes in the US.
- **stateOrProvince** (string)
  - The state name that can be used by sellers for tax purposes.

### TaxIdentifier
**Description:** This type is used by the **taxIdentifier** container that is returned in **getOrder**. The **taxIdentifier** container consists of taxpayer identification information for buyers from Italy, Spain, or Guatemala. It is currently only returned for orders occurring on the eBay Italy or eBay Spain marketplaces.

**Note:** Currently, the **taxIdentifier** container is only returned in **getOrder** and not in [getOrders](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorders). So, if a seller wanted to view a buyer's tax information for a particular order returned in **getOrders**, that seller would need to use the **orderId** value for that particular order, and then run a [getOrder](/develop/api/sell/fulfillment_api#sell-fulfillment_api-order-getorder) call against that order ID.
**Type:** object

**Properties:**
- **taxpayerId** (string)
  - This value is the unique tax ID associated with the buyer. The type of tax identification is shown in the **taxIdentifierType** field.
- **taxIdentifierType** (TaxIdentifierTypeEnum)
  - This enumeration value indicates the type of tax identification being used for the buyer. The different tax types are defined in the **TaxIdentifierTypeEnum** type.
- **issuingCountry** (CountryCodeEnum)
  - This two-letter code indicates the country that issued the buyer's tax ID. The country that the two-letter code represents can be found in the **CountryCodeEnum** type or in the [ISO 3166](https://www.iso.org/iso-3166-country-codes.html) standard.

### TaxIdentifierTypeEnum
**Description:** This enumeration type defines the different tax identification types being used by buyers. This includes Spanish, Italian, and Guatamalan buyers, as well as buyers from other countries using a value-added tax identifier number (VATIN). | - **CODICE_FISCALE**: This value indicates that the **taxpayerId** value is a Codice Fiscale ID, which is an identifier used by the Italian government to identify taxpayers in Italy. - **CURP**: This value indicates that the **taxpayerId** value is a CURP number, which is one identifier used by the Mexican tax authorities (SAT) to identify taxpayers in Mexico. In Spanish, this ID is known as the 'Clave Única de Registro de Población'. - **DNI**: This value indicates that the **taxpayerId** value is a Spanish National Identity Number, which is one identifier used by the Spanish government to identify taxpayers in Spain. In Spanish, this ID is known as the 'Documento nacional de identidad'. The other tax identifier for Spanish residents is the NIE number, or 'Numero de Identidad de Extranjero'. - **NIE**: This value indicates that the **taxpayerId** value is a NIE Number, which is one identifier used by the Spanish government to identify taxpayers in Spain. 'NIE' stands for 'Numero de Identidad de Extranjero'. The other tax identifier for Spanish residents is the DNI number, or 'Documento nacional de identidad'. Spanish residents can also be identified by their Spanish VAT (Value-Added Tax) number, which is also called the 'Numero de Identificacion Fiscal' or NIF. - **NIF**: This value indicates that the **taxpayerId** value is an NIF Number, which is also known as their Spanish VAT (Value-Added Tax) number. 'NIF' stands for 'Numero de Identificacion Fiscal'. Spanish residents can also be identified by their DNI ('Documento nacional de identidad') number or their NIE ('Numero de Identidad de Extranjero') number. - **NIT**: This value indicates that the **taxpayerId** value is a NIT number, which is an identifier used by the Guatemalan government to identify taxpayers in Guatemala. In Spanish, this ID is known as the 'Numero de identificacion tributaria'. - **RFC**: This value indicates taxpayerId value is a RFC number, which is one identifier used by the Mexican tax authorities (SAT) to identify taxpayers in Mexico. In Spanish, this ID is known as the 'Registro Federal de Contribuyentes'. - **RUT**: This value indicates that the **taxpayerId** value is a Tax Registration Number, which is an identifier used by the Chileans government to identify taxpayers in Chile. In Spanish, this ID is known as the 'Rol Único Tributario'. - **VATIN**: This value indicates that the **taxpayerId** value is a VATIN number, which is the value-added tax identification number for the buyer. This identifier is used for value added tax purposes in many countries, including the countries of the European Union.
**Type:** object

### TaxTypeEnum
**Description:** This enumeration type defines the sales tax types that may be collected by eBay and remitted to the appropriate taxing authority for a given line item in an order. Although not all sales tax is subject to be collected and remitted by eBay, this type is only used by the **eBayCollectAndRemitTaxes** container, so all of these tax types will be subject to 'Collect and Remit'. | - **STATE_SALES_TAX**: This enumeration value indicates that US state sales tax was charged to the buyer against the order line item. EBay now calculates, collects, and remits sales tax to the proper taxing authorities in all 50 states and Washington, DC. — any sales tax rate set up by the seller for the buyer's state will be ignored. However, sellers may continue to set sales tax rates for the following US territories:

*   American Samoa (AS)
*   Guam (GU)
*   Northern Mariana Islands (MP)
*   Palau (PW)
*   US Virgin Islands (VI) - **PROVINCE_SALES_TAX**: This enumeration value indicates that provincial sales tax was charged to the buyer against the order line item. In provinces that mandate sales tax, any sales tax rate set up by the seller for the buyer's province will be ignored, and the seller is not involved with the collection of this tax at all. - **REGION**: This enumeration value indicates that regional sales tax was charged to the buyer against the order line item. In regions that mandate sales tax, any sales tax rate set up by the seller for the buyer's region will be ignored, and the seller is not involved with the collection of this tax at all. - **VAT**: This enumeration value indicates that Value-Added tax (VAT) was charged to the buyer against the order line item. VAT is not applicable in all countries, including the United States. - **GST**: This enumeration value indicates that a Goods and Services Tax was charged to the buyer against the order line item. This tax type applies to:

*   Australia and New Zealand: this is an import tax charged to buyers outside of these two countries
*   Canada: GST indicates that a Federal Sales Tax was charged to the buyer against the order line item. Depending on the province this can be either Goods and Services Tax (GST) or Harmonized Sales Tax (HST).
*   Jersey: this is a transactional tax on sales of goods and services supplied. - **ELECTRONIC_RECYCLING_FEE**: This enumeration value indicates that an Electronic Recycling Fee was charged to the buyer against the order line item. This fee is imposed on the retail sale or lease of certain electronic products that have been identified as covered electronic devices (CEDs). This is only available when **fieldGroups** is set to `TAX_BREAKDOWN`. - **MATTRESS_RECYCLING_FEE**: This enumeration value indicates that a mattress waste recycling fee was charged to the buyer against the order line item for each mattress, box spring, foundation, and base sold. This recycling fee is per piece. This is only available when **fieldGroups** is set to `TAX_BREAKDOWN`. - **ADDITIONAL_FEE**: This enumeration value indicates that an additional recycling fee was charged to the buyer against the order line item. This is only available when **fieldGroups** is set to `TAX_BREAKDOWN`. - **BATTERY_RECYCLING_FEE**: This enumeration value indicates that the battery recycling fee was charged to the buyer against the order line item. This is only available when **fieldGroups** is set to `TAX_BREAKDOWN`. - **TIRE_RECYCLING_FEE**: This enumeration value indicates that the tire recycling fee was charged to the buyer against the order line item. This is only available when **fieldGroups** is set to `TAX_BREAKDOWN`. - **WHITE_GOODS_DISPOSABLE_TAX**: This enumeration value indicates that the disposal tax for white goods was charged to the buyer against the order line item (White Goods Disposal Tax). White goods includes items like refrigerators, ranges, water heaters, freezers, unit air conditioners, washing machines, clothes dryers, and other similar domestic and commercial large appliances. This is only available when **fieldGroups** is set to `TAX_BREAKDOWN`. - **IMPORT_VAT**: This enumeration value indicates that the Value-Added Tax (VAT) was charged to the buyer against an imported order line item (only applies to international orders). VAT is not applicable in all countries, including the United States. - **SST**: This enumeration value indicates that a Sales & Service Tax was charged to the buyer against the order line item. SST only applies to Malaysia.
**Type:** object

### TrackingInfo
**Description:** This type is used for seller provided shipment tracking information.
**Type:** object

**Properties:**
- **shipmentTrackingNumber** (string)
  - This string value represents the shipment tracking number of the package.
- **shippingCarrierCode** (string)
  - This string value represents the shipping carrier used to ship the package.

### UpdateEvidencePaymentDisputeRequest
**Description:** This type is used by the request payload of the **updateEvidence** method. The **updateEvidence** method is used to update an existing evidence set against a payment dispute with one or more evidence files.
**Type:** object

**Properties:**
- **evidenceId** (string)
  - The unique identifier of the evidence set that is being updated with new evidence files.

This ID is returned under the **evidence** array in the [getPaymentDispute](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdispute) response.
- **evidenceType** (EvidenceTypeEnum)
  - This field is used to indicate the type of evidence being provided through one or more evidence files. All evidence files (if more than one) should be associated with the evidence type passed in this field.

See the [EvidenceTypeEnum](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-addevidence.evidencetypeenum) type for the supported evidence types.
- **files** (array)
  - This array is used to specify one or more evidence files that will be added to the evidence set associated with a payment dispute. At least one evidence file must be specified in the **files** array.

The unique identifier of an evidence file is returned in the response payload of the **uploadEvidence** method.
- **lineItems** (array)
  - This required array identifies the order line item(s) for which the evidence file(s) will be applicable.

These values are returned under the **evidenceRequests.lineItems** array in the [getPaymentDispute](/develop/api/sell/fulfillment_api#sell-fulfillment_api-payment_dispute-getpaymentdispute) response.

**Note:** Both the **itemId** and **lineItemID** fields are needed to identify each order line item.

## Rate Limits

See [API Call Limits](https://developer.ebay.com/develop/get-started/api-call-limits) on the eBay Developer Program.

## Resources

### Documentation

- [eBay Developer Program](https://developer.ebay.com/)
- [API Documentation](https://developer.ebay.com/develop/api/)
- [SDKs and Widgets](https://developer.ebay.com/develop/sdks-and-widgets)
- [Developer Community Forum](https://community.ebay.com/t5/Developer-Groups/ct-p/developergroup)

### Tools

- [API Explorer](https://developer.ebay.com/my/api_test_tool)
- [GraphQL Explorer](https://developer.ebay.com/my/graphql_explorer)

### Support

- [Developer Support](https://developer.ebay.com/support/)
- [API Status](https://developer.ebay.com/support/api-status)
- [Release Notes](https://developer.ebay.com/develop/api/release_notes/)

---
*Generated on 2026-05-22T22:19:30.880Z*
