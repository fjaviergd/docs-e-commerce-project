# Database Schema Reference

**Database:** `javier_database`  
**Engine:** MySQL 8.0 / InnoDB / utf8mb4_unicode_ci

---

## Table Relationships Overview

```
ecommerce_categories
    └── ecommerce_listings (category_id → categoryId)
    └── ecommerce_listings (ebay_category_id_level_1 → categoryId)
    └── ecommerce_listings (ebay_category_id_level_2 → categoryId)
    └── ecommerce_listings (ebay_category_id_level_3 → categoryId)

ecommerce_groups_variations
    └── ecommerce_listings (variation_group_id → variation_id)
    └── ecommerce_variation_images (variation_group_id → variation_id)

ecommerce_listings
    └── ecommerce_listing_images (listing_id → listing_id)
    └── ecommerce_listings_inventory (listing_id → listing_id)
```

---

## Tables

### `ecommerce_categories`
Stores eBay category tree nodes.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `categoryId` | int | NO | — | PRIMARY KEY |

> Referenced by `ecommerce_listings` via `category_id`, `ebay_category_id_level_1/2/3`.

---

### `ecommerce_groups_variations`
Represents a variation group (e.g. a product sold in multiple sizes/colors). One group → many variant listings.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `variation_id` | int | NO | AUTO_INCREMENT | PRIMARY KEY |
| `variant_group_sku` | varchar(100) | NO | — | UNIQUE — identifies the group |
| `title` | varchar(500) | NO | — | Group title |
| `description` | longtext | YES | NULL | Group description |
| `common_aspects` | json | YES | NULL | Shared aspects across variants |
| `variant_listing_skus` | json | NO | — | Array of SKUs belonging to this group |
| `aspects_image_varies_by` | json | YES | NULL | Which aspects determine image variation |
| `specifications` | json | YES | NULL | Technical specs |
| `active` | tinyint(1) | NO | 1 | Soft-active flag |
| `created_at` | timestamp(6) | NO | CURRENT_TIMESTAMP(6) | |
| `updated_at` | timestamp(6) | NO | CURRENT_TIMESTAMP(6) | Auto-updates on change |
| `deleted_at` | timestamp(6) | YES | NULL | Soft-delete timestamp |

**Indexes:**
- `UNIQUE` on `variant_group_sku`
- Index on `(active, deleted_at)`

---

### `ecommerce_listings`
Core table. Each row is a single product listing (simple or variant). Syncs to eBay and/or GTS Store.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `listing_id` | int | NO | AUTO_INCREMENT | PRIMARY KEY |
| `sku` | varchar(100) | NO | — | UNIQUE |
| `title` | varchar(500) | NO | — | |
| `description` | longtext | NO | — | |
| `condition` | varchar(50) | NO | — | e.g. `USED_EXCELLENT` |
| `price` | decimal(12,2) | NO | — | |
| `currency` | varchar(3) | NO | `USD` | |
| `stock` | int | NO | — | |
| `main_image` | varchar(500) | YES | NULL | URL of main image |
| `aspects` | json | YES | NULL | eBay item specifics |
| `important_notes` | json | YES | NULL | Array of notes |
| `included_items` | json | YES | NULL | Array of included items |
| `is_variant` | tinyint(1) | NO | 0 | 1 = belongs to a variation group |
| `variation_group_id` | int | YES | NULL | FK → `ecommerce_groups_variations.variation_id` |
| `variant_group_sku` | varchar(100) | YES | NULL | Denormalized group SKU |
| `category_id` | int | NO | — | FK → `ecommerce_categories.categoryId` |
| `category_tree_node_level` | int | NO | — | Depth level in eBay category tree |
| `ebay_category_id_level_1` | int | YES | NULL | FK → `ecommerce_categories.categoryId` |
| `ebay_category_id_level_2` | int | YES | NULL | FK → `ecommerce_categories.categoryId` |
| `ebay_category_id_level_3` | int | YES | NULL | FK → `ecommerce_categories.categoryId` |
| `marketplace_id` | varchar(20) | NO | `EBAY_US` | |
| `sales_format` | varchar(20) | NO | `FIXED_PRICE` | |
| `listing_duration` | varchar(10) | NO | `GTC` | |
| `merchant_location_key` | varchar(100) | NO | — | |
| `fulfillment_policy_id` | bigint | YES | NULL | |
| `payment_policy_id` | bigint | YES | NULL | |
| `return_policy_id` | bigint | YES | NULL | |
| `posted_on_ebay` | tinyint(1) | NO | 0 | |
| `posted_on_gts_store` | tinyint(1) | NO | 0 | |
| `offer_id` | bigint | YES | NULL | eBay offer ID |
| `ebay_listing_id` | bigint | YES | NULL | eBay listing ID |
| `ebay_account_id` | int | YES | NULL | |
| `gts_store_id` | int | YES | NULL | |
| `store_user_id` | int | YES | NULL | |
| `dashboard_user_id` | int | YES | NULL | |
| `store_category_names` | json | YES | NULL | GTS store category names in eBay |
| `ebay_sync_status` | enum | NO | `NOT_REQUESTED` | `PENDING`, `SUCCESS`, `FAILED`, `NOT_REQUESTED` |
| `gts_store_sync_status` | enum | NO | `NOT_REQUESTED` | `PENDING`, `SUCCESS`, `FAILED`, `NOT_REQUESTED` |
| `ebay_sync_pending` | tinyint(1) | YES | 0 | Stock update pending flag |
| `ebay_last_sync_attempt` | timestamp | YES | NULL | |
| `ebay_sync_error` | text | YES | NULL | Last eBay sync error |
| `ebay_listing_id_sync_pending` | tinyint(1) | NO | 0 | Listing ID sync pending across DBs |
| `last_sync_attempt` | timestamp | YES | NULL | General last sync attempt |
| `sync_error_message` | text | YES | NULL | General sync error |
| `data_sanitization_status` | varchar(20) | YES | NULL | Template identifier |
| `cosmetic_description` | varchar(20) | YES | NULL | Template identifier |
| `product_functionality_description` | varchar(20) | YES | NULL | Template identifier |
| `listing_template` | longtext | YES | NULL | Full HTML template for the listing |
| `active` | tinyint(1) | NO | 1 | Soft-active flag |
| `created_at` | timestamp(6) | NO | CURRENT_TIMESTAMP(6) | |
| `updated_at` | timestamp(6) | NO | CURRENT_TIMESTAMP(6) | Auto-updates on change |
| `deleted_at` | timestamp(6) | YES | NULL | Soft-delete timestamp |

**Foreign Keys:**
- `category_id` → `ecommerce_categories.categoryId` (RESTRICT on delete)
- `ebay_category_id_level_1/2/3` → `ecommerce_categories.categoryId` (SET NULL on delete)
- `variation_group_id` → `ecommerce_groups_variations.variation_id` (SET NULL on delete)

---

### `ecommerce_listing_images`
Images associated with a single listing (not a variation group).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `image_id` | int | NO | AUTO_INCREMENT | PRIMARY KEY |
| `listing_id` | int | NO | — | FK → `ecommerce_listings.listing_id` |
| `listing_sku` | varchar(100) | NO | — | Denormalized SKU |
| `image_url` | varchar(1000) | NO | — | |
| `image_type` | enum | NO | `EBAY_INVENTORY` | `EBAY_INVENTORY` or `GTS_STORE` |
| `sort_order` | int | NO | 0 | Display order |
| `active` | tinyint(1) | NO | 1 | |
| `created_at` | timestamp(6) | NO | CURRENT_TIMESTAMP(6) | |
| `updated_at` | timestamp(6) | NO | CURRENT_TIMESTAMP(6) | |
| `deleted_at` | timestamp(6) | YES | NULL | Soft-delete |

**Foreign Keys:**
- `listing_id` → `ecommerce_listings.listing_id` (CASCADE on delete)

---

### `ecommerce_variation_images`
Images associated with a variation group (shared across variants).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `image_id` | int | NO | AUTO_INCREMENT | PRIMARY KEY |
| `variation_group_id` | int | NO | — | FK → `ecommerce_groups_variations.variation_id` |
| `variant_group_sku` | varchar(100) | NO | — | Denormalized group SKU |
| `image_url` | varchar(1000) | NO | — | |
| `sort_order` | int | NO | 0 | Display order |
| `active` | tinyint(1) | NO | 1 | |
| `created_at` | timestamp(6) | NO | CURRENT_TIMESTAMP(6) | |
| `updated_at` | timestamp(6) | NO | CURRENT_TIMESTAMP(6) | |
| `deleted_at` | timestamp(6) | YES | NULL | Soft-delete |

**Foreign Keys:**
- `variation_group_id` → `ecommerce_groups_variations.variation_id` (CASCADE on delete)

---

### `ecommerce_listings_inventory`
Junction table linking listings to inventory items (many-to-many).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | bigint unsigned | NO | AUTO_INCREMENT | PRIMARY KEY |
| `listing_id` | int | NO | — | FK → `ecommerce_listings.listing_id` |
| `inventory_id` | bigint | NO | — | External inventory item ID |
| `iq_id` | bigint | YES | NULL | IQ reference ID |
| `po_id` | bigint | YES | NULL | Purchase Order ID |
| `po_line` | varchar(255) | YES | NULL | Purchase Order line |
| `created_at` | timestamp | YES | CURRENT_TIMESTAMP | |
| `updated_at` | timestamp | YES | CURRENT_TIMESTAMP | Auto-updates on change |

**Constraints:**
- `UNIQUE (listing_id, inventory_id)` — a listing can't link to the same inventory item twice
- `listing_id` → `ecommerce_listings.listing_id` (CASCADE on delete)

---

## Key Design Patterns

- **Soft deletes:** All main tables use `deleted_at` (NULL = active, timestamp = deleted).
- **Sync status enum:** `NOT_REQUESTED → PENDING → SUCCESS / FAILED` for both eBay and GTS Store.
- **Variants:** A variant listing has `is_variant = 1` and references a `variation_group_id`. The group holds shared data; each variant listing holds its own SKU, price, and stock.
- **Images split by scope:** `ecommerce_listing_images` = per-listing images; `ecommerce_variation_images` = group-level images.
- **Denormalized SKUs:** `listing_sku` and `variant_group_sku` are stored alongside FK IDs for query convenience.
