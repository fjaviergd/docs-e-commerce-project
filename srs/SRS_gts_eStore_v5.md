# Especificación de Requerimientos de Software (SRS)
## GreenTek Solutions — gts eStore

| Campo | Valor |
|---|---|
| Proyecto | Plataforma E-commerce GreenTek Solutions (gts eStore) |
| Versión | 5.0 |
| Estado | En revisión |
| Fecha | 2026-04-08 |
| Autor | Javier García, Guadalupe Mendoza|
| Revisado por | Javier García, Guadalupe Mendoza |

---

## Control de cambios

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| 1.0 | 2026-03-18 | | Versión inicial basada en borrador de requerimientos v0.3 |
| 2.0 | 2026-03-20 | | Actualización con decisiones de la sesión de definición de requerimientos (2026-03-18). Se resolvieron 30+ puntos pendientes, se incorporaron nuevos requerimientos y se documentaron puntos aún abiertos. |
| 3.0 | 2026-03-24 | | Cierre de todos los puntos de pendientes_v2.md y varios de pendientes_para_devs.md. Cambios principales: pasarela Stripe confirmada con Apple Pay/Google Pay; eliminación de integración QuickBooks (solo comprobante inmediato); definición completa de operación multi-bodega; 3 políticas de envío por listing (Freight/Free/Normal); fallback de ShipEngine con costo fijo por listing; horario laboral y SLA de procesamiento. |
| 4.0 | 2026-03-27 | | Cierre de pendientes_para_devs_v2.md y pendientes_v3.md. Cambios principales: nuevo RF-USR-006 (registro y autenticación de clientes con vinculación opcional a CRM); reglas del carrito guest (UUID/cookie, expiración 7 días, fusión al login); patrón SAGA para descuento de stock; formato de número de orden (UUID interno + GTS-YYYY-SO_ID visible); cancelación en multi-shipment (cualquier label bloquea toda la orden); proceso de devolución manual; comportamiento de sobreventa (flags en orden y listing); email desacoplado (SMTP dev → AWS SES/SendGrid prod); limpieza total de referencias a QuickBooks/Factura en todo el documento. |
| 5.0 | 2026-04-08 | | Incorporación de comentarios de stakeholders. Cambios principales: RF-CAT-008 (Bundle/Kit) definido como Futura; RF-INV-002 (sincronización de stock) se explorará automatización desde V1 via Order Notifications API de eBay; adición de módulo de Configuración de Precios en RF-ADM-001 con descripción detallada en RF-PAG-002; nota futura sobre creación de listings sin inventario (RF-CAT-001); nota de live chat como idea pendiente de definición (sección 7.1); nota sobre Bulk Items como concepto a evaluar en versiones futuras (RF-INV-001). |

---

## Tabla de contenido

1. [Introducción](#1-introducción)
2. [Descripción general del sistema](#2-descripción-general-del-sistema)
3. [Requerimientos funcionales](#3-requerimientos-funcionales)
   - [RF-CAT — Catálogo y Listings](#rf-cat--catálogo-y-listings)
   - [RF-INV — Inventario](#rf-inv--inventario)
   - [RF-BUS — Búsqueda y Navegación](#rf-bus--búsqueda-y-navegación)
   - [RF-USR — Usuarios y Cuentas](#rf-usr--usuarios-y-cuentas)
   - [RF-CAR — Carrito de Compras](#rf-car--carrito-de-compras)
   - [RF-CHK — Checkout](#rf-chk--checkout)
   - [RF-PAG — Pagos e Impuestos](#rf-pag--pagos-e-impuestos)
   - [RF-ORD — Órdenes y Facturación](#rf-ord--órdenes-y-facturación)
   - [RF-LOG — Logística y Envíos](#rf-log--logística-y-envíos)
   - [RF-NOT — Notificaciones](#rf-not--notificaciones)
   - [RF-PCV — Post-venta y Atención al Cliente](#rf-pcv--post-venta-y-atención-al-cliente)
   - [RF-MKT — Marketing y Contenido](#rf-mkt--marketing-y-contenido)
   - [RF-ADM — Panel Administrativo](#rf-adm--panel-administrativo)
   - [RF-AVZ — Funcionalidades Avanzadas (Alcance Futuro)](#rf-avz--funcionalidades-avanzadas-alcance-futuro)
4. [Requerimientos no funcionales](#4-requerimientos-no-funcionales)
5. [Integraciones externas](#5-integraciones-externas)
6. [Restricciones y supuestos](#6-restricciones-y-supuestos)
7. [Puntos pendientes de definición](#7-puntos-pendientes-de-definición)
8. [Glosario](#8-glosario)

---

## 1. Introducción

### 1.1 Propósito

Este documento describe los requerimientos funcionales y no funcionales de la plataforma de e-commerce **gts eStore** para GreenTek Solutions. Sirve como referencia para el equipo de desarrollo, diseño y stakeholders durante la etapa de planeación y construcción del sistema.

### 1.2 Alcance

El sistema es una plataforma de comercio electrónico orientada al nicho de **ITAD (IT Asset Disposition)**. Permite la venta en línea de equipos de tecnología en múltiples condiciones (nuevo, caja abierta, usado, reacondicionado, entre otros), incluyendo categorías como servidores, laptops, PCs, networking, almacenamiento, monitores, impresoras, accesorios, etc.

El sistema gestionará:
- Publicación y administración de listings (tienda propia + eBay)
- Proceso de compra completo (carrito → checkout → pago → orden)
- Logística de envíos (vía ShipEngine)
- Gestión administrativa de clientes, órdenes e inventario (integrada al CRM existente)
- Comprobante de compra inmediato al cliente (generado por el e-commerce)

### 1.3 Definiciones y acrónimos

| Término | Definición |
|---|---|
| Listing | Publicación de un producto en la tienda o en un marketplace |
| ITAD | IT Asset Disposition — sector de compra/venta de activos tecnológicos |
| SKU | Stock Keeping Unit — unidad de control de inventario |
| CRM | Sistema interno de GreenTek Solutions para gestión de operaciones (desarrollado en Angular) |
| R2V3 | Certificación de responsabilidad en reciclaje de equipos electrónicos |
| Guest | Usuario que completa una compra sin registrar una cuenta |
| V1 | Requerimiento incluido en el alcance de la versión 1 |
| Futura | Requerimiento considerado para una versión posterior (número de versión por definir) |
| Comprobante de compra | Documento inmediato enviado al cliente al confirmar el pago, con todos los montos desglosados; descargable como PDF |

### 1.4 Referencias

- Borrador de Requerimientos v0.3 — `borrador_requerimientos.md`
- Sesión de definición de requerimientos — `preguntas_para_anuar.md` (2026-03-18)
- Documentación de API ShipEngine
- Documentación de API eBay
- Documentación de API Stripe

### 1.5 Audiencia del documento

- Equipo de desarrollo
- Diseñador UX/UI
- Product Owner (Anuar)
- Stakeholders del proyecto

---

## 2. Descripción general del sistema

### 2.1 Perspectiva del producto

El sistema es una plataforma web independiente que se integra con los sistemas existentes de GreenTek Solutions (CRM interno, eBay). No sustituye al CRM, sino que se complementa con él:

- **Frontend de tienda:** Next.js — interfaz que ve el cliente final (`store.greenteksolutions.com`)
- **Backend:** NestJS — API que conecta tienda, CRM e integraciones externas
- **Panel administrativo:** Integrado al CRM existente (Angular) — donde el equipo interno gestiona listings, órdenes e inventario

### 2.2 Funciones principales del sistema

- Publicación y gestión de listings en múltiples canales (tienda + eBay)
- Proceso de compra completo para clientes B2C (registrados e invitados)
- Cotización y gestión de envíos vía ShipEngine
- Sincronización de inventario con CRM y eBay (automatización parcial desde V1 via Order Notifications API de eBay; el alcance exacto se confirma con el equipo de desarrollo)
- Ciclo de notificaciones al cliente: comprobante inmediato al pagar, actualizaciones de estado por email con link de seguimiento
- Panel administrativo dentro del CRM para gestión operativa diaria

### 2.3 Tipos de usuario

| Tipo | Descripción |
|---|---|
| Cliente registrado | Usuario con cuenta activa en la plataforma |
| Cliente invitado (Guest) | Usuario que compra sin registrar cuenta |
| Administrador | Operador interno de GreenTek con acceso al panel administrativo en el CRM (MANGER, PURCHASNGREP, SALESREP, entre otros ) |
| Super administrador | Acceso total al sistema, incluyendo configuración global (ADMINISTRATOR) (precios, impuestos, carriers) |

> **Nota:** Los roles y permisos de administradores son gestionados por el CRM existente. Los usuarios con acceso ya están definidos dentro del CRM.

### 2.4 Entorno operativo

- Plataforma web accesible desde navegadores modernos (desktop y mobile)
- Dominio: `store.greenteksolutions.com`
- Mercado inicial: Estados Unidos
- Idioma inicial: inglés
- Moneda: USD
- Operación de la tienda: 24/7 de forma autónoma (compras a cualquier hora)
- Procesamiento de órdenes por el equipo: horario laboral definido
- Atención al cliente: email y teléfono, horario laboral, SLA de respuesta de 24 horas hábiles

> **Idea futura (pendiente de definición):** Se ha mencionado la posibilidad de incorporar un widget de live chat en la tienda, con la capacidad de activarlo y desactivarlo manualmente para operar únicamente en horario laboral. Esta funcionalidad no está en el alcance de V1; los detalles se definirán en una sesión futura con stakeholders. Ver también sección 7.1.

### 2.5 Restricciones generales

- V1 no incluye expansión internacional ni soporte multimoneda
- V1 no almacena métodos de pago del cliente
- V1 no automatiza devoluciones ni reembolsos (proceso manual vía email/teléfono)
- V1 buscará automatizar la sincronización de inventario con eBay via Order Notifications API; los ajustes manuales desde el CRM se mantienen como respaldo
- La condición del producto no puede ser una variación de listing
- No se usarán logos de fabricantes de terceros en la plataforma
- No hay migración de clientes existentes de eBay ni del CRM al e-commerce
- Ventas únicamente en el territorio de EE.UU.
- No hay bulk import de listings en V1 — todos se crean manualmente

---

## 3. Requerimientos funcionales

> **Convención de IDs:**
> Cada requerimiento tiene un identificador con el formato `RF-[MÓDULO]-[NNN]`.
> La versión puede ser: **V1** (incluido en la versión 1), **Futura** (versión posterior por definir), o **Por definir** (pendiente de decisión).

---

> **Plantilla de requerimiento:**
>
> ### RF-XXX-NNN — Nombre del requerimiento
>
> | Campo | Valor |
> |---|---|
> | **Módulo** | Nombre del módulo |
> | **Versión** | V1 / Futura / Por definir |
> | **Actores** | Cliente registrado, Administrador, etc. |
> | **Precondiciones** | Lo que debe existir antes de ejecutar este requerimiento |
>
> **Descripción:**
> Descripción clara y concisa de la funcionalidad.
>
> **Requerimientos funcionales:**
> - RF-XXX-NNN-1: ...
>
> **Reglas de negocio:**
> - RN-1: ...
>
> **Criterios de aceptación:**
> - El sistema debe...
>
> **Dependencias / Integraciones:**
> - Integración con X
>
> **Puntos pendientes:**
> - Pendiente confirmar con [persona]
>
> **Extensiones futuras (fuera de alcance V1):**
> - ...

---

### RF-CAT — Catálogo y Listings

---

#### RF-CAT-001 — Gestión de Listings

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo |
| **Versión** | V1 |
| **Actores** | Administrador |
| **Precondiciones** | El administrador debe estar autenticado en el CRM |

**Descripción:**
El sistema permitirá crear, editar, publicar y administrar listings de productos desde el CRM. Cada listing puede ser publicado en la tienda propia y/o en eBay desde una única fuente de información. Todos los listings se crean manualmente; no hay importación masiva en V1.

**Requerimientos funcionales:**
- RF-CAT-001-1: El sistema debe permitir crear nuevos listings
- RF-CAT-001-2: El sistema debe permitir editar listings existentes
- RF-CAT-001-3: El sistema debe permitir eliminar listings
- RF-CAT-001-4: El sistema debe permitir guardar listings en estado borrador (draft)
- RF-CAT-001-5: El sistema debe permitir publicar listings en uno o más canales
- RF-CAT-001-6: El formulario de creación debe ser modular y adaptarse según el canal seleccionado
- RF-CAT-001-7: El sistema debe permitir subir imágenes durante la creación del listing
- RF-CAT-001-8: El sistema debe permitir asociar información de certificación R2V3 a cada listing
- RF-CAT-001-9: Los atributos técnicos de cada listing se definen con base en las categorías de la API de eBay, las cuales proveen atributos estándar y permiten agregar valores personalizados
- RF-CAT-001-10: El formulario de atributos debe ser reactivo (se adapta al seleccionar categoría)

**Campos del formulario de listing:**
- Información general (nombre, descripción, categoría, condición)
- Imágenes
- Atributos técnicos (basados en categoría eBay)
- Variaciones (si aplica)
- Contenido específico por canal
- Certificaciones (R2V3)
- Peso y dimensiones (para cálculo de envíos con ShipEngine)
- Inventario asociado (IDs de items del CRM)
- Precio base (`base_price`) — único campo de precio que ingresa el empleado; representa el precio real de referencia. El formulario muestra en tiempo real la preview de precios por canal (eBay y GTS Store) con sus respectivos descuentos y badges. Ver RF-PAG-002
- **Política de envío** (`Normal` / `Freight` / `Free`) — ver RF-LOG-003
- **Costo fijo de envío** (obligatorio; usado como fallback si ShipEngine no está disponible, y como precio de envío en política `Freight`)

**Reglas de negocio:**
- RN-1: La condición del producto (nuevo, usado, reacondicionado, etc.) es un atributo fijo del listing y **no puede ser una variación**
- RN-2: Un listing puede tener múltiples items de inventario asociados
- RN-3: Un item de inventario solo puede estar asociado a un listing
- RN-4: No se usarán logos de fabricantes de terceros en los listings
- RN-5: El empleado ingresa únicamente `base_price`; el sistema calcula y almacena el precio y porcentaje de descuento por canal al momento de guardar el listing. Ver RF-PAG-002
- RN-6: El campo `costo fijo de envío` es obligatorio para todos los listings sin excepción

**Estados del listing:**

| Estado | Descripción |
|---|---|
| `draft` | En creación, no publicado en ningún canal |
| `ready` | Listo para publicar |
| `published` | Publicado en al menos un canal |
| `partially_published` | Publicado en algunos canales, no en todos |
| `out_of_stock` | Sin stock disponible, permanece visible como agotado |
| `unpublished` | Despublicado de todos los canales |
| `inactive` | Desactivado |

**Dependencias / Integraciones:**
- API de eBay (para publicación multicanal y definición de atributos por categoría)
- CRM interno (para asociación de inventario)

**Puntos pendientes:**
- Definir estructura exacta del formulario por canal
- Definir mapeo completo de campos con eBay
- Definir validaciones específicas por canal
- Definir manejo de errores en publicación a marketplace
- Definir reglas de visibilidad de listings por bodega (pendiente definición multi-bodega)

**Extensiones futuras (fuera de alcance V1):**
- Importación masiva de listings (bulk import)
- Duplicado de listings
- Templates reutilizables de listings
- Publicación programada por fecha y canal
- Publicación en Amazon, Walmart y otros marketplaces
- Creación de listings sin inventario asociado (idea mencionada por stakeholders — pendiente de definir detalles, reglas de negocio y viabilidad antes de incorporarse a una versión futura)

---

#### RF-CAT-002 — Variaciones de Listing

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo |
| **Versión** | V1 |
| **Actores** | Administrador |
| **Precondiciones** | Listing creado o en creación |

**Descripción:**
El sistema soportará variaciones dentro de un mismo listing, similar al modelo de eBay.

**Requerimientos funcionales:**
- RF-CAT-002-1: El sistema debe permitir definir variaciones para un listing
- RF-CAT-002-2: Cada variación debe poder tener su propio precio e inventario

**Ejemplos de variaciones válidas:**
- Capacidad de RAM (8GB, 16GB, 32GB)
- Almacenamiento (256GB SSD, 512GB SSD, 1TB HDD)

**Reglas de negocio:**
- RN-1: La condición del producto **no puede ser una variación** — es un atributo fijo del listing

**Puntos pendientes:**
- Definir si las variaciones impactan el modelo de inventario a nivel de ítem individual

---

#### RF-CAT-003 — Generador de HTML para eBay

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo — Integración eBay |
| **Versión** | V1 |
| **Actores** | Sistema (automático) |
| **Precondiciones** | Listing completo con descripción, imágenes y especificaciones |

**Descripción:**
El sistema generará automáticamente un template HTML para la descripción de listings publicados en eBay, incluyendo branding de GreenTek Solutions.

**Requerimientos funcionales:**
- RF-CAT-003-1: El sistema debe generar el HTML al momento de publicar en eBay
- RF-CAT-003-2: El template debe incluir imágenes, descripción, especificaciones y branding de GreenTek

**Puntos pendientes:**
- Definir diseño del template HTML para eBay

---

#### RF-CAT-004 — Colecciones de Listings

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo |
| **Versión** | Futura |
| **Actores** | Administrador |
| **Precondiciones** | Listings publicados en la tienda |

**Descripción:**
Las colecciones permiten agrupar productos bajo una temática o campaña específica para mejorar la navegación y el marketing.

**Requerimientos funcionales:**
- RF-CAT-004-1: El sistema debe permitir crear colecciones con nombre, imagen de portada y descripción
- RF-CAT-004-2: El administrador debe poder asignar listings manualmente a una colección
- RF-CAT-004-3: El administrador debe poder activar o desactivar colecciones
- RF-CAT-004-4: Las colecciones deben ser visibles en el frontend

**Ejemplos de colecciones:** Back 2 School, Liquidación Q1, Arma tu Servidor

---

#### RF-CAT-005 — Branding de Fabricantes

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo |
| **Versión** | Descartado |
| **Actores** | — |
| **Precondiciones** | — |

**Decisión:** Los stakeholders han decidido **no utilizar logos de fabricantes de terceros** (Cisco, HP, Dell, Lenovo, etc.) en la plataforma. Esta funcionalidad queda fuera del alcance del proyecto.

---

#### RF-CAT-006 — Información de Certificaciones

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo |
| **Versión** | V1 |
| **Actores** | Cliente, Administrador |
| **Precondiciones** | — |

**Descripción:**
El sistema incluirá una sección informativa sobre las certificaciones con las que cuenta GreenTek Solutions, como la certificación R2V3.

**Requerimientos funcionales:**
- RF-CAT-006-1: El sistema debe incluir una sección con información de certificaciones de GreenTek
- RF-CAT-006-2: Se debe poder asociar información de certificación R2V3 a nivel de listing

---

#### RF-CAT-007 — Productos sin Stock (Out of Stock)

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo |
| **Versión** | V1 |
| **Actores** | Cliente, Sistema |
| **Precondiciones** | Listing publicado con stock en cero |

**Descripción:**
Cuando el stock de un listing llega a cero, el producto permanece visible en la tienda mostrando su estado como "Agotado", en lugar de despublicarse. Esta estrategia protege el posicionamiento SEO de los listings y mantiene la visibilidad del catálogo.

**Requerimientos funcionales:**
- RF-CAT-007-1: Cuando el stock de un listing llegue a cero, el sistema debe marcarlo como `out_of_stock` y mantenerlo visible
- RF-CAT-007-2: El listing agotado debe mostrar claramente el indicador "Out of Stock" / "Agotado"
- RF-CAT-007-3: No debe ser posible agregar al carrito un listing agotado
- RF-CAT-007-4: El listing agotado debe mostrar una sección de productos relacionados disponibles

**Reglas de negocio:**
- RN-1: El equipo administrativo es responsable de reponer el stock de forma constante para mantener disponibilidad
- RN-2: Los listings agotados permanecen en el catálogo hasta que un administrador los despublique explícitamente

**Extensiones futuras:**
- Suscripción a notificación de restock por email (cliente se suscribe al producto agotado)
- Automatización de despublicación tras N días agotado (configurable)

---

#### RF-CAT-008 — Productos Bundle / Kit

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo |
| **Versión** | Futura |
| **Actores** | Administrador, Cliente |
| **Precondiciones** | — |

**Descripción:**
Un bundle es un listing compuesto por múltiples productos individuales comercializados como un conjunto a un precio combinado.

**Ejemplos:** Kit de escritorio (laptop + monitor + teclado y mouse), Pack de almacenamiento (SSD + RAM)

**Implicaciones técnicas:**
- Lógica de inventario compuesta: el bundle se agota si cualquiera de sus componentes se agota
- Precio del bundle puede ser diferente a la suma de sus partes
- Impacto en el modelo de descuento global (¿aplica el 5% sobre precio de marketplace?)

**Decisión:** Confirmado por stakeholders — esta funcionalidad queda fuera del alcance de V1 y se evaluará en una versión posterior.

**Puntos a definir cuando se retome:**
- Definir reglas de inventario para bundles
- Definir modelo de precios para bundles

---

#### RF-CAT-009 — Sistema de Grading de Listings

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo |
| **Versión** | V1 |
| **Actores** | Cliente, Administrador |
| **Precondiciones** | Listing creado en el CRM con condición asignada |

**Descripción:**
Todo listing publicado en GTS eStore lleva una calificación de condición (grade) que describe de forma estandarizada el estado cosmético, funcional y de saneamiento de datos del equipo. El sistema expone este grade en múltiples puntos de la experiencia de compra — desde la card del listado hasta el detalle de producto — y cuenta con una sección educativa en el home que explica el sistema al comprador. El grading está alineado al estándar de certificación **R2V3** (Responsible Recycling, versión 3), adoptado por GreenTek Solutions.

---

**Niveles de condición (GTS Grade)**

El sistema maneja tres niveles de condición, mostrados en la tienda con etiqueta de texto, color y puntaje numérico de referencia:

| GTS Grade | Puntaje de referencia | Color UI | Descripción resumida |
|---|---|---|---|
| **Excellent** | 95 / 100 | Verde (primary) | Apariencia como nueva. Desgaste mínimo o nulo. Todas las funciones al 100%. |
| **Good** | 75 / 100 | Azul | Desgaste cosmético leve visible solo bajo inspección cercana. Funciones al 100%. |
| **Fair** | 55 / 100 | Ámbar | Desgaste cosmético visible — rayones, marcas o pequeños golpes. Funciones principales operativas. |

> El puntaje numérico es orientativo y se usa exclusivamente en la UI para comunicar la condición al comprador. No es un campo de entrada del administrador.

---

**Saneamiento de datos (R2V3 — Sanitization)**

Todos los equipos con medios de almacenamiento deben documentar su estado de saneamiento. El prototipo implementa el grado NON-DATA, aplicable a equipos evaluados como no contenedores de datos o que ya fueron saneados.

| Código R2V3 | Etiqueta | Descripción |
|---|---|---|
| **NON-DATA** | Sanitized or free of data storage media | El equipo no contiene medios de almacenamiento con datos, o fue saneado mediante destrucción física, software certificado, o fue evaluado como equipo que no contiene datos. |

---

**Condición cosmética (R2V3 — Cosmetic Description)**

Describe el estado visual externo del equipo. El administrador asigna uno de los siguientes grados al crear el listing:

| Código R2V3 | Etiqueta GTS | Descripción |
|---|---|---|
| **C1** | Like New | Sin blemishes cosméticos visibles. Apariencia tal como fue fabricado — sin rayones, golpes ni decoloración. Todos los paneles, marcos y cubiertas presentes e intactos. Sin daño funcional en bisagras, cierres ni componentes mecánicos. |
| **C2** | Lightly Used | Pueden existir rayones o marcas menores visibles bajo luz directa o inspección cercana. Sin golpes, gouges, decoloración ni daño cosmético significativo. Todos los paneles intactos. Sin daño funcional en bisagras, cierres ni teclado. |
| **C3** | Used Fair | Blemishes cosméticos consistentes con el uso: múltiples golpes, decoloración y rayones de leve a severos. Posible daño en cierres, bisagras o teclado. Algunas partes, marcos o cubiertas pueden estar ausentes. |

---

**Condición funcional (R2V3 — Description of Product Functionality)**

Describe el estado operativo verificado del equipo. El administrador asigna uno de los siguientes grados:

| Código R2V3 | Etiqueta | Descripción |
|---|---|---|
| **F1** | All Functions Working | Todas las funciones primarias y secundarias verificadas como operativas mediante pruebas manuales o de software. Todos los Focus Materials (batería, disco duro, teclado) presentes y funcionales. Probado a especificaciones del fabricante. Sin componentes faltantes. Todos los puertos, conectores e interfaces externas probados y confirmados funcionales. |
| **F2** | Key Functions Working | Funciones primarias verificadas como operativas. Todos los Focus Materials presentes y funcionales. Las funciones secundarias pueden no estar completamente probadas pero se espera que funcionen. Sin componentes faltantes para funciones primarias. |
| **F3** | Key Functions Working (Appendix C — Test and Repair) | Un subconjunto de las funciones primarias verificadas. El hardware requerido para funciones clave puede haber sido removido tras la prueba (ej. disco duro). Pueden faltar componentes no esenciales para funciones clave. Las funciones secundarias pueden no estar probadas ni funcionar. Todos los componentes faltantes serán listados individualmente. |

---

**Correspondencia entre GTS Grade y códigos R2V3**

| GTS Grade | Cosmética (R2V3) | Funcionalidad (R2V3) | Casos de uso típicos |
|---|---|---|---|
| Excellent | C1 | F1 | Equipo reacondicionado premium, casi sin uso |
| Good | C2 | F1 / F2 | Equipo usado con desgaste cosmético leve, totalmente funcional |
| Fair | C3 | F2 / F3 | Equipo con desgaste cosmético notable, funciones clave operativas |

> La combinación exacta de códigos R2V3 es asignada por el administrador al crear el listing. El campo `condition` del listing ("Excellent", "Good" o "Fair") es la etiqueta simplificada que ve el cliente en la tienda y en las cards.

---

**Requerimientos funcionales:**

- RF-CAT-009-1: Cada listing debe tener asignado un GTS Grade (`Excellent`, `Good` o `Fair`) — campo obligatorio en el formulario de creación
- RF-CAT-009-2: El grade del listing debe mostrarse como badge con color en la card del producto (catálogo y secciones del home)
- RF-CAT-009-3: El detalle de producto debe mostrar el grade con su puntaje de referencia y descripción completa
- RF-CAT-009-4: El detalle de producto debe incluir una pestaña "Condition Details" con los tres componentes R2V3 del listing (Sanitización, Cosmética, Funcionalidad) y sus ítems verificados
- RF-CAT-009-5: La tienda debe incluir una sección educativa ("Our Grading System") que explique los tres niveles al comprador, con descripción, puntaje y contenido incluido por nivel
- RF-CAT-009-6: El sistema debe asociar al listing los códigos R2V3 específicos utilizados en la certificación (sanitization key, cosmetic key, functionality key)
- RF-CAT-009-7: La condición **no puede ser una variación de listing** — es un atributo fijo del listing (refuerza RN-1 de RF-CAT-001)

**Reglas de negocio:**

- RN-1: El GTS Grade es el campo que ve el cliente; los códigos R2V3 son el respaldo certificado de ese grade
- RN-2: Una unidad individual puede tener una condición cosmética diferente a otra unidad del mismo listing — sin embargo, el listing expone una única condición representativa; la condición no puede ser variación
- RN-3: Todo listing con medios de almacenamiento debe tener un grado de sanitización R2V3 asignado antes de publicarse
- RN-4: El puntaje numérico (95, 75, 55) es exclusivo de la UI informativa y no se almacena como dato operacional del listing

**Puntos de exposición en la UI (prototipo):**

| Componente | Dónde | Qué muestra |
|---|---|---|
| `ProductCard` | Grid de listados, Flash Deals, secciones del home | Badge con label y color del grade |
| `InfoPanel` (detalle) | Página `/product/[slug]` | Badge de grade + dot indicador de condición |
| `TabsSection` (Condition Details) | Página `/product/[slug]` | Tres secciones R2V3: Sanitización, Cosmética, Funcionalidad — con código, etiqueta e ítems verificados |
| `GtsConditionSection` | Home (`/gts-home`) | Sección educativa con los tres grades, puntaje, descripción y contenido incluido |

**Dependencias / Integraciones:**
- La estructura de grados R2V3 debe estar alineada con los campos de certificación exportables hacia eBay al publicar el listing (ver RF-CAT-003)
- La condición es un filtro disponible en el catálogo de búsqueda (ver RF-BUS)

**Extensiones futuras (fuera de alcance V1):**
- Score de condición calculado automáticamente a partir de ítems R2V3 chequeados (en lugar de asignación manual del grade)
- Fotografías de condición por sección (cosmética, funcionalidad) adjuntas al listing
- Historial de cambios de condición de un equipo a lo largo de su ciclo de vida en el CRM

---

### RF-INV — Inventario

---

#### RF-INV-001 — Modelo de Inventario

| Campo | Valor |
|---|---|
| **Módulo** | Inventario |
| **Versión** | V1 |
| **Actores** | Administrador, Sistema |
| **Precondiciones** | — |

**Descripción:**
El inventario se gestiona a nivel de ítem individual. El modelo de datos del CRM ya está alineado con este modelo: cada registro en la tabla de inventario del CRM representa una unidad física.

**Modelo de relación:**
- 1 listing → múltiples items de inventario (N unidades físicas)
- 1 item de inventario → 1 solo listing (relación bidireccional)
- El listing referencia los IDs de los items del CRM que le corresponden

**Requerimientos funcionales:**
- RF-INV-001-1: El sistema debe mantener un registro de cada ítem de inventario individual
- RF-INV-001-2: El sistema debe descontar inventario al confirmar el pago de una orden, siguiendo el patrón SAGA
- RF-INV-001-3: El sistema debe registrar un historial de cambios en el stock con trazabilidad

**Patrón SAGA para descuento de stock:**
El descuento de inventario se realiza únicamente al confirmar el pago exitoso, no al iniciar el checkout. El flujo es:
1. Pago confirmado por Stripe → se inicia el worker de stock
2. Worker descuenta el ítem de inventario → orden pasa a `paid`
3. Si el worker falla → reintenta automáticamente hasta 3 veces
4. Si los 3 reintentos fallan → compensación: reembolso automático a través de Stripe, orden pasa a `cancelled`, se notifica al cliente por email
5. Errores persistentes → se envían a DLQ (Dead Letter Queue) para revisión manual

**Reglas de negocio:**
- RN-1: El sistema debe evitar sobreventa — no se puede vender más unidades de las disponibles. El stock se valida a nivel de base de datos antes de procesar el pago
- RN-2: Cualquier ajuste de stock debe quedar registrado con usuario, fecha y motivo
- RN-3: No se permite venta con stock en cero en V1 (sin pre-order/backorder)

**Extensiones futuras (fuera de alcance V1):**
- **Bulk Items:** Concepto mencionado por stakeholders — un "bulk item" sería un ítem con cantidad mayor a 1 pero con un solo ID en el sistema, en lugar del modelo actual donde cada unidad física tiene su propio ID. Pendiente de definición detallada y evaluación de viabilidad antes de considerar su implementación en una versión futura.

---

#### RF-INV-002 — Sincronización de Stock entre Canales

| Campo | Valor |
|---|---|
| **Módulo** | Inventario |
| **Versión** | V1: ajuste manual — V2: automatización via API |
| **Actores** | Sistema, CRM, eBay |
| **Precondiciones** | Inventario configurado |

**Descripción:**
El stock debe mantenerse sincronizado entre la tienda propia, eBay y el CRM. Se buscará automatizar este proceso desde V1 mediante las APIs de eBay y del CRM. Si la automatización completa no resulta viable dentro del alcance de V1, se implementará un flujo híbrido: automatización parcial vía Order Notifications API de eBay para las ventas en ese canal, con ajuste manual como respaldo. El alcance exacto de automatización en V1 se confirmará con el equipo de desarrollo durante la implementación.

**Fuentes de cambio de stock:**
- Ventas en tienda propia (automático)
- Ventas en eBay (manual en V1 — administrador actualiza desde CRM)
- Ajustes manuales desde el CRM (destrucción, pérdida, recepción de mercancía)

**Requerimientos funcionales (V1 — manual):**
- RF-INV-002-1: El sistema debe proporcionar un mecanismo para ajustar stock desde el CRM
- RF-INV-002-2: Cuando se detecte una posible sobreventa (venta simultánea en eBay y tienda), el sistema debe alertar al administrador
- RF-INV-002-3: El administrador debe poder cancelar órdenes manualmente en caso de sobreventa confirmada

**Manejo de sobreventa en V1:**

**Primera línea de defensa:** El sistema rechaza cualquier pago si el stock es 0 a nivel de base de datos (SELECT FOR UPDATE o equivalente). Esto cubre ventas simultáneas en la tienda.

**Automatización con eBay:** En V1 se intentará automatizar la sincronización de stock cuando se registre una venta en eBay, usando la Order Notifications API de eBay. Si no es viable en V1, el administrador actualiza el stock manualmente desde el CRM.

**Cuando ocurre sobreventa de todas formas** (ventana de desync entre venta eBay y actualización de stock):
1. El sistema coloca una **bandera de conflicto en la orden** afectada
2. El sistema coloca una **bandera en el listing** correspondiente
3. No se envía notificación automática — el equipo detecta el conflicto visualmente en el panel
4. El administrador cancela la orden conflictiva y procesa el reembolso de forma manual

**WMS:** GreenTek no usa WMS. Los ítems raramente cambian de bodega; cuando ocurre, el equipo actualiza el `location_id` en el CRM. El checkout siempre usa el `location_id` actual del ítem al cotizar envíos, por lo que la información de bodega siempre está actualizada.

**Extensiones futuras (V2):**
- Sincronización automática de stock vía API del CRM
- Webhooks de eBay para actualización en tiempo real
- Resolución automática de conflictos de sobreventa

---

### RF-BUS — Búsqueda y Navegación

---

#### RF-BUS-001 — Buscador de Productos

| Campo | Valor |
|---|---|
| **Módulo** | Búsqueda |
| **Versión** | V1 |
| **Actores** | Cliente registrado, Cliente invitado |
| **Precondiciones** | — |

**Descripción:**
El sistema incluirá un motor de búsqueda que permita a los usuarios encontrar productos por palabras clave y filtros.

**Requerimientos funcionales:**
- RF-BUS-001-1: El sistema debe permitir búsqueda por palabras clave
- RF-BUS-001-2: El sistema debe permitir filtrar resultados por categoría
- RF-BUS-001-3: El sistema debe permitir filtrar resultados por atributos técnicos

**Extensiones futuras:**
- Autocompletado en campo de búsqueda
- Historial de búsqueda por usuario

---

#### RF-BUS-002 — Secciones Destacadas Dinámicas

| Campo | Valor |
|---|---|
| **Módulo** | Navegación |
| **Versión** | Futura |
| **Actores** | Cliente, Administrador |
| **Precondiciones** | Listings y datos de ventas disponibles |

**Descripción:**
Secciones automáticas en el home y categorías que muestran listings basados en reglas dinámicas.

**Ejemplos:** Más vendidos del día / semana / mes, Recién agregados, Mayor rotación

**Requerimientos funcionales:**
- RF-BUS-002-1: Las secciones deben generarse automáticamente basadas en reglas predefinidas
- RF-BUS-002-2: Los administradores deben poder activar o desactivar cada sección desde el panel

---

#### RF-BUS-003 — Listings Patrocinados

| Campo | Valor |
|---|---|
| **Módulo** | Navegación / Marketing |
| **Versión** | Futura |
| **Actores** | Administrador |
| **Precondiciones** | Listings publicados |

**Descripción:**
Permite priorizar la visibilidad de listings específicos dentro de los resultados de búsqueda, categorías y home.

**Requerimientos funcionales:**
- RF-BUS-003-1: El administrador debe poder seleccionar listings para patrocinar manualmente
- RF-BUS-003-2: El administrador debe poder programar el periodo de patrocinio por fechas

---

#### RF-BUS-004 — Métricas Visibles en Listings

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo / Navegación |
| **Versión** | Mixta (ver detalle) |
| **Actores** | Cliente |
| **Precondiciones** | — |

**Requerimientos funcionales:**
- RF-BUS-004-1 (Priority): Mostrar unidades vendidas
- RF-BUS-004-2 (Futura): Mostrar número de vistas
- RF-BUS-004-3 (Futura): Mostrar cuántos usuarios tienen el producto en carrito
- RF-BUS-004-4 (Futura): Mostrar cuántos usuarios tienen el producto en favoritos
- RF-BUS-004-5 (Futura): Mostrar indicador visual de stock bajo
- RF-BUS-004-6 (Futura): Mostrar indicador de tendencia (alta rotación)

---

### RF-USR — Usuarios y Cuentas

---

#### RF-USR-001 — Gestión de Usuarios (Clientes)

| Campo | Valor |
|---|---|
| **Módulo** | Usuarios |
| **Versión** | V1 |
| **Actores** | Administrador |
| **Precondiciones** | — |

**Descripción:**
El panel administrativo (CRM) permitirá gestionar las cuentas de clientes registrados.

**Requerimientos funcionales:**
- RF-USR-001-1: El administrador debe poder ver el listado de usuarios registrados
- RF-USR-001-2: El administrador debe poder ver el historial de compras de un usuario
- RF-USR-001-3: El administrador debe poder bloquear/desbloquear cuentas de usuario

**Reglas de negocio:**
- RN-1: No hay migración de clientes existentes de eBay ni del CRM — la base de clientes del e-commerce empieza desde cero

---

#### RF-USR-002 — Gestión de Direcciones

| Campo | Valor |
|---|---|
| **Módulo** | Usuarios |
| **Versión** | V1 |
| **Actores** | Cliente registrado |
| **Precondiciones** | Usuario autenticado |

**Descripción:**
Los usuarios registrados podrán almacenar múltiples direcciones para agilizar futuras compras.

**Requerimientos funcionales:**
- RF-USR-002-1: El usuario debe poder agregar hasta 5 direcciones (configurable desde panel admin)
- RF-USR-002-2: El usuario debe poder marcar una dirección como predeterminada
- RF-USR-002-3: El usuario debe poder editar y eliminar direcciones guardadas
- RF-USR-002-4: Durante el checkout, el usuario debe poder seleccionar, agregar o editar una dirección

**Campos requeridos por dirección:**
- Nombre del destinatario
- Calle y número
- Ciudad, estado, código postal, país
- Teléfono de contacto

**Flujo en checkout:**
1. Se solicita primero la dirección de **envío**
2. El usuario puede indicar que la dirección de **facturación** es la misma, o capturar una diferente

**Reglas de negocio:**
- RN-1: La dirección de facturación puede ser diferente a la de envío
- RN-2: El comprobante de compra es el único documento generado directamente por el e-commerce. Las facturas fiscales formales son gestionadas por GreenTek desde el CRM bajo solicitud del cliente (por email o teléfono)

---

#### RF-USR-003 — Favoritos y Wishlist

| Campo | Valor |
|---|---|
| **Módulo** | Usuarios |
| **Versión** | Futura |
| **Actores** | Cliente registrado |
| **Precondiciones** | Usuario autenticado |

**Descripción:**
Aunque visualmente se presentan como funcionalidades distintas, Favoritos y Wishlist comparten la misma entidad en la base de datos — la diferencia es de propósito e intención desde el punto de vista del usuario:

- **Favoritos:** Lista personal e informal de productos que le llamaron la atención al usuario. El propósito es guardar referencias para volver a verlas fácilmente, sin intención de compra inmediata declarada.
- **Wishlist:** Lista de productos que el usuario *quiere comprar*. Tiene una intención de compra más explícita y está orientada a ser compartida con terceros (ej. listas de deseos para regalos).

Ambas listas se implementan sobre la misma estructura de datos; la distinción es a nivel de UI y semántica de uso.

**Requerimientos funcionales:**
- RF-USR-003-1: El usuario debe poder agregar y eliminar listings de su lista de favoritos
- RF-USR-003-2: El usuario debe poder agregar y eliminar listings de su wishlist
- RF-USR-003-3: El sistema debe mantener ambas listas de forma independiente por usuario
- RF-USR-003-4: El sistema debe limitar la cantidad de items por lista; al alcanzar el límite, debe mostrar un mensaje informativo al usuario e impedir agregar más

**Reglas de negocio:**
- RN-1: El límite máximo de items por lista se configura mediante variable de entorno (`WISHLIST_MAX_ITEMS`); el valor por defecto es 50
- RN-2: El límite aplica de forma independiente a cada lista — un usuario puede tener hasta 50 favoritos y hasta 50 items en su wishlist al mismo tiempo
- RN-3: El límite es global para todos los usuarios en V1; no varía por tipo de cuenta

**Extensiones futuras:** Wishlist compartible (link público), múltiples listas personalizadas, notificaciones de bajada de precio o disponibilidad para ítems en wishlist, límite configurable por tipo de cuenta desde la base de datos (ej. usuarios premium con límite extendido)

---

#### RF-USR-004 — Productos Vistos Recientemente

| Campo | Valor |
|---|---|
| **Módulo** | Usuarios |
| **Versión** | Futura |
| **Actores** | Cliente registrado, Cliente invitado |
| **Precondiciones** | — |

**Requerimientos funcionales:**
- RF-USR-004-1: El sistema debe registrar y mostrar listings vistos recientemente
- RF-USR-004-2: El usuario debe poder eliminar ítems del historial

---

#### RF-USR-005 — Conversión de Guest a Cuenta Registrada

| Campo | Valor |
|---|---|
| **Módulo** | Usuarios |
| **Versión** | Futura |
| **Actores** | Cliente invitado |
| **Precondiciones** | Cliente completó una compra como invitado |

**Descripción:**
Al completar una compra como invitado, el sistema ofrecerá la opción de crear una cuenta usando los datos ya capturados durante el checkout, sin necesidad de volver a ingresarlos. Si el registro requiere campos adicionales que no fueron solicitados durante el checkout, el sistema los pedirá en ese momento para completar el perfil.

**Extensiones futuras:** Esta funcionalidad mejora la retención de clientes y se contempla para V2.

---

#### RF-USR-006 — Registro y Autenticación de Clientes

| Campo | Valor |
|---|---|
| **Módulo** | Usuarios |
| **Versión** | V1 |
| **Actores** | Cliente registrado, Cliente invitado |
| **Precondiciones** | — |

**Descripción:**
El e-commerce gestiona su propia base de usuarios de clientes, independiente del CRM. Los clientes pueden registrarse con email y contraseña, o comprar como invitados sin crear cuenta.

**Flujo de registro (cliente registrado):**
1. El cliente ingresa sus datos y crea una cuenta (no es necesario haber comprado antes)
2. El sistema envía un email de verificación — el cliente debe verificar su email para activar la cuenta
3. Opcionalmente, durante el registro, el cliente puede **vincular su cuenta con una cuenta del CRM de GreenTek** (para clientes empresariales con cuenta en el sistema interno)
4. Una vez verificado, el cliente puede iniciar sesión y acceder a su historial de órdenes

**Vinculación con cuenta CRM (opcional):**
- El cliente ingresa el email de su cuenta en el CRM de GreenTek
- El cliente genera un código de verificación desde el CRM
- Al ingresar el código en el e-commerce, el sistema hace el match y vincula ambas cuentas
- La vinculación permite a GreenTek gestionar internamente la relación con ese cliente

**Flujo de compra como invitado (guest):**
1. El cliente no crea cuenta — ingresa directamente al checkout
2. Se solicita email para enviar el comprobante y actualizaciones de la orden
3. La verificación de email es **opcional** para invitados — si no verifica, queda bajo su responsabilidad ingresar correctamente el email
4. Si elige verificar, el sistema envía un código o link de confirmación antes de continuar
5. No se crea ninguna cuenta — el cliente accede a su orden únicamente por el link enviado al email

**Requerimientos funcionales:**
- RF-USR-006-1: El sistema debe permitir registro con email + contraseña
- RF-USR-006-2: El sistema debe enviar email de verificación al registrarse; la cuenta no se activa hasta verificar
- RF-USR-006-3: El sistema debe permitir recuperación de contraseña mediante link enviado al email registrado
- RF-USR-006-4: El sistema debe permitir vinculación opcional de la cuenta del e-commerce con una cuenta del CRM de GreenTek, mediante email + código generado desde el CRM
- RF-USR-006-5: El sistema debe permitir compra como invitado sin registro
- RF-USR-006-6: Al comprar como invitado, el sistema debe solicitar un email para notificaciones; la verificación de dicho email es opcional
- RF-USR-006-7: Tanto clientes registrados como invitados deben recibir por email el comprobante de compra y actualizaciones de estado, incluyendo un link de acceso al detalle de su orden
- RF-USR-006-8: Al finalizar la compra, ambos tipos de usuario deben poder descargar el comprobante en PDF directamente desde la pantalla de confirmación, y nuevamente desde la vista de detalle de la orden accesible por el link del email. Los clientes registrados tienen adicionalmente acceso al PDF desde su historial de órdenes en el portal. Ver RF-ORD-002 para el detalle completo

**Reglas de negocio:**
- RN-1: El sistema del e-commerce administra su propia base de datos de usuarios — no usa servicios externos de autenticación (Auth0, Supabase Auth, etc.)
- RN-2: Un cliente puede registrarse sin haber comprado previamente
- RN-3: La verificación de email es obligatoria para activar una cuenta registrada; es opcional para compras como invitado
- RN-4: La vinculación con cuenta CRM es estrictamente opcional y no afecta la capacidad del cliente de comprar en la tienda
- RN-5: Social login (Google, etc.) no está incluido en V1

**Campos del formulario de registro:**

| Campo | Obligatorio |
|---|---|
| Nombre | Sí |
| Apellido | Sí |
| Email | Sí |
| Contraseña | Sí |
| Teléfono | No |
| Dirección de envío | No |

> La dirección de envío es opcional al registrarse — el cliente puede guardarla como dirección predefinida para agilizar futuros checkouts. Si no la ingresa al registrarse, se solicitará obligatoriamente al momento de completar una compra.

---

### RF-CAR — Carrito de Compras

---

#### RF-CAR-001 — Funcionalidades del Carrito

| Campo | Valor |
|---|---|
| **Módulo** | Carrito |
| **Versión** | V1 |
| **Actores** | Cliente registrado, Cliente invitado |
| **Precondiciones** | — |

**Descripción:**
El carrito permite a los usuarios seleccionar y acumular productos antes de completar la compra.

**Requerimientos funcionales:**
- RF-CAR-001-1: El usuario debe poder agregar productos al carrito
- RF-CAR-001-2: El usuario debe poder eliminar productos del carrito
- RF-CAR-001-3: El usuario debe poder modificar la cantidad de un producto
- RF-CAR-001-4: El sistema debe mostrar un resumen del carrito con subtotal y total estimado
- RF-CAR-001-5: El carrito debe ser persistente para usuarios autenticados (base de datos)
- RF-CAR-001-6: El carrito debe ser persistente para usuarios no autenticados (sesión/cookies)
- RF-CAR-001-7: Al iniciar sesión, el carrito de la sesión debe fusionarse con el carrito guardado

**Información mostrada por ítem:**
- Imagen del producto
- Nombre del producto
- Variación seleccionada (si aplica)
- Precio unitario (actualizado dinámicamente)
- Cantidad
- Subtotal

**Reglas de negocio:**
- RN-1: No se pueden agregar productos sin stock (out_of_stock)
- RN-2: No se puede exceder el stock disponible
- RN-3: El carrito no almacena precios estáticos — siempre refleja el precio actual del listing
- RN-4: Si el stock de un producto en carrito cambia, el carrito debe validarse antes del checkout
- RN-5: El carrito de un usuario no autenticado se identifica mediante un `cartId` UUID generado en el backend y almacenado en cookie del cliente
- RN-6: El `cartId` debe generarse de forma aleatoria y no predecible (UUID) para evitar acceso no autorizado a carritos ajenos
- RN-7: El carrito del usuario invitado se almacena en base de datos con `user_id = null` mientras no esté autenticado
- RN-8: El carrito de usuario invitado expira si no presenta actividad durante **7 días**; el sistema lo elimina o marca como expirado mediante proceso automático de limpieza
- RN-9: Al iniciar sesión o registrarse, el carrito invitado se fusiona con el carrito del usuario registrado si ya tiene uno activo
- RN-10: El carrito almacena un snapshot del precio al agregar el producto con fines informativos, pero el precio final al pagar es el vigente en ese momento

---

#### RF-CAR-002 — Indicadores de Cambio de Precio en Carrito

| Campo | Valor |
|---|---|
| **Módulo** | Carrito |
| **Versión** | V1 |
| **Actores** | Cliente |
| **Precondiciones** | Producto en carrito con precio modificado |

**Requerimientos funcionales:**
- RF-CAR-002-1: Cuando el precio baja, mostrar etiqueta visual destacada ("Precio bajó") con precio anterior tachado
- RF-CAR-002-2: Cuando el precio sube, mostrar mensaje informativo con precio anterior
- RF-CAR-002-3: Los cambios de precio deben reflejarse antes de proceder al checkout

---

### RF-CHK — Checkout

---

#### RF-CHK-001 — Flujo de Checkout

| Campo | Valor |
|---|---|
| **Módulo** | Checkout |
| **Versión** | V1 |
| **Actores** | Cliente registrado, Cliente invitado |
| **Precondiciones** | Carrito con al menos un producto disponible |

**Descripción:**
El checkout es el flujo mediante el cual el usuario completa la compra. Una sola página con comportamiento visual tipo multi-step (stepper).

**Pasos del flujo:**
1. Identificación del usuario (autenticado / guest / login durante checkout)
2. Dirección de envío
3. Dirección de facturación (misma que envío o diferente)
4. Método de envío (opciones de ShipEngine + opción de seguro de envío)
5. Método de pago
6. Revisión de orden (subtotal + envío + impuesto + total)
7. Confirmación

**Requerimientos funcionales:**
- RF-CHK-001-1: El sistema debe permitir compra como usuario invitado (guest checkout)
- RF-CHK-001-2: El sistema debe permitir iniciar sesión durante el checkout sin perder el progreso
- RF-CHK-001-3: En el paso de envío, mostrar opciones con costo y tiempo estimado filtradas según configuración del CRM
- RF-CHK-001-4: La revisión de orden debe mostrar: productos, cantidades, subtotal, costo de envío, impuestos (desglosados) y total final
- RF-CHK-001-5: El sistema debe validar stock actualizado antes de procesar el pago
- RF-CHK-001-6: El sistema debe validar precios actualizados antes de procesar el pago
- RF-CHK-001-7: Al confirmar la compra, el sistema debe: crear la orden, procesar el pago, descontar inventario, y enviar notificaciones al cliente

**Reglas de negocio:**
- RN-1: No se almacenarán métodos de pago en V1
- RN-2: Los precios se muestran sin impuestos; el impuesto se calcula y muestra en el resumen final
- RN-3: Todos los datos sensibles de tarjeta serán tokenizados por el proveedor de pago — nunca almacenados en el sistema

**Consideraciones de seguridad:**
- Uso de HTTPS en todo el proceso
- Tokenización de pagos (Stripe)
- No almacenar datos de tarjeta

**Extensiones futuras:**
- Checkout express (Apple Pay, Google Pay vía Stripe)
- One-click purchase para usuarios recurrentes
- Autocompletado de direcciones
- Cálculo de costo de envío desde el carrito (pre-checkout)

---

#### RF-CHK-002 — Manejo de Pagos Rechazados

| Campo | Valor |
|---|---|
| **Módulo** | Checkout |
| **Versión** | V1 |
| **Actores** | Cliente, Sistema |
| **Precondiciones** | Pago procesado y rechazado |

**Requerimientos funcionales:**
- RF-CHK-002-1: Mostrar mensaje claro y amigable indicando que el pago fue rechazado (sin mensajes técnicos)
- RF-CHK-002-2: No eliminar el carrito ni la información del checkout al rechazar el pago
- RF-CHK-002-3: Permitir al usuario reintentar el pago
- RF-CHK-002-4: Permitir al usuario cambiar el método de pago sin reiniciar el flujo

---

### RF-PAG — Pagos e Impuestos

---

#### RF-PAG-001 — Pasarela de Pago

| Campo | Valor |
|---|---|
| **Módulo** | Pagos |
| **Versión** | V1 |
| **Actores** | Cliente, Sistema |
| **Precondiciones** | — |

**Descripción:**
El sistema utilizará **Stripe** como pasarela de pago única en V1. Decisión confirmada por stakeholders. Se habilitarán Apple Pay y Google Pay desde el lanzamiento ya que Stripe los incluye sin costo adicional de integración.

**Stripe — características clave:**

| Aspecto | Detalle |
|---|---|
| Costo por transacción | 2.9% + $0.30 |
| Métodos soportados | Tarjetas de crédito/débito, Apple Pay, Google Pay |
| Tarjetas internacionales | Soportadas por Stripe (revisar impacto de cargos por divisa — no bloqueante para V1) |
| Seguridad | PCI DSS Level 1, tokenización, 3D Secure opcional |
| Experiencia de desarrollo | SDK robusto para Next.js/NestJS, bien documentado |
| Disponibilidad | Alta disponibilidad, SLA garantizado |

**Requerimientos funcionales:**
- RF-PAG-001-1: El sistema debe integrarse con Stripe para procesar pagos con tarjeta de crédito/débito
- RF-PAG-001-2: El sistema debe habilitar Apple Pay y Google Pay mediante Stripe desde V1
- RF-PAG-001-3: El sistema debe manejar errores y rechazos de Stripe de forma clara para el usuario
- RF-PAG-001-4: Todos los datos de tarjeta deben ser manejados por Stripe directamente (tokenización) — nunca por el backend del e-commerce

**Reglas de negocio:**
- RN-1: Stripe es el único proveedor de pagos en V1 — no se implementará PayPal
- RN-2: Los pagos con tarjetas de otros países son soportados por Stripe; revisar configuración de divisas antes del lanzamiento (no bloqueante)

---

#### RF-PAG-002 — Estrategia de Precios (Diferencial con Marketplaces)

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo / Pagos |
| **Versión** | V1 |
| **Actores** | Super administrador, Empleados (creación de listings) |
| **Precondiciones** | — |

**Descripción:**
La tienda propia ofrecerá precios siempre menores a los marketplaces como eBay. El modelo de precios está diseñado para soportar múltiples canales de venta — cada canal tiene su propio porcentaje de descuento y precio calculado independientemente. El empleado ingresa un único **precio base** (`base_price`) que representa el precio real de referencia; el sistema calcula automáticamente el precio final para cada canal activo.

**Campos de precio por listing:**

| Campo en BD | Definido por | Descripción |
|---|---|---|
| `base_price` | Empleado (manual) | Precio real de referencia. Es el precio "original" mostrado tachado en la GTS Store |
| `ebay_discount_pct` | Sistema (configuración) | % de descuento para eBay. **0% por defecto en V1** — el precio en eBay es igual al `base_price` |
| `ebay_price` | Sistema (calculado) | `base_price × (1 − ebay_discount_pct)` |
| `store_discount_pct` | Sistema (snapshot del descuento global) | % de descuento para la GTS Store, tomado del descuento global vigente al momento de crear el listing |
| `store_price` | Sistema (calculado) | `base_price × (1 − store_discount_pct)` — precio final que paga el cliente en la tienda |

> Los campos calculados se almacenan al guardar el listing. Si el super administrador cambia el descuento global posteriormente, los listings ya existentes **no se ven afectados** — solo los nuevos listings usarán el nuevo porcentaje.

> Este modelo está preparado para agregar canales futuros (ej. Amazon) sin cambios estructurales en la base de datos — solo se añaden las columnas del nuevo canal (`amazon_discount_pct`, `amazon_price`).

**Sección de configuración de precios (panel administrativo — CRM):**
El super administrador accede a la sección **Configuración de Precios** dentro del panel administrativo del CRM para definir el porcentaje de descuento global por canal. Esta sección es exclusiva del rol Super Administrador y permite:
- Consultar el porcentaje de descuento vigente para cada canal (GTS Store, eBay)
- Modificar el porcentaje de descuento para la GTS Store
- Ver el historial de cambios de configuración (para auditoría)

> El cambio en el porcentaje de descuento aplica únicamente a los listings creados a partir de ese momento — los listings ya existentes conservan el porcentaje con el que fueron creados (ver RN-3).

**Flujo:**
1. Super administrador accede a la sección **Configuración de Precios** en el CRM y define el porcentaje de descuento global para la GTS Store (ej. 5%)
2. Empleado abre el formulario de creación del listing e ingresa el `base_price` (ej. $1,105)
3. El formulario muestra en tiempo real la preview por canal:
   - eBay: $1,105 (0% descuento)
   - GTS Store: ~~$1,105~~ **$1,049** `5% OFF`
4. Al guardar, el sistema almacena todos los campos de precio por canal
5. En la tienda el cliente ve el precio original tachado, el precio con descuento y el badge con el porcentaje

**Requerimientos funcionales:**
- RF-PAG-002-1: El super administrador debe poder configurar el porcentaje de descuento global para la GTS Store desde el panel administrativo del CRM
- RF-PAG-002-2: El formulario de creación de listings debe mostrar en tiempo real la preview de precios por canal mientras el empleado escribe el `base_price`
- RF-PAG-002-3: Al guardar el listing, el sistema debe calcular y almacenar el precio y porcentaje de descuento de cada canal activo con base en la configuración vigente
- RF-PAG-002-4: El listing debe mostrar visualmente en la tienda el `base_price` tachado, el `store_price` en grande y un badge con `store_discount_pct` (ej. "5% OFF")
- RF-PAG-002-5: El empleado ingresa únicamente `base_price` — todos los precios por canal los calcula el sistema

**Reglas de negocio:**
- RN-1: El descuento global de la GTS Store es configurable únicamente por el super administrador
- RN-2: El `store_price` siempre debe ser menor al `base_price` (descuento global > 0%)
- RN-3: El porcentaje de descuento queda congelado en el listing al momento de su creación; cambios posteriores al descuento global no afectan listings existentes
- RN-4: En V1, el descuento de eBay es 0% — el precio publicado en eBay es igual al `base_price`
- RN-5: Agregar un nuevo canal en el futuro requiere definir su porcentaje de descuento en la configuración del sistema y añadir sus campos correspondientes al listing

**Extensiones futuras:**
- Sistema de descuentos avanzados: ofertas por listing con fecha de expiración, cupones, campañas automáticas (Black Friday, etc.), descuentos por volumen — pendiente definir en sesión dedicada con stakeholders
- Configuración de descuento independiente por canal adicional (ej. Amazon)

---

#### RF-PAG-003 — Impuestos (Sales Tax)

| Campo | Valor |
|---|---|
| **Módulo** | Pagos |
| **Versión** | V1 |
| **Actores** | Sistema, Cliente |
| **Precondiciones** | Dirección de envío definida en checkout |

**Descripción:**
El sistema calculará y aplicará Sales Tax conforme a las tasas configuradas en el CRM de GreenTek.

**Decisiones confirmadas:**

| Aspecto | Decisión |
|---|---|
| Visualización de precios | Sin impuestos; se agregan en el resumen del checkout |
| Granularidad del cálculo | Por estado (no por ZIP code ni ciudad) |
| Fuente de tasas | Tabla configurada en el CRM (estado/país + porcentaje) |
| Servicio externo | No se usará en V1 (TaxJar, Avalara, Stripe Tax) |
| Exenciones | No aplica en V1 — todos los clientes pagan el impuesto correspondiente |
| Clientes con certificado de exención | En V1: contactar a GreenTek por email/teléfono para tramitar devolución del impuesto |

**Requerimientos funcionales:**
- RF-PAG-003-1: El sistema debe obtener la tasa de impuesto aplicable consultando la tabla del CRM según el estado de la dirección de envío
- RF-PAG-003-2: El impuesto debe calcularse sobre el subtotal de productos (sin incluir envío, a menos que aplique)
- RF-PAG-003-3: El monto del impuesto debe mostrarse desglosado en el resumen del checkout antes del pago
- RF-PAG-003-4: El comprobante de compra debe mostrar todos los montos: subtotal, envío, impuesto y total

**Extensiones futuras:**
- Integración con servicio externo de impuestos para mayor precisión
- Módulo de certificado de exención fiscal (cliente sube certificado durante checkout para quedar exento del impuesto)

---

#### RF-PAG-004 — Sistema de Cupones y Promociones

| Campo | Valor |
|---|---|
| **Módulo** | Pagos / Marketing |
| **Versión** | Futura |
| **Actores** | Administrador, Cliente |
| **Precondiciones** | — |

**Tipos de cupones:**
- Descuento por porcentaje (ej. 10% en toda la tienda)
- Descuento por monto fijo (ej. $20 en compras mayores a $200)
- Cupón específico por usuario
- Cupón por categoría

**Condiciones configurables:** Fecha de expiración, usos máximos, monto mínimo, restricción a registrados

**Reglas de negocio:**
- RN-1: Solo se puede usar un cupón por orden
- RN-2: Los cupones no se pueden combinar entre sí
- RN-3: El descuento no puede superar el subtotal
- RN-4: Los cupones no aplican sobre costos de envío (configurable)

**Extensiones futuras:**
- Descuentos automáticos sin código
- Descuentos por volumen
- Recuperación de carrito abandonado vía cupón: cuando un usuario deja productos en el carrito sin completar la compra, el sistema detecta el abandono y le envía automáticamente un email con un cupón de descuento para incentivar que regrese y finalice. El descuento aplica sobre el total del carrito abandonado tal como está — no sobre productos o marcas específicas

---

#### RF-PAG-005 — Sistema de Descuentos Avanzados (Alcance Futuro)

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo / Pagos / Marketing |
| **Versión** | Futura |
| **Actores** | Administrador |
| **Precondiciones** | RF-PAG-002 implementado |

**Descripción:**
En V1 el único mecanismo de descuento es el descuento global configurable (RF-PAG-002). El sistema de descuentos avanzados se implementará en versiones posteriores y deberá definirse en una sesión dedicada con stakeholders.

**Funcionalidades a definir en versión futura:**
- Precios de oferta por listing con fecha de expiración (precio tachado + precio de oferta temporal)
- Campañas de descuento automáticas (ej. Black Friday: X% en toda la tienda)
- Cupones y promociones (ver también RF-PAG-004)
- Descuentos por volumen (relacionado con módulo Wholesale)

---

### RF-ORD — Órdenes y Facturación

---

#### RF-ORD-001 — Ciclo de Vida de Órdenes

| Campo | Valor |
|---|---|
| **Módulo** | Órdenes |
| **Versión** | V1 |
| **Actores** | Sistema, Administrador, Cliente |
| **Precondiciones** | Pago procesado exitosamente |

**Descripción:**
Las órdenes representan la confirmación de compra y contienen toda la información necesaria para su procesamiento, envío y seguimiento.

**Información almacenada en la orden:**
- Datos del cliente (nombre, email, teléfono, tipo: registrado/invitado)
- Productos (ID, nombre, variación, precio histórico al momento de compra, cantidad, subtotal)
- Información financiera (subtotal, envío, impuestos, total)
- Dirección de envío y de facturación
- Carrier seleccionado, servicio, costo de envío, número de tracking

> **Nota:** La orden almacena **precios históricos** al momento de la compra para mantener consistencia contable.

**Estados de la orden:**

| Estado | Descripción |
|---|---|
| `pending` | Orden creada, pago en proceso |
| `paid` | Pago confirmado |
| `processing` | En preparación para envío |
| `shipped` | Enviada (carrier ha recogido el paquete y escaneado) |
| `delivered` | Entregada al cliente |
| `completed` | Orden cerrada |
| `cancelled` | Cancelada antes de generar cualquier label de envío |
| `partially_returned` | El cliente devolvió algunos productos; reembolso parcial procesado manualmente |
| `fully_returned` | El cliente devolvió todos los productos; reembolso total procesado manualmente |

**Requerimientos funcionales (Panel Admin — CRM):**
- RF-ORD-001-1: Visualizar listado de órdenes con filtro por estado
- RF-ORD-001-2: Ver detalle completo de una orden
- RF-ORD-001-3: Actualizar el estado de una orden manualmente (fallback)
- RF-ORD-001-4: Agregar número de tracking a una orden

**Requerimientos funcionales (Portal del cliente):**
- RF-ORD-001-5: El cliente puede cancelar su orden desde el portal desde el estado `paid` hasta antes de que se genere la label de envío en ShipEngine
- RF-ORD-001-6: El sistema debe bloquear la opción de cancelación en el momento en que se genera la label de envío — este evento es el punto de no retorno para cancelaciones
- RF-ORD-001-7: Una vez generada la label, el cliente no puede cancelar — debe esperar a recibir el paquete y solicitar una devolución dentro de los 30 días por email o teléfono

**Actualización automática de estados:**
- Los cambios de estado `shipped`, `delivered` y similares se actualizan automáticamente via webhooks del carrier (ShipEngine)
- El administrador puede actualizar el estado manualmente en caso de falla del webhook

**Reglas de negocio:**
- RN-1: Una orden no puede modificarse después de ser pagada (excepto por administrador)
- RN-2: El inventario se descuenta al confirmar el pago (patrón SAGA — ver RF-INV-001)
- RN-3: Cada orden almacena dos identificadores:
  - **UUID interno** (`uuid_ecommerce_order`): para uso técnico, integraciones y trazabilidad. Nunca se muestra al cliente.
  - **ID visible** (`id_ecommerce_order`): formato `GTS-YYYY-SO_ID` donde `SO_ID` es el identificador generado por el CRM en la tabla `so_info`. Ejemplo: `GTS-2026-15432`. Este es el identificador usado en emails, comprobantes y soporte al cliente.
- RN-4: **La generación de la label de envío de cualquier shipment bloquea la cancelación de toda la orden** — no del shipment individual ni del escaneo del carrier
- RN-5: El identificador visible se genera únicamente después de que el CRM cree la orden y devuelva el `so_id`

---

#### RF-ORD-002 — Comprobante de Compra

| Campo | Valor |
|---|---|
| **Módulo** | Órdenes |
| **Versión** | V1 |
| **Actores** | Sistema, Cliente |
| **Precondiciones** | Orden pagada |

**Descripción:**
Al confirmar el pago, el sistema envía inmediatamente un comprobante de compra al cliente. No se emiten facturas formales — el comprobante es el único documento de la transacción. La integración con QuickBooks fue eliminada del alcance del e-commerce.

**Flujo:**

```
Cliente completa el pago
    └── INMEDIATO: Pantalla de confirmación de compra
        ├── Muestra resumen de la orden
        └── Opción de descarga del comprobante en PDF (disponible para invitados y registrados)

    └── INMEDIATO: Email de confirmación al cliente
        ├── Resumen de la orden
        └── Link a la vista de detalle de la orden
                └── Desde esa vista: seguimiento de la orden + descarga del comprobante en PDF

    └── [Solo clientes registrados] Comprobante también disponible en el portal,
            sección historial de órdenes, con descarga PDF
```

**Contenido del comprobante:**
- Número de orden
- Fecha y hora de la compra
- Listado de productos (nombre, variación, condición, cantidad, precio unitario, subtotal)
- Desglose: subtotal de productos, costo(s) de envío, impuesto(s), **total**
- Dirección de envío
- Método de pago (últimos 4 dígitos)
- Bodega(s) de origen si aplica multi-bodega

**Requerimientos funcionales:**
- RF-ORD-002-1: Al confirmar el pago, el sistema debe mostrar una pantalla de confirmación de compra con resumen de la orden y opción de descargar el comprobante en PDF
- RF-ORD-002-2: El comprobante debe incluir todos los montos desglosados: subtotal, envío, impuesto y total
- RF-ORD-002-3: El sistema debe enviar inmediatamente un email de confirmación al cliente con un link a la vista de detalle de su orden; desde esa vista el cliente puede ver el estado de la orden y descargar el comprobante en PDF
- RF-ORD-002-4: Si el cliente tiene cuenta registrada, el comprobante debe estar disponible adicionalmente desde su portal en la sección de historial de órdenes, con opción de descarga PDF
- RF-ORD-002-5: Los clientes invitados (guest) no tienen portal — acceden al detalle de la orden y al PDF a través de la pantalla de confirmación inmediata y del link enviado por email

**Reglas de negocio:**
- RN-1: El comprobante es el único documento de compra generado por el e-commerce — no se emiten facturas fiscales
- RN-2: Tanto clientes registrados como invitados pueden descargar el comprobante en PDF: inmediatamente en la pantalla de confirmación y posteriormente desde el link del email
- RN-3: El PDF se genera bajo demanda al momento en que el cliente lo solicita

---

#### RF-ORD-003 — Horario Laboral y SLA de Procesamiento de Órdenes

| Campo | Valor |
|---|---|
| **Módulo** | Órdenes / Operación |
| **Versión** | V1 (documentar e informar al cliente) |
| **Actores** | Equipo de GreenTek, Cliente |
| **Precondiciones** | — |

**Descripción:**
La tienda opera y recibe órdenes 24/7 de forma autónoma. Sin embargo, el procesamiento humano de las órdenes (preparación, despacho) se realiza únicamente en horario laboral. Esta información debe estar disponible para el cliente en las secciones de soporte, FAQ y Términos y Condiciones.

**Horario de operación del equipo:**
- **Días:** Lunes a Viernes
- **Horas:** 8:00 AM – 5:00 PM (Central Time)
- **Días sin procesamiento:** Fines de semana y major holidays de EE.UU.
- **SLA de procesamiento:** Las órdenes pagadas se procesan dentro de las 24 horas hábiles siguientes al pago

**Ejemplos de comunicación al cliente:**

| Momento de compra | Cuándo se procesa |
|---|---|
| Lunes – Jueves antes de las 5 PM CT | Mismo día o siguiente día hábil |
| Viernes | Lunes siguiente |
| Fin de semana | Lunes siguiente |
| Día anterior a un holiday | Siguiente día hábil |

**Requerimientos funcionales:**
- RF-ORD-003-1: El horario de atención y el SLA de procesamiento deben estar documentados en T&C, FAQ y página de Contact Us
- RF-ORD-003-2 (Futura): El sistema debe contar con un **banner de anuncios** configurable en la tienda para comunicar mensajes especiales al cliente (ej. "Hoy estamos cerrados por holiday — las órdenes se procesarán el próximo lunes")

**Reglas de negocio:**
- RN-1: El procesamiento fuera de horario laboral es responsabilidad del cliente al elegir comprar en ese momento
- RN-2: Los fines de semana y holidays no cuentan para el conteo del SLA de 24 horas

---

### RF-LOG — Logística y Envíos

---

#### RF-LOG-001 — Integración ShipEngine

| Campo | Valor |
|---|---|
| **Módulo** | Logística |
| **Versión** | V1 |
| **Actores** | Sistema, Cliente |
| **Precondiciones** | ShipEngine ya configurado con carriers de GreenTek |

**Descripción:**
El sistema utilizará ShipEngine como motor de cotización y gestión de envíos. ShipEngine ya está configurado en el entorno de GreenTek.

**Requerimientos funcionales:**
- RF-LOG-001-1: El sistema debe consultar ShipEngine para cotizar opciones de envío durante el checkout (listings con política `Normal`)
- RF-LOG-001-2: Solo deben mostrarse los carriers y servicios configurados en el CRM de GreenTek
- RF-LOG-001-3: Cada opción de envío debe mostrar carrier, servicio, costo y tiempo estimado de entrega
- RF-LOG-001-4: ShipEngine debe enviar webhooks al sistema para actualizar el estado de la orden automáticamente
- RF-LOG-001-5: Si ShipEngine no está disponible durante el checkout, el sistema debe usar el **costo fijo de envío** configurado en cada listing como fallback (ocultar selección de carrier/servicio y mostrar costo fijo calculado)

**Reglas de negocio:**
- RN-1: El costo fijo de envío es un campo obligatorio al crear cualquier listing — se utiliza como fallback cuando ShipEngine no está disponible
- RN-2: En modo fallback, el cliente ve el costo fijo por unidad multiplicado por la cantidad; no puede seleccionar carrier ni servicio

**Puntos pendientes:**
- Confirmar lista específica de carriers habilitados (equipo de desarrollo revisar configuración actual de ShipEngine/CRM)

---

#### RF-LOG-002 — Restricciones de Ubicación

| Campo | Valor |
|---|---|
| **Módulo** | Logística |
| **Versión** | V1 |
| **Actores** | Administrador, Sistema |
| **Precondiciones** | — |

**Descripción:**
El sistema bloqueará envíos a ubicaciones no permitidas mediante una lista negra configurable desde el CRM.

**Requerimientos funcionales:**
- RF-LOG-002-1: El administrador debe poder configurar una lista de ubicaciones restringidas
- RF-LOG-002-2: El sistema debe bloquear el checkout si la dirección de envío está en la lista negra

**Ejemplos de restricciones:** Hawaii, Puerto Rico, direcciones militares (APO/FPO)

---

#### RF-LOG-003 — Políticas de Envío por Listing

| Campo | Valor |
|---|---|
| **Módulo** | Logística / Catálogo |
| **Versión** | V1 |
| **Actores** | Administrador (al crear el listing) |
| **Precondiciones** | — |

**Descripción:**
Cada listing tiene una **política de envío** que determina cómo se cotiza y cobra el envío al cliente. Esta política se configura al crear el listing y se basa en los tipos de envío de eBay. El cliente no puede seleccionar carrier ni servicio en los modos Freight y Free.

**Tipos de política de envío:**

| Política | Comportamiento | Selección de carrier/servicio |
|---|---|---|
| `Normal` | ShipEngine cotiza opciones en tiempo real | Sí — cliente elige |
| `Freight` | Precio fijo por producto configurado al crear el listing, sin importar el destino | No |
| `Free` | Sin costo de envío | No |

**Detalle por política:**

**Normal:**
- El checkout consulta ShipEngine y muestra opciones de carrier, servicio, costo y tiempo estimado
- El cliente elige la opción que prefiera
- Si ShipEngine no está disponible, se usa el costo fijo del listing como fallback (ver RF-LOG-001-5)

**Freight:**
- Al crear el listing se captura un precio fijo de envío por unidad
- En el checkout se muestra ese precio fijo sin opciones de carrier — el cliente acepta o no procede con ese producto
- En V1 no hay alternativa al precio Freight — el pickup en bodega no está disponible en esta versión (ver RF-LOG-005)

**Free:**
- El envío no tiene costo para el cliente
- En el checkout se indica "Envío gratuito" sin mostrar opciones de carrier
- El costo de envío lo absorbe GreenTek

**Requerimientos funcionales:**
- RF-LOG-003-1: Cada listing debe tener un campo `política de envío` con las opciones: `Normal`, `Freight`, `Free`
- RF-LOG-003-2: Los listings con política `Freight` deben requerir un campo `precio fijo de envío por unidad` obligatorio
- RF-LOG-003-3: Cada listing debe incluir peso y dimensiones del producto (requerido para ShipEngine en política `Normal`)
- RF-LOG-003-4: El checkout debe adaptar la UI de envío según la política del listing en el carrito
- RF-LOG-003-5 (Futura): El sistema debe ofrecer un catálogo de paquetes estándar para facilitar la captura de dimensiones

**Reglas de negocio:**
- RN-1: Un carrito puede tener productos con diferentes políticas de envío; cada shipment se cotiza según su política
- RN-2: Los listings con política `Free` o `Freight` no muestran opciones de carrier/servicio al cliente

---

#### RF-LOG-004 — Envíos Gratuitos

| Campo | Valor |
|---|---|
| **Módulo** | Logística |
| **Versión** | Futura |
| **Actores** | Administrador |
| **Precondiciones** | Reglas definidas por el negocio |

**Descripción:** El envío gratuito se implementará en una versión futura. GreenTek confirma que habrá envío gratuito en la tienda pero los detalles exactos (monto mínimo, temporadas, carriers aplicables, exclusiones de categoría) se definirán en su momento.

**Puntos a definir cuando se retome:**
- ¿Aplica a partir de un monto mínimo de compra? ¿Cuánto?
- ¿Aplica para todos los carriers o solo para algunos?
- ¿Aplica de forma permanente o por temporadas/campañas?
- ¿Hay categorías o productos excluidos (ej. productos de gran tamaño)?

---

#### RF-LOG-005 — Recoger en Bodega (Pickup)

| Campo | Valor |
|---|---|
| **Módulo** | Logística |
| **Versión** | Futura |
| **Actores** | Cliente |
| **Precondiciones** | — |

**Opciones a evaluar:**
- Recoger en bodega de GreenTek (requiere indicar disponibilidad por bodega)
- Recoger en punto de transportista (investigar soporte en ShipEngine)

---

#### RF-LOG-006 — Operación Multi-Bodega

| Campo | Valor |
|---|---|
| **Módulo** | Logística |
| **Versión** | V1 |
| **Actores** | Sistema, Administrador, Cliente |
| **Precondiciones** | — |

**Descripción:**
GreenTek Solutions opera desde **2 bodegas**. La información de ubicación de cada bodega está en la tabla `locations` del CRM. Cada ítem de inventario tiene un campo `warehouse_id` que referencia su bodega. Una orden puede generar múltiples shipments si los productos provienen de distintas bodegas.

**Decisiones confirmadas:**

| Aspecto | Decisión |
|---|---|
| Número de bodegas | 2 actualmente |
| Fuente de la ubicación | `inventory.warehouse_id` → tabla `locations` en CRM |
| ¿Listing en múltiples bodegas? | Sí — un listing puede tener items en ambas bodegas |
| Envíos por orden | Una sola orden, múltiples shipments (uno por bodega involucrada) |
| Costo de envíos múltiples | El cliente paga cada shipment por separado; total visible en checkout |
| Consolidación de envíos | No aplica en V1 |
| Visibilidad de bodega | El cliente ve de qué bodega proviene cada shipment |

**Caso: producto disponible en 2 bodegas (cliente compra 1 unidad):**
- El checkout muestra 2 cotizaciones de envío (una por bodega)
- El cliente elige de qué bodega quiere recibir el producto
- Se genera 1 shipment desde la bodega elegida

**Caso: cliente compra 2 unidades del mismo listing y cada una está en una bodega diferente:**
- Se generan 2 shipments automáticamente
- El cliente ve y paga el costo de envío de cada shipment en el checkout

**Caso: orden con productos de 2 bodegas distintas (diferentes listings):**
- Se genera 1 orden con 2 shipments
- El cliente paga ambos costos de envío
- El comprobante detalla cada shipment por separado

**Requerimientos funcionales:**
- RF-LOG-006-1: El sistema debe leer `inventory.warehouse_id` para determinar la bodega de origen de cada item
- RF-LOG-006-2: Si una orden incluye products de múltiples bodegas, se debe generar un shipment independiente por bodega
- RF-LOG-006-3: El checkout debe cotizar y mostrar el costo de envío de cada shipment por separado
- RF-LOG-006-4: Cuando un producto está disponible en 2 bodegas, el checkout debe mostrar ambas cotizaciones de envío para que el cliente elija
- RF-LOG-006-5: El cliente debe ver claramente de qué bodega proviene cada shipment en el detalle de la orden y en el comprobante

**Reglas de negocio:**
- RN-1: Una orden es una sola transacción de pago, independientemente del número de shipments
- RN-2: No hay consolidación de envíos entre bodegas en V1 — cada bodega genera su propio shipment
- RN-3: No hay recargo adicional de GreenTek por envíos múltiples — el cliente paga las tarifas de carrier de cada shipment

---

#### RF-LOG-007 — Seguro de Envío (Opcional)

| Campo | Valor |
|---|---|
| **Módulo** | Logística |
| **Versión** | V1 |
| **Actores** | Cliente, Sistema |
| **Precondiciones** | ShipEngine configurado con opciones de seguro |

**Descripción:**
El cliente podrá optar por agregar seguro de envío a su pedido durante el checkout. Es una opción voluntary, no obligatoria.

**Requerimientos funcionales:**
- RF-LOG-007-1: El sistema debe mostrar la opción de seguro de envío en el paso de método de envío del checkout
- RF-LOG-007-2: El costo del seguro debe mostrarse claramente y sumarse al total si el cliente lo selecciona
- RF-LOG-007-3: La configuración del seguro se gestiona mediante la API de ShipEngine

**Puntos pendientes:**
- Revisar la configuración actual de seguro de envío en ShipEngine/CRM (equipo de desarrollo)

---

### RF-NOT — Notificaciones

---

#### RF-NOT-001 — Notificaciones al Cliente

| Campo | Valor |
|---|---|
| **Módulo** | Notificaciones |
| **Versión** | V1 |
| **Actores** | Sistema |
| **Precondiciones** | Orden creada o actualizada |

**Descripción:**
El sistema enviará notificaciones por email a los clientes en eventos clave del ciclo de vida de la orden.

**Eventos con notificación automática:**

| Evento | Contenido clave |
|---|---|
| Compra confirmada (pago exitoso) | Comprobante de compra: número de orden (`GTS-YYYY-SO_ID`), productos, montos desglosados (subtotal, envío, impuesto, total), dirección de envío, link de acceso al detalle de la orden, link para descargar el PDF del comprobante |
| Orden enviada (por shipment) | Se envía **un email por cada shipment** cuando su label es generada. Incluye: número de tracking del shipment, enlace al sitio del carrier, bodega de origen, productos incluidos en ese shipment |
| Orden entregada | Confirmación de entrega, recordatorio de política de devoluciones y garantía (30 días para devolución; hasta 1 año para garantía) |

> **Nota:** Las facturas fiscales no son generadas ni enviadas por el e-commerce. Si el cliente requiere su factura, debe solicitarla a GreenTek directamente por email o teléfono.

**Extensiones futuras:**
- Notificación de restock de producto agotado
- Notificación de cambio de precio en producto en carrito

---

#### RF-NOT-002 — Alertas de Stock (Admin)

| Campo | Valor |
|---|---|
| **Módulo** | Notificaciones |
| **Versión** | Futura |
| **Actores** | Administrador |
| **Precondiciones** | Stock configurado |

**Descripción:**
El sistema notificará a los administradores cuando el stock de un producto llegue a un umbral definido.

**Ejemplo:** Alerta cuando stock ≤ 5 unidades (umbral configurable)

---

#### RF-NOT-003 — Aviso de Restock a Clientes

| Campo | Valor |
|---|---|
| **Módulo** | Notificaciones |
| **Versión** | Futura |
| **Actores** | Cliente |
| **Precondiciones** | Producto en estado `out_of_stock` |

**Descripción:**
Los usuarios podrán suscribirse para recibir una notificación cuando un producto agotado vuelva a tener stock disponible.

---

### RF-PCV — Post-venta y Atención al Cliente

---

#### RF-PCV-001 — Tracking de Órdenes

| Campo | Valor |
|---|---|
| **Módulo** | Post-venta |
| **Versión** | V1 |
| **Actores** | Cliente registrado, Cliente invitado |
| **Precondiciones** | Orden en estado `shipped` o superior |

**Requerimientos funcionales:**
- RF-PCV-001-1: El cliente autenticado debe poder ver su historial de órdenes y el detalle de cada una
- RF-PCV-001-2: El cliente invitado debe poder acceder a su orden mediante link por email o mediante número de orden + email
- RF-PCV-001-3: El sistema debe mostrar el número de tracking con enlace al sitio del carrier

---

#### RF-PCV-002 — Política de Devoluciones y Garantías

| Campo | Valor |
|---|---|
| **Módulo** | Post-venta |
| **Versión** | V1 (información) — Futura (automatización) |
| **Actores** | Cliente, Equipo de soporte |
| **Precondiciones** | — |

**Descripción:**
En V1, el proceso de devoluciones y garantías se gestiona manualmente a través de email y teléfono. El e-commerce proporcionará información clara y accesible sobre la política al cliente.

**Política de garantía y devoluciones (confirmada):**

| Periodo | ¿Quién decide la resolución? | Opciones de resolución |
|---|---|---|
| 0 – 30 días desde entrega | El cliente | Devolución de dinero o reemplazo del producto |
| 30 días – 1 año desde entrega | GreenTek | Reparación, reemplazo o reembolso (a criterio de GreenTek) |

**Costo de envío en devoluciones:** GreenTek cubre el costo del envío de retorno.

**Proceso de devolución en V1 (manual):**
1. Cliente contacta a GreenTek por **email o teléfono** dentro del plazo aplicable
2. Puede devolver productos parciales o la totalidad de la orden
3. GreenTek proporciona instrucciones y espera a recibir físicamente el/los productos
4. Una vez recibidos, GreenTek procesa el reembolso de forma manual (transferencia, cheque u otro medio acordado)
5. El administrador actualiza la orden al estado correspondiente:
   - `partially_returned` si solo algunos productos fueron devueltos
   - `fully_returned` si se devolvieron todos los productos
6. Se registra metadata de la devolución en la orden: fecha, hora, motivo, ítems devueltos

**Requerimientos funcionales (V1 — informativo):**
- RF-PCV-002-1: El e-commerce debe incluir una página de política de devoluciones y garantías visible y accesible
- RF-PCV-002-2: Desde el detalle de la orden, el cliente debe poder ver información clara sobre cómo iniciar una devolución o garantía
- RF-PCV-002-3: La sección de FAQ debe incluir información sobre el proceso de devoluciones
- RF-PCV-002-4: El email de entrega (orden `delivered`) debe incluir recordatorio de la política de garantía y devoluciones
- RF-PCV-002-5: El administrador debe poder marcar una orden como `partially_returned` o `fully_returned` y registrar los metadatos de la devolución (ítems devueltos, fecha, motivo)

**Reglas de negocio:**
- RN-1: La garantía aplica a **todos los productos** sin excepción ni exclusión por categoría o condición
- RN-2: El plazo para solicitar devolución es de **30 días desde la entrega**
- RN-3: Después de los 30 días y hasta cumplir 1 año, la garantía aplica pero la resolución (reparación, reemplazo o reembolso) es decisión de GreenTek
- RN-4: GreenTek cubre el costo del envío de retorno
- RN-5: El reembolso en V1 es manual — GreenTek procesa el pago al cliente una vez que recibe físicamente los productos devueltos
- RN-6: Las facturas fiscales no son gestionadas por el e-commerce — el cliente debe solicitarlas directamente a GreenTek

**Puntos pendientes:**
- Los stakeholders deben redactar/actualizar el documento de Política de Devoluciones antes del lanzamiento

**Extensiones futuras:**
- Solicitudes de devolución desde el portal (flujo digitalizado)
- Generación de etiquetas de envío para devolución
- Automatización de reembolsos vía Stripe

---

#### RF-PCV-003 — Panel de Gestión de Interacciones

| Campo | Valor |
|---|---|
| **Módulo** | Post-venta / Soporte |
| **Versión** | Futura |
| **Actores** | Administrador, Cliente |
| **Precondiciones** | — |

**Descripción:**
Panel centralizado en el CRM para gestionar preguntas de clientes sobre listings y comunicaciones relacionadas a órdenes.

**Tipos de interacción:**
1. Preguntas sobre listings (pueden ser visibles al público si el admin lo decide)
2. Comunicación sobre órdenes (siempre privada, disponible solo después del pago)

**Requerimientos funcionales:**
- RF-PCV-003-1: Panel tipo inbox con filtros por tipo y estado
- RF-PCV-003-2: Respuestas a preguntas de listings pueden ser públicas o privadas
- RF-PCV-003-3: Comunicaciones de órdenes siempre privadas

---

### RF-MKT — Marketing y Contenido

---

#### RF-MKT-001 — FAQ (Preguntas Frecuentes)

| Campo | Valor |
|---|---|
| **Módulo** | Contenido |
| **Versión** | V1 |
| **Actores** | Cliente, Administrador (roles `ADMINISTRATOR`, `MANAGER`) |
| **Precondiciones** | — |

**Descripción:**
Sección de preguntas frecuentes para resolver dudas comunes, reducir carga de soporte e informar sobre políticas. Las preguntas se organizan por grupos (categorías) y la API las expone ya agrupadas para simplificar el renderizado en el frontend.

**Requerimientos funcionales:**
- RF-MKT-001-1: El sistema debe mostrar únicamente las preguntas con estado activo (`is_active = true`)
- RF-MKT-001-2: El administrador debe poder crear, editar y eliminar preguntas desde el CRM (roles `ADMINISTRATOR` o `MANAGER`)
- RF-MKT-001-3: El administrador debe poder activar o desactivar preguntas individualmente — las preguntas desactivadas se conservan en el sistema pero no se muestran en la tienda
- RF-MKT-001-4: Las preguntas pertenecen a un grupo (`group`) que actúa como categoría. El campo es requerido al crear y sirve como agrupador en la respuesta de la API
- RF-MKT-001-5: `GET /v1/faqs` retorna todas las preguntas activas agrupadas: `[{ group: string, faqs: FAQ[] }]`, ordenadas por grupo y `sort_order` dentro del grupo
- RF-MKT-001-6: `GET /v1/faqs/groups/:group` retorna las preguntas activas de un grupo específico por slug (case-insensitive). Retorna 404 si el grupo no tiene preguntas activas
- RF-MKT-001-7 (Futura): Incluir buscador dentro del FAQ

**Grupos iniciales (seed):** `Payments`, `Shipping`, `Returns`, `About GTS`, `Inventory`

**API — Endpoints públicos (sin autenticación):**

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/v1/faqs` | Todas las preguntas activas agrupadas por `group` |
| `GET` | `/v1/faqs/groups/:group` | Preguntas activas de un grupo específico (slug case-insensitive) |
| `GET` | `/v1/faqs/:id` | Pregunta activa por UUID |

**API — Endpoints administrativos (requiere JWT CRM — rol `ADMINISTRATOR` o `MANAGER`):**

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/v1/faqs` | Crear pregunta |
| `PATCH` | `/v1/faqs/:id` | Editar pregunta |
| `PATCH` | `/v1/faqs/:id/toggle-status` | Activar / desactivar |
| `DELETE` | `/v1/faqs/:id` | Soft delete (marca `is_active = false`) |

---

#### RF-MKT-002 — Redes Sociales y Links Externos

| Campo | Valor |
|---|---|
| **Módulo** | Contenido |
| **Versión** | V1 |
| **Actores** | Cliente |
| **Precondiciones** | — |

**Requerimientos funcionales:**
- RF-MKT-002-1: El footer debe incluir enlaces a redes sociales (Facebook, Instagram, LinkedIn)
- RF-MKT-002-2: Los enlaces deben abrirse en una nueva pestaña
- RF-MKT-002-3: Incluir enlace a la landing page corporativa de GreenTek

---

#### RF-MKT-003 — Formulario de Leads

| Campo | Valor |
|---|---|
| **Módulo** | Marketing |
| **Versión** | Futura |
| **Actores** | Visitante |
| **Precondiciones** | — |

**Descripción:**
Formulario para capturar datos de usuarios interesados en comprar o vender equipo tecnológico.

**Campos:** Nombre, email, teléfono (opcional), tipo de interés (comprar/vender), mensaje

---

#### RF-MKT-004 — Optimización SEO

| Campo | Valor |
|---|---|
| **Módulo** | Marketing / Catálogo |
| **Versión** | V1 |
| **Actores** | Sistema, Administrador |
| **Precondiciones** | — |

**Descripción:**
La plataforma debe estar optimizada para motores de búsqueda desde el lanzamiento, como parte de la estrategia de posicionamiento orgánico masivo planificada por GreenTek.

**Requerimientos funcionales:**
- RF-MKT-004-1: Todas las URLs deben ser amigables y descriptivas (ej. `/products/cisco-catalyst-switch-3750`)
- RF-MKT-004-2: Cada página de producto (listing) debe tener meta title y meta description editables
- RF-MKT-004-3: El sistema debe generar automáticamente un `sitemap.xml` actualizado
- RF-MKT-004-4: Las páginas de producto deben incluir datos estructurados (schema.org — Product, Offer, Review si aplica)
- RF-MKT-004-5: Las imágenes deben incluir atributos `alt` descriptivos
- RF-MKT-004-6: El sistema debe generar el archivo `robots.txt` correctamente configurado

**Extensiones futuras:**
- Integración con Google Analytics / Meta Pixel para seguimiento de campañas
- Email marketing via Mailchimp, Klaviyo u otra plataforma

---

### RF-ADM — Panel Administrativo

---

#### RF-ADM-001 — Gestión Administrativa General

| Campo | Valor |
|---|---|
| **Módulo** | Administración |
| **Versión** | V1 |
| **Actores** | Administrador |
| **Precondiciones** | Administrador autenticado en el CRM |

**Descripción:**
El panel administrativo está integrado al CRM existente (Angular). Las interfaces de gestión del e-commerce se implementarán como nuevas secciones del CRM. Los permisos y roles son heredados del sistema de usuarios del CRM.

**Módulos del panel administrativo:**

| Módulo | Funcionalidades principales | Prioridad |
|---|---|---|
| Clientes | Ver lista, ver historial de compras, bloquear/desbloquear cuentas | V1 |
| Listings | Crear, editar, publicar, despublicar, marcar restricciones de envío | V1 |
| Órdenes | Ver listado, filtrar, ver detalle, actualizar estado, agregar tracking, cancelar | V1 |
| Inventario | Ajustar stock, ver historial de cambios, alertas de sobreventa | V1 |
| Impuestos | Ver tabla de tasas por estado (configurada en CRM) | V1 |
| Configuración de precios | Configurar el porcentaje de descuento global por canal (GTS Store, eBay). Solo accesible para el rol Super Administrador. Ver RF-PAG-002 | V1 |
| Configuración de envíos | Gestionar restricciones de ubicación, carriers habilitados | V1 |
| FAQ | Crear, editar, eliminar preguntas frecuentes | V1 |
| Cupones | Crear, editar, activar/desactivar, ver métricas | Futura |
| Colecciones | Crear, editar, activar/desactivar | Futura |
| Interacciones | Panel de preguntas y mensajes de clientes | Futura |

---

### RF-AVZ — Funcionalidades Avanzadas (Alcance Futuro)

---

#### RF-AVZ-001 — Configurador de Servidores (Build Your Server)

| Campo | Valor |
|---|---|
| **Módulo** | Configurador |
| **Versión** | Futura |
| **Actores** | Cliente |
| **Precondiciones** | Catálogo de componentes disponible |

**Descripción:**
Herramienta interactiva para que el usuario construya una configuración personalizada de servidor, seleccionando componentes compatibles.

**Flujo:** Seleccionar base → Elegir componentes (CPU, RAM, storage) → Ver precio total en tiempo real → Agregar al carrito

---

#### RF-AVZ-002 — Asistente Inteligente de Configuración (IA)

| Campo | Valor |
|---|---|
| **Módulo** | Configurador — IA |
| **Versión** | Futura |
| **Actores** | Cliente |
| **Precondiciones** | Configurador de servidores implementado |

**Descripción:**
Extensión del configurador que incorpora IA para ayudar a los usuarios a seleccionar componentes compatibles y recomendar configuraciones en lenguaje natural.

---

#### RF-AVZ-003 — Pre-order / Backorder

| Campo | Valor |
|---|---|
| **Módulo** | Catálogo / Inventario |
| **Versión** | Futura |
| **Actores** | Administrador, Cliente |
| **Precondiciones** | — |

**Descripción:**
Funcionalidad para permitir la venta de productos que aún no están disponibles en inventario pero cuya llegada es conocida (ej. flotillas de equipo en tránsito).

**Caso de uso identificado:** GreenTek sabe que recibirá una flotilla de un modelo específico. Quiere publicar el listing de inmediato para prevender el inventario antes de su llegada.

**Puntos a definir antes de implementar:**
- ¿Cómo se muestra la fecha estimada de envío al cliente?
- ¿Cuándo se cobra al cliente (inmediato o al enviar)?
- ¿Límite de unidades en pre-order?
- ¿Qué pasa si la flotilla se retrasa o no llega?

---

#### RF-AVZ-004 — Exención Fiscal (Tax Exemption Certificate)

| Campo | Valor |
|---|---|
| **Módulo** | Pagos / Impuestos |
| **Versión** | Futura |
| **Actores** | Cliente, Sistema |
| **Precondiciones** | — |

**Descripción:**
Funcionalidad para clientes con certificado de exención de impuestos. El cliente sube su certificado durante el registro o el checkout, el sistema lo valida y aplica exención de Sales Tax a sus compras.

**Proceso en V1 (sin automatizar):** El cliente con certificado de exención debe contactar a GreenTek por email o teléfono para tramitar la devolución del impuesto cobrado.

---

#### RF-AVZ-005 — Canal Wholesale / B2B

| Campo | Valor |
|---|---|
| **Módulo** | Usuarios / Pagos / Catálogo |
| **Versión** | Futura |
| **Actores** | Clientes empresariales, Administrador |
| **Precondiciones** | — |

**Descripción:**
Canal de ventas al mayoreo para clientes empresariales (B2B), con precios especiales, volúmenes mínimos, opciones de pago extendidas y atención dedicada.

Ver documento completo: `propuesta_wholesale.md`

---

## 4. Requerimientos no funcionales

### RNF-001 — Rendimiento

| ID | Requerimiento | Prioridad |
|---|---|---|
| RNF-001-1 | Las páginas de listing deben cargar en menos de 3 segundos en conexión estándar | V1 |
| RNF-001-2 | El proceso de checkout debe responder en menos de 5 segundos en cada paso | V1 |
| RNF-001-3 | Las consultas al buscador deben retornar resultados en menos de 2 segundos | V1 |

### RNF-002 — Seguridad

| ID | Requerimiento | Prioridad |
|---|---|---|
| RNF-002-1 | Toda comunicación debe realizarse mediante HTTPS | V1 |
| RNF-002-2 | Los datos de tarjeta deben manejarse exclusivamente mediante tokenización (Stripe) — nunca almacenarse en el sistema | V1 |
| RNF-002-3 | El sistema debe proteger contra ataques CSRF, XSS e inyección SQL | V1 |
| RNF-002-4 | El acceso al panel administrativo debe requerir autenticación y autorización por roles (gestionado por CRM) | V1 |

### RNF-003 — Usabilidad

| ID | Requerimiento | Prioridad |
|---|---|---|
| RNF-003-1 | El diseño debe ser responsivo y funcionar correctamente en dispositivos móviles | V1 |
| RNF-003-2 | El checkout debe poder completarse en el menor número de pasos posible | V1 |
| RNF-003-3 | Los mensajes de error deben ser claros y orientados al usuario, sin mensajes técnicos | V1 |

### RNF-004 — Disponibilidad y Confiabilidad

| ID | Requerimiento | Prioridad |
|---|---|---|
| RNF-004-1 | La plataforma debe aspirar a una disponibilidad del 99.5% mensual | V1 |
| RNF-004-2 | El sistema debe manejar errores en integraciones externas (ShipEngine, pagos) sin bloquear el flujo al usuario | V1 |
| RNF-004-3 | Debe existir un mecanismo de actualización manual de estado de órdenes como fallback ante fallas de webhooks | V1 |

### RNF-005 — Mantenibilidad

| ID | Requerimiento | Prioridad |
|---|---|---|
| RNF-005-1 | La configuración de carriers, restricciones de envío, tasas de impuesto y parámetros operativos debe gestionarse desde el panel admin, sin cambios en código | V1 |
| RNF-005-2 | El sistema debe estar diseñado para agregar nuevos canales de venta (marketplaces) con cambios mínimos | Futura |

### RNF-006 — Escalabilidad

| ID | Requerimiento | Prioridad |
|---|---|---|
| RNF-006-1 | La arquitectura debe soportar un catálogo de hasta 8,000 listings activos sin degradación de rendimiento | V1 |
| RNF-006-2 | La infraestructura debe diseñarse para escalar horizontalmente ante picos de tráfico | V1 |

> **Contexto de volumen esperado:**
> - Catálogo al lanzamiento: 1,000 – 2,000 listings
> - Catálogo estable (versión madura): ~8,000 listings activos
> - Crecimiento de catálogo: ~1,000 listings/mes
> - Órdenes esperadas: escala ambiciosa de 1,000 hasta 20,000+ órdenes/mes a 6 meses del lanzamiento
>
> **Referencia de escala de tráfico en e-commerce:**
>
> | Escala | Órdenes/mes | Implicaciones de infraestructura |
> |---|---|---|
> | Pequeño | < 1,000 | Servidor compartido / VPS básico |
> | Mediano | 1,000 – 10,000 | VPS o cloud con auto-scaling básico |
> | Grande | 10,000 – 100,000 | Cloud con CDN, auto-scaling, cache distribuido |
> | Muy grande | > 100,000 | Arquitectura distribuida dedicada |
>
> El objetivo de GreenTek se sitúa en la categoría **mediano a grande**. La infraestructura debe diseñarse desde el inicio para escalar hacia ese rango sin refactorización mayor.

---

## 5. Integraciones externas

| Sistema | Propósito | Prioridad | Estado en V1 |
|---|---|---|---|
| **ShipEngine** | Cotización y gestión de envíos, webhooks de tracking | V1 | Configurado — pendiente confirmar lista exacta de carriers |
| **API de eBay** | Publicación y sincronización de listings, categorías y atributos; Order Notifications API para sincronización de stock | V1 | Acceso API configurado y habilitado |
| **Stripe** | Procesamiento de pagos: tarjetas, Apple Pay, Google Pay | V1 | Confirmado — pendiente integración técnica |
| **CRM interno GreenTek** | Inventario (`inventory`, `locations`), configuración de carriers, impuestos, órdenes (`so_info`) | V1 | V1: integración vía API del CRM |
| **Email transaccional** | Notificaciones al cliente (comprobante, estado de orden, tracking). Dev: Gmail SMTP. Producción: AWS SES o SendGrid. Módulo desacoplado del proveedor. | V1 | Pendiente configurar |
| **Google Analytics / Meta Pixel** | Analytics y tracking de campañas | Futura | Versión futura |
| **Email marketing (Mailchimp/Klaviyo)** | Newsletters y campañas | Futura | Versión futura |
| **Amazon / Walmart** | Publicación multicanal futura | Futura | Futuro |

---

## 6. Restricciones y supuestos

### 6.1 Restricciones confirmadas

- El sistema operará únicamente en el mercado de Estados Unidos (V1)
- V1 no incluye expansión internacional ni soporte multimoneda
- Los reembolsos en V1 son procesados manualmente
- El proceso de devoluciones y garantías en V1 es manual (email/teléfono)
- La sincronización de inventario con eBay se buscará automatizar desde V1 via Order Notifications API; si no es viable en su totalidad, se opera con flujo híbrido (automatización parcial + ajuste manual)
- No se usarán logos de fabricantes de terceros
- No hay migración de clientes existentes de eBay ni del CRM
- No hay importación masiva de listings en V1 — creación manual
- No se generan facturas fiscales formales directamente desde el e-commerce (QuickBooks via CRM)
- Social login (Google, etc.) no incluido en V1
- App móvil nativa no planificada

### 6.2 Supuestos

- ShipEngine ya está configurado con los carriers de GreenTek; la lista exacta de carriers será confirmada por el equipo de desarrollo (ver T-D-01)
- La API de eBay ya está configurada y habilitada para la cuenta de GreenTek
- Los stakeholders elaborarán los documentos legales (Términos y Condiciones, Política de Privacidad, Política de Devoluciones) antes del lanzamiento
- El dominio `store.greenteksolutions.com` será provisionado y configurado antes del lanzamiento

**Infraestructura por etapa:**

| Etapa | Frontend (Next.js) | Backend (NestJS) | Base de datos | Cache |
|---|---|---|---|---|
| Desarrollo | Vercel | Railway | PostgreSQL en Railway | Redis en Upstash |
| Pruebas (QA) | Servidor propio de GreenTek | Servidor propio (Docker) | Servidor propio (Docker) | Servidor propio (Docker) |
| Producción | Vercel | AWS | AWS (RDS PostgreSQL) | AWS (ElastiCache) |

> Ver T-D-04 en `tasks/tasks_devs.md` para los diagramas de despliegue detallados.

---

## 7. Puntos pendientes de definición

Los siguientes puntos requieren resolución antes de poder finalizar los requerimientos o iniciar el desarrollo de las áreas indicadas.

> **Nota:** Las tareas técnicas concretas del equipo de desarrollo se gestionan en `questions_and_pending_issues/tasks/tasks_devs.md`.

### 7.1 Pendientes con stakeholders (negocio)

| ID | Tema | Área | Responsable |
|---|---|---|---|
| PP-S-003 | Definir detalles de productos bundle/kit para versión futura (reglas de inventario compuesto, modelo de precios). *(Resuelto: confirmado por stakeholders que no va en V1. Pendiente solo la definición de detalles para la versión futura.)* | Catálogo | Anuar |
| PP-S-004 | Definir reglas de pre-order/backorder para inventario en tránsito *(No prioritario — no bloquea V1. Se identificó el caso de uso de flotillas en tránsito pero no se definió el alcance ni la versión.)* | Catálogo / Inventario | Anuar |
| PP-S-006 | Reglas para envío gratuito (monto mínimo, temporadas, carriers específicos) *(Futura — se implementará en versión futura, ver RF-LOG-004)* | Logística | Anuar |
| PP-S-008 | Definición completa del sistema de descuentos avanzados (ofertas por listing, cupones, campañas) *(Futura — V1 solo implementa descuento global, ver RF-PAG-002 y RF-PAG-005)* | Catálogo / Pagos | Anuar |
| PP-S-009 | Live chat en la tienda: widget activable/desactivable manualmente para operar solo en horario laboral. *(Idea mencionada por stakeholders — no prioritaria para V1. Pendiente definir proveedor, costos, flujo de activación y SLA de respuesta.)* | Atención al cliente | Anuar |

### 7.2 Pendientes legales (stakeholders)

| ID | Tema | Área | Responsable |
|---|---|---|---|
| PP-L-001 | Redactar Términos y Condiciones para el e-commerce (CCPA compliance) | Legal | Stakeholders |
| PP-L-002 | Redactar / actualizar Política de Privacidad | Legal | Stakeholders |
| PP-L-003 | Redactar / actualizar Política de Devoluciones | Legal | Stakeholders |

### 7.3 Pendientes para el equipo de desarrollo

La mayoría de los puntos técnicos pendientes han sido resueltos o trasladados a `tasks/tasks_devs.md`. El único punto aún abierto en esta sección es:

| ID | Tema | Área | Notas |
|---|---|---|---|
| PP-D-004 | Configuración exacta de seguro de envío en ShipEngine/CRM | Logística | Revisar si el seguro de envío está habilitado, en qué carriers y bajo qué condiciones — coordinar con T-D-01 |

Para el resto de tareas técnicas pendientes (carriers habilitados, diseño de BD, diagramas de despliegue, fecha de lanzamiento, revisión de seguridad), ver `questions_and_pending_issues/tasks/tasks_devs.md`.

---

## 8. Glosario

| Término | Definición |
|---|---|
| Listing | Publicación de un producto disponible para venta en la tienda o en un marketplace |
| Variación | Opciones seleccionables dentro de un mismo listing (ej. RAM, almacenamiento) |
| Condición | Estado del producto: nuevo, caja abierta, usado, reacondicionado. No es una variación |
| ITAD | IT Asset Disposition — sector dedicado a la gestión del ciclo de vida de activos tecnológicos |
| SKU | Stock Keeping Unit — código único de identificación de un ítem de inventario |
| CRM | Sistema interno de GreenTek Solutions para gestión de operaciones, desarrollado en Angular |
| R2V3 | Responsible Recycling — certificación de responsabilidad ambiental en reciclaje de electrónicos |
| Guest / Invitado | Usuario que completa una compra sin registrar una cuenta |
| Carrier | Empresa de transporte o mensajería (UPS, FedEx, USPS, DHL, etc.) |
| Sales Tax | Impuesto sobre ventas en Estados Unidos, variable por estado |
| ShipEngine | Plataforma de cotización y gestión de envíos integrada al sistema |
| Comprobante de compra | Documento inmediato enviado al cliente al confirmar el pago, con resumen de la orden; descargable en PDF desde el portal (usuarios registrados) o por email (invitados) |
| Sponsored Listing | Listing al que se le da visibilidad prioritaria en búsqueda, categorías o home |
| Stepper | Componente de UI que divide un flujo largo en pasos numerados con indicador de progreso |
| Pickup | Modalidad donde el cliente recoge el producto en bodega en lugar de recibirlo por envío |
| Out of Stock | Estado de un listing sin inventario disponible que permanece visible en la tienda |
| Wholesale / B2B | Canal de ventas al mayoreo para clientes empresariales con condiciones especiales |
| CCPA | California Consumer Privacy Act — ley de privacidad de datos del estado de California, EE.UU. |
