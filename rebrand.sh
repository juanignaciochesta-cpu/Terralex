#!/usr/bin/env bash
#
# Renombrado de marca del sitio.
#
# El equipo, los datos de contacto, la direccion y las matriculas NO cambian:
# lo unico que cambia es el nombre comercial y, si corresponde, el dominio.
#
# Uso:
#   ./rebrand.sh --nombre "NuevaMarca" [opciones]
#
# Opciones:
#   --nombre     NOMBRE   Nombre comercial nuevo. Reemplaza a TerraLex.   (obligatorio)
#   --dominio    DOMINIO  Dominio nuevo, ej: nuevamarca.com.ar
#   --instagram  USUARIO  Usuario de Instagram nuevo, ej: nuevamarca.cba
#   --calendly   SLUG     Slug de Calendly nuevo, ej: nuevamarcacba
#   --asistente  NOMBRE   Nombre nuevo del chatbot. Hoy se llama Terri.
#   --aplicar             Escribe los cambios. Sin esto solo muestra que haria.
#
# Ejemplo:
#   ./rebrand.sh --nombre "Lexar" --dominio "lexar.com.ar" --aplicar
#
# Lo que NO hace este script (queda para vos):
#   - Reemplazar las imagenes con el logo nuevo. Ver la lista que imprime al final.
#   - Renombrar la cuenta de Instagram y la de Calendly en esos servicios.
#   - Cambiar el dominio en Netlify y en Supabase (Authentication > URL Configuration).

set -euo pipefail

NOMBRE=""; DOMINIO=""; INSTAGRAM=""; CALENDLY=""; ASISTENTE=""; APLICAR=0

while [ $# -gt 0 ]; do
  case "$1" in
    --nombre)    NOMBRE="${2:-}";    shift 2 ;;
    --dominio)   DOMINIO="${2:-}";   shift 2 ;;
    --instagram) INSTAGRAM="${2:-}"; shift 2 ;;
    --calendly)  CALENDLY="${2:-}";  shift 2 ;;
    --asistente) ASISTENTE="${2:-}"; shift 2 ;;
    --aplicar)   APLICAR=1;          shift ;;
    -h|--help)   sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Opcion desconocida: $1"; exit 1 ;;
  esac
done

# El informe de progreso va a STDERR, no a stdout, y no es un capricho:
# si sale por stdout y el lector se va antes de tiempo (por ejemplo
# 'rebrand.sh --aplicar | head'), lo que quedo pendiente en el buffer se cuela
# dentro del siguiente $(...) y corrompe el contador de reemplazos. El sintoma
# es feo y silencioso: el script aborta a mitad del renombrado y deja la mitad
# de los archivos migrados. Con stderr el problema no existe, y ademas es lo
# convencional en Unix: por stdout van los datos, por stderr el diagnostico.
say()  { echo "$@" >&2; }
sayf() { printf "$@" >&2; }

if [ -z "$NOMBRE" ]; then
  say "Falta --nombre. Corré '$0 --help' para ver el uso."
  exit 1
fi

cd "$(dirname "$0")"

# Archivos con texto de marca. Las imagenes se listan aparte al final.
ARCHIVOS="index.html netlify/functions/chat.js netlify.toml sitemap.xml robots.txt README.md supabase-setup.sql"

# Variantes de caja del nombre viejo -> nuevo
NOMBRE_LOWER="$(printf '%s' "$NOMBRE" | tr '[:upper:]' '[:lower:]')"
NOMBRE_UPPER="$(printf '%s' "$NOMBRE" | tr '[:lower:]' '[:upper:]')"

if [ "$APLICAR" -eq 0 ]; then
  say "=== SIMULACION (agregá --aplicar para escribir los cambios) ==="
else
  say "=== APLICANDO CAMBIOS ==="
fi
say

reemplazar() {
  # $1 = descripcion, $2 = patron viejo, $3 = texto nuevo
  local desc="$1" viejo="$2" nuevo="$3" total=0 n
  for f in $ARCHIVOS; do
    [ -f "$f" ] || continue
    # El '|| true' es necesario: con pipefail, un grep sin coincidencias
    # devuelve 1 y cortaria el script en los archivos que no tienen el patron.
    n=$( { grep -o -- "$viejo" "$f" 2>/dev/null || true; } | wc -l | tr -d ' ')
    [ "$n" -eq 0 ] && continue
    total=$((total + n))
    if [ "$APLICAR" -eq 1 ]; then
      # Delimitador | para no chocar con las barras de las URLs
      sed -i '' "s|$viejo|$nuevo|g" "$f"
    fi
  done
  sayf '  %-38s %3s reemplazo(s)\n' "$desc" "$total"
}

# ORDEN IMPORTANTE: primero lo mas especifico (Instagram, Calendly, archivos de
# logo, dominio) y recien despues el nombre suelto. Al reves, "terralex" pisaria
# el usuario de Instagram y el slug de Calendly, que son cuentas externas y no
# cambian solas al cambiar la marca.

# Lo que se deja igual hay que BLINDARLO antes del reemplazo generico de
# "terralex" en minuscula, porque si no se lo come igual: 'terralex.cba' y
# 'terralexcba' contienen la palabra. Se cambian por un centinela y al final
# se restauran. Sin esto, un rebrand sin --instagram rompe el link de Instagram.
PROTEGIDOS=""

proteger() {
  # $1 = texto a preservar, $2 = centinela
  PROTEGIDOS="$PROTEGIDOS$1|$2
"
  [ "$APLICAR" -eq 1 ] || return 0
  for f in $ARCHIVOS; do
    [ -f "$f" ] && sed -i '' "s|$1|$2|g" "$f"
  done
  return 0
}

restaurar() {
  [ "$APLICAR" -eq 1 ] || return 0
  # printf real, no sayf: esto alimenta el while de abajo, no es salida al usuario
  printf '%s' "$PROTEGIDOS" | while IFS='|' read -r orig centinela; do
    [ -n "$centinela" ] || continue
    for f in $ARCHIVOS; do
      [ -f "$f" ] && sed -i '' "s|$centinela|$orig|g" "$f"
    done
  done
  return 0
}

say "Cuentas externas y URLs:"
if [ -n "$INSTAGRAM" ]; then
  reemplazar "Instagram (terralex.cba)" "terralex\.cba" "$INSTAGRAM"
else
  proteger "terralex\.cba" "@@IG@@"
  say "  Instagram                              intacto (--instagram para cambiarlo)"
fi

if [ -n "$CALENDLY" ]; then
  reemplazar "Calendly (terralexcba)" "terralexcba" "$CALENDLY"
else
  proteger "terralexcba" "@@CAL@@"
  say "  Calendly                               intacto (--calendly para cambiarlo)"
fi

if [ -n "$DOMINIO" ]; then
  reemplazar "Dominio (terralex.com.ar)" "terralex\.com\.ar" "$DOMINIO"
else
  proteger "terralex\.com\.ar" "@@DOM@@"
  say "  Dominio                                intacto (--dominio para cambiarlo)"
fi

say
say "Archivos de logo referenciados en el HTML:"
reemplazar "logo-terralex.*"      "logo-terralex"      "logo-$NOMBRE_LOWER"
reemplazar "terralex-wordmark.*"  "terralex-wordmark"  "$NOMBRE_LOWER-wordmark"
reemplazar "equipo-terralex.jpg"  "equipo-terralex"    "equipo-$NOMBRE_LOWER"

say
say "Nombre de marca:"
reemplazar "TerraLex"  "TerraLex"  "$NOMBRE"
reemplazar "TERRALEX"  "TERRALEX"  "$NOMBRE_UPPER"
reemplazar "terralex"  "terralex"  "$NOMBRE_LOWER"

if [ -n "$ASISTENTE" ]; then
  say
  say "Asistente del chat:"
  reemplazar "Terri -> $ASISTENTE" "Terri" "$ASISTENTE"
fi

# Devolver a su valor original lo que se decidio no cambiar
restaurar

# Renombrar los archivos de imagen para que coincidan con las referencias
say
say "Archivos de imagen:"
for par in \
  "logo-terralex.png:logo-$NOMBRE_LOWER.png" \
  "logo-terralex.webp:logo-$NOMBRE_LOWER.webp" \
  "terralex-wordmark.png:$NOMBRE_LOWER-wordmark.png" \
  "terralex-wordmark.webp:$NOMBRE_LOWER-wordmark.webp" \
  "equipo-terralex.jpg:equipo-$NOMBRE_LOWER.jpg"; do
  viejo="${par%%:*}"; nuevo="${par##*:}"
  [ -f "$viejo" ] || continue
  if [ "$APLICAR" -eq 1 ]; then
    git mv "$viejo" "$nuevo" 2>/dev/null || mv "$viejo" "$nuevo"
    say "  renombrado: $viejo -> $nuevo"
  else
    say "  se renombraria: $viejo -> $nuevo"
  fi
done

say
if [ "$APLICAR" -eq 0 ]; then
  say "Nada se modificó. Volvé a correrlo con --aplicar cuando estes conforme."
else
  say "Listo. Ahora, a mano:"
  say
  say "  1. Reemplazá el contenido de estas imagenes con el diseño nuevo"
  say "     (respetando los nombres, que ya quedaron actualizados):"
  say "       logo-$NOMBRE_LOWER.png / .webp    logo principal"
  say "       $NOMBRE_LOWER-wordmark.png / .webp  wordmark del hero"
  say "       favicon.png                        icono de la pestaña"
  say "       og.jpg                             imagen al compartir en redes"
  say "       logo-mark-acento.png               isotipo suelto"
  say
  if [ -n "$DOMINIO" ]; then
    say "  2. Netlify: agregá el dominio $DOMINIO en Domain management."
    say "  3. Supabase: Authentication > URL Configuration, poné"
    say "     Site URL = https://$DOMINIO y Redirect URLs = https://$DOMINIO/**"
    say "     Si no, los mails de recuperar contraseña no funcionan."
  fi
  say
  say "  Revisá el resultado con 'git diff' antes de commitear."
fi
