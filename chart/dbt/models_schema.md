# Data Models Schema Documentation

Table schemas, materialization strategies, indexes, and column-level mappings for the dimension and fact tables in the warehouse `public` schema.

- Dimensions: 12 tables
- Facts: 10 tables

**Data types** are the actual column types from the warehouse `information_schema` (`Vizkit/reportwisp_warehousemation_schema_columns.json`). Every column is nullable. `TIMESTAMP` is `timestamp without time zone`, `TIMESTAMPTZ` is `timestamp with time zone`.

**Source expressions** come from the dbt model SQL. `safe_cast_numeric` returns `numeric(15,2)`, and `clean_string` returns `TEXT`.

**Soft delete:** tables with `record_status` keep Shopify-deleted rows flagged `DELETED`. Report queries must filter `record_status = 'ACTIVE'`.

---

## Table of Contents

- [Dimensions](#part-1-dimension-tables)
  - [1. dim_collection_products](#1-dim_collection_productssql)
  - [2. dim_collections](#2-dim_collectionssql)
  - [3. dim_customer_addresses](#3-dim_customer_addressessql)
  - [4. dim_customers](#4-dim_customerssql)
  - [5. dim_fulfillment_orders](#5-dim_fulfillment_orderssql)
  - [6. dim_gift_cards](#6-dim_gift_cardssql)
  - [7. dim_inventory_items](#7-dim_inventory_itemssql)
  - [8. dim_inventory_levels](#8-dim_inventory_levelssql)
  - [9. dim_inventory_locations](#9-dim_inventory_locationssql)
  - [10. dim_product_variants](#10-dim_product_variantssql)
  - [11. dim_products](#11-dim_productssql)
  - [12. dim_taxonomy_categories](#12-dim_taxonomy_categoriessql)
- [Facts](#part-2-fact-tables)
  - [1. fact_order_headers](#1-fact_order_headerssql)
  - [2. fact_order_line_items](#2-fact_order_line_itemssql)
  - [3. fact_order_refunds](#3-fact_order_refundssql)
  - [4. fact_order_refund_line_items](#4-fact_order_refund_line_itemssql)
  - [5. fact_order_transactions](#5-fact_order_transactionssql)
  - [6. fact_tender_transactions](#6-fact_tender_transactionssql)
  - [7. fact_cash_drawers](#7-fact_cash_drawerssql)
  - [8. fact_disputes](#8-fact_disputessql)
  - [9. fact_gift_card_transactions](#9-fact_gift_card_transactionssql)
  - [10. fact_payouts](#10-fact_payoutssql)

---

# Part 1: Dimension Tables

---

### 1. `dim_collection_products.sql`

- **Path**: `models/dimensions/dim_collection_products.sql`
- **Materialization**: `incremental` (`unique_key: ['collection_id']`)
- **Source**: `raw_collections` unnested over `products.nodes`
- **Indexes**: `collection_id`, `(collection_id, product_id)`, `loaded_at desc`

| Column Name     | Data Type     | Source Expression / JSON Path      | Notes / Description                                                   |
| :-------------- | :------------ | :--------------------------------- | :-------------------------------------------------------------------- |
| `seller_id`     | `VARCHAR`     | `b.seller_id`                      | Shop/seller identifier                                                |
| `collection_id` | `VARCHAR`     | `b.collection_id`                  | Collection identifier                                                 |
| `product_id`    | `TEXT`        | `clean_string(p.value #>> '{id}')` | Product identifier                                                    |
| `loaded_at`     | `TIMESTAMPTZ` | `b.loaded_at`                      | Timestamp record was loaded                                           |
| `record_status` | `VARCHAR`     | `b.record_status`                  | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 2. `dim_collections.sql`

- **Path**: `models/dimensions/dim_collections.sql`
- **Materialization**: `incremental` (`unique_key: ['seller_id', 'id']`)
- **Source**: `raw_collections`
- **Indexes**: `(seller_id, id)`, `loaded_at desc`

| Column Name     | Data Type     | Source Expression / JSON Path                         | Notes / Description                                                   |
| :-------------- | :------------ | :---------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`            | `VARCHAR`     | `rc.id`                                               | Collection ID                                                         |
| `seller_id`     | `VARCHAR`     | `rc.shop_id`                                          | Shop/seller identifier                                                |
| `title`         | `TEXT`        | `clean_string(rc.jsonb_doc #>> '{title}')`            | Collection title                                                      |
| `description`   | `TEXT`        | `clean_string(rc.jsonb_doc #>> '{description}')`      | Description text                                                      |
| `products`      | `JSONB`       | `rc.jsonb_doc #> '{products, nodes}'`                 | Raw array of product nodes                                            |
| `updated_at`    | `TIMESTAMP`   | `safe_cast_timestamp(rc.jsonb_doc #>> '{updatedAt}')` | Update timestamp                                                      |
| `loaded_at`     | `TIMESTAMPTZ` | `rc.loaded_at`                                        | Timestamp record was loaded                                           |
| `record_status` | `VARCHAR`     | `rc.status`                                           | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 3. `dim_customer_addresses.sql`

- **Path**: `models/dimensions/dim_customer_addresses.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `raw_customers` unnested over `addressesV2.nodes`
- **Indexes**: `id`, `(customer_id, id)`, `loaded_at desc`

| Column Name             | Data Type     | Source Expression / JSON Path                             | Notes / Description                                                   |
| :---------------------- | :------------ | :-------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`                    | `TEXT`        | `clean_string(a.value #>> '{id}')`                        | Address ID                                                            |
| `seller_id`             | `VARCHAR`     | `b.seller_id`                                             | Shop/seller identifier                                                |
| `customer_id`           | `VARCHAR`     | `b.customer_id`                                           | Customer ID                                                           |
| `title`                 | `TEXT`        | `clean_string(a.value #>> '{name}')`                      | Full name / address title                                             |
| `address1`              | `TEXT`        | `clean_string(a.value #>> '{address1}')`                  | Street address line 1                                                 |
| `address2`              | `TEXT`        | `clean_string(a.value #>> '{address2}')`                  | Street address line 2                                                 |
| `city`                  | `TEXT`        | `clean_string(a.value #>> '{city}')`                      | City name                                                             |
| `company`               | `TEXT`        | `clean_string(a.value #>> '{company}')`                   | Company name                                                          |
| `coordinates_validated` | `BOOLEAN`     | `safe_cast_boolean(a.value #>> '{coordinatesValidated}')` | Geo validation status                                                 |
| `country`               | `TEXT`        | `clean_string(a.value #>> '{country}')`                   | Country name                                                          |
| `province`              | `TEXT`        | `clean_string(a.value #>> '{province}')`                  | State / Province                                                      |
| `phone`                 | `TEXT`        | `clean_string(a.value #>> '{phone}')`                     | Contact phone number                                                  |
| `zip`                   | `TEXT`        | `clean_string(a.value #>> '{zip}')`                       | Postal / Zip code                                                     |
| `loaded_at`             | `TIMESTAMPTZ` | `b.loaded_at`                                             | Timestamp record was loaded                                           |
| `record_status`         | `VARCHAR`     | `b.record_status`                                         | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 4. `dim_customers.sql`

- **Path**: `models/dimensions/dim_customers.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `raw_customers`
- **Indexes**: `email`, `(seller_id, id)`, `id`, `loaded_at desc`

| Column Name                   | Data Type     | Source Expression / JSON Path                                          | Notes / Description                                                   |
| :---------------------------- | :------------ | :--------------------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`                          | `VARCHAR`     | `rc.id`                                                                | Customer identifier                                                   |
| `seller_id`                   | `VARCHAR`     | `rc.shop_id`                                                           | Shop/seller identifier                                                |
| `first_name`                  | `TEXT`        | `clean_string(rc.jsonb_doc #>> '{firstName}')`                         | Customer first name                                                   |
| `last_name`                   | `TEXT`        | `clean_string(rc.jsonb_doc #>> '{lastName}')`                          | Customer last name                                                    |
| `email`                       | `TEXT`        | `clean_string(rc.jsonb_doc #>> '{defaultEmailAddress, emailAddress}')` | Default email address                                                 |
| `default_address_id`          | `TEXT`        | `rc.jsonb_doc #>> '{defaultAddress, id}'`                              | Default address identifier                                            |
| `amount_spent`                | `NUMERIC`     | `safe_cast_numeric(rc.jsonb_doc #>> '{amountSpent, amount}')`          | Total amount spent                                                    |
| `number_of_orders`            | `INTEGER`     | `safe_cast_int(rc.jsonb_doc #>> '{numberOfOrders}')`                   | Order count                                                           |
| `state`                       | `TEXT`        | `clean_string(rc.jsonb_doc #>> '{state}')`                             | Customer account state                                                |
| `taxexempt`                   | `BOOLEAN`     | `safe_cast_boolean(rc.jsonb_doc #>> '{taxExempt}')`                    | Tax exemption flag                                                    |
| `taxexemptions`               | `JSONB`       | `rc.jsonb_doc #> '{taxExemptions}'`                                    | Tax exemptions JSON list                                              |
| `last_ordered_date`           | `TIMESTAMP`   | `safe_cast_timestamp(rc.jsonb_doc #>> '{lastOrder, createdAt}')`       | Created timestamp of the last order                                   |
| `last_order_financial_status` | `TEXT`        | `clean_string(rc.jsonb_doc #>> '{lastOrder, displayFinancialStatus}')` | Financial status of the last order                                    |
| `created_at`                  | `TIMESTAMP`   | `safe_cast_timestamp(rc.jsonb_doc #>> '{createdAt}')`                  | Creation timestamp                                                    |
| `updated_at`                  | `TIMESTAMP`   | `safe_cast_timestamp(rc.jsonb_doc #>> '{updatedAt}')`                  | Update timestamp                                                      |
| `loaded_at`                   | `TIMESTAMPTZ` | `rc.loaded_at`                                                         | Timestamp record was loaded                                           |
| `record_status`               | `VARCHAR`     | `rc.status`                                                            | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 5. `dim_fulfillment_orders.sql`

- **Path**: `models/dimensions/dim_fulfillment_orders.sql`
- **Materialization**: `incremental` (`unique_key: ['fo_id']`)
- **Source**: `raw_fulfillment_orders`
- **Indexes**: `fo_id`, `(seller_id, fo_id)`, `order_id`, `(order_id, seller_id)`, `loaded_at desc`

| Column Name              | Data Type     | Source Expression / JSON Path                                                    | Notes / Description                                                   |
| :----------------------- | :------------ | :------------------------------------------------------------------------------- | :-------------------------------------------------------------------- |
| `fo_id`                  | `VARCHAR`     | `rfo.id`                                                                         | Fulfillment order identifier                                          |
| `seller_id`              | `VARCHAR`     | `rfo.shop_id`                                                                    | Shop/seller identifier                                                |
| `order_id`               | `TEXT`        | `clean_string(rfo.jsonb_doc #>> '{orderId}')`                                    | Associated order identifier                                           |
| `status`                 | `TEXT`        | `clean_string(rfo.jsonb_doc #>> '{status}')`                                     | Fulfillment status                                                    |
| `requeststatus`          | `TEXT`        | `clean_string(rfo.jsonb_doc #>> '{requestStatus}')`                              | Request status                                                        |
| `delivery_method_type`   | `TEXT`        | `clean_string(rfo.jsonb_doc #>> '{deliveryMethod, methodType}')`                 | Delivery method                                                       |
| `max_delivery_date_time` | `TIMESTAMP`   | `safe_cast_timestamp(rfo.jsonb_doc #>> '{deliveryMethod, maxDeliveryDateTime}')` | Max delivery datetime                                                 |
| `created_at`             | `TIMESTAMP`   | `safe_cast_timestamp(rfo.jsonb_doc #>> '{createdAt}')`                           | Creation timestamp                                                    |
| `fulfill_at`             | `TIMESTAMP`   | `safe_cast_timestamp(rfo.jsonb_doc #>> '{fulfillAt}')`                           | Scheduled fulfillment time                                            |
| `updated_at`             | `TIMESTAMP`   | `safe_cast_timestamp(rfo.jsonb_doc #>> '{updatedAt}')`                           | Update timestamp                                                      |
| `loaded_at`              | `TIMESTAMPTZ` | `rfo.loaded_at`                                                                  | Timestamp record was loaded                                           |
| `record_status`          | `VARCHAR`     | `rfo.status`                                                                     | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 6. `dim_gift_cards.sql`

- **Path**: `models/dimensions/dim_gift_cards.sql`
- **Materialization**: `table`
- **Source**: `stg_giftcards` JOIN `raw_gift_cards`
- **Indexes**: `id`

| Column Name       | Data Type     | Source Expression / JSON Path                                   | Notes / Description                                                   |
| :---------------- | :------------ | :-------------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`              | `VARCHAR`     | `sgc.id`                                                        | Gift card identifier                                                  |
| `seller_id`       | `VARCHAR`     | `sgc.seller_id`                                                 | Shop/seller identifier                                                |
| `initialvalue`    | `NUMERIC`     | `safe_cast_numeric(rgc.jsonb_doc #>> '{initialValue, amount}')` | Initial card balance                                                  |
| `balance`         | `NUMERIC`     | `safe_cast_numeric(rgc.jsonb_doc #>> '{balance, amount}')`      | Current card balance                                                  |
| `customer_id`     | `TEXT`        | `clean_string(rgc.jsonb_doc #>> '{customer, id}')`              | Associated customer ID                                                |
| `order_id`        | `TEXT`        | `clean_string(rgc.jsonb_doc #>> '{order, id}')`                 | Associated order ID                                                   |
| `enabled`         | `BOOLEAN`     | `safe_cast_boolean(rgc.jsonb_doc #>> '{enabled}')`              | Card active status                                                    |
| `masked_code`     | `TEXT`        | `clean_string(rgc.jsonb_doc #>> '{maskedCode}')`                | Masked card code                                                      |
| `last_characters` | `TEXT`        | `clean_string(rgc.jsonb_doc #>> '{lastCharacters}')`            | Last card characters                                                  |
| `deactivated_at`  | `TIMESTAMP`   | `safe_cast_timestamp(rgc.jsonb_doc #>> '{deactivatedAt}')`      | Deactivation timestamp                                                |
| `expires_on`      | `TIMESTAMP`   | `safe_cast_timestamp(rgc.jsonb_doc #>> '{expiresOn}')`          | Expiration date                                                       |
| `created_at`      | `TIMESTAMP`   | `safe_cast_timestamp(rgc.jsonb_doc #>> '{createdAt}')`          | Creation timestamp                                                    |
| `updated_at`      | `TIMESTAMP`   | `safe_cast_timestamp(rgc.jsonb_doc #>> '{updatedAt}')`          | Update timestamp                                                      |
| `record_status`   | `VARCHAR`     | `sgc.record_status`                                             | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |
| `loaded_at`       | `TIMESTAMPTZ` | `sgc.loaded_at`                                                 | Timestamp record was loaded                                           |

---

### 7. `dim_inventory_items.sql`

- **Path**: `models/dimensions/dim_inventory_items.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `stg_inventory_items` JOIN `raw_inventory_items`
- **Indexes**: `id`, `(seller_id, id)`, `loaded_at desc`

| Column Name               | Data Type     | Source Expression / JSON Path                               | Notes / Description                                                   |
| :------------------------ | :------------ | :---------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`                      | `VARCHAR`     | `sii.id`                                                    | Inventory item identifier                                             |
| `seller_id`               | `VARCHAR`     | `sii.seller_id`                                             | Shop/seller identifier                                                |
| `province_code_of_origin` | `TEXT`        | `clean_string(rii.jsonb_doc #>> '{provinceCodeOfOrigin}')`  | Province of origin                                                    |
| `country_code_of_origin`  | `TEXT`        | `clean_string(rii.jsonb_doc #>> '{countryCodeOfOrigin}')`   | Country of origin                                                     |
| `sku`                     | `TEXT`        | `clean_string(rii.jsonb_doc #>> '{sku}')`                   | SKU identifier                                                        |
| `unit_cost`               | `NUMERIC`     | `safe_cast_numeric(rii.jsonb_doc #>> '{unitCost, amount}')` | Unit cost amount                                                      |
| `created_at`              | `TIMESTAMP`   | `safe_cast_timestamp(rii.jsonb_doc #>> '{createdAt}')`      | Creation timestamp                                                    |
| `updated_at`              | `TIMESTAMP`   | `safe_cast_timestamp(rii.jsonb_doc #>> '{updatedAt}')`      | Update timestamp                                                      |
| `loaded_at`               | `TIMESTAMPTZ` | `sii.loaded_at`                                             | Timestamp record was loaded                                           |
| `record_status`           | `VARCHAR`     | `sii.record_status`                                         | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 8. `dim_inventory_levels.sql`

- **Path**: `models/dimensions/dim_inventory_levels.sql`
- **Materialization**: `incremental` (`unique_key: ['id', 'inventory_item_id']`)
- **Source**: Union of `stg_inventory_items` + `raw_inventory_levels`, unnested over `inventory_levels`
- **Indexes**: `id`, `(id, inventory_item_id)`, `(seller_id, inventory_item_id)`, `loaded_at desc`

| Column Name                | Data Type     | Source Expression / JSON Path                                         | Notes / Description                                                   |
| :------------------------- | :------------ | :-------------------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`                       | `TEXT`        | `il.value #>> '{id}'`                                                 | Inventory level identifier                                            |
| `seller_id`                | `VARCHAR`     | `ile.seller_id`                                                       | Shop/seller identifier                                                |
| `inventory_location_id`    | `TEXT`        | `il.value #>> '{location, id}'`                                       | Inventory location identifier                                         |
| `inventory_item_id`        | `VARCHAR`     | `ile.inventory_item_id`                                               | Inventory item identifier                                             |
| `incoming_quantity`        | `INTEGER`     | `get_quantity_by_name(il.value #> '{quantities}', 'incoming')`        | Incoming quantity                                                     |
| `on_hand_quantity`         | `INTEGER`     | `get_quantity_by_name(il.value #> '{quantities}', 'on_hand')`         | On hand quantity                                                      |
| `available_quantity`       | `INTEGER`     | `get_quantity_by_name(il.value #> '{quantities}', 'available')`       | Available quantity                                                    |
| `committed_quantity`       | `INTEGER`     | `get_quantity_by_name(il.value #> '{quantities}', 'committed')`       | Committed quantity                                                    |
| `reserved_quantity`        | `INTEGER`     | `get_quantity_by_name(il.value #> '{quantities}', 'reserved')`        | Reserved quantity                                                     |
| `damaged_quantity`         | `INTEGER`     | `get_quantity_by_name(il.value #> '{quantities}', 'damaged')`         | Damaged quantity                                                      |
| `safety_stock_quantity`    | `INTEGER`     | `get_quantity_by_name(il.value #> '{quantities}', 'safety_stock')`    | Safety stock quantity                                                 |
| `quality_control_quantity` | `INTEGER`     | `get_quantity_by_name(il.value #> '{quantities}', 'quality_control')` | QC quantity                                                           |
| `is_active`                | `BOOLEAN`     | `safe_cast_boolean(il.value #>> '{isActive}')`                        | Active status flag                                                    |
| `created_at`               | `TIMESTAMP`   | `safe_cast_timestamp(il.value #>> '{createdAt}')`                     | Creation timestamp                                                    |
| `updated_at`               | `TIMESTAMP`   | `safe_cast_timestamp(il.value #>> '{updatedAt}')`                     | Update timestamp                                                      |
| `loaded_at`                | `TIMESTAMPTZ` | `ile.loaded_at`                                                       | Timestamp record was loaded                                           |
| `record_status`            | `VARCHAR`     | `ile.record_status`                                                   | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 9. `dim_inventory_locations.sql`

- **Path**: `models/dimensions/dim_inventory_locations.sql`
- **Materialization**: `table`
- **Source**: `raw_inventory_locations`
- **Indexes**: `id`

| Column Name              | Data Type     | Source Expression / JSON Path                                   | Notes / Description                                                   |
| :----------------------- | :------------ | :-------------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`                     | `VARCHAR`     | `ril.id`                                                        | Location identifier                                                   |
| `seller_id`              | `VARCHAR`     | `ril.shop_id`                                                   | Shop/seller identifier                                                |
| `address`                | `JSONB`       | `ril.jsonb_doc #> '{address}'`                                  | Location address JSON                                                 |
| `fulfills_online_orders` | `BOOLEAN`     | `safe_cast_boolean(ril.jsonb_doc #>> '{fulfillsOnlineOrders}')` | Online orders capability                                              |
| `has_active_inventory`   | `BOOLEAN`     | `safe_cast_boolean(ril.jsonb_doc #>> '{hasActiveInventory}')`   | Active inventory flag                                                 |
| `has_unfulfilled_orders` | `BOOLEAN`     | `safe_cast_boolean(ril.jsonb_doc #>> '{hasUnfulfilledOrders}')` | Unfulfilled orders flag                                               |
| `is_active`              | `BOOLEAN`     | `safe_cast_boolean(ril.jsonb_doc #>> '{isActive}')`             | Location active flag                                                  |
| `is_fulfillment_service` | `BOOLEAN`     | `safe_cast_boolean(ril.jsonb_doc #>> '{isFulfillmentService}')` | Fulfillment service flag                                              |
| `name`                   | `TEXT`        | `clean_string(ril.jsonb_doc #>> '{name}')`                      | Location name                                                         |
| `created_at`             | `TIMESTAMP`   | `safe_cast_timestamp(ril.jsonb_doc #>> '{createdAt}')`          | Creation timestamp                                                    |
| `updated_at`             | `TIMESTAMP`   | `safe_cast_timestamp(ril.jsonb_doc #>> '{updatedAt}')`          | Update timestamp                                                      |
| `deactivated_at`         | `TIMESTAMP`   | `safe_cast_timestamp(ril.jsonb_doc #>> '{deactivatedAt}')`      | Deactivation timestamp                                                |
| `record_status`          | `VARCHAR`     | `ril.status`                                                    | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |
| `loaded_at`              | `TIMESTAMPTZ` | `ril.loaded_at`                                                 | Timestamp record was loaded                                           |

---

### 10. `dim_product_variants.sql`

- **Path**: `models/dimensions/dim_product_variants.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `raw_product_variants`
- **Indexes**: `id`, `(seller_id, id)`, `product_id`, `inventory_item_id`, `loaded_at desc`

| Column Name          | Data Type     | Source Expression / JSON Path                            | Notes / Description                                                   |
| :------------------- | :------------ | :------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`                 | `VARCHAR`     | `rpv.id`                                                 | Product variant identifier                                            |
| `seller_id`          | `VARCHAR`     | `rpv.shop_id`                                            | Shop/seller identifier                                                |
| `product_id`         | `TEXT`        | `clean_string(rpv.jsonb_doc #>> '{product, id}')`        | Associated product ID                                                 |
| `inventory_item_id`  | `TEXT`        | `clean_string(rpv.jsonb_doc #>> '{inventoryItem, id}')`  | Associated inventory item ID                                          |
| `inventory_quantity` | `INTEGER`     | `safe_cast_int(rpv.jsonb_doc #>> '{inventoryQuantity}')` | Available inventory count                                             |
| `price`              | `NUMERIC`     | `safe_cast_numeric(rpv.jsonb_doc #>> '{price}')`         | Variant price                                                         |
| `sku`                | `TEXT`        | `clean_string(rpv.jsonb_doc #>> '{sku}')`                | Variant SKU code                                                      |
| `variant_title`      | `TEXT`        | `clean_string(rpv.jsonb_doc #>> '{title}')`              | Variant title                                                         |
| `taxable`            | `BOOLEAN`     | `safe_cast_boolean(rpv.jsonb_doc #>> '{taxable}')`       | Taxable indicator                                                     |
| `created_at`         | `TIMESTAMP`   | `safe_cast_timestamp(rpv.jsonb_doc #>> '{createdAt}')`   | Creation timestamp                                                    |
| `updated_at`         | `TIMESTAMP`   | `safe_cast_timestamp(rpv.jsonb_doc #>> '{updatedAt}')`   | Update timestamp                                                      |
| `loaded_at`          | `TIMESTAMPTZ` | `rpv.loaded_at`                                          | Timestamp record was loaded                                           |
| `record_status`      | `VARCHAR`     | `rpv.status`                                             | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 11. `dim_products.sql`

- **Path**: `models/dimensions/dim_products.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `raw_products`
- **Indexes**: `id`, `(seller_id, id)`, `category_id`, `loaded_at desc`

| Column Name       | Data Type     | Source Expression / JSON Path                           | Notes / Description                                                   |
| :---------------- | :------------ | :------------------------------------------------------ | :-------------------------------------------------------------------- |
| `id`              | `VARCHAR`     | `rp.id`                                                 | Product identifier                                                    |
| `seller_id`       | `VARCHAR`     | `rp.shop_id`                                            | Shop/seller identifier                                                |
| `category_id`     | `TEXT`        | `clean_string(rp.jsonb_doc #>> '{category, id}')`       | Taxonomy category identifier                                          |
| `title`           | `TEXT`        | `clean_string(rp.jsonb_doc #>> '{title}')`              | Product title                                                         |
| `description`     | `TEXT`        | `clean_string(rp.jsonb_doc #>> '{description}')`        | Product description                                                   |
| `is_gift_card`    | `BOOLEAN`     | `safe_cast_boolean(rp.jsonb_doc #>> '{isGiftCard}')`    | Gift card flag                                                        |
| `product_type`    | `TEXT`        | `clean_string(rp.jsonb_doc #>> '{productType}')`        | Product type / category text                                          |
| `status`          | `TEXT`        | `clean_string(rp.jsonb_doc #>> '{status}')`             | Product catalog status                                                |
| `total_inventory` | `INTEGER`     | `safe_cast_int(rp.jsonb_doc #>> '{totalInventory}')`    | Total aggregated inventory                                            |
| `vendor`          | `TEXT`        | `clean_string(rp.jsonb_doc #>> '{vendor}')`             | Product vendor / brand                                                |
| `created_at`      | `TIMESTAMP`   | `safe_cast_timestamp(rp.jsonb_doc #>> '{createdAt}')`   | Creation timestamp                                                    |
| `published_at`    | `TIMESTAMP`   | `safe_cast_timestamp(rp.jsonb_doc #>> '{publishedAt}')` | Published timestamp                                                   |
| `updated_at`      | `TIMESTAMP`   | `safe_cast_timestamp(rp.jsonb_doc #>> '{updatedAt}')`   | Update timestamp                                                      |
| `loaded_at`       | `TIMESTAMPTZ` | `rp.loaded_at`                                          | Timestamp record was loaded                                           |
| `record_status`   | `VARCHAR`     | `rp.status`                                             | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 12. `dim_taxonomy_categories.sql`

- **Path**: `models/dimensions/dim_taxonomy_categories.sql`
- **Materialization**: `table`
- **Source**: `raw_taxonomy`
- **Indexes**: `id`

| Column Name     | Data Type     | Source Expression / JSON Path                        | Notes / Description                                                   |
| :-------------- | :------------ | :--------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`            | `VARCHAR`     | `rt.id`                                              | Category identifier                                                   |
| `seller_id`     | `VARCHAR`     | `rt.shop_id`                                         | Shop/seller identifier                                                |
| `name`          | `TEXT`        | `clean_string(rt.jsonb_doc #>> '{name}')`            | Category name                                                         |
| `is_archived`   | `BOOLEAN`     | `safe_cast_boolean(rt.jsonb_doc #>> '{isArchived}')` | Category archived flag                                                |
| `is_root`       | `BOOLEAN`     | `safe_cast_boolean(rt.jsonb_doc #>> '{isRoot}')`     | Root category flag                                                    |
| `parent_id`     | `TEXT`        | `clean_string(rt.jsonb_doc #>> '{parentId}')`        | Parent category identifier                                            |
| `record_status` | `VARCHAR`     | `rt.status`                                          | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |
| `loaded_at`     | `TIMESTAMPTZ` | `rt.loaded_at`                                       | Timestamp record was loaded                                           |

---

# Part 2: Fact Tables

---

### 1. `fact_order_headers.sql`

- **Path**: `models/facts/fact_order_headers.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `stg_orders` JOIN `raw_orders`
- **Indexes**: `id`, `(seller_id, id)`, `loaded_at desc`

| Column Name                           | Data Type     | Source Expression / JSON Path                                                               | Notes / Description                                                   |
| :------------------------------------ | :------------ | :------------------------------------------------------------------------------------------ | :-------------------------------------------------------------------- |
| `id`                                  | `VARCHAR`     | `so.id`                                                                                     | Order identifier                                                      |
| `seller_id`                           | `VARCHAR`     | `so.seller_id`                                                                              | Shop/seller identifier                                                |
| `customer_id`                         | `TEXT`        | `ro.jsonb_doc #>> '{customer, id}'`                                                         | Customer identifier                                                   |
| `attribution_handle`                  | `TEXT`        | `clean_string(ro.jsonb_doc #>> '{attribution, handle}')`                                    | Attribution handle                                                    |
| `attribution_displayname`             | `TEXT`        | `clean_string(ro.jsonb_doc #>> '{attribution, displayName}')`                               | Attribution display name                                              |
| `currency_code`                       | `TEXT`        | `clean_string(ro.jsonb_doc #>> '{presentmentCurrencyCode}')`                                | Presentment currency code                                             |
| `cart_discount_amount`                | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{cartDiscountAmountSet, shopMoney, amount}')`          | Cart discount amount                                                  |
| `current_cart_discount_amount`        | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{currentCartDiscountAmountSet, shopMoney, amount}')`   | Current cart discount amount                                          |
| `current_shipping_price`              | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{currentShippingPriceSet, shopMoney, amount}')`        | Current shipping price                                                |
| `current_subtotal_lineitems_quantity` | `INTEGER`     | `safe_cast_int(ro.jsonb_doc #>> '{currentSubtotalLineItemsQuantity}')`                      | Current subtotal quantity                                             |
| `current_subtotal_price`              | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{currentSubtotalPriceSet, shopMoney, amount}')`        | Current subtotal price                                                |
| `current_total_additional_fees`       | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalAdditionalFeesSet, shopMoney, amount}')`  | Current total additional fees                                         |
| `current_total_discounts`             | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalDiscountsSet, shopMoney, amount}')`       | Current total discounts                                               |
| `current_total_duties`                | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalDutiesSet, shopMoney, amount}')`          | Current total duties                                                  |
| `current_total_price`                 | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalPriceSet, shopMoney, amount}')`           | Current total price                                                   |
| `current_total_tax`                   | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalTaxSet, shopMoney, amount}')`             | Current total tax                                                     |
| `current_total_weight`                | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{currentTotalWeight}')`                                | Current total order weight                                            |
| `discountcode`                        | `JSONB`       | `ro.jsonb_doc #> '{discountCodes}'`                                                         | Array of applied discount codes                                       |
| `duties_included`                     | `BOOLEAN`     | `safe_cast_boolean(ro.jsonb_doc #>> '{dutiesIncluded}')`                                    | Flag if duties are included                                           |
| `fullypaid`                           | `BOOLEAN`     | `safe_cast_boolean(ro.jsonb_doc #>> '{fullyPaid}')`                                         | Flag if order is fully paid                                           |
| `net_payment`                         | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{netPaymentSet, shopMoney, amount}')`                  | Net payment amount                                                    |
| `original_total_additional_fees`      | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{originalTotalAdditionalFeesSet, shopMoney, amount}')` | Original additional fees                                              |
| `original_total_duties`               | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{originalTotalDutiesSet, shopMoney, amount}')`         | Original duties total                                                 |
| `original_total_price`                | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{originalTotalPriceSet, shopMoney, amount}')`          | Original order total                                                  |
| `test`                                | `BOOLEAN`     | `safe_cast_boolean(ro.jsonb_doc #>> '{test}')`                                              | Flag for test order                                                   |
| `source_identifier`                   | `TEXT`        | `clean_string(ro.jsonb_doc #>> '{sourceIdentifier}')`                                       | Source system identifier                                              |
| `source_name`                         | `TEXT`        | `clean_string(ro.jsonb_doc #>> '{sourceName}')`                                             | Source channel name                                                   |
| `subtotal_line_items_quantity`        | `INTEGER`     | `safe_cast_int(ro.jsonb_doc #>> '{subtotalLineItemsQuantity}')`                             | Line items quantity sum                                               |
| `subtotal_price`                      | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{subtotalPriceSet, shopMoney, amount}')`               | Order subtotal price                                                  |
| `taxes_included`                      | `BOOLEAN`     | `safe_cast_boolean(ro.jsonb_doc #>> '{taxesIncluded}')`                                     | Flag if taxes are included                                            |
| `tax_exempt`                          | `BOOLEAN`     | `safe_cast_boolean(ro.jsonb_doc #>> '{taxExempt}')`                                         | Flag if order is tax exempt                                           |
| `total_capturable_amount`             | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{totalCapturableSet, shopMoney, amount}')`             | Total capturable amount                                               |
| `total_discounts_amount`              | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{totalDiscountsSet, shopMoney, amount}')`              | Total discount amount                                                 |
| `total_outstanding_amount`            | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{totalOutstandingSet, shopMoney, amount}')`            | Total outstanding amount                                              |
| `total_price`                         | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{totalPriceSet, shopMoney, amount}')`                  | Total price                                                           |
| `total_received_amount`               | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{totalReceivedSet, shopMoney, amount}')`               | Total received amount                                                 |
| `total_refunded_amount`               | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{totalRefundedSet, shopMoney, amount}')`               | Total refunded amount                                                 |
| `total_refunded_shipping_amount`      | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{totalRefundedShippingSet, shopMoney, amount}')`       | Refunded shipping amount                                              |
| `total_shipping_price`                | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{totalShippingPriceSet, shopMoney, amount}')`          | Total shipping charges                                                |
| `total_tax`                           | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{totalTaxSet, shopMoney, amount}')`                    | Total tax charged                                                     |
| `total_tip_received`                  | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{totalTipReceivedSet, shopMoney, amount}')`            | Tip amount received                                                   |
| `total_weight`                        | `NUMERIC`     | `safe_cast_numeric(ro.jsonb_doc #>> '{totalWeight}')`                                       | Total order weight                                                    |
| `unpaid`                              | `BOOLEAN`     | `safe_cast_boolean(ro.jsonb_doc #>> '{unpaid}')`                                            | Flag if order is unpaid                                               |
| `payment_gateway_names`               | `JSONB`       | `ro.jsonb_doc #> '{paymentGatewayNames}'`                                                   | List of payment gateways                                              |
| `order_app_id`                        | `TEXT`        | `ro.jsonb_doc #>> '{app, id}'`                                                              | App identifier                                                        |
| `order_app_name`                      | `TEXT`        | `clean_string(ro.jsonb_doc #>> '{app, name}')`                                              | App name                                                              |
| `billing_address`                     | `JSONB`       | `ro.jsonb_doc #> '{billingAddress}'`                                                        | Billing address JSON                                                  |
| `shipping_address`                    | `JSONB`       | `ro.jsonb_doc #> '{shippingAddress}'`                                                       | Shipping address JSON                                                 |
| `customer_journey_summary`            | `JSONB`       | `ro.jsonb_doc #> '{customerJourneySummary}'`                                                | Customer journey JSON (first/last visit, referrer, UTM)               |
| `financialstatus`                     | `TEXT`        | `clean_string(ro.jsonb_doc #>> '{displayFinancialStatus}')`                                 | Financial status                                                      |
| `fulfillmentstatus`                   | `TEXT`        | `clean_string(ro.jsonb_doc #>> '{displayFulfillmentStatus}')`                               | Fulfillment status                                                    |
| `created_at`                          | `TIMESTAMP`   | `safe_cast_timestamp(ro.jsonb_doc #>> '{createdAt}')`                                       | Order creation timestamp                                              |
| `updated_at`                          | `TIMESTAMP`   | `safe_cast_timestamp(ro.jsonb_doc #>> '{updatedAt}')`                                       | Order update timestamp                                                |
| `processed_at`                        | `TIMESTAMP`   | `safe_cast_timestamp(ro.jsonb_doc #>> '{processedAt}')`                                     | Processed timestamp                                                   |
| `cancelled_at`                        | `TIMESTAMP`   | `safe_cast_timestamp(ro.jsonb_doc #>> '{cancelledAt}')`                                     | Cancellation timestamp                                                |
| `closed`                              | `BOOLEAN`     | `safe_cast_boolean(ro.jsonb_doc #>> '{closed}')`                                            | Flag if closed                                                        |
| `closed_at`                           | `TIMESTAMP`   | `safe_cast_timestamp(ro.jsonb_doc #>> '{closedAt}')`                                        | Closed timestamp                                                      |
| `confirmed`                           | `BOOLEAN`     | `safe_cast_boolean(ro.jsonb_doc #>> '{confirmed}')`                                         | Confirmation flag                                                     |
| `loaded_at`                           | `TIMESTAMPTZ` | `so.loaded_at`                                                                              | Timestamp record was loaded                                           |
| `record_status`                       | `VARCHAR`     | `so.record_status`                                                                          | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 2. `fact_order_line_items.sql`

- **Path**: `models/facts/fact_order_line_items.sql`
- **Materialization**: `incremental` (`unique_key: ['id', 'order_id']`)
- **Source**: Union of `stg_orders` + `raw_order_lineitems`, unnested over `line_items`
- **Indexes**: `id`, `(order_id, id)`, `(seller_id, order_id)`, `loaded_at desc`

| Column Name                                 | Data Type     | Source Expression / JSON Path                                                                    | Notes / Description                                                   |
| :------------------------------------------ | :------------ | :----------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`                                        | `TEXT`        | `li.value #>> '{id}'`                                                                            | Line item identifier                                                  |
| `order_id`                                  | `VARCHAR`     | `lie.order_id`                                                                                   | Order identifier                                                      |
| `seller_id`                                 | `VARCHAR`     | `lie.seller_id`                                                                                  | Shop/seller identifier                                                |
| `product_variant_id`                        | `TEXT`        | `li.value #>> '{variant, id}'`                                                                   | Variant identifier                                                    |
| `product_name`                              | `TEXT`        | `clean_string(li.value #>> '{name}')`                                                            | Line item name (product title)                                        |
| `variant_name`                              | `TEXT`        | `clean_string(li.value #>> '{variantTitle}')`                                                    | Variant title                                                         |
| `sku`                                       | `TEXT`        | `clean_string(li.value #>> '{sku}')`                                                             | SKU at time of order                                                  |
| `vendor`                                    | `TEXT`        | `clean_string(li.value #>> '{vendor}')`                                                          | Product vendor                                                        |
| `taxable`                                   | `BOOLEAN`     | `safe_cast_boolean(li.value #>> '{taxable}')`                                                    | Taxable indicator                                                     |
| `requires_shipping`                         | `BOOLEAN`     | `safe_cast_boolean(li.value #>> '{requiresShipping}')`                                           | Requires shipping flag                                                |
| `current_quantity`                          | `INTEGER`     | `safe_cast_int(li.value #>> '{currentQuantity}')`                                                | Current item quantity                                                 |
| `discounted_total_amount`                   | `NUMERIC`     | `safe_cast_numeric(li.value #>> '{discountedTotalSet, shopMoney, amount}')`                      | Discounted total amount                                               |
| `discounted_unit_price_after_all_discounts` | `NUMERIC`     | `safe_cast_numeric(li.value #>> '{discountedUnitPriceAfterAllDiscountsSet, shopMoney, amount}')` | Unit price after all discounts                                        |
| `discounted_unit_price`                     | `NUMERIC`     | `safe_cast_numeric(li.value #>> '{discountedUnitPriceSet, shopMoney, amount}')`                  | Discounted unit price                                                 |
| `is_giftcard`                               | `BOOLEAN`     | `safe_cast_boolean(li.value #>> '{isGiftCard}')`                                                 | Gift card line item flag                                              |
| `original_total_amount`                     | `NUMERIC`     | `safe_cast_numeric(li.value #>> '{originalTotalSet, shopMoney, amount}')`                        | Original total before discount                                        |
| `original_unit_price`                       | `NUMERIC`     | `safe_cast_numeric(li.value #>> '{originalUnitPriceSet, shopMoney, amount}')`                    | Original unit price                                                   |
| `quantity`                                  | `INTEGER`     | `safe_cast_int(li.value #>> '{quantity}')`                                                       | Ordered quantity                                                      |
| `refundable_quantity`                       | `INTEGER`     | `safe_cast_int(li.value #>> '{refundableQuantity}')`                                             | Refundable quantity                                                   |
| `total_discount_amount`                     | `NUMERIC`     | `safe_cast_numeric(li.value #>> '{totalDiscountSet, shopMoney, amount}')`                        | Total line discount amount                                            |
| `unfulfilled_discounted_total_amount`       | `NUMERIC`     | `safe_cast_numeric(li.value #>> '{unfulfilledDiscountedTotalSet, shopMoney, amount}')`           | Unfulfilled discounted total                                          |
| `unfulfilled_original_total_amount`         | `NUMERIC`     | `safe_cast_numeric(li.value #>> '{unfulfilledOriginalTotalSet, shopMoney, amount}')`             | Unfulfilled original total                                            |
| `unfulfilled_quantity`                      | `INTEGER`     | `safe_cast_int(li.value #>> '{unfulfilledQuantity}')`                                            | Unfulfilled quantity                                                  |
| `loaded_at`                                 | `TIMESTAMPTZ` | `lie.loaded_at`                                                                                  | Timestamp record was loaded                                           |
| `record_status`                             | `VARCHAR`     | `lie.record_status`                                                                              | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 3. `fact_order_refunds.sql`

- **Path**: `models/facts/fact_order_refunds.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `stg_order_refunds` (one row per refund node from `raw_orders`)
- **Indexes**: `id`, `(seller_id, order_id)`, `(order_id, id)`, `loaded_at desc`

| Column Name             | Data Type     | Source Expression / JSON Path                                            | Notes / Description                                                   |
| :---------------------- | :------------ | :----------------------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`                    | `TEXT`        | `r.id`                                                                   | Refund identifier                                                     |
| `order_id`              | `VARCHAR`     | `r.order_id`                                                             | Order identifier                                                      |
| `seller_id`             | `VARCHAR`     | `r.seller_id`                                                            | Shop/seller identifier                                                |
| `note`                  | `TEXT`        | `clean_string(r.value #>> '{note}')`                                     | Refund note / reason                                                  |
| `total_refunded_amount` | `NUMERIC`     | `safe_cast_numeric(r.value #>> '{totalRefundedSet, shopMoney, amount}')` | Total refunded amount                                                 |
| `processed_at`          | `TIMESTAMP`   | `safe_cast_timestamp(r.value #>> '{processedAt}')`                       | Processed timestamp                                                   |
| `created_at`            | `TIMESTAMP`   | `safe_cast_timestamp(r.value #>> '{createdAt}')`                         | Creation timestamp                                                    |
| `updated_at`            | `TIMESTAMP`   | `safe_cast_timestamp(r.value #>> '{updatedAt}')`                         | Update timestamp                                                      |
| `loaded_at`             | `TIMESTAMPTZ` | `r.loaded_at`                                                            | Timestamp record was loaded                                           |
| `record_status`         | `VARCHAR`     | `r.record_status`                                                        | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 4. `fact_order_refund_line_items.sql`

- **Path**: `models/facts/fact_order_refund_line_items.sql`
- **Materialization**: `incremental` (`unique_key: ['id', 'refund_id']`)
- **Source**: Union of `stg_order_refunds` + `raw_order_refund_lineitems`, unnested over `refund_line_items`
- **Indexes**: `id`, `(refund_id, id)`, `(seller_id, refund_id)`, `loaded_at desc`

| Column Name              | Data Type     | Source Expression / JSON Path                                        | Notes / Description                                                   |
| :----------------------- | :------------ | :------------------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`                     | `TEXT`        | `rli.value #>> '{id}'`                                               | Refund line item identifier                                           |
| `seller_id`              | `VARCHAR`     | `rlie.seller_id`                                                     | Shop/seller identifier                                                |
| `refund_id`              | `TEXT`        | `rlie.refund_id`                                                     | Refund identifier                                                     |
| `order_line_item_id`     | `TEXT`        | `rli.value #>> '{lineItem, id}'`                                     | Refunded order line item identifier                                   |
| `refund_line_item_price` | `NUMERIC`     | `safe_cast_numeric(rli.value #>> '{priceSet,shopMoney, amount}')`    | Refunded unit price                                                   |
| `refund_sub_total`       | `NUMERIC`     | `safe_cast_numeric(rli.value #>> '{subtotalSet,shopMoney, amount}')` | Refund line subtotal                                                  |
| `refund_total_tax`       | `NUMERIC`     | `safe_cast_numeric(rli.value #>> '{totalTaxSet,shopMoney, amount}')` | Total tax amount                                                      |
| `refund_quantity`        | `INTEGER`     | `safe_cast_int(rli.value #>> '{quantity}')`                          | Refund Quantity                                                       |
| `restock_type`           | `TEXT`        | `clean_string(rli.value #>> '{restockType}')`                        | Restock Type                                                          |
| `loaded_at`              | `TIMESTAMPTZ` | `rlie.loaded_at`                                                     | Timestamp record was loaded                                           |
| `record_status`          | `VARCHAR`     | `rlie.record_status`                                                 | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 5. `fact_order_transactions.sql`

- **Path**: `models/facts/fact_order_transactions.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `stg_orders` unnested over `transactions`
- **Indexes**: `id`, `(seller_id, order_id)`, `(order_id, id)`, `loaded_at desc`

| Column Name                 | Data Type     | Source Expression / JSON Path                                             | Notes / Description                                                   |
| :-------------------------- | :------------ | :------------------------------------------------------------------------ | :-------------------------------------------------------------------- |
| `id`                        | `TEXT`        | `t.value #>> '{id}'`                                                      | Order transaction identifier                                          |
| `order_id`                  | `VARCHAR`     | `b.order_id`                                                              | Order identifier                                                      |
| `seller_id`                 | `VARCHAR`     | `b.seller_id`                                                             | Shop/seller identifier                                                |
| `amount_rounding`           | `NUMERIC`     | `safe_cast_numeric(t.value #>> '{amountRoundingSet, shopMoney, amount}')` | Rounding difference amount                                            |
| `amount`                    | `NUMERIC`     | `safe_cast_numeric(t.value #>> '{amountSet, shopMoney, amount}')`         | Transaction amount                                                    |
| `device_id`                 | `TEXT`        | `t.value #>> '{device, id}'`                                              | POS device identifier                                                 |
| `cashdrawer_name`           | `TEXT`        | `clean_string(t.value #>> '{device, cashDrawer, name}')`                  | POS cash drawer name                                                  |
| `transaction_fee`           | `NUMERIC`     | `safe_cast_numeric(t.value #>> '{fees, amount, amount}')`                 | Payment processing fee                                                |
| `gateway`                   | `TEXT`        | `clean_string(t.value #>> '{gateway}')`                                   | Payment gateway name                                                  |
| `kind`                      | `TEXT`        | `clean_string(t.value #>> '{kind}')`                                      | Transaction kind (e.g. sale, capture, refund)                         |
| `location_id`               | `TEXT`        | `clean_string(t.value #>> '{location, id}')`                              | Location identifier                                                   |
| `manual_payment_gateway`    | `BOOLEAN`     | `safe_cast_boolean(t.value #>> '{manualPaymentGateway}')`                 | Manual gateway flag                                                   |
| `maximum_refundable_amount` | `NUMERIC`     | `safe_cast_numeric(t.value #>> '{maximumRefundableV2, amount}')`          | Max refundable amount                                                 |
| `status`                    | `TEXT`        | `clean_string(t.value #>> '{status}')`                                    | Transaction status                                                    |
| `test`                      | `BOOLEAN`     | `safe_cast_boolean(t.value #>> '{test}')`                                 | Test transaction flag                                                 |
| `created_at`                | `TIMESTAMP`   | `safe_cast_timestamp(t.value #>> '{createdAt}')`                          | Creation timestamp                                                    |
| `processed_at`              | `TIMESTAMP`   | `safe_cast_timestamp(t.value #>> '{processedAt}')`                        | Processed timestamp                                                   |
| `loaded_at`                 | `TIMESTAMPTZ` | `b.loaded_at`                                                             | Timestamp record was loaded                                           |
| `record_status`             | `VARCHAR`     | `b.record_status`                                                         | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 6. `fact_tender_transactions.sql`

- **Path**: `models/facts/fact_tender_transactions.sql`
- **Materialization**: `incremental` (`unique_key: ['id']`)
- **Source**: `raw_tender_transactions`
- **Indexes**: `id`, `(seller_id, id)`, `loaded_at desc`

| Column Name                       | Data Type     | Source Expression / JSON Path                                               | Notes / Description                                                   |
| :-------------------------------- | :------------ | :-------------------------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`                              | `VARCHAR`     | `rtt.id`                                                                    | Tender transaction identifier                                         |
| `seller_id`                       | `VARCHAR`     | `rtt.shop_id`                                                               | Shop/seller identifier                                                |
| `order_id`                        | `TEXT`        | `clean_string(rtt.jsonb_doc #>> '{order, id}')`                             | Associated order ID                                                   |
| `amount`                          | `NUMERIC`     | `safe_cast_numeric(rtt.jsonb_doc #>> '{amount, amount}')`                   | Transaction amount                                                    |
| `payment_method`                  | `TEXT`        | `clean_string(rtt.jsonb_doc #>> '{paymentMethod}')`                         | Payment method description                                            |
| `processed_at`                    | `TIMESTAMP`   | `safe_cast_timestamp(rtt.jsonb_doc #>> '{processedAt}')`                    | Transaction processed timestamp                                       |
| `remote_reference`                | `TEXT`        | `clean_string(rtt.jsonb_doc #>> '{remoteReference}')`                       | Remote payment reference                                              |
| `test`                            | `BOOLEAN`     | `safe_cast_boolean(rtt.jsonb_doc #>> '{test}')`                             | Test transaction flag                                                 |
| `transaction_credit_card_company` | `TEXT`        | `clean_string(rtt.jsonb_doc #>> '{transactionDetails, creditCardCompany}')` | Credit card company name                                              |
| `loaded_at`                       | `TIMESTAMPTZ` | `rtt.loaded_at`                                                             | Timestamp record was loaded                                           |
| `record_status`                   | `VARCHAR`     | `rtt.status`                                                                | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |

---

### 7. `fact_cash_drawers.sql`

- **Path**: `models/facts/fact_cash_drawers.sql`
- **Materialization**: `table`
- **Source**: `raw_cash_drawers`
- **Indexes**: `id`

| Column Name         | Data Type     | Source Expression / JSON Path                                       | Notes / Description                                                   |
| :------------------ | :------------ | :------------------------------------------------------------------ | :-------------------------------------------------------------------- |
| `id`                | `VARCHAR`     | `rcd.id`                                                            | Primary key identifier                                                |
| `seller_id`         | `VARCHAR`     | `rcd.shop_id`                                                       | Shop/seller identifier                                                |
| `location_id`       | `TEXT`        | `rcd.jsonb_doc #>> '{location, id}'`                                | Location identifier                                                   |
| `name`              | `TEXT`        | `clean_string(rcd.jsonb_doc #>> '{name}')`                          | Drawer name                                                           |
| `net_sales`         | `NUMERIC`     | `safe_cast_numeric(rcd.jsonb_doc #>> '{netSales, amount}')`         | Net sales amount                                                      |
| `total_adjustments` | `NUMERIC`     | `safe_cast_numeric(rcd.jsonb_doc #>> '{totalAdjustments, amount}')` | Adjustments total                                                     |
| `total_refunds`     | `NUMERIC`     | `safe_cast_numeric(rcd.jsonb_doc #>> '{totalRefunds, amount}')`     | Refunds total                                                         |
| `total_sales`       | `NUMERIC`     | `safe_cast_numeric(rcd.jsonb_doc #>> '{totalSales, amount}')`       | Sales total                                                           |
| `record_status`     | `VARCHAR`     | `rcd.status`                                                        | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |
| `loaded_at`         | `TIMESTAMPTZ` | `rcd.loaded_at`                                                     | Timestamp record was loaded                                           |

---

### 8. `fact_disputes.sql`

- **Path**: `models/facts/fact_disputes.sql`
- **Materialization**: `table`
- **Source**: `raw_disputes`
- **Indexes**: `id`

| Column Name     | Data Type     | Source Expression / JSON Path                              | Notes / Description                                                   |
| :-------------- | :------------ | :--------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`            | `VARCHAR`     | `id`                                                       | Dispute identifier                                                    |
| `seller_id`     | `VARCHAR`     | `shop_id`                                                  | Shop/seller identifier                                                |
| `amount`        | `NUMERIC`     | `safe_cast_numeric(rd.jsonb_doc #>> '{amount, amount}')`   | Disputed amount                                                       |
| `order_id`      | `TEXT`        | `clean_string(rd.jsonb_doc #>> '{order, id}')`             | Associated order identifier                                           |
| `reason`        | `TEXT`        | `clean_string(rd.jsonb_doc #>> '{reasonDetails, reason}')` | Dispute reason details                                                |
| `status`        | `TEXT`        | `clean_string(rd.jsonb_doc #>> '{status}')`                | Dispute status                                                        |
| `type`          | `TEXT`        | `clean_string(rd.jsonb_doc #>> '{type}')`                  | Dispute type                                                          |
| `initiated_at`  | `TIMESTAMP`   | `safe_cast_timestamp(rd.jsonb_doc #>> '{initiatedAt}')`    | Initiation timestamp                                                  |
| `finalized_on`  | `TIMESTAMP`   | `safe_cast_timestamp(rd.jsonb_doc #>> '{finalizedOn}')`    | Finalization date/timestamp                                           |
| `record_status` | `VARCHAR`     | `rd.status`                                                | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |
| `loaded_at`     | `TIMESTAMPTZ` | `rd.loaded_at`                                             | Timestamp record was loaded                                           |

---

### 9. `fact_gift_card_transactions.sql`

- **Path**: `models/facts/fact_gift_card_transactions.sql`
- **Materialization**: `table`
- **Source**: Union of `stg_giftcards` + `raw_gift_card_transactions`, unnested over `gift_card_transactions`
- **Indexes**: `id`, `(id, gift_card_id)`, `(seller_id, gift_card_id)`

| Column Name     | Data Type     | Source Expression / JSON Path                         | Notes / Description                                                   |
| :-------------- | :------------ | :---------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`            | `TEXT`        | `gct.value #>> '{id}'`                                | Transaction identifier                                                |
| `gift_card_id`  | `VARCHAR`     | `gcte.gift_card_id`                                   | Associated gift card ID                                               |
| `seller_id`     | `VARCHAR`     | `gcte.seller_id`                                      | Shop/seller identifier                                                |
| `amount`        | `NUMERIC`     | `safe_cast_numeric(gct.value #>> '{amount, amount}')` | Transaction amount                                                    |
| `note`          | `TEXT`        | `clean_string(gct.value #>> '{note}')`                | Transaction note                                                      |
| `processed_at`  | `TIMESTAMP`   | `safe_cast_timestamp(gct.value #>> '{processedAt}')`  | Processing timestamp                                                  |
| `record_status` | `VARCHAR`     | `gcte.record_status`                                  | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |
| `loaded_at`     | `TIMESTAMPTZ` | `gcte.loaded_at`                                      | Timestamp record was loaded                                           |

---

### 10. `fact_payouts.sql`

- **Path**: `models/facts/fact_payouts.sql`
- **Materialization**: `table`
- **Source**: `raw_payouts`
- **Indexes**: `id`

| Column Name        | Data Type     | Source Expression / JSON Path                                                                | Notes / Description                                                   |
| :----------------- | :------------ | :------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------- |
| `id`               | `VARCHAR`     | `id`                                                                                         | Payout identifier                                                     |
| `seller_id`        | `VARCHAR`     | `shop_id`                                                                                    | Shop/seller identifier                                                |
| `activated`        | `BOOLEAN`     | `safe_cast_boolean(rp.jsonb_doc #>> '{businessEntity, shopifyPaymentsAccount, activated}')`  | Account activation flag                                               |
| `balance_amount`   | `JSONB`       | `rp.jsonb_doc #> '{businessEntity, shopifyPaymentsAccount, balance}'`                        | Balance info JSON                                                     |
| `country`          | `TEXT`        | `clean_string(rp.jsonb_doc #>> '{businessEntity, shopifyPaymentsAccount, country}')`         | Payout country code                                                   |
| `default_currency` | `TEXT`        | `clean_string(rp.jsonb_doc #>> '{businessEntity, shopifyPaymentsAccount, defaultCurrency}')` | Default currency code                                                 |
| `net`              | `JSONB`       | `rp.jsonb_doc #> '{net}'`                                                                    | Net amount details JSON                                               |
| `summary`          | `JSONB`       | `rp.jsonb_doc #> '{summary}'`                                                                | Summary details JSON                                                  |
| `status`           | `TEXT`        | `clean_string(rp.jsonb_doc #>> '{status}')`                                                  | Payout status                                                         |
| `transactiontype`  | `TEXT`        | `clean_string(rp.jsonb_doc #>> '{transactionType}')`                                         | Type of payout transaction                                            |
| `issued_at`        | `TIMESTAMP`   | `safe_cast_timestamp(rp.jsonb_doc #>> '{issuedAt}')`                                         | Issue date/timestamp                                                  |
| `record_status`    | `VARCHAR`     | `rp.status`                                                                                  | `ACTIVE` / `DELETED` (soft delete); filter `record_status = 'ACTIVE'` |
| `loaded_at`        | `TIMESTAMPTZ` | `rp.loaded_at`                                                                               | Timestamp record was loaded                                           |
