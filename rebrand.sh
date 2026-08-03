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

if [ -z "$NOMBRE" ]; then
  echo "Falta --nombre. Corré '$0 --help' para ver el uso."
  exit 1
fi

cd "$(dirname "$0")"

# Archivos con texto de marca. Las imagenes se listan aparte al final.
ARCHIVOS="index.html netlify/functions/chat.js netlify.toml sitemap.xml robots.txt README.md supabase-setup.sql"

# Variantes de caja del nombre viejo -> nuevo
NOMBRE_LOWER="$(printf '%s' "$NOMBRE" | tr '[:upper:]' '[:lower:]')"
NOMBRE_UPPER="$(printf '%s' "$NOMBRE" | tr '[:lower:]' '[:upper:]')"

if [ "$APLICAR" -eq 0 ]; then
  echo "=== SIMULACION (agregá --aplicar para escribir los cambios) ==="
else
  echo "=== APLICANDO CAMBIOS ==="
fi
echo

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
  printf '  %-38s %3s reemplazo(s)\n' "$desc" "$total"
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
  printf '%s' "$PROTEGIDOS" | while IFS='|' read -r orig centinela; do
    [ -n "$centinela" ] || continue
    for f in $ARCHIVOS; do
      [ -f "$f" ] && sed -i '' "s|$centinela|$orig|g" "$f"
    done
  done
  return 0
}

echo "Cuentas externas y URLs:"
if [ -n "$INSTAGRAM" ]; then
  reemplazar "Instagram (terralex.cba)" "terralex\.cba" "$INSTAGRAM"
else
  proteger "terralex\.cba" "@@IG@@"
  echo "  Instagram                              intacto (--instagram para cambiarlo)"
fi

if [ -n "$CALENDLY" ]; then
  reemplazar "Calendly (terralexcba)" "terralexcba" "$CALENDLY"
else
  proteger "terralexcba" "@@CAL@@"
  echo "  Calendly                               intacto (--calendly para cambiarlo)"
fi

if [ -n "$DOMINIO" ]; then
  reemplazar "Dominio (terralex.com.ar)" "terralex\.com\.ar" "$DOMINIO"
else
  proteger "terralex\.com\.ar" "@@DOM@@"
  echo "  Dominio                                intacto (--dominio para cambiarlo)"
fi

echo
echo "Archivos de logo referenciados en el HTML:"
reemplazar "logo-terralex.*"      "logo-terralex"      "logo-$NOMBRE_LOWER"
reemplazar "terralex-wordmark.*"  "terralex-wordmark"  "$NOMBRE_LOWER-wordmark"
reemplazar "equipo-terralex.jpg"  "equipo-terralex"    "equipo-$NOMBRE_LOWER"

echo
echo "Nombre de marca:"
reemplazar "TerraLex"  "TerraLex"  "$NOMBRE"
reemplazar "TERRALEX"  "TERRALEX"  "$NOMBRE_UPPER"
reemplazar "terralex"  "terralex"  "$NOMBRE_LOWER"

if [ -n "$ASISTENTE" ]; then
  echo
  echo "Asistente del chat:"
  reemplazar "Terri -> $ASISTENTE" "Terri" "$ASISTENTE"
fi

# Devolver a su valor original lo que se decidio no cambiar
restaurar

# Renombrar los archivos de imagen para que coincidan con las referencias
echo
echo "Archivos de imagen:"
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
    echo "  renombrado: $viejo -> $nuevo"
  else
    echo "  se renombraria: $viejo -> $nuevo"
  fi
done

echo
if [ "$APLICAR" -eq 0 ]; then
  echo "Nada se modificó. Volvé a correrlo con --aplicar cuando estes conforme."
else
  echo "Listo. Ahora, a mano:"
  echo
  echo "  1. Reemplazá el contenido de estas imagenes con el diseño nuevo"
  echo "     (respetando los nombres, que ya quedaron actualizados):"
  echo "       logo-$NOMBRE_LOWER.png / .webp    logo principal"
  echo "       $NOMBRE_LOWER-wordmark.png / .webp  wordmark del hero"
  echo "       favicon.png                        icono de la pestaña"
  echo "       og.jpg                             imagen al compartir en redes"
  echo "       logo-mark-acento.png               isotipo suelto"
  echo
  if [ -n "$DOMINIO" ]; then
    echo "  2. Netlify: agregá el dominio $DOMINIO en Domain management."
    echo "  3. Supabase: Authentication > URL Configuration, poné"
    echo "     Site URL = https://$DOMINIO y Redirect URLs = https://$DOMINIO/**"
    echo "     Si no, los mails de recuperar contraseña no funcionan."
  fi
  echo
  echo "  Revisá el resultado con 'git diff' antes de commitear."
fi
