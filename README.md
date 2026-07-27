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

Dos formas de abrir el login:

- Link **"Acceso equipo"** en el pie de página (funciona también en celular).
- Atajo de teclado `Ctrl + Shift + A`.

Se ingresa con el email y contraseña creados en Supabase → Authentication → Users.

### Si olvidás la contraseña

1. Abrí el login, escribí tu email y tocá **"¿Olvidaste tu contraseña?"**.
2. Te llega un correo con un link; al abrirlo el sitio muestra el formulario
   para elegir la contraseña nueva y te deja adentro del panel.

Para que ese link funcione, en Supabase → Authentication → URL Configuration
el **Site URL** tiene que ser `https://terralex.com.ar` y en **Redirect URLs**
debe figurar `https://terralex.com.ar/**`. Si quedó en `localhost:3000`, el
mail lleva a una página inexistente.

## Desarrollo local

No hay build. Para levantarlo:

```bash
python3 -m http.server 4321
```

Y abrir `http://localhost:4321`. Las propiedades se leen de Supabase en vivo,
así que se ven igual que en producción.
