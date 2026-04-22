# 01 — eBay Media API

**Orden en el flujo de listing:** Paso 1 — Se sube la imagen antes de crear el inventory item, para obtener la URL de eBay Picture Services que se incluirá en el producto.

## Información general

| Campo | Valor |
|-------|-------|
| eBay API Name | **Media API** |
| Base URL | `https://apim.ebay.com` |
| Base Path | `/commerce/media/v1_beta/` |
| Sandbox disponible | **No** — siempre producción |
| Auth requerida | User token (`getValidToken`) |
| Servicio en CRM | `EbayMediaService` |
| Archivo | `src/ecommerce/modules/ebay-media/ebay-media.service.ts` |

> **Nota:** Esta API usa el dominio `apim.ebay.com` (no `api.ebay.com`). El path tiene sufijo `_beta`, lo que indica que aún es una versión beta de eBay.

---

## Endpoints implementados

### 1. `createImageFromUrl`
**Usado en el flujo de listing: SÍ**

Sube una imagen a eBay Picture Services a partir de una URL pública HTTPS. eBay descarga la imagen, la almacena en sus servidores y devuelve una URL propia de eBay que se usa en el `inventory_item`.

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://apim.ebay.com/commerce/media/v1_beta/image/create_image_from_url` |

**Request Body:**
```json
{
  "imageUrl": "https://www.tu-dominio.com/tu-imagen/producto.jpg"
}
```

**Response:**
```json
{
  "imageUrl": "https://i.ebayimg.com/images/g/XXXX/s-l1600.jpg",
  "expirationDate": "2026-07-01T00:00:00.000Z"
}
```

**Validaciones en el CRM:**
- La URL debe usar HTTPS (HTTP no está permitido)
- Se valida que sea una URL con formato válido
- Timeout de 30 segundos para darle tiempo a eBay de descargar la imagen
- Error `190204` de eBay = no se pudo descargar la imagen desde la URL

---

### 2. `createImageFromFile`
**Usado en el flujo de listing: SÍ (variante file upload)**

Sube una imagen a eBay Picture Services desde un buffer de archivo (multipart/form-data).

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://apim.ebay.com/commerce/media/v1_beta/image/create_image_from_file` |
| Content-Type | `multipart/form-data` |

**Formatos soportados:** JPG, PNG, GIF, BMP, TIFF, WEBP  
**Tamaño máximo:** 12 MB

**Response:** Igual que `createImageFromUrl`.

---

### 3. `createDocument`
**Usado en el flujo de listing: No (feature adicional)**

Crea un documento (ej. manual de usuario, ficha de seguridad) en eBay para adjuntar a listings que lo requieran.

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://apim.ebay.com/commerce/media/v1_beta/document` |

**Request Body:**
```json
{
  "documentType": "USER_GUIDE_OR_MANUAL",
  "languages": ["ENGLISH"]
}
```

**Response:** Devuelve un `documentId` que se usa para subir el archivo en el paso siguiente.

---

### 4. `uploadDocument`
**Usado en el flujo de listing: No (feature adicional)**

Sube el archivo PDF/documento al `documentId` obtenido en el paso anterior.

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://apim.ebay.com/commerce/media/v1_beta/document/{documentId}/upload` |
| Content-Type | `multipart/form-data` |

---

### 5. `getDocument`
**Usado en el flujo de listing: No**

Obtiene el estado/información de un documento previamente creado.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://apim.ebay.com/commerce/media/v1_beta/document/{documentId}` |

---

### 6. `uploadVideo` / `getVideo`
**Usado en el flujo de listing: No (feature adicional)**

| Método | Endpoint |
|--------|----------|
| `POST` | `https://apim.ebay.com/commerce/media/v1_beta/video` |
| `GET` | `https://apim.ebay.com/commerce/media/v1_beta/video/{videoId}` |

---

## Notas para v2

- El path `v1_beta` podría graduarse a `v1` en el futuro — monitorear cambios en la documentación de eBay.
- Las imágenes de eBay Picture Services tienen fecha de expiración (`expirationDate`). En v2 considerar un job que renueve imágenes próximas a expirar.
- La URL que devuelve eBay (`i.ebayimg.com`) es la que hay que guardar en el inventory item, **no** la URL original.
