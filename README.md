# Global TV Max · v1.0 (MVP)

Plataforma de TV en vivo, catálogo de cine/series, directorio de plataformas y reproductor de listas M3U, con panel de administración, roles, usuarios y control de accesos.
Desarrollo: **Mr. Escudero · EIEL**.

## Archivos

| Archivo | Qué es |
|---|---|
| `index.html` | La app completa (un solo archivo, sin instalación). |
| `db/schema.sql` | Migración PostgreSQL / Supabase para la versión con servidor (Fase 2). |
| `README.md` | Este documento. |

## Cómo ejecutarla

**Opción A — GitHub Pages (recomendada, reproduce video):**
1. Crea un repositorio (por ejemplo `global-tv-max`) y sube `index.html`.
2. Settings → Pages → Branch `main` / root → Save.
3. Abre `https://TU-USUARIO.github.io/global-tv-max/`. En iPhone: Compartir → Agregar a inicio.

**Opción B — local:** en la carpeta, `python3 -m http.server 8080` y abre `http://localhost:8080`.

> La vista previa dentro de Claude bloquea videos y descargas externas. Ahí puedes revisar diseño, usuarios y administración; la reproducción de streams y la descarga de listas funcionan en GitHub Pages o local. El canal **GTM Señal de Prueba** funciona en todos lados.

### Cuentas de demostración

| Rol | Usuario | Contraseña |
|---|---|---|
| Superadministrador | `admin` | `GlobalTV-Demo-2026` |
| Editor | `editor` | `Editor-Demo-2026` |
| Usuario (Plan Básico) | `demo` | `Demo-2026-tv` |

Cámbialas en cuanto publiques la app.

## 1. Funciones de la primera versión

- **Inicio**: destacado, continuar viendo, en vivo ahora, populares, recientes, recomendados, favoritos, accesos por categoría.
- **TV en vivo**: México, EE. UU. y otros países; filtros por categoría; nombre, logo, país, idioma, calidad, EPG (demo), estado de la fuente, favoritos.
- **Reproductor**: HLS (hls.js) y MPEG-DASH (dash.js), bitrate adaptativo, selector de calidad, reintentos controlados (2), detección de fuente caída, medición del tiempo de inicio, resolución real de reproducción, reanudar donde te quedaste.
- **Mis listas M3U** (modo reproductor): carga por enlace, archivo o texto; agrupa por `group-title`; carga rápida de índices públicos de canales gratuitos (iptv-org: México, EE. UU., español).
- **Películas y series**: catálogo abierto de Blender Studio (CC) con ficha completa, filtros por género, control parental por clasificación.
- **Plataformas**: directorio con enlaces oficiales (Netflix, Prime Video, Disney+, HBO Max, Apple TV, Paramount+, ViX, Pluto TV, Tubi).
- **Mi cuenta**: plan, vigencia, dispositivos autorizados (quitar), cambio de contraseña.
- **Administración** (según rol): usuarios (crear, ID único, temporal segura de un solo uso visual, manual, suspender/reactivar, vencimiento, revocar sesiones y dispositivos, búsqueda, filtros, paginación, acciones masivas, reporte CSV sin contraseñas), planes, canales con autorización y validación obligatorias, catálogo, sesiones, registro de auditoría, matriz de roles, ajustes de bloqueo.
- **Seguridad del cliente**: hash PBKDF2‑SHA256 (120 000 iteraciones, sal aleatoria), comparación de tiempo constante, bloqueo temporal por intentos, contraseña temporal con caducidad y cambio obligatorio, límite de dispositivos por plan, escape de todo texto mostrado (anti‑XSS).
- **Control remoto**: navegación con flechas, OK y Atrás/Esc.

**Limitación honesta de v1:** los datos viven en el navegador (localStorage). Sirve para demostrar y probar el flujo, pero la seguridad real (contraseñas, sesiones simultáneas, revocación entre equipos) requiere el servidor de la Fase 2.

## 2. Servicios externos que requieren API o contrato

| Necesidad | Servicio sugerido | Tipo |
|---|---|---|
| Señales de TV de México/EE. UU. | Televisoras o agregadores con licencia (contrato de retransmisión) | Contrato |
| Guía EPG | XMLTV de proveedores con licencia, Gracenote | API / contrato |
| Metadatos de películas | TMDB | API (atribución obligatoria; uso comercial requiere acuerdo) |
| Dónde ver cada título | JustWatch / TMDB Watch Providers | API / contrato |
| Pagos | Stripe, Mercado Pago, Conekta | Contrato |
| Correo (recuperación, invitaciones) | Resend, SendGrid, Amazon SES | API |
| Backend y base de datos | Supabase (Auth + Postgres) o NestJS + PostgreSQL | Servicio |
| CDN / DRM (si hay contenido propio) | Cloudflare Stream, Mux, AWS CloudFront + Widevine/FairPlay | Contrato |

## 3. Formatos de streaming

HLS (`.m3u8`) en todos los navegadores (nativo en Safari/iOS); MPEG‑DASH (`.mpd`) en navegadores con MSE (no en iPhone). Sin DRM en v1. Las listas M3U/M3U8 se aceptan como contenedor de canales.

## 4. Costos operativos estimados (orientativos, sin contratos de contenido)

| Etapa | Infraestructura | Costo aproximado/mes |
|---|---|---|
| Demo / piloto (hasta ~100 usuarios) | GitHub Pages + Supabase gratis | $0 |
| Pequeña (≈1 000 usuarios) | Supabase Pro, dominio, correo | ≈ USD 25–60 |
| Con video propio en CDN | Mux / Cloudflare Stream | Por minuto entregado; crece con la audiencia |
| Licencias de canales y catálogo | Contratos con titulares | Variable y el mayor costo del proyecto |

Si la app solo **enlaza** o reproduce señales que el proveedor sirve desde su propia infraestructura, tu costo de ancho de banda es casi cero.

## 5. Restricciones técnicas y legales

- Retransmitir canales de paga o plataformas (Televisa, TV Azteca, ESPN, Netflix, etc.) sin contrato infringe la Ley Federal del Derecho de Autor y la LFTR en México y la DMCA en EE. UU. La app solo muestra canales con autorización **Aprobada** y enlaza a las plataformas oficiales.
- El modo M3U reproduce listas que el usuario carga bajo su responsabilidad; la app no incluye listas de canales de paga.
- iOS no reproduce DASH; navegadores bloquean streams HTTP en páginas HTTPS (contenido mixto) y servidores sin CORS.
- Muchos streams tienen restricción geográfica; un enlace puede funcionar en MX y no en EE. UU.
- Datos personales: aviso de privacidad (LFPDPPP) obligatorio al cobrar o registrar usuarios reales.

## Hoja de ruta

- **Fase 2**: migrar a Supabase con `db/schema.sql`, Auth del servidor (Argon2id), RLS por rol, sesiones simultáneas reales, PWA instalable con service worker.
- **Fase 3**: EPG XMLTV, TMDB/JustWatch, correo de recuperación e invitaciones, pagos, estadísticas por día.
- **Fase 4**: pruebas de seguridad y carga, app Android TV/Fire TV, manual de administración, respaldos.
