# Data Models Schema Documentation

This document contains the table schema, materialization strategies, indexes, and column-level mappings for all dbt models in:

- `models/dimensions/` (17 models)
- `models/facts/` (4 models)

---

## Table of Contents

- [Dimensions](#part-1-dimension-models-modelsdimensions)
  - [1. dim_cash_drawers](#1-dim_cash_drawerssql)
  - [2. dim_collection_products](#2-dim_collection_productssql)
  - [3. dim_collections](#3-dim_collectionssql)
  - [4. dim_customer_addresses](#4-dim_customer_addressessql)
  - [5. dim_customers](#5-dim_customerssql)
  - [6. dim_disputes](#6-dim_disputessql)
  - [7. dim_fulfillment_orders](#7-dim_fulfillment_orderssql)
  - [8. dim_gift_card_transactions](#8-dim_gift_card_transactionssql)
  - [9. dim_gift_cards](#9-dim_gift_cardssql)
  - [10. dim_inventory_items](#10-dim_inventory_itemssql)
  - [11. dim_inventory_levels](#11-dim_inventory_levelssql)
  - [12. dim_inventory_locations](#12-dim_inventory_locationssql)
  - [13. dim_payouts](#13-dim_payoutssql)
  - [14. dim_product_variants](#14-dim_product_variantssql)
  - [15. dim_products](#15-dim_productssql)
  - [16. dim_taxonomy_categories](#16-dim_taxonomy_categoriessql)
  - [17. dim_tender_transactions](#17-dim_tender_transactionssql)
- [Facts](#part-2-fact-models-modelsfacts)
  - [1. fact_order_headers](#1-fact_order_headerssql)
  - [2. fact_order_line_items](#2-fact_order_line_itemssql)
  - [3. fact_order_refunds](#3-fact_order_refundssql)
  - [4. fact_order_transactions](#4-fact_order_transactionssql)

---

# Part 1: Dimension Models (`models/dimensions`)

---

### 1. `dim_cash_drawers.sql`

- **Path**: `models/dimensions/dim_cash_drawers.sql`
- **Materialization**: `table`
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_cash_drawers`
- **Indexes**: `id`

| Column Name         | Inferred Data Type | Source Expression / JSON Path                                       | Notes / Description         |
| :------------------ | :----------------- | :------------------------------------------------------------------ | :-------------------------- |
| `id`                | `VARCHAR / TEXT`   | `rcd.id`                                                            | Primary key identifier      |
| `seller_id`         | `VARCHAR / TEXT`   | `rcd.shop_id`                                                       | Shop/seller identifier      |
| `location_id`       | `VARCHAR / TEXT`   | `rcd.jsonb_doc #>> '{location, id}'`                                | Location identifier         |
| `name`              | `VARCHAR / TEXT`   | `clean_string(rcd.jsonb_doc #>> '{name}')`                          | Drawer name                 |
| `net_sales`         | `NUMERIC`          | `safe_cast_numeric(rcd.jsonb_doc #>> '{netSales, amount}')`         | Net sales amount            |
| `total_adjustments` | `NUMERIC`          | `safe_cast_numeric(rcd.jsonb_doc #>> '{totalAdjustments, amount}')` | Adjustments total           |
| `total_refunds`     | `NUMERIC`          | `safe_cast_numeric(rcd.jsonb_doc #>> '{totalRefunds, amount}')`     | Refunds total               |
| `total_sales`       | `NUMERIC`          | `safe_cast_numeric(rcd.jsonb_doc #>> '{totalSales, amount}')`       | Sales total                 |
| `loaded_at`         | `TIMESTAMPTZ`      | `rcd.loaded_at`                                                     | Timestamp record was loaded |

---

### 2. `dim_collection_products.sql`

- **Path**: `models/dimensions/dim_collection_products.sql`
- **Materialization**: `incremental` (`unique_key: ['collection_id']`)
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_collections` unnested over `products.nodes`
- **Indexes**: `collection_id`, `(collection_id, product_id)`, `loaded_at desc`

| Column Name     | Inferred Data Type | Source Expression / JSON Path      | Notes / Description         |
| :-------------- | :----------------- | :--------------------------------- | :-------------------------- |
| `seller_id`     | `VARCHAR / TEXT`   | `rc.shop_id`                       | Shop/seller identifier      |
| `collection_id` | `VARCHAR / TEXT`   | `rc.id`                            | Collection identifier       |
| `product_id`    | `VARCHAR / TEXT`   | `clean_string(p.value #>> '{id}')` | Product identifier          |
| `loaded_at`     | `TIMESTAMPTZ`      | `b.loaded_at`                      | Timestamp record was loaded |

---

### 3. `dim_collections.sql`

- **Path**: `models/dimensions/dim_collections.sql`
- **Materialization**: `incremental` (`unique_key: ['seller_id', 'id']`)
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_collections`
- **Indexes**: `(seller_id, id)`, `loaded_at desc`

| Column Name   | Inferred Data Type | Source Expression / JSON Path                         | Notes / Description         |
| :------------ | :----------------- | :---------------------------------------------------- | :-------------------------- |
| `id`          | `VARCHAR / TEXT`   | `rc.id`                                               | Collection ID               |
| `seller_id`   | `VARCHAR / TEXT`   | `rc.shop_id`                                          | Shop/seller identifier      |
| `title`       | `VARCHAR / TEXT`   | `clean_string(rc.jsonb_doc #>> '{title}')`            | Collection title            |
| `description` | `VARCHAR / TEXT`   | `clean_string(rc.jsonb_doc #>> '{description}')`      | Description text            |
| `products`    | `JSONB`            | `rc.jsonb_doc #> '{products, nodes}'`                 | Raw array of product nodes  |
| `updated_at`  | `TIMESTAMP`        | `safe_cast_timestamp(rc.jsonb_doc #>> '{updatedAt}')` | Update timestamp            |
| `loaded_at`   | `TIMESTAMPTZ`      | `rc.loaded_at`                                        | Timestamp record was loaded |

---

### 4. `dim_customer_addresses.sql`

- **Path**: `models/dimensions/dim_customer_addresses.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_customers` unnested over `addressesV2.nodes`
- **Indexes**: `id`, `(customer_id, id)`, `loaded_at desc`

| Column Name             | Inferred Data Type | Source Expression / JSON Path                             | Notes / Description         |
| :---------------------- | :----------------- | :-------------------------------------------------------- | :-------------------------- |
| `id`                    | `VARCHAR / TEXT`   | `clean_string(a.value #>> '{id}')`                        | Address ID                  |
| `seller_id`             | `VARCHAR / TEXT`   | `b.seller_id`                                             | Shop/seller identifier      |
| `customer_id`           | `VARCHAR / TEXT`   | `b.customer_id`                                           | Customer ID                 |
| `title`                 | `VARCHAR / TEXT`   | `clean_string(a.value #>> '{name}')`                      | Full name / address title   |
| `address1`              | `VARCHAR / TEXT`   | `clean_string(a.value #>> '{address1}')`                  | Street address line 1       |
| `address2`              | `VARCHAR / TEXT`   | `clean_string(a.value #>> '{address2}')`                  | Street address line 2       |
| `city`                  | `VARCHAR / TEXT`   | `clean_string(a.value #>> '{city}')`                      | City name                   |
| `company`               | `VARCHAR / TEXT`   | `clean_string(a.value #>> '{company}')`                   | Company name                |
| `coordinates_validated` | `BOOLEAN`          | `safe_cast_boolean(a.value #>> '{coordinatesValidated}')` | Geo validation status       |
| `country`               | `VARCHAR / TEXT`   | `clean_string(a.value #>> '{country}')`                   | Country name                |
| `province`              | `VARCHAR / TEXT`   | `clean_string(a.value #>> '{province}')`                  | State / Province            |
| `phone`                 | `VARCHAR / TEXT`   | `clean_string(a.value #>> '{phone}')`                     | Contact phone number        |
| `zip`                   | `VARCHAR / TEXT`   | `clean_string(a.value #>> '{zip}')`                       | Postal / Zip code           |
| `loaded_at`             | `TIMESTAMPTZ`      | `b.loaded_at`                                             | Timestamp record was loaded |

---

### 5. `dim_customers.sql`

- **Path**: `models/dimensions/dim_customers.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_customers`
- **Indexes**: `email`, `(seller_id, id)`, `id`, `loaded_at desc`

| Column Name        | Inferred Data Type | Source Expression / JSON Path                                          | Notes / Description         |
| :----------------- | :----------------- | :--------------------------------------------------------------------- | :-------------------------- |
| `id`               | `VARCHAR / TEXT`   | `rc.id`                                                                | Customer identifier         |
| `seller_id`        | `VARCHAR / TEXT`   | `rc.shop_id`                                                           | Shop/seller identifier      |
| `first_name`       | `VARCHAR / TEXT`   | `clean_string(rc.jsonb_doc #>> '{firstName}')`                         | Customer first name         |
| `last_name`        | `VARCHAR / TEXT`   | `clean_string(rc.jsonb_doc #>> '{lastName}')`                          | Customer last name          |
| `email`            | `VARCHAR / TEXT`   | `clean_string(rc.jsonb_doc #>> '{defaultEmailAddress, emailAddress}')` | Default email address       |
| `amount_spent`     | `NUMERIC`          | `safe_cast_numeric(rc.jsonb_doc #>> '{amountSpent, amount}')`          | Total amount spent          |
| `number_of_orders` | `BIGINT / INTEGER` | `safe_cast_int(rc.jsonb_doc #>> '{numberOfOrders}')`                   | Order count                 |
| `state`            | `VARCHAR / TEXT`   | `clean_string(rc.jsonb_doc #>> '{state}')`                             | Customer account state      |
| `taxExempt`        | `BOOLEAN`          | `safe_cast_boolean(rc.jsonb_doc #>> '{taxExempt}')`                    | Tax exemption flag          |
| `taxExemptions`    | `JSONB`            | `rc.jsonb_doc #> '{taxExemptions}'`                                    | Tax exemptions JSON list    |
| `created_at`       | `TIMESTAMP`        | `safe_cast_timestamp(rc.jsonb_doc #>> '{createdAt}')`                  | Creation timestamp          |
| `updated_at`       | `TIMESTAMP`        | `safe_cast_timestamp(rc.jsonb_doc #>> '{updatedAt}')`                  | Update timestamp            |
| `loaded_at`        | `TIMESTAMPTZ`      | `rc.loaded_at`                                                         | Timestamp record was loaded |

---

### 6. `dim_disputes.sql`

- **Path**: `models/dimensions/dim_disputes.sql`
- **Materialization**: `table`
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_disputes`
- **Indexes**: `id`

| Column Name    | Inferred Data Type | Source Expression / JSON Path                              | Notes / Description         |
| :------------- | :----------------- | :--------------------------------------------------------- | :-------------------------- |
| `id`           | `VARCHAR / TEXT`   | `rd.id`                                                    | Dispute identifier          |
| `seller_id`    | `VARCHAR / TEXT`   | `rd.shop_id`                                               | Shop/seller identifier      |
| `amount`       | `NUMERIC`          | `safe_cast_numeric(rd.jsonb_doc #>> '{amount, amount}')`   | Disputed amount             |
| `order_id`     | `VARCHAR / TEXT`   | `clean_string(rd.jsonb_doc #>> '{order, id}')`             | Associated order identifier |
| `reason`       | `VARCHAR / TEXT`   | `clean_string(rd.jsonb_doc #>> '{reasonDetails, reason}')` | Dispute reason details      |
| `status`       | `VARCHAR / TEXT`   | `clean_string(rd.jsonb_doc #>> '{status}')`                | Dispute status              |
| `type`         | `VARCHAR / TEXT`   | `clean_string(rd.jsonb_doc #>> '{type}')`                  | Dispute type                |
| `initiated_at` | `TIMESTAMP`        | `safe_cast_timestamp(rd.jsonb_doc #>> '{initiatedAt}')`    | Initiation timestamp        |
| `finalized_on` | `TIMESTAMP`        | `safe_cast_timestamp(rd.jsonb_doc #>> '{finalizedOn}')`    | Finalization date/timestamp |
| `loaded_at`    | `TIMESTAMPTZ`      | `rd.loaded_at`                                             | Timestamp record was loaded |

---

### 7. `dim_fulfillment_orders.sql`

- **Path**: `models/dimensions/dim_fulfillment_orders.sql`
- **Materialization**: `incremental` (`unique_key: ['fo_id']`)
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_fulfillment_orders`
- **Indexes**: `fo_id`, `(seller_id, fo_id)`, `order_id`, `(order_id, seller_id)`, `loaded_at desc`

| Column Name              | Inferred Data Type | Source Expression / JSON Path                                                    | Notes / Description          |
| :----------------------- | :----------------- | :------------------------------------------------------------------------------- | :--------------------------- |
| `fo_id`                  | `VARCHAR / TEXT`   | `rfo.id`                                                                         | Fulfillment order identifier |
| `seller_id`              | `VARCHAR / TEXT`   | `rfo.shop_id`                                                                    | Shop/seller identifier       |
| `order_id`               | `VARCHAR / TEXT`   | `clean_string(rfo.jsonb_doc #>> '{orderId}')`                                    | Associated order identifier  |
| `status`                 | `VARCHAR / TEXT`   | `clean_string(rfo.jsonb_doc #>> '{status}')`                                     | Fulfillment status           |
| `requestStatus`          | `VARCHAR / TEXT`   | `clean_string(rfo.jsonb_doc #>> '{requestStatus}')`                              | Request status               |
| `delivery_method_type`   | `VARCHAR / TEXT`   | `clean_string(rfo.jsonb_doc #>> '{deliveryMethod, methodType}')`                 | Delivery method              |
| `max_delivery_date_time` | `TIMESTAMP`        | `safe_cast_timestamp(rfo.jsonb_doc #>> '{deliveryMethod, maxDeliveryDateTime}')` | Max delivery datetime        |
| `created_at`             | `TIMESTAMP`        | `safe_cast_timestamp(rfo.jsonb_doc #>> '{createdAt}')`                           | Creation timestamp           |
| `fulfill_at`             | `TIMESTAMP`        | `safe_cast_timestamp(rfo.jsonb_doc #>> '{fulfillAt}')`                           | Scheduled fulfillment time   |
| `updated_at`             | `TIMESTAMP`        | `safe_cast_timestamp(rfo.jsonb_doc #>> '{updatedAt}')`                           | Update timestamp             |
| `loaded_at`              | `TIMESTAMPTZ`      | `rfo.loaded_at`                                                                  | Timestamp record was loaded  |

---

### 8. `dim_gift_card_transactions.sql`

- **Path**: `models/dimensions/dim_gift_card_transactions.sql`
- **Materialization**: `table`
- **Source**: Union of `stg_giftcards` + `raw_gift_card_transactions` unnested over `gift_card_transactions`
- **Indexes**: `id`, `(id, gift_card_id)`, `(seller_id, gift_card_id)`

| Column Name    | Inferred Data Type | Source Expression / JSON Path                         | Notes / Description         |
| :------------- | :----------------- | :---------------------------------------------------- | :-------------------------- |
| `id`           | `VARCHAR / TEXT`   | `gct.value #>> '{id}'`                                | Transaction identifier      |
| `gift_card_id` | `VARCHAR / TEXT`   | `gcte.gift_card_id`                                   | Associated gift card ID     |
| `seller_id`    | `VARCHAR / TEXT`   | `gcte.seller_id`                                      | Shop/seller identifier      |
| `amount`       | `NUMERIC`          | `safe_cast_numeric(gct.value #>> '{amount, amount}')` | Transaction amount          |
| `note`         | `VARCHAR / TEXT`   | `clean_string(gct.value #>> '{note}')`                | Transaction note            |
| `processed_at` | `TIMESTAMP`        | `safe_cast_timestamp(gct.value #>> '{processedAt}')`  | Processing timestamp        |
| `loaded_at`    | `TIMESTAMPTZ`      | `gcte.loaded_at`                                      | Timestamp record was loaded |

---

### 9. `dim_gift_cards.sql`

- **Path**: `models/dimensions/dim_gift_cards.sql`
- **Materialization**: `table`
- **Source**: `stg_giftcards` JOIN `raw_gift_cards`
- **Indexes**: `id`

| Column Name       | Inferred Data Type | Source Expression / JSON Path                                   | Notes / Description         |
| :---------------- | :----------------- | :-------------------------------------------------------------- | :-------------------------- |
| `id`              | `VARCHAR / TEXT`   | `sgc.id`                                                        | Gift card identifier        |
| `seller_id`       | `VARCHAR / TEXT`   | `sgc.seller_id`                                                 | Shop/seller identifier      |
| `initialValue`    | `NUMERIC`          | `safe_cast_numeric(rgc.jsonb_doc #>> '{initialValue, amount}')` | Initial card balance        |
| `balance`         | `NUMERIC`          | `safe_cast_numeric(rgc.jsonb_doc #>> '{balance, amount}')`      | Current card balance        |
| `customer_id`     | `VARCHAR / TEXT`   | `clean_string(rgc.jsonb_doc #>> '{customer, id}')`              | Associated customer ID      |
| `order_id`        | `VARCHAR / TEXT`   | `clean_string(rgc.jsonb_doc #>> '{order, id}')`                 | Associated order ID         |
| `enabled`         | `BOOLEAN`          | `safe_cast_boolean(rgc.jsonb_doc #>> '{enabled}')`              | Card active status          |
| `masked_code`     | `VARCHAR / TEXT`   | `clean_string(rgc.jsonb_doc #>> '{maskedCode}')`                | Masked card code            |
| `last_characters` | `VARCHAR / TEXT`   | `clean_string(rgc.jsonb_doc #>> '{lastCharacters}')`            | Last card characters        |
| `deactivated_at`  | `TIMESTAMP`        | `safe_cast_timestamp(rgc.jsonb_doc #>> '{deactivatedAt}')`      | Deactivation timestamp      |
| `expires_on`      | `TIMESTAMP`        | `safe_cast_timestamp(rgc.jsonb_doc #>> '{expiresOn}')`          | Expiration date             |
| `created_at`      | `TIMESTAMP`        | `safe_cast_timestamp(rgc.jsonb_doc #>> '{createdAt}')`          | Creation timestamp          |
| `updated_at`      | `TIMESTAMP`        | `safe_cast_timestamp(rgc.jsonb_doc #>> '{updatedAt}')`          | Update timestamp            |
| `loaded_at`       | `TIMESTAMPTZ`      | `sgc.loaded_at`                                                 | Timestamp record was loaded |

---

### 10. `dim_inventory_items.sql`

- **Path**: `models/dimensions/dim_inventory_items.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `stg_inventory_items` JOIN `raw_inventory_items`
- **Indexes**: `id`, `(seller_id, id)`, `loaded_at desc`

| Column Name               | Inferred Data Type | Source Expression / JSON Path                               | Notes / Description         |
| :------------------------ | :----------------- | :---------------------------------------------------------- | :-------------------------- |
| `id`                      | `VARCHAR / TEXT`   | `sii.id`                                                    | Inventory item identifier   |
| `seller_id`               | `VARCHAR / TEXT`   | `sii.seller_id`                                             | Shop/seller identifier      |
| `province_code_of_origin` | `VARCHAR / TEXT`   | `clean_string(rii.jsonb_doc #>> '{provinceCodeOfOrigin}')`  | Province of origin          |
| `country_code_of_origin`  | `VARCHAR / TEXT`   | `clean_string(rii.jsonb_doc #>> '{countryCodeOfOrigin}')`   | Country of origin           |
| `sku`                     | `VARCHAR / TEXT`   | `clean_string(rii.jsonb_doc #>> '{sku}')`                   | SKU identifier              |
| `unit_cost`               | `NUMERIC`          | `safe_cast_numeric(rii.jsonb_doc #>> '{unitCost, amount}')` | Unit cost amount            |
| `created_at`              | `TIMESTAMP`        | `safe_cast_timestamp(rii.jsonb_doc #>> '{createdAt}')`      | Creation timestamp          |
| `updated_at`              | `TIMESTAMP`        | `safe_cast_timestamp(rii.jsonb_doc #>> '{updatedAt}')`      | Update timestamp            |
| `loaded_at`               | `TIMESTAMPTZ`      | `sii.loaded_at`                                             | Timestamp record was loaded |

---

### 11. `dim_inventory_levels.sql`

- **Path**: `models/dimensions/dim_inventory_levels.sql`
- **Materialization**: `incremental` (`unique_key: ['id', 'inventory_item_id']`)
- **Source**: Union of `stg_inventory_items` + `raw_inventory_levels` unnested over `inventory_levels`
- **Indexes**: `id`, `(id, inventory_item_id)`, `(seller_id, inventory_item_id)`, `loaded_at desc`

| Column Name                | Inferred Data Type | Source Expression / JSON Path                                         | Notes / Description           |
| :------------------------- | :----------------- | :-------------------------------------------------------------------- | :---------------------------- |
| `id`                       | `VARCHAR / TEXT`   | `il.value #>> '{id}'`                                                 | Inventory level identifier    |
| `seller_id`                | `VARCHAR / TEXT`   | `ile.seller_id`                                                       | Shop/seller identifier        |
| `inventory_location_id`    | `VARCHAR / TEXT`   | `il.value #>> '{location, id}'`                                       | Inventory location identifier |
| `inventory_item_id`        | `VARCHAR / TEXT`   | `ile.inventory_item_id`                                               | Inventory item identifier     |
| `incoming_quantity`        | `NUMERIC / INT`    | `get_quantity_by_name(il.value #> '{quantities}', 'incoming')`        | Incoming quantity             |
| `on_hand_quantity`         | `NUMERIC / INT`    | `get_quantity_by_name(il.value #> '{quantities}', 'on_hand')`         | On hand quantity              |
| `available_quantity`       | `NUMERIC / INT`    | `get_quantity_by_name(il.value #> '{quantities}', 'available')`       | Available quantity            |
| `committed_quantity`       | `NUMERIC / INT`    | `get_quantity_by_name(il.value #> '{quantities}', 'committed')`       | Committed quantity            |
| `reserved_quantity`        | `NUMERIC / INT`    | `get_quantity_by_name(il.value #> '{quantities}', 'reserved')`        | Reserved quantity             |
| `damaged_quantity`         | `NUMERIC / INT`    | `get_quantity_by_name(il.value #> '{quantities}', 'damaged')`         | Damaged quantity              |
| `safety_stock_quantity`    | `NUMERIC / INT`    | `get_quantity_by_name(il.value #> '{quantities}', 'safety_stock')`    | Safety stock quantity         |
| `quality_control_quantity` | `NUMERIC / INT`    | `get_quantity_by_name(il.value #> '{quantities}', 'quality_control')` | QC quantity                   |
| `is_active`                | `BOOLEAN`          | `safe_cast_boolean(il.value #>> '{isActive}')`                        | Active status flag            |
| `created_at`               | `TIMESTAMP`        | `safe_cast_timestamp(il.value #>> '{createdAt}')`                     | Creation timestamp            |
| `updated_at`               | `TIMESTAMP`        | `safe_cast_timestamp(il.value #>> '{updatedAt}')`                     | Update timestamp              |
| `loaded_at`                | `TIMESTAMPTZ`      | `ile.loaded_at`                                                       | Timestamp record was loaded   |

---

### 12. `dim_inventory_locations.sql`

- **Path**: `models/dimensions/dim_inventory_locations.sql`
- **Materialization**: `table`
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_inventory_locations`
- **Indexes**: `id`

| Column Name              | Inferred Data Type | Source Expression / JSON Path                                   | Notes / Description         |
| :----------------------- | :----------------- | :-------------------------------------------------------------- | :-------------------------- |
| `id`                     | `VARCHAR / TEXT`   | `ril.id`                                                        | Location identifier         |
| `seller_id`              | `VARCHAR / TEXT`   | `ril.shop_id`                                                   | Shop/seller identifier      |
| `address`                | `JSONB`            | `ril.jsonb_doc #> '{address}'`                                  | Location address JSON       |
| `fulfills_online_orders` | `BOOLEAN`          | `safe_cast_boolean(ril.jsonb_doc #>> '{fulfillsOnlineOrders}')` | Online orders capability    |
| `has_active_inventory`   | `BOOLEAN`          | `safe_cast_boolean(ril.jsonb_doc #>> '{hasActiveInventory}')`   | Active inventory flag       |
| `has_unfulfilled_orders` | `BOOLEAN`          | `safe_cast_boolean(ril.jsonb_doc #>> '{hasUnfulfilledOrders}')` | Unfulfilled orders flag     |
| `is_active`              | `BOOLEAN`          | `safe_cast_boolean(ril.jsonb_doc #>> '{isActive}')`             | Location active flag        |
| `is_fulfillment_service` | `BOOLEAN`          | `safe_cast_boolean(ril.jsonb_doc #>> '{isFulfillmentService}')` | Fulfillment service flag    |
| `name`                   | `VARCHAR / TEXT`   | `clean_string(ril.jsonb_doc #>> '{name}')`                      | Location name               |
| `created_at`             | `TIMESTAMP`        | `safe_cast_timestamp(ril.jsonb_doc #>> '{createdAt}')`          | Creation timestamp          |
| `updated_at`             | `TIMESTAMP`        | `safe_cast_timestamp(ril.jsonb_doc #>> '{updatedAt}')`          | Update timestamp            |
| `deactivated_at`         | `TIMESTAMP`        | `safe_cast_timestamp(ril.jsonb_doc #>> '{deactivatedAt}')`      | Deactivation timestamp      |
| `loaded_at`              | `TIMESTAMPTZ`      | `ril.loaded_at`                                                 | Timestamp record was loaded |

---

### 13. `dim_payouts.sql`

- **Path**: `models/dimensions/dim_payouts.sql`
- **Materialization**: `table`
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_payouts`
- **Indexes**: `id`

| Column Name        | Inferred Data Type | Source Expression / JSON Path                                                                | Notes / Description         |
| :----------------- | :----------------- | :------------------------------------------------------------------------------------------- | :-------------------------- |
| `id`               | `VARCHAR / TEXT`   | `rp.id`                                                                                      | Payout identifier           |
| `seller_id`        | `VARCHAR / TEXT`   | `rp.shop_id`                                                                                 | Shop/seller identifier      |
| `activated`        | `BOOLEAN`          | `safe_cast_boolean(rp.jsonb_doc #>> '{businessEntity, shopifyPaymentsAccount, activated}')`  | Account activation flag     |
| `balance_amount`   | `JSONB`            | `rp.jsonb_doc #> '{businessEntity, shopifyPaymentsAccount, balance}'`                        | Balance info JSON           |
| `country`          | `VARCHAR / TEXT`   | `clean_string(rp.jsonb_doc #>> '{businessEntity, shopifyPaymentsAccount, country}')`         | Payout country code         |
| `default_currency` | `VARCHAR / TEXT`   | `clean_string(rp.jsonb_doc #>> '{businessEntity, shopifyPaymentsAccount, defaultCurrency}')` | Default currency code       |
| `net`              | `JSONB`            | `rp.jsonb_doc #> '{net}'`                                                                    | Net amount details JSON     |
| `summary`          | `JSONB`            | `rp.jsonb_doc #> '{summary}'`                                                                | Summary details JSON        |
| `status`           | `VARCHAR / TEXT`   | `clean_string(rp.jsonb_doc #>> '{status}')`                                                  | Payout status               |
| `transactionType`  | `VARCHAR / TEXT`   | `clean_string(rp.jsonb_doc #>> '{transactionType}')`                                         | Type of payout transaction  |
| `issued_at`        | `TIMESTAMP`        | `safe_cast_timestamp(rp.jsonb_doc #>> '{issuedAt}')`                                         | Issue date/timestamp        |
| `loaded_at`        | `TIMESTAMPTZ`      | `rp.loaded_at`                                                                               | Timestamp record was loaded |

---

### 14. `dim_product_variants.sql`

- **Path**: `models/dimensions/dim_product_variants.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_product_variants`
- **Indexes**: `id`, `(seller_id, id)`, `product_id`, `inventory_item_id`, `loaded_at desc`

| Column Name          | Inferred Data Type | Source Expression / JSON Path                            | Notes / Description          |
| :------------------- | :----------------- | :------------------------------------------------------- | :--------------------------- |
| `id`                 | `VARCHAR / TEXT`   | `rpv.id`                                                 | Product variant identifier   |
| `seller_id`          | `VARCHAR / TEXT`   | `rpv.shop_id`                                            | Shop/seller identifier       |
| `product_id`         | `VARCHAR / TEXT`   | `clean_string(rpv.jsonb_doc #>> '{product, id}')`        | Associated product ID        |
| `inventory_item_id`  | `VARCHAR / TEXT`   | `clean_string(rpv.jsonb_doc #>> '{inventoryItem, id}')`  | Associated inventory item ID |
| `inventory_quantity` | `BIGINT / INTEGER` | `safe_cast_int(rpv.jsonb_doc #>> '{inventoryQuantity}')` | Available inventory count    |
| `price`              | `NUMERIC`          | `safe_cast_numeric(rpv.jsonb_doc #>> '{price}')`         | Variant price                |
| `sku`                | `VARCHAR / TEXT`   | `clean_string(rpv.jsonb_doc #>> '{sku}')`                | Variant SKU code             |
| `taxable`            | `BOOLEAN`          | `safe_cast_boolean(rpv.jsonb_doc #>> '{taxable}')`       | Taxable indicator            |
| `created_at`         | `TIMESTAMP`        | `safe_cast_timestamp(rpv.jsonb_doc #>> '{createdAt}')`   | Creation timestamp           |
| `updated_at`         | `TIMESTAMP`        | `safe_cast_timestamp(rpv.jsonb_doc #>> '{updatedAt}')`   | Update timestamp             |
| `loaded_at`          | `TIMESTAMPTZ`      | `rpv.loaded_at`                                          | Timestamp record was loaded  |

---

### 15. `dim_products.sql`

- **Path**: `models/dimensions/dim_products.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_products`
- **Indexes**: `id`, `(seller_id, id)`, `category_id`, `loaded_at desc`

| Column Name       | Inferred Data Type | Source Expression / JSON Path                           | Notes / Description          |
| :---------------- | :----------------- | :------------------------------------------------------ | :--------------------------- |
| `id`              | `VARCHAR / TEXT`   | `rp.id`                                                 | Product identifier           |
| `seller_id`       | `VARCHAR / TEXT`   | `rp.shop_id`                                            | Shop/seller identifier       |
| `category_id`     | `VARCHAR / TEXT`   | `clean_string(rp.jsonb_doc #>> '{category, id}')`       | Taxonomy category identifier |
| `title`           | `VARCHAR / TEXT`   | `clean_string(rp.jsonb_doc #>> '{title}')`              | Product title                |
| `description`     | `VARCHAR / TEXT`   | `clean_string(rp.jsonb_doc #>> '{description}')`        | Product description          |
| `is_gift_card`    | `BOOLEAN`          | `safe_cast_boolean(rp.jsonb_doc #>> '{isGiftCard}')`    | Gift card flag               |
| `product_type`    | `VARCHAR / TEXT`   | `clean_string(rp.jsonb_doc #>> '{productType}')`        | Product type / category text |
| `status`          | `VARCHAR / TEXT`   | `clean_string(rp.jsonb_doc #>> '{status}')`             | Product catalog status       |
| `total_inventory` | `BIGINT / INTEGER` | `safe_cast_int(rp.jsonb_doc #>> '{totalInventory}')`    | Total aggregated inventory   |
| `vendor`          | `VARCHAR / TEXT`   | `clean_string(rp.jsonb_doc #>> '{vendor}')`             | Product vendor / brand       |
| `created_at`      | `TIMESTAMP`        | `safe_cast_timestamp(rp.jsonb_doc #>> '{createdAt}')`   | Creation timestamp           |
| `published_at`    | `TIMESTAMP`        | `safe_cast_timestamp(rp.jsonb_doc #>> '{publishedAt}')` | Published timestamp          |
| `updated_at`      | `TIMESTAMP`        | `safe_cast_timestamp(rp.jsonb_doc #>> '{updatedAt}')`   | Update timestamp             |
| `loaded_at`       | `TIMESTAMPTZ`      | `rp.loaded_at`                                          | Timestamp record was loaded  |

---

### 16. `dim_taxonomy_categories.sql`

- **Path**: `models/dimensions/dim_taxonomy_categories.sql`
- **Materialization**: `table`
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_taxonomy`
- **Indexes**: `id`

| Column Name   | Inferred Data Type | Source Expression / JSON Path                        | Notes / Description         |
| :------------ | :----------------- | :--------------------------------------------------- | :-------------------------- |
| `id`          | `VARCHAR / TEXT`   | `rt.id`                                              | Category identifier         |
| `seller_id`   | `VARCHAR / TEXT`   | `rt.shop_id`                                         | Shop/seller identifier      |
| `name`        | `VARCHAR / TEXT`   | `clean_string(rt.jsonb_doc #>> '{name}')`            | Category name               |
| `is_archived` | `BOOLEAN`          | `safe_cast_boolean(rt.jsonb_doc #>> '{isArchived}')` | Category archived flag      |
| `is_root`     | `BOOLEAN`          | `safe_cast_boolean(rt.jsonb_doc #>> '{isRoot}')`     | Root category flag          |
| `parent_id`   | `VARCHAR / TEXT`   | `clean_string(rt.jsonb_doc #>> '{parentId}')`        | Parent category identifier  |
| `loaded_at`   | `TIMESTAMPTZ`      | `rt.loaded_at`                                       | Timestamp record was loaded |

---

### 17. `dim_tender_transactions.sql`

- **Path**: `models/dimensions/dim_tender_transactions.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `{{ env_var('DBT_SOURCE_SCHEMA') }}.raw_tender_transactions`
- **Indexes**: `id`, `(seller_id, id)`, `loaded_at desc`

| Column Name                       | Inferred Data Type | Source Expression / JSON Path                                               | Notes / Description             |
| :-------------------------------- | :----------------- | :-------------------------------------------------------------------------- | :------------------------------ |
| `id`                              | `VARCHAR / TEXT`   | `rtt.id`                                                                    | Tender transaction identifier   |
| `seller_id`                       | `VARCHAR / TEXT`   | `rtt.shop_id`                                                               | Shop/seller identifier          |
| `order_id`                        | `VARCHAR / TEXT`   | `clean_string(rtt.jsonb_doc #>> '{order, id}')`                             | Associated order ID             |
| `amount`                          | `NUMERIC`          | `safe_cast_numeric(rtt.jsonb_doc #>> '{amount, amount}')`                   | Transaction amount              |
| `payment_method`                  | `VARCHAR / TEXT`   | `clean_string(rtt.jsonb_doc #>> '{paymentMethod}')`                         | Payment method description      |
| `processed_at`                    | `TIMESTAMP`        | `safe_cast_timestamp(rtt.jsonb_doc #>> '{processedAt}')`                    | Transaction processed timestamp |
| `remote_reference`                | `VARCHAR / TEXT`   | `clean_string(rtt.jsonb_doc #>> '{remoteReference}')`                       | Remote payment reference        |
| `test`                            | `BOOLEAN`          | `safe_cast_boolean(rtt.jsonb_doc #>> '{test}')`                             | Test transaction flag           |
| `transaction_credit_card_company` | `VARCHAR / TEXT`   | `clean_string(rtt.jsonb_doc #>> '{transactionDetails, creditCardCompany}')` | Credit card company name        |
| `loaded_at`                       | `TIMESTAMPTZ`      | `rtt.loaded_at`                                                             | Timestamp record was loaded     |

---

# Part 2: Fact Models (`models/facts`)

---

### 1. `fact_order_headers.sql`

- **Path**: `models/facts/fact_order_headers.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `stg_orders` JOIN `raw_orders`
- **Indexes**: `id`, `(seller_id, id)`, `loaded_at desc`

| Column Name                           | Inferred Data Type | Source Expression / JSON Path                                                               | Notes / Description             |
| :------------------------------------ | :----------------- | :------------------------------------------------------------------------------------------ | :------------------------------ |
| `id`                                  | `VARCHAR / TEXT`   | `so.id`                                                                                     | Order identifier                |
| `seller_id`                           | `VARCHAR / TEXT`   | `so.seller_id`                                                                              | Shop/seller identifier          |
| `customer_id`                         | `VARCHAR / TEXT`   | `ro.jsonb_doc #>> '{customer, id}'`                                                         | Customer identifier             |
| `billing_address_id`                  | `VARCHAR / TEXT`   | `ro.jsonb_doc #>> '{billingAddress, id}'`                                                   | Billing address identifier      |
| `channel_id`                          | `VARCHAR / TEXT`   | `ro.jsonb_doc #>> '{channelInformation, id}'`                                               | Sales channel identifier        |
| `attribution_handle`                  | `VARCHAR / TEXT`   | `clean_string(ro.jsonb_doc #>> '{attribution, handle}')`                                    | Attribution handle              |
| `attribution_displayname`             | `VARCHAR / TEXT`   | `clean_string(ro.jsonb_doc #>> '{attribution, displayName}')`                               | Attribution display name        |
| `currency_code`                       | `VARCHAR / TEXT`   | `clean_string(ro.jsonb_doc #>> '{presentmentCurrencyCode}')`                                | Presentment currency code       |
| `cart_discount_amount`                | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{cartDiscountAmountSet, shopMoney, amount}')`          | Cart discount amount            |
| `current_cart_discount_amount`        | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{currentCartDiscountAmountSet, shopMoney, amount}')`   | Current cart discount amount    |
| `current_shipping_price`              | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{currentShippingPriceSet, shopMoney, amount}')`        | Current shipping price          |
| `current_subtotal_lineItems_quantity` | `BIGINT / INTEGER` | `safe_cast_int(ro.jsonb_doc #>> '{currentSubtotalLineItemsQuantity}')`                      | Current subtotal quantity       |
| `current_subtotal_price`              | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{currentSubtotalPriceSet, shopMoney, amount}')`        | Current subtotal price          |
| `current_total_additional_fees`       | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalAdditionalFeesSet, shopMoney, amount}')`  | Current total additional fees   |
| `current_total_discounts`             | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalDiscountsSet, shopMoney, amount}')`       | Current total discounts         |
| `current_total_duties`                | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalDutiesSet, shopMoney, amount}')`          | Current total duties            |
| `current_total_price`                 | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalPriceSet, shopMoney, amount}')`           | Current total price             |
| `current_total_tax`                   | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalTaxSet, shopMoney, amount}')`             | Current total tax               |
| `current_total_weight`                | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalWeight}')`                                | Current total order weight      |
| `discountCode`                        | `JSONB`            | `ro.jsonb_doc #> '{discountCodes}'`                                                         | Array of applied discount codes |
| `duties_included`                     | `BOOLEAN`          | `safe_cast_boolean(ro.jsonb_doc #>> '{dutiesIncluded}')`                                    | Flag if duties are included     |
| `fullyPaid`                           | `BOOLEAN`          | `safe_cast_boolean(ro.jsonb_doc #>> '{fullyPaid}')`                                         | Flag if order is fully paid     |
| `net_payment`                         | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{netPaymentSet, shopMoney, amount}')`                  | Net payment amount              |
| `original_total_additional_fees`      | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{originalTotalAdditionalFeesSet, shopMoney, amount}')` | Original additional fees        |
| `original_total_duties`               | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{originalTotalDutiesSet, shopMoney, amount}')`         | Original duties total           |
| `original_total_price`                | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{originalTotalPriceSet, shopMoney, amount}')`          | Original order total            |
| `test`                                | `BOOLEAN`          | `safe_cast_boolean(ro.jsonb_doc #>> '{test}')`                                              | Flag for test order             |
| `source_identifier`                   | `VARCHAR / TEXT`   | `clean_string(ro.jsonb_doc #>> '{sourceIdentifier}')`                                       | Source system identifier        |
| `source_name`                         | `VARCHAR / TEXT`   | `clean_string(ro.jsonb_doc #>> '{sourceName}')`                                             | Source channel name             |
| `subtotal_line_items_quantity`        | `BIGINT / INTEGER` | `safe_cast_int(ro.jsonb_doc #>> '{subtotalLineItemsQuantity}')`                             | Line items quantity sum         |
| `subtotal_price`                      | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{subtotalPriceSet, shopMoney, amount}')`               | Order subtotal price            |
| `taxes_included`                      | `BOOLEAN`          | `safe_cast_boolean(ro.jsonb_doc #>> '{taxesIncluded}')`                                     | Flag if taxes are included      |
| `tax_exempt`                          | `BOOLEAN`          | `safe_cast_boolean(ro.jsonb_doc #>> '{taxExempt}')`                                         | Flag if order is tax exempt     |
| `total_capturable_amount`             | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{totalCapturableSet, shopMoney, amount}')`             | Total capturable amount         |
| `total_discounts_amount`              | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{totalDiscountsSet, shopMoney, amount}')`              | Total discount amount           |
| `total_outstanding_amount`            | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{totalOutstandingSet, shopMoney, amount}')`            | Total outstanding amount        |
| `total_price`                         | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{totalPriceSet, shopMoney, amount}')`                  | Total price                     |
| `total_received_amount`               | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{totalReceivedSet, shopMoney, amount}')`               | Total received amount           |
| `total_refunded_amount`               | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{totalRefundedSet, shopMoney, amount}')`               | Total refunded amount           |
| `total_refunded_shipping_amount`      | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{totalRefundedShippingSet, shopMoney, amount}')`       | Refunded shipping amount        |
| `total_shipping_price`                | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{totalShippingPriceSet, shopMoney, amount}')`          | Total shipping charges          |
| `total_tax`                           | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{totalTaxSet, shopMoney, amount}')`                    | Total tax charged               |
| `total_tip_received`                  | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{totalTipReceivedSet, shopMoney, amount}')`            | Tip amount received             |
| `total_weight`                        | `NUMERIC`          | `safe_cast_numeric(ro.jsonb_doc #>> '{totalWeight}')`                                       | Total order weight              |
| `unpaid`                              | `BOOLEAN`          | `safe_cast_boolean(ro.jsonb_doc #>> '{unpaid}')`                                            | Flag if order is unpaid         |
| `payment_gateway_names`               | `JSONB`            | `ro.jsonb_doc #> '{paymentGatewayNames}'`                                                   | List of payment gateways        |
| `shipping_address_id`                 | `VARCHAR / TEXT`   | `clean_string(ro.jsonb_doc #>> '{shippingAddress, id}')`                                    | Shipping address identifier     |
| `order_app_id`                        | `VARCHAR / TEXT`   | `clean_string(ro.jsonb_doc #>> '{app, id}')`                                                | App identifier                  |
| `order_app_name`                      | `VARCHAR / TEXT`   | `clean_string(ro.jsonb_doc #>> '{app, name}')`                                              | App name                        |
| `referringSites`                      | `JSONB`            | `jsonb_build_object('firstVisit', ..., 'lastVisit', ...)`                                   | Referrer URL object             |
| `uTMParameters`                       | `JSONB`            | `jsonb_build_object('firstVisit', ..., 'lastVisit', ...)`                                   | UTM parameters object           |
| `financialStatus`                     | `VARCHAR / TEXT`   | `clean_string(ro.jsonb_doc #>> '{displayFinancialStatus}')`                                 | Financial status                |
| `fulfillmentStatus`                   | `VARCHAR / TEXT`   | `clean_string(ro.jsonb_doc #>> '{displayFulfillmentStatus}')`                               | Fulfillment status              |
| `created_at`                          | `TIMESTAMP`        | `safe_cast_timestamp(ro.jsonb_doc #>> '{createdAt}')`                                       | Order creation timestamp        |
| `updated_at`                          | `TIMESTAMP`        | `safe_cast_timestamp(ro.jsonb_doc #>> '{updatedAt}')`                                       | Order update timestamp          |
| `processed_at`                        | `TIMESTAMP`        | `safe_cast_timestamp(ro.jsonb_doc #>> '{processedAt}')`                                     | Processed timestamp             |
| `cancelled_at`                        | `TIMESTAMP`        | `safe_cast_timestamp(ro.jsonb_doc #>> '{cancelledAt}')`                                     | Cancellation timestamp          |
| `closed`                              | `BOOLEAN`          | `safe_cast_boolean(ro.jsonb_doc #>> '{closed}')`                                            | Flag if closed                  |
| `closed_at`                           | `TIMESTAMP`        | `safe_cast_timestamp(ro.jsonb_doc #>> '{closedAt}')`                                        | Closed timestamp                |
| `confirmed`                           | `BOOLEAN`          | `safe_cast_boolean(ro.jsonb_doc #>> '{confirmed}')`                                         | Confirmation flag               |
| `loaded_at`                           | `TIMESTAMPTZ`      | `so.loaded_at`                                                                              | Timestamp record was loaded     |

---

### 2. `fact_order_line_items.sql`

- **Path**: `models/facts/fact_order_line_items.sql`
- **Materialization**: `incremental` (`unique_key: ['id', 'order_id']`)
- **Source**: Union of `stg_orders` + `raw_order_lineitems` unnested over `line_items`
- **Indexes**: `id`, `(order_id, id)`, `(seller_id, order_id)`, `loaded_at desc`

| Column Name                                 | Inferred Data Type | Source Expression / JSON Path                                                                    | Notes / Description            |
| :------------------------------------------ | :----------------- | :----------------------------------------------------------------------------------------------- | :----------------------------- |
| `id`                                        | `VARCHAR / TEXT`   | `li.value #>> '{id}'`                                                                            | Line item identifier           |
| `order_id`                                  | `VARCHAR / TEXT`   | `lie.order_id`                                                                                   | Order identifier               |
| `seller_id`                                 | `VARCHAR / TEXT`   | `lie.seller_id`                                                                                  | Shop/seller identifier         |
| `product_variant_id`                        | `VARCHAR / TEXT`   | `li.value #>> '{variant, id}'`                                                                   | Variant identifier             |
| `current_quantity`                          | `BIGINT / INTEGER` | `safe_cast_int(li.value #>> '{currentQuantity}')`                                                | Current item quantity          |
| `discounted_total_amount`                   | `NUMERIC`          | `safe_cast_numeric(li.value #>> '{discountedTotalSet, shopMoney, amount}')`                      | Discounted total amount        |
| `discounted_unit_price_after_all_discounts` | `NUMERIC`          | `safe_cast_numeric(li.value #>> '{discountedUnitPriceAfterAllDiscountsSet, shopMoney, amount}')` | Unit price after all discounts |
| `discounted_unit_price`                     | `NUMERIC`          | `safe_cast_numeric(li.value #>> '{discountedUnitPriceSet, shopMoney, amount}')`                  | Discounted unit price          |
| `is_giftcard`                               | `BOOLEAN`          | `safe_cast_boolean(li.value #>> '{isGiftCard}')`                                                 | Gift card line item flag       |
| `original_total_amount`                     | `NUMERIC`          | `safe_cast_numeric(li.value #>> '{originalTotalSet, shopMoney, amount}')`                        | Original total before discount |
| `original_unit_price`                       | `NUMERIC`          | `safe_cast_numeric(li.value #>> '{originalUnitPriceSet, shopMoney, amount}')`                    | Original unit price            |
| `quantity`                                  | `BIGINT / INTEGER` | `safe_cast_int(li.value #>> '{quantity}')`                                                       | Ordered quantity               |
| `refundable_quantity`                       | `BIGINT / INTEGER` | `safe_cast_int(li.value #>> '{refundableQuantity}')`                                             | Refundable quantity            |
| `total_discount_amount`                     | `NUMERIC`          | `safe_cast_numeric(li.value #>> '{totalDiscountSet, shopMoney, amount}')`                        | Total line discount amount     |
| `unfulfilled_discounted_total_amount`       | `NUMERIC`          | `safe_cast_numeric(li.value #>> '{unfulfilledDiscountedTotalSet, shopMoney, amount}')`           | Unfulfilled discounted total   |
| `unfulfilled_original_total_amount`         | `NUMERIC`          | `safe_cast_numeric(li.value #>> '{unfulfilledOriginalTotalSet, shopMoney, amount}')`             | Unfulfilled original total     |
| `unfulfilled_quantity`                      | `BIGINT / INTEGER` | `safe_cast_int(li.value #>> '{unfulfilledQuantity}')`                                            | Unfulfilled quantity           |
| `loaded_at`                                 | `TIMESTAMPTZ`      | `lie.loaded_at`                                                                                  | Timestamp record was loaded    |

---

### 3. `fact_order_refunds.sql`

- **Path**: `models/facts/fact_order_refunds.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `stg_orders` unnested over `refunds`
- **Indexes**: `id`, `(seller_id, order_id)`, `(order_id, id)`, `loaded_at desc`

| Column Name             | Inferred Data Type | Source Expression / JSON Path                                            | Notes / Description         |
| :---------------------- | :----------------- | :----------------------------------------------------------------------- | :-------------------------- |
| `id`                    | `VARCHAR / TEXT`   | `r.value #>> '{id}'`                                                     | Refund identifier           |
| `order_id`              | `VARCHAR / TEXT`   | `b.order_id`                                                             | Order identifier            |
| `seller_id`             | `VARCHAR / TEXT`   | `b.seller_id`                                                            | Shop/seller identifier      |
| `note`                  | `VARCHAR / TEXT`   | `clean_string(r.value #>> '{note}')`                                     | Refund note / reason        |
| `total_refunded_amount` | `NUMERIC`          | `safe_cast_numeric(r.value #>> '{totalRefundedSet, shopMoney, amount}')` | Total refunded amount       |
| `processed_at`          | `TIMESTAMP`        | `safe_cast_timestamp(r.value #>> '{processedAt}')`                       | Processed timestamp         |
| `created_at`            | `TIMESTAMP`        | `safe_cast_timestamp(r.value #>> '{createdAt}')`                         | Creation timestamp          |
| `updated_at`            | `TIMESTAMP`        | `safe_cast_timestamp(r.value #>> '{updatedAt}')`                         | Update timestamp            |
| `loaded_at`             | `TIMESTAMPTZ`      | `b.loaded_at`                                                            | Timestamp record was loaded |

---

### 4. `fact_order_transactions.sql`

- **Path**: `models/facts/fact_order_transactions.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `stg_orders` unnested over `transactions`
- **Indexes**: `id`, `(seller_id, order_id)`, `(order_id, id)`, `loaded_at desc`

| Column Name                 | Inferred Data Type | Source Expression / JSON Path                                             | Notes / Description                           |
| :-------------------------- | :----------------- | :------------------------------------------------------------------------ | :-------------------------------------------- |
| `id`                        | `VARCHAR / TEXT`   | `t.value #>> '{id}'`                                                      | Order transaction identifier                  |
| `order_id`                  | `VARCHAR / TEXT`   | `b.order_id`                                                              | Order identifier                              |
| `seller_id`                 | `VARCHAR / TEXT`   | `b.seller_id`                                                             | Shop/seller identifier                        |
| `amount_rounding`           | `NUMERIC`          | `safe_cast_numeric(t.value #>> '{amountRoundingSet, shopMoney, amount}')` | Rounding difference amount                    |
| `amount`                    | `NUMERIC`          | `safe_cast_numeric(t.value #>> '{amountSet, shopMoney, amount}')`         | Transaction amount                            |
| `device_id`                 | `VARCHAR / TEXT`   | `t.value #>> '{device, id}'`                                              | POS device identifier                         |
| `cashDrawer_name`           | `VARCHAR / TEXT`   | `clean_string(t.value #>> '{device, cashDrawer, name}')`                  | POS cash drawer name                          |
| `transaction_fee`           | `NUMERIC`          | `safe_cast_numeric(t.value #>> '{fees, amount, amount}')`                 | Payment processing fee                        |
| `gateway`                   | `VARCHAR / TEXT`   | `clean_string(t.value #>> '{gateway}')`                                   | Payment gateway name                          |
| `kind`                      | `VARCHAR / TEXT`   | `clean_string(t.value #>> '{kind}')`                                      | Transaction kind (e.g. sale, capture, refund) |
| `location_id`               | `VARCHAR / TEXT`   | `clean_string(t.value #>> '{location, id}')`                              | Location identifier                           |
| `manual_payment_gateway`    | `BOOLEAN`          | `safe_cast_boolean(t.value #>> '{manualPaymentGateway}')`                 | Manual gateway flag                           |
| `maximum_refundable_amount` | `NUMERIC`          | `safe_cast_numeric(t.value #>> '{maximumRefundableV2, amount}')`          | Max refundable amount                         |
| `status`                    | `VARCHAR / TEXT`   | `clean_string(t.value #>> '{status}')`                                    | Transaction status                            |
| `test`                      | `BOOLEAN`          | `safe_cast_boolean(t.value #>> '{test}')`                                 | Test transaction flag                         |
| `created_at`                | `TIMESTAMP`        | `safe_cast_timestamp(t.value #>> '{createdAt}')`                          | Creation timestamp                            |
| `processed_at`              | `TIMESTAMP`        | `safe_cast_timestamp(t.value #>> '{processedAt}')`                        | Processed timestamp                           |
| `loaded_at`                 | `TIMESTAMPTZ`      | `b.loaded_at`                                                             | Timestamp record was loaded                   |
