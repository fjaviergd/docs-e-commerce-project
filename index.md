# GTS CRM — Documentación técnica

Índice general de toda la documentación técnica del proyecto.

---

## Diseño de base de datos

**[database/db-listing-schema.md](./database/db-listing-schema.md)** — Esquema completo del módulo de listings: 12 tablas, ERD Mermaid. Soporta listing simple, listing con variaciones, canal eBay, canal GTS Store, publicación diferida y programada por canal, borradores incompletos, plantillas reutilizables, copia de listings, y control de stock con historial completo de movimientos.

**[current_system/database_current.md](./current_system/database_current.md)** — Esquema de la base de datos del sistema actual (referencia).

---

## Integración eBay — Flujos y APIs

**[flows/index.md](./flows/index.md)** — Índice de todos los flujos de integración con eBay y documentación de cada API.

---

## SRS

**[srs/SRS_gts_eStore_v5.md](./srs/SRS_gts_eStore_v5.md)** — Documento de requerimientos del sistema GTS eStore v5.0.

---

## Specs eBay (OpenAPI)

Especificaciones oficiales de las APIs de eBay en formato OpenAPI 3.0:

| Archivo | API |
|---------|-----|
| [docs-ebay/commerce_media_v1_beta_oas3.yaml](./docs-ebay/commerce_media_v1_beta_oas3.yaml) | Media API |
| [docs-ebay/commerce_taxonomy_v1_oas3.yaml](./docs-ebay/commerce_taxonomy_v1_oas3.yaml) | Taxonomy API |
| [docs-ebay/sell_account_v1_oas3.yaml](./docs-ebay/sell_account_v1_oas3.yaml) | Sell Account API |
| [docs-ebay/sell_inventory_v1_oas3.yaml](./docs-ebay/sell_inventory_v1_oas3.yaml) | Sell Inventory API |
| [docs-ebay/sell_stores_v1_oas3.yaml](./docs-ebay/sell_stores_v1_oas3.yaml) | Sell Stores API |
| [docs-ebay/buy_browse_v1_oas3.yaml](./docs-ebay/buy_browse_v1_oas3.yaml) | Buy Browse API |
