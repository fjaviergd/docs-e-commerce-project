# Esquema de BD — Modulo Compradores (Registered + Guest)

> Basado en SRS GTS eStore v5.0  
> Soporta usuarios registrados e invitados, carrito invitado, carrito, ordenenes, direcciones.


## Consideraciones de diseño

1. Los usuarios invitados (guest) **no generan cuenta**, pero sí generan datos transaccionales (carrito, órdenes).
2. Las órdenes almacenan un **snapshot del cliente**, por lo que no dependen completamente de `users`.
3. El carrito funciona para:

   * usuarios autenticados (`user_id`)
   * invitados (`user_id = NULL` + UUID en cookie)
4. El acceso de invitados a órdenes se resuelve mediante tokens seguros.

---

# 1. Tabla: `users`

### Descripción

Almacena únicamente usuarios registrados. No incluye invitados.

```sql
users (
  id UUID PRIMARY KEY, -- Identificador único del usuario

  first_name VARCHAR(100) NOT NULL, -- Nombre del usuario
  last_name VARCHAR(100) NOT NULL, -- Apellido del usuario

  email VARCHAR(255) UNIQUE NOT NULL, -- Email único usado para login
  password_hash TEXT NOT NULL, -- Hash seguro de la contraseña

  phone VARCHAR(30), -- Teléfono opcional del usuario

  email_verified BOOLEAN DEFAULT FALSE, -- Indica si el email fue verificado
  email_verified_at TIMESTAMP NULL, -- Fecha de verificación de email

  status VARCHAR(20) DEFAULT 'active', -- Estado de la cuenta (active, blocked)

  created_at TIMESTAMP NOT NULL, -- Fecha de creación
  updated_at TIMESTAMP NOT NULL, -- Última actualización
  deleted_at TIMESTAMP NULL -- Soft delete
);
```

---

# 2. Tabla: `user_crm_links`

### Descripción

Permite vincular opcionalmente un usuario del e-commerce con un cliente en el CRM.

```sql
user_crm_links (
  id UUID PRIMARY KEY, -- Identificador del vínculo

  user_id UUID REFERENCES users(id), -- Usuario del e-commerce

  crm_email VARCHAR(255) NOT NULL, -- Email registrado en el CRM
  crm_reference_id VARCHAR(100), -- ID del cliente en el CRM

  linked_at TIMESTAMP NOT NULL -- Fecha de vinculación
);
```

---

# 3. Tabla: `user_addresses`

### Descripción

Direcciones guardadas por usuarios registrados. No aplica para invitados.

```sql
user_addresses (
  id UUID PRIMARY KEY, -- Identificador de la dirección

  user_id UUID REFERENCES users(id), -- Usuario propietario

  recipient_name VARCHAR(255) NOT NULL, -- Nombre del destinatario
  phone VARCHAR(30), -- Teléfono de contacto

  address_line1 VARCHAR(255) NOT NULL, -- Calle y número
  address_line2 VARCHAR(255), -- Información adicional

  city VARCHAR(100) NOT NULL, -- Ciudad
  state VARCHAR(100) NOT NULL, -- Estado
  postal_code VARCHAR(20) NOT NULL, -- Código postal
  country VARCHAR(100) NOT NULL, -- País

  is_default BOOLEAN DEFAULT FALSE, -- Indica si es dirección predeterminada

  created_at TIMESTAMP, -- Fecha de creación
  updated_at TIMESTAMP -- Última actualización
);
```

---

# 4. Tabla: `carts`

### Descripción

Carrito de compras para usuarios registrados y guest.

```sql
carts (
  id UUID PRIMARY KEY, -- Identificador del carrito (usado como cartId en cookie)

  user_id UUID NULL REFERENCES users(id), -- Usuario dueño (NULL si es guest)

  status VARCHAR(20) DEFAULT 'active', -- Estado del carrito (active, merged, expired)

  expires_at TIMESTAMP NOT NULL, -- Fecha de expiración (7 días para guest)

  created_at TIMESTAMP NOT NULL, -- Fecha de creación
  updated_at TIMESTAMP NOT NULL -- Última actualización
);
```

---

# 5. Tabla: `cart_items`

### Descripción

Productos dentro del carrito.

```sql
cart_items (
  id UUID PRIMARY KEY, -- Identificador del item

  cart_id UUID REFERENCES carts(id), -- Carrito al que pertenece

  listing_id UUID NOT NULL, -- ID del producto (listing)
  variation_id UUID NULL, -- ID de variación si aplica

  quantity INT NOT NULL, -- Cantidad seleccionada

  price_snapshot DECIMAL(10,2) NOT NULL, -- Precio al momento de agregar (informativo)

  created_at TIMESTAMP -- Fecha de creación
);
```

---

# 6. Tabla: `auth_tokens`

### Descripción

Gestión de tokens para verificación de email y recuperación de contraseña.

```sql
auth_tokens (
  id UUID PRIMARY KEY, -- Identificador del token

  user_id UUID REFERENCES users(id), -- Usuario asociado

  type VARCHAR(50), -- Tipo (verify_email, reset_password)

  token_hash TEXT NOT NULL, -- Hash del token (no se guarda en texto plano)

  expires_at TIMESTAMP NOT NULL, -- Fecha de expiración
  used_at TIMESTAMP NULL, -- Fecha en que se utilizó

  created_at TIMESTAMP -- Fecha de creación
);
```

---

# 7. Tabla: `orders`

### Descripción

Representa la orden de compra. Funciona tanto para usuarios registrados como invitados.

```sql
orders (
  id UUID PRIMARY KEY, -- Identificador interno de la orden

  user_id UUID NULL REFERENCES users(id), -- Usuario (NULL si es guest)

  customer_first_name VARCHAR(100) NOT NULL, -- Nombre capturado en checkout
  customer_last_name VARCHAR(100) NOT NULL, -- Apellido capturado en checkout
  customer_email VARCHAR(255) NOT NULL, -- Email del cliente
  customer_phone VARCHAR(30), -- Teléfono del cliente

  customer_type VARCHAR(20) NOT NULL, -- Tipo de cliente (guest o registered)

  status VARCHAR(50) NOT NULL, -- Estado de la orden

  currency VARCHAR(10) DEFAULT 'USD', -- Moneda

  subtotal DECIMAL(10,2) NOT NULL, -- Suma de productos
  shipping_cost DECIMAL(10,2) NOT NULL, -- Costo de envío
  tax_amount DECIMAL(10,2) NOT NULL, -- Impuestos
  total DECIMAL(10,2) NOT NULL, -- Total final

  created_at TIMESTAMP NOT NULL, -- Fecha de creación
  updated_at TIMESTAMP NOT NULL -- Última actualización
);
```

---

# 8. Tabla: `order_addresses`

### Descripción

Snapshot de direcciones usadas en la orden (envío y facturación).

```sql
order_addresses (
  id UUID PRIMARY KEY, -- Identificador de la dirección

  order_id UUID REFERENCES orders(id), -- Orden asociada

  type VARCHAR(20), -- Tipo (shipping o billing)

  recipient_name VARCHAR(255), -- Nombre del destinatario
  phone VARCHAR(30), -- Teléfono

  address_line1 VARCHAR(255), -- Calle y número
  address_line2 VARCHAR(255), -- Complemento

  city VARCHAR(100), -- Ciudad
  state VARCHAR(100), -- Estado
  postal_code VARCHAR(20), -- Código postal
  country VARCHAR(100) -- País
);
```

---

# 9. Tabla: `order_items`

### Descripción

Productos comprados en la orden (snapshot completo).

```sql
order_items (
  id UUID PRIMARY KEY, -- Identificador del item

  order_id UUID REFERENCES orders(id), -- Orden asociada

  listing_id UUID NOT NULL, -- ID del producto
  variation_id UUID NULL, -- Variación seleccionada

  product_name VARCHAR(255) NOT NULL, -- Nombre del producto al momento de compra
  product_condition VARCHAR(50), -- Condición del producto

  quantity INT NOT NULL, -- Cantidad comprada

  unit_price DECIMAL(10,2) NOT NULL, -- Precio unitario histórico
  subtotal DECIMAL(10,2) NOT NULL -- Subtotal del item
);
```

---

# 10. Tabla: `guest_order_access`

### Descripción

Permite a usuarios invitados acceder a su orden mediante un link seguro.

```sql
guest_order_access (
  id UUID PRIMARY KEY, -- Identificador del acceso

  order_id UUID REFERENCES orders(id), -- Orden asociada

  access_token_hash TEXT NOT NULL, -- Hash del token de acceso

  expires_at TIMESTAMP NOT NULL, -- Expiración del acceso

  created_at TIMESTAMP -- Fecha de creación
);
```

---

# Relaciones principales

```mermaid
erDiagram
  users ||--o{ user_addresses
  users ||--o{ carts
  users ||--o{ orders

  carts ||--o{ cart_items

  orders ||--o{ order_items
  orders ||--o{ order_addresses
  orders ||--o{ guest_order_access
```

---

# Notas finales de arquitectura

* `users` y `orders` están desacoplados para soportar guest correctamente
* `orders` contiene snapshot completo para integridad histórica
* `carts` soporta persistencia híbrida (DB + cookie UUID)
* `guest_order_access` es obligatorio para cumplir acceso sin cuenta
* `auth_tokens` evita almacenar tokens en texto plano (seguridad)
