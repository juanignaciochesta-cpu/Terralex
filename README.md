# TerraLex — terralex.com.ar

Sitio web del estudio jurídico e inmobiliario TerraLex (Córdoba, Argentina).

## Stack

- **Frontend**: HTML/CSS/JS vanilla en un solo `index.html` (sin build).
- **Hosting**: Netlify (deploy automático desde este repo, rama `main`).
- **Base de datos y fotos**: Supabase (tabla `propiedades` + bucket `fotos-propiedades`).
- **Chat "Terri"**: Netlify Function (`netlify/functions/chat.js`) que llama a la API de Anthropic (Claude Haiku).
- **Turnos**: Calendly embebido.

## Seguridad

- El panel admin usa **Supabase Auth** (email + contraseña creados en Supabase → Authentication → Users). No hay credenciales en el código.
- Las políticas RLS de Supabase permiten **lectura pública** y **escritura solo a usuarios autenticados**. Ver `supabase-setup.sql`.
- La función del chat tiene CORS restringido a terralex.com.ar, validación de entrada y rate limiting por IP.
- Todo el contenido dinámico se renderiza escapando HTML (helper `esc()`), para prevenir XSS.

## Variables de entorno (Netlify → Site settings → Environment variables)

| Variable | Descripción |
|---|---|
| `ANTHROPIC_API_KEY` | API key de Anthropic para el chat Terri |
| `EXTRA_ORIGIN` | (Opcional) origen adicional permitido para el chat, ej. `https://tu-sitio.netlify.app` |

## Acceso al panel admin

Atajo en el sitio: `Ctrl + Shift + A` → iniciar sesión con email y contraseña de Supabase.
