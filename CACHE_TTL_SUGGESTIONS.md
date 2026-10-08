# Vizkit cache_ttl suggestions

## Business Performance Overview

| Name | Type | Suggested TTL (min) | Reason |
|---|---|---|---|
| Total Revenue | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Net Sales | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Average Order Value | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Orders | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Total Customers | KPI | 60 | Customer counts and revenue from orders. Changes with new orders |
| Inventory Value | KPI | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Revenue & Sales Trend | PLOT | 30 | Headline sales number. New orders land with every extractor run |
| Revenue by Category | PLOT | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| Stock Status Mix | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Top Products Performance | PLOT | 30 | Headline sales number. New orders land with every extractor run |

## Executive Store Health

| Name | Type | Suggested TTL (min) | Reason |
|---|---|---|---|
| Net Sales | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Gross Sales | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Orders | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Average Order Value | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Refunded Amount | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Refund Rate | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Discount Leakage | KPI | 120 | Only changes when orders use discounts, which depends on the seller running promotions |
| Low Stock Revenue Risk | KPI | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Outstanding Amount | KPI | 30 | Money still owed or in flight that may need follow-up |
| Gross Margin Estimate | KPI | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Sales Trend | PLOT | 30 | Headline sales number. New orders land with every extractor run |
| Revenue Waterfall | PLOT | 60 | Sales-driven figure. Refunds are only a small part of it |
| Orders vs AOV | PLOT | 30 | Headline sales number. New orders land with every extractor run |
| Discount Impact Trend | PLOT | 120 | Only changes when orders use discounts, which depends on the seller running promotions |
| Refund Trend | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Top Refunded Products | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Stock Value by Location | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Unfulfilled Revenue Risk | PLOT | 30 | Fulfillment backlog that the team works through during the day |
| Fulfillment Status Mix | PLOT | 30 | Fulfillment backlog that the team works through during the day |
| Inventory Risk by Product | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| New vs Repeat Revenue | PLOT | 60 | Customer counts and revenue from orders. Changes with new orders |
| Top Country Segments | PLOT | 360 | Geographic split of sales shifts slowly |
| Sales by Channel | PLOT | 60 | Channel breakdown of sales. The split moves slowly |
| Channel Quality Matrix | TABLE | 60 | Sales-driven figure. Refunds are only a small part of it |
| Payment Method Mix | PLOT | 60 | Payment breakdown. The mix moves slowly |
| Transaction Fee Impact | PLOT | 60 | Fees come with each payment but the rate barely moves |

## Order Reports

| Name | Type | Suggested TTL (min) | Reason |
|---|---|---|---|
| Net Sales | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Gross Sales | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Average Order Value | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Discount Amount | KPI | 120 | Only changes when orders use discounts, which depends on the seller running promotions |
| Refunded Order Value | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Tax Collected | KPI | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| Total Orders | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Fulfilled Orders | KPI | 30 | Fulfillment backlog that the team works through during the day |
| Fulfillment Pending Orders | KPI | 30 | Fulfillment backlog that the team works through during the day |
| Cancelled Orders | KPI | 180 | Cancellations are occasional, so there may be none for hours |
| Outstanding Amount | KPI | 30 | Money still owed or in flight that may need follow-up |
| Paid Order Rate | KPI | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| Pending Amount | KPI | 30 | Money still owed or in flight that may need follow-up |
| Refunded Amount | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Sales Trend | PLOT | 30 | Headline sales number. New orders land with every extractor run |
| Revenue Waterfall | PLOT | 60 | Sales-driven figure. Refunds are only a small part of it |
| Discount Trend | PLOT | 120 | Only changes when orders use discounts, which depends on the seller running promotions |
| Refunded Orders Trend | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Orders vs AOV Trend | PLOT | 30 | Headline sales number. New orders land with every extractor run |
| Orders Detail Report | TABLE | 30 | Headline sales number. New orders land with every extractor run |
| Orders by Status | PLOT | 30 | Order status moves as orders are paid, fulfilled or cancelled |
| Cancelled Order Loss | PLOT | 180 | Cancellations are occasional, so there may be none for hours |
| Cancelled Orders Report | TABLE | 180 | Cancellations are occasional, so there may be none for hours |
| Unpaid Orders Aging | PLOT | 60 | Unpaid orders are grouped into age buckets measured in days |
| Payment Gateway Mix | PLOT | 60 | Payment breakdown. The mix moves slowly |
| Sales by Channel | PLOT | 60 | Channel breakdown of sales. The split moves slowly |
| Channel Order Report | TABLE | 60 | Channel breakdown of sales. The split moves slowly |
| Geography Sales Report | TABLE | 360 | Geographic split of sales shifts slowly |

## Order Line Item Analytics

| Name | Type | Suggested TTL (min) | Reason |
|---|---|---|---|
| Units Sold | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Line Item Net Sales | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Line Item Gross Sales | KPI | 30 | Headline sales number. New orders land with every extractor run |
| Average Unit Price | KPI | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| Total Line Discounts | KPI | 120 | Only changes when orders use discounts, which depends on the seller running promotions |
| Discount Rate | KPI | 120 | Only changes when orders use discounts, which depends on the seller running promotions |
| Unfulfilled Quantity | KPI | 30 | Fulfillment backlog that the team works through during the day |
| Unfulfilled Value | KPI | 30 | Fulfillment backlog that the team works through during the day |
| Refund Removed Quantity | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Refundable Quantity | KPI | 60 | Sales-driven figure. Refunds are only a small part of it |
| Top SKU Contribution | KPI | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| Gift Card Line Sales | KPI | 180 | Gift card sales are occasional |
| Top Vendor | KPI | 360 | The leader rarely changes within a day |
| Total Vendor | KPI | 360 | Number of vendors or collections selling in the period changes slowly |
| Top Collection | KPI | 360 | The leader rarely changes within a day |
| Total Collection | KPI | 360 | Number of vendors or collections selling in the period changes slowly |
| SKU Sales Trend | PLOT | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| SKU Performance Report | TABLE | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| Product Performance Report | TABLE | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| Discount Leakage Report | TABLE | 120 | Only changes when orders use discounts, which depends on the seller running promotions |
| Unfulfilled Line Items Report | TABLE | 30 | Fulfillment backlog that the team works through during the day |
| Refund / Removed Quantity Report | TABLE | 180 | Refunds are occasional, so there may be none for hours |
| Product Revenue Pareto | PLOT | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| Average Unit Price Trend | PLOT | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| Sales by Category | PLOT | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| Gross vs Net Sales by Product | PLOT | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |

## Refunds & Reversals

| Name | Type | Suggested TTL (min) | Reason |
|---|---|---|---|
| Total Refunded Amount | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Refund Rate by Value | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Refunded Orders | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Refunded Order Rate | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Average Refund Value | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Refunded Shipping Amount | KPI | 240 | Only some refunds include shipping or discounts, so these are rarer than refunds in general |
| Refund Transaction Amount | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Refunded Discount Value | KPI | 240 | Only some refunds include shipping or discounts, so these are rarer than refunds in general |
| Partially Refunded Orders | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Fully Refunded Orders | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Refund Removed Quantity | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Refundable Quantity | KPI | 60 | Sales-driven figure. Refunds are only a small part of it |
| Refund Trend | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Refund Rate Trend | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Refunds vs Sales | PLOT | 60 | Sales-driven figure. Refunds are only a small part of it |
| Refunded Shipping Trend | PLOT | 240 | Only some refunds include shipping or discounts, so these are rarer than refunds in general |
| Refund Transaction Reconciliation | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Refund Transaction Reconciliation Report | TABLE | 180 | Refunds are occasional, so there may be none for hours |
| Refund Shipping Report | TABLE | 240 | Only some refunds include shipping or discounts, so these are rarer than refunds in general |
| Refund Severity Distribution | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Top Refunded Products / SKUs | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Top Refunded Products Report | TABLE | 180 | Refunds are occasional, so there may be none for hours |
| Refunds by Channel | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Refunds by Customer Segment | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Refunds by Payment Gateway | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Channel Refund Report | TABLE | 180 | Refunds are occasional, so there may be none for hours |
| Customer Refund Risk Report | TABLE | 360 | Built on refund history per customer, which grows slowly |
| Refund Note Keyword Analysis | TABLE | 360 | Needs refunds with notes, which are rare, and keyword patterns shift slowly |
| Refund Detail Report | TABLE | 180 | Refunds are occasional, so there may be none for hours |
| Refund Notes Report | TABLE | 180 | Refunds are occasional, so there may be none for hours |

## Product & Inventory Health

| Name | Type | Suggested TTL (min) | Reason |
|---|---|---|---|
| Total Inventory Units | KPI | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Available Stock | KPI | 30 | Live stock level that changes with every sale and stock update |
| Low Stock SKUs | KPI | 30 | Live stock level that changes with every sale and stock update |
| Out of Stock SKUs | KPI | 30 | Live stock level that changes with every sale and stock update |
| Sell Through Rate | KPI | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Low Stock Revenue Risk | KPI | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Stock Coverage Days | KPI | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Incoming Stock | KPI | 120 | Changes only when transfers or purchase orders are created or received |
| Inventory Value | KPI | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Dead Stock Value | KPI | 360 | Dead stock means no sales over a long window, so it moves over days |
| Damaged Stock Value | KPI | 360 | Changes only when staff adjust damaged, QC or safety stock |
| Committed Stock | KPI | 30 | Live stock level that changes with every sale and stock update |
| Reserved Stock | KPI | 120 | Reserved stock comes from draft orders and manual holds, which are occasional |
| Unfulfilled Stock Demand | KPI | 30 | Fulfillment backlog that the team works through during the day |
| Active Inventory Locations | KPI | 360 | Location setup only changes when the seller adds, edits or deactivates a location |
| Stock Status Mix | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Inventory Health Report | TABLE | 30 | Live stock level that changes with every sale and stock update |
| Fast-Moving SKU Report | TABLE | 30 | Live stock level that changes with every sale and stock update |
| Low Stock Revenue Risk by SKU | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Stock Coverage Days by SKU | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Inventory Movement Trend | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Low Stock Report | TABLE | 30 | Live stock level that changes with every sale and stock update |
| Out of Stock Report | TABLE | 30 | Live stock level that changes with every sale and stock update |
| Inventory Value by Product | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Dead Stock by Product | PLOT | 360 | Dead stock means no sales over a long window, so it moves over days |
| Inventory Value Report | TABLE | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Dead Stock Report | TABLE | 360 | Dead stock means no sales over a long window, so it moves over days |
| Unfulfilled Quantity by Product | PLOT | 30 | Fulfillment backlog that the team works through during the day |
| Unfulfilled Inventory Report | TABLE | 30 | Fulfillment backlog that the team works through during the day |
| Inventory by Location | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Damaged / QC / Safety Stock Mix | PLOT | 360 | Changes only when staff adjust damaged, QC or safety stock |
| Inventory Value by Vendor | PLOT | 360 | Split by vendor, collection or origin is stable. Only the catalog setup moves it |
| Inventory Value by Collection | PLOT | 360 | Split by vendor, collection or origin is stable. Only the catalog setup moves it |
| Origin Country Stock Mix | PLOT | 360 | Split by vendor, collection or origin is stable. Only the catalog setup moves it |

## Customer Retention

| Name | Type | Suggested TTL (min) | Reason |
|---|---|---|---|
| Total Customers | KPI | 60 | Customer counts and revenue from orders. Changes with new orders |
| New Customers | KPI | 60 | Customer counts and revenue from orders. Changes with new orders |
| Repeat Customers | KPI | 120 | A customer only becomes repeat on their second order, so this moves slower than order counts |
| Repeat Customer Rate | KPI | 120 | A customer only becomes repeat on their second order, so this moves slower than order counts |
| Customer Revenue | KPI | 60 | Customer counts and revenue from orders. Changes with new orders |
| Average Customer Value | KPI | 360 | Customer-level metric that needs several orders per customer to move |
| Average Orders per Customer | KPI | 360 | Customer-level metric that needs several orders per customer to move |
| High Value Customers | KPI | 360 | Customer-level metric that needs several orders per customer to move |
| Refund-Risk Customers | KPI | 360 | Built on refund history per customer, which grows slowly |
| New Customer Revenue | KPI | 60 | Customer counts and revenue from orders. Changes with new orders |
| Repeat Customer Revenue | KPI | 60 | Customer counts and revenue from orders. Changes with new orders |
| Tax Exempt Customers | KPI | 360 | Few customers are tax-exempt and that status rarely changes |
| Inactive Customers | KPI | 360 | Inactivity is measured in days since the last order |
| Weak Address Customers | KPI | 360 | Addresses only change when customers are added or edit their details |
| Customer Growth Trend | PLOT | 60 | Customer counts and revenue from orders. Changes with new orders |
| New vs Repeat Orders | PLOT | 60 | Customer counts and revenue from orders. Changes with new orders |
| New vs Repeat Customer Revenue | PLOT | 60 | Customer counts and revenue from orders. Changes with new orders |
| Revenue by Customer Segment | PLOT | 360 | Customer-level metric that needs several orders per customer to move |
| Top Customers by Revenue | PLOT | 360 | Customer-level metric that needs several orders per customer to move |
| Customer Revenue Cohort | PLOT | 360 | Cohorts build up over weeks and months |
| Customer Cohort Report | TABLE | 360 | Cohorts build up over weeks and months |
| Refund-Risk Customers by Segment | PLOT | 360 | Built on refund history per customer, which grows slowly |
| Refund-Risk Customer Report | TABLE | 360 | Built on refund history per customer, which grows slowly |
| Customer Geography | PLOT | 360 | Geographic split of sales shifts slowly |
| Customer Location Revenue Ranking | PLOT | 360 | Geographic split of sales shifts slowly |
| Customer Geography Report | TABLE | 360 | Geographic split of sales shifts slowly |
| Tax-Exempt Customer Revenue | PLOT | 360 | Few customers are tax-exempt and that status rarely changes |
| Inactive Customer Aging | PLOT | 360 | Inactivity is measured in days since the last order |
| Address Quality Report | TABLE | 360 | Addresses only change when customers are added or edit their details |

## Sales Channel Attribution

| Name | Type | Suggested TTL (min) | Reason |
|---|---|---|---|
| Total Channel Revenue | KPI | 60 | Channel breakdown of sales. The split moves slowly |
| Channel Orders | KPI | 60 | Channel breakdown of sales. The split moves slowly |
| Channel AOV | KPI | 60 | Channel breakdown of sales. The split moves slowly |
| Top Revenue Channel | KPI | 360 | The leader rarely changes within a day |
| Top AOV Channel | KPI | 360 | The leader rarely changes within a day |
| Net Revenue After Refunds | KPI | 60 | Sales-driven figure. Refunds are only a small part of it |
| Channel Refund Rate | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Channel Discount Rate | KPI | 120 | Only changes when orders use discounts, which depends on the seller running promotions |
| UTM Revenue | KPI | 120 | Only orders from tagged campaigns or referrals change it, which depends on the seller's marketing |
| UTM AOV | KPI | 120 | Only orders from tagged campaigns or referrals change it, which depends on the seller's marketing |
| Referral Revenue | KPI | 120 | Only orders from tagged campaigns or referrals change it, which depends on the seller's marketing |
| Paid Revenue Share | KPI | 120 | Only orders from tagged campaigns or referrals change it, which depends on the seller's marketing |
| Orders Without Attribution | KPI | 360 | Data-quality check, not time-sensitive |
| Channel Tax Collected | KPI | 60 | Sales breakdown. Changes with new orders but the shape moves slowly |
| Channel Fulfillment Risk | KPI | 30 | Fulfillment backlog that the team works through during the day |
| Revenue by Channel | PLOT | 60 | Channel breakdown of sales. The split moves slowly |
| Orders by Channel | PLOT | 60 | Channel breakdown of sales. The split moves slowly |
| Channel AOV Comparison | PLOT | 60 | Channel breakdown of sales. The split moves slowly |
| Channel Revenue Trend | PLOT | 60 | Channel breakdown of sales. The split moves slowly |
| Channel Quality Matrix | TABLE | 60 | Sales-driven figure. Refunds are only a small part of it |
| Net Revenue After Refunds by Channel | PLOT | 60 | Sales-driven figure. Refunds are only a small part of it |
| Refund Rate by Channel | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Discount Rate by Channel | PLOT | 120 | Only changes when orders use discounts, which depends on the seller running promotions |
| UTM Campaign Revenue | PLOT | 120 | Only orders from tagged campaigns or referrals change it, which depends on the seller's marketing |
| UTM Source / Medium Performance | PLOT | 120 | Only orders from tagged campaigns or referrals change it, which depends on the seller's marketing |
| Referral Site Revenue | PLOT | 120 | Only orders from tagged campaigns or referrals change it, which depends on the seller's marketing |
| Paid vs Organic Revenue Mix | PLOT | 120 | Only orders from tagged campaigns or referrals change it, which depends on the seller's marketing |
| Unattributed Orders Trend | PLOT | 360 | Data-quality check, not time-sensitive |
| Attribution Gap Report | TABLE | 360 | Data-quality check, not time-sensitive |
| Channel Fulfillment Backlog | PLOT | 30 | Fulfillment backlog that the team works through during the day |
| Channel Geography Mix | PLOT | 360 | Geographic split of sales shifts slowly |
| Channel Fulfillment Report | TABLE | 30 | Fulfillment backlog that the team works through during the day |

## Payments & Transactions

| Name | Type | Suggested TTL (min) | Reason |
|---|---|---|---|
| Total Payment Amount | KPI | 30 | Money coming in, changes with every payment |
| Net Payment Received | KPI | 30 | Money coming in, changes with every payment |
| Transaction Count | KPI | 30 | Money coming in, changes with every payment |
| Top Payment Method | KPI | 360 | The leader rarely changes within a day |
| Top Gateway | KPI | 360 | The leader rarely changes within a day |
| Transaction Fees | KPI | 60 | Fees come with each payment but the rate barely moves |
| Fee Rate | KPI | 60 | Fees come with each payment but the rate barely moves |
| Failed Transactions | KPI | 30 | Money still owed or in flight that may need follow-up |
| Failed Amount | KPI | 30 | Money still owed or in flight that may need follow-up |
| Pending Transactions | KPI | 30 | Money still owed or in flight that may need follow-up |
| Pending Amount | KPI | 30 | Money still owed or in flight that may need follow-up |
| Refund Transactions | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Refund Amount | KPI | 180 | Refunds are occasional, so there may be none for hours |
| Maximum Refundable Amount | KPI | 60 | Sales-driven figure. Refunds are only a small part of it |
| Uncaptured Amount | KPI | 30 | Money still owed or in flight that may need follow-up |
| Manual Payment Amount | KPI | 120 | Manual payments are occasional |
| Cash Rounding Adjustment | KPI | 360 | Cash rounding only happens on POS cash payments, which are rare |
| Top Card Brand | KPI | 360 | The leader rarely changes within a day |
| Payment Amount Trend | PLOT | 30 | Money coming in, changes with every payment |
| Payment Method Mix | PLOT | 60 | Payment breakdown. The mix moves slowly |
| Gateway Performance | PLOT | 60 | Payment breakdown. The mix moves slowly |
| Payment Method Report | TABLE | 60 | Payment breakdown. The mix moves slowly |
| Transaction Fee Trend | PLOT | 60 | Fees come with each payment but the rate barely moves |
| Gateway Fee Report | TABLE | 60 | Fees come with each payment but the rate barely moves |
| Transaction Status Mix | PLOT | 30 | Money coming in, changes with every payment |
| Failed / Pending Payment Trend | PLOT | 30 | Money still owed or in flight that may need follow-up |
| Failed / Pending Transactions Report | TABLE | 30 | Money still owed or in flight that may need follow-up |
| Sales vs Payments Reconciliation | PLOT | 60 | Payment breakdown. The mix moves slowly |
| Refund Transaction Trend | PLOT | 180 | Refunds are occasional, so there may be none for hours |
| Order Payment Reconciliation Report | TABLE | 60 | Payment breakdown. The mix moves slowly |
| Refund Transaction Report | TABLE | 180 | Refunds are occasional, so there may be none for hours |
| Authorization vs Capture | PLOT | 30 | Money still owed or in flight that may need follow-up |
| Manual vs Automated Payments | PLOT | 120 | Manual payments are occasional |
| POS Payments by Location | PLOT | 60 | Payment breakdown. The mix moves slowly |
| Card Brand Mix | PLOT | 360 | Card brand mix stays stable from day to day |
| Cash Rounding Adjustments Trend | PLOT | 360 | Cash rounding only happens on POS cash payments, which are rare |
| Manual Payment Report | TABLE | 120 | Manual payments are occasional |
| POS Payment Report | TABLE | 60 | Payment breakdown. The mix moves slowly |
| Card Brand Report | TABLE | 360 | Card brand mix stays stable from day to day |

## Inventory Location

| Name | Type | Suggested TTL (min) | Reason |
|---|---|---|---|
| Active Locations | KPI | 360 | Location setup only changes when the seller adds, edits or deactivates a location |
| Locations With Active Inventory | KPI | 360 | Location setup only changes when the seller adds, edits or deactivates a location |
| Total Stock Across Locations | KPI | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Available Stock | KPI | 30 | Live stock level that changes with every sale and stock update |
| Committed Stock | KPI | 30 | Live stock level that changes with every sale and stock update |
| Reserved Stock | KPI | 120 | Reserved stock comes from draft orders and manual holds, which are occasional |
| Damaged Stock | KPI | 360 | Changes only when staff adjust damaged, QC or safety stock |
| Low Stock SKUs | KPI | 30 | Live stock level that changes with every sale and stock update |
| Out of Stock SKUs | KPI | 30 | Live stock level that changes with every sale and stock update |
| Incoming Stock | KPI | 120 | Changes only when transfers or purchase orders are created or received |
| Fulfillment Risk Locations | KPI | 30 | Fulfillment backlog that the team works through during the day |
| Inventory Value | KPI | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Non-Sellable Stock | KPI | 360 | Changes only when staff adjust damaged, QC or safety stock |
| Inactive Locations With Stock | KPI | 360 | Location setup only changes when the seller adds, edits or deactivates a location |
| Fulfillment Service Locations | KPI | 360 | Location setup only changes when the seller adds, edits or deactivates a location |
| Stock by Location | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Available Stock by Location | PLOT | 30 | Live stock level that changes with every sale and stock update |
| Location Inventory Summary | TABLE | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| SKU by Location Report | TABLE | 30 | Live stock level that changes with every sale and stock update |
| Stock Composition by Location | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Damaged Stock by Location | PLOT | 360 | Changes only when staff adjust damaged, QC or safety stock |
| Damaged / QC Stock Report | TABLE | 360 | Changes only when staff adjust damaged, QC or safety stock |
| Low-Stock SKUs by Location | PLOT | 30 | Live stock level that changes with every sale and stock update |
| Out-of-Stock SKUs by Location | PLOT | 30 | Live stock level that changes with every sale and stock update |
| Incoming vs Available Stock | PLOT | 120 | Changes only when transfers or purchase orders are created or received |
| Low Stock by Location Report | TABLE | 30 | Live stock level that changes with every sale and stock update |
| Out-of-Stock by Location Report | TABLE | 30 | Live stock level that changes with every sale and stock update |
| Incoming Stock Report | TABLE | 120 | Changes only when transfers or purchase orders are created or received |
| Fulfillment Risk by Location | PLOT | 30 | Fulfillment backlog that the team works through during the day |
| Fulfillment Risk Report | TABLE | 30 | Fulfillment backlog that the team works through during the day |
| Inventory Value by Location | PLOT | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Stock by City / Region | PLOT | 360 | Regional spread of stock shifts slowly |
| Inventory Value by Location Report | TABLE | 60 | Inventory analysis. Live stock levels are in the 30-minute charts |
| Inactive Location Stock Exposure | PLOT | 360 | Location setup only changes when the seller adds, edits or deactivates a location |
| Inactive Location Stock Report | TABLE | 360 | Location setup only changes when the seller adds, edits or deactivates a location |
| Fulfillment Service Location Report | TABLE | 360 | Location setup only changes when the seller adds, edits or deactivates a location |
