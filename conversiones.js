/* ===== CONVERSIONES DE GOOGLE ADS =====

   PARA ACTIVARLAS hay que pegar abajo la etiqueta de cada accion. Se saca de:
     Google Ads > Objetivos > Conversiones > (la accion) > "Configurar la
     etiqueta" > opcion "Instalar la etiqueta manualmente".
   Ahi aparece algo como:  send_to: 'AW-18553859405/AbC-D_efGhIjKlMnOp'
   Ese valor completo va entre las comillas.

   Mientras esten vacias NO se envia nada. Es a proposito: mandar eventos sin
   etiqueta no los atribuye a ninguna accion y solo ensucia los informes. */

var CONVERSIONES = {
  // Etiquetas de las acciones de conversion de Google Ads (cuenta 612-156-7035).
  // Se obtienen en: Objetivos > Conversiones > (la accion) > Administrar >
  // "Ver fragmento de evento". Si alguna vez se recrea la accion, cambia.
  whatsapp:   'AW-18553859405/CL_ZCJe50r8dEM3alY9F',   // accion "Clic en WhatsApp"   (categoria Contacto)
  formulario: 'AW-18553859405/nxHLCJS50r8dEM3alY9F'    // accion "Envio de formulario" (categoria Cliente potencial)
};

/* Dispara la conversion y despues ejecuta 'seguir'. Si Google no contesta en
   1 segundo seguimos igual: nunca dejamos al usuario esperando por una
   metrica. 'seguir' se ejecuta una sola vez, conteste Google o gane el reloj. */
function registrarConversion(cual, seguir) {
  var etiqueta = CONVERSIONES[cual];
  var hecho = false;
  function continuar() {
    if (hecho) return;
    hecho = true;
    if (typeof seguir === 'function') seguir();
  }
  if (!etiqueta || typeof gtag !== 'function') { continuar(); return; }
  try {
    gtag('event', 'conversion', { send_to: etiqueta, event_callback: continuar });
    setTimeout(continuar, 1000);
  } catch (e) { continuar(); }
}

/* --- WhatsApp ---
   Listener delegado en vez de uno por boton: la mitad de los enlaces los
   genera el JS (tarjetas de propiedades, galeria, el boton que ofrece Yani
   para hablar con el equipo), asi que tambien quedan cubiertos los que
   aparecen despues. Los enlaces abren en pestana nueva, de modo que esta
   pagina sigue viva y el beacon llega sin necesidad de demorar nada. */
document.addEventListener('click', function(e) {
  var a = e.target.closest && e.target.closest('a[href*="wa.me"]');
  if (a) registrarConversion('whatsapp');
}, true);

/* --- Formulario de contacto ---
   Aca si hay que frenar el envio un instante: Netlify hace un POST que
   descarga la pagina, y si no esperamos el beacon se corta a mitad de camino.
   form.submit() no vuelve a disparar este evento, asi que no hay recursion. */
(function() {
  // Todos los formularios de Netlify, no uno solo por nombre: el de la home se
  // llama "contact" y el de las paginas de servicio "consulta-servicio".
  // Buscar un unico nombre dejaria sin medir justo donde cae el trafico pago.
  var forms = document.querySelectorAll('form[data-netlify]');
  Array.prototype.forEach.call(forms, function(form) {
    form.addEventListener('submit', function(e) {
      if (form.dataset.conversionEnviada === '1') return;  // ya paso por aca
      e.preventDefault();
      registrarConversion('formulario', function() {
        form.dataset.conversionEnviada = '1';
        form.submit();
      });
    });
  });
})();
