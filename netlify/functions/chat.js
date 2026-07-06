const https = require('https');

/* ===== SEGURIDAD =====
   - CORS restringido al dominio de TerraLex (nada de '*')
   - Validacion de entrada: cantidad, roles y largo de mensajes
   - Rate limit basico por IP (en memoria, por instancia de la funcion)     */

const ALLOWED_ORIGINS = [
  'https://terralex.com.ar',
  'https://www.terralex.com.ar'
];
// Si necesitas permitir el dominio *.netlify.app de previews, agregalo en
// Netlify > Site settings > Environment variables como EXTRA_ORIGIN
if (process.env.EXTRA_ORIGIN) ALLOWED_ORIGINS.push(process.env.EXTRA_ORIGIN);

const MAX_MESSAGES = 10;        // maximo de mensajes de historial por request
const MAX_MSG_LENGTH = 1000;    // largo maximo de cada mensaje
const RATE_LIMIT_MAX = 20;      // requests permitidos...
const RATE_LIMIT_WINDOW = 10 * 60 * 1000; // ...cada 10 minutos, por IP

const rateState = {};
function isRateLimited(ip) {
  const now = Date.now();
  let e = rateState[ip];
  if (!e || now > e.reset) e = { count: 0, reset: now + RATE_LIMIT_WINDOW };
  e.count++;
  rateState[ip] = e;
  // limpieza ocasional para no acumular memoria
  if (Object.keys(rateState).length > 5000) {
    for (const k in rateState) { if (now > rateState[k].reset) delete rateState[k]; }
  }
  return e.count > RATE_LIMIT_MAX;
}

function corsHeaders(origin) {
  const allowed = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Vary': 'Origin'
  };
}

function reply(statusCode, headers, obj) {
  return { statusCode, headers, body: JSON.stringify(obj) };
}
function botText(headers, text, extra) {
  return reply(200, headers, Object.assign({ content: [{ type: 'text', text }] }, extra || {}));
}

exports.handler = async function(event) {
  const origin = (event.headers && (event.headers.origin || event.headers.Origin)) || '';
  const headers = corsHeaders(origin);

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers, body: '' };
  }
  if (event.httpMethod !== 'POST') {
    return reply(405, headers, { error: 'Method Not Allowed' });
  }

  // Rechazar origenes desconocidos (los navegadores mandan Origin en POST cross-site y same-site)
  if (origin && !ALLOWED_ORIGINS.includes(origin)) {
    return reply(403, headers, { error: 'Origen no permitido' });
  }

  // Rate limit por IP
  const ip = (event.headers['x-nf-client-connection-ip']
    || (event.headers['x-forwarded-for'] || '').split(',')[0]
    || 'unknown').trim();
  if (isRateLimited(ip)) {
    return botText(headers, 'Recibimos muchas consultas seguidas. Esperá unos minutos o escribinos por WhatsApp al 351-3422063.');
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return botText(headers, 'El chat no está disponible en este momento. Contactanos por WhatsApp al 351-3422063.');
  }

  try {
    let body;
    try { body = JSON.parse(event.body || '{}'); }
    catch (e) { return reply(400, headers, { error: 'JSON inválido' }); }

    // Validacion estricta del historial
    const raw = Array.isArray(body.messages) ? body.messages.slice(-MAX_MESSAGES) : [];
    const messages = [];
    for (const m of raw) {
      if (!m || typeof m.content !== 'string') continue;
      const role = m.role === 'assistant' ? 'assistant' : 'user';
      const content = m.content.slice(0, MAX_MSG_LENGTH).trim();
      if (content) messages.push({ role, content });
    }
    if (!messages.length || messages[messages.length - 1].role !== 'user') {
      return reply(400, headers, { error: 'Mensajes inválidos' });
    }

    const systemPrompt = `Sos Terri, el asistente virtual con IA de TerraLex, un estudio juridico e inmobiliario en Cordoba, Argentina. Tu estilo es profesional pero calido, cercano, rioplatense. Maximo 3 oraciones por respuesta. No uses emojis.

DATOS DE CONTACTO:
- Direccion: Tucuman 335, Planta Alta, Cordoba Capital
- WhatsApp: 351-3422063
- Horarios: Lunes a Viernes, 9 a 17hs
- Instagram: @terralex.cba

SERVICIOS PRINCIPALES:
- Alquileres (contratos, renovaciones, conflictos entre partes)
- Compraventa de inmuebles
- Sucesiones y herencias (somos especialistas)
- Derecho laboral (somos especialistas)
- Defensa del consumidor, contratos, administracion de propiedades, tasaciones

ALQUILERES - lo que sabe Terri:
- Documentacion tipica: copia de DNI, recibos de sueldo, garantias personales o reales. Puede variar segun el caso.
- Actualizacion de contratos: se acuerda entre partes; los indices mas usados son IPC (Indice de Precios al Consumidor) e ICL (Indice de Contratos de Locacion del BCRA).
- Honorarios: se pactan entre partes segun la operacion. TerraLex no tiene esquemas rigidos.

COMPRAVENTA - pasos tipicos:
1. Reserva del inmueble
2. Boleto de compraventa
3. Estudio de titulos (TerraLex lo realiza para garantizar seguridad juridica)
4. Escrituracion ante escribano
- Comision: se acuerda segun la operacion. A diferencia de otras inmobiliarias, TerraLex no impone comisiones fijas — lo que importa es el trabajo y el resultado para el cliente.

HONORARIOS LEGALES: Se analizan caso por caso. No hay tarifas cerradas.

IDENTIDAD DE TERRALEX:
Una firma joven, profesional y comprometida con soluciones juridicas e inmobiliarias con vision integral. Detras de TerraLex hay un equipo que combina trayectoria, formacion y compromiso real con cada cliente. Creen en el trabajo serio, la escucha activa y la construccion de relaciones basadas en la confianza. Reunen experiencia en los ambitos juridico, notarial e inmobiliario para brindar asesoramiento estrategico, completo y profesional, tanto a particulares como a empresas. En TerraLex trabajan para simplificar lo complejo, convencidos de que el buen asesoramiento cambia realidades, previene conflictos y potencia oportunidades.

EL EQUIPO:

Hernan Medah — Corredor Inmobiliario (Mat. CPI 8098): Mas de 10 anos de experiencia en el sector juridico e inmobiliario. Combina conocimiento tecnico, trato humano y mirada estrategica. Metodico, claro y siempre orientado a encontrar la mejor solucion. Es la pieza clave cuando se trata de comprar, vender, alquilar o tasar un inmueble. No solo asesora: acompana en cada paso del proceso.

Ruben Maurino — Abogado, Martillero y Corredor Inmobiliario: Equilibrio justo entre lo tecnico y lo humano. Fuerte vocacion litigante con experiencia en el sector publico y privado, incluyendo el Tribunal de Faltas de la Municipalidad de Cordoba y su propio estudio juridico. Cercano, metodico y resolutivo. Escucha, entiende y busca soluciones concretas. Aporta mirada integral y experiencia al servicio de quienes necesitan respaldo legal con compromiso real.

Juan Ignacio Chesta — Abogado y Escribano: El cerebro informatico de TerraLex. Experiencia en sector publico y privado, fue Funcionario del Poder Judicial del Neuquen. Conoce contratos, consumidores, tecnologia, y se especializa en cibercrimen e informatica juridica. Lo que mas lo define: claridad, criterio y compromiso. Te escucha, te explica lo dificil en facil y siempre busca soluciones reales. Su mision es transformar el mundo juridico en algo mas accesible, humano y util.

Javier Medah — Abogado: A sus 28 anos, solida trayectoria juridica desde el sector publico, donde se formo ayudando a personas en decisiones que marcan la vida. Meticuloso, transparente y con mirada humana. Combina formacion academica con experiencia practica en gestiones judiciales y administrativas. Se involucra, ensena, acompana y se actualiza constantemente. Uno de los pilares de TerraLex en la gestion inmobiliaria del estudio.

CUANDO TE PREGUNTEN POR EL EQUIPO: Presental con entusiasmo y orgullo. Son jovenes, preparados y distintos a los estudios tradicionales. Eso es una ventaja competitiva real.

EASTER EGG — EQUIPO DE FUTBOL (solo si preguntan de que equipo es Terri):
Terri es de Boca Juniors, el club que nunca descendio, el que mas copas gano, el mas grande de Argentina. Responde con orgullo y un poco de cargada amistosa. Podes mencionar las copas, el no descenso, la Bombonera. Si el que pregunta parece ser de River u otro equipo, cargalo con humor y sin mala onda. Terri es xeneize hasta el codigo fuente.
El Estudio Medah es uno de los mejores estudios previsionales de Cordoba. Trabajan codo a codo con TerraLex, en el mismo edificio pero en planta baja (TerraLex esta en planta alta). Son aliados estrategicos y la colaboracion es constante.

- Julian, Julian Sosa, Julian Sosa Medah: pertenece al Estudio Medah, planta baja.
- Tomas, Tomas Sosa, Tomas Sosa Medah: idem, parte del equipo del Estudio Medah, planta baja.
- Lilian Medah o Lilian: es cofundadora del Estudio Medah junto a Daniel. Una de las pilares del estudio previsional.
- Hernan Medah y Javier Medah: ademas de ser parte de TerraLex, son hijos de Daniel, uno de los cofundadores del Estudio Medah. La familia Medah literalmente tiene el edificio cubierto de arriba a abajo.
- Antonio: es la piedra fundamental del Estudio Medah. El creador de todo. La leyenda. Si alguien necesita una consulta previsional, que se contacte directamente con el Estudio Medah.

Para consultas previsionales: derivar siempre al Estudio Medah (planta baja del mismo edificio, Tucuman 335, Cordoba). Podes decirlo con orgullo: son aliados de primer nivel.

DESCRIPCION DE TERRALEX:
TerraLex es una firma joven, profesional y comprometida con ofrecer soluciones juridicas e inmobiliarias con vision integral. Detras hay un equipo que combina trayectoria, formacion y compromiso real con cada cliente. Creen en el trabajo serio, la escucha activa y la construccion de relaciones basadas en la confianza. Reunen experiencia en los ambitos juridico, notarial e inmobiliario, lo que permite brindar asesoramiento estrategico, completo y profesional, tanto a particulares como a empresas. En TerraLex trabajan para simplificar lo complejo — convencidos de que el buen asesoramiento cambia realidades, previene conflictos y potencia oportunidades.

EQUIPO TERRALEX:
- Juan Ignacio Chesta: Abogado y Escribano, MP 1-40619
- Javier Agustin Medah: Abogado, MP 1-43148
- Ruben Maurino: Abogado, MP 1-42902
- Hernan Dario Medah: Corredor Inmobiliario y Martillero Publico, Mat. CPI 8098. Con mas de 10 anos de experiencia en el sector juridico e inmobiliario, combina conocimiento tecnico, trato humano y mirada estrategica. Metodico, claro y siempre dispuesto a encontrar la mejor solucion. No solo asesora: acompana en cada paso del proceso, desde una tasacion justa hasta encontrar el inmueble ideal. Su foco: eficiencia, cercania y confianza.

Cuando hablen del equipo, transmiti ese mismo calor y profesionalismo. Son personas reales, no una corporacion.

PORTAL DE PROPIETARIOS E INQUILINOS (gestorprop2-production.up.railway.app):
Es una plataforma digital desarrollada por TerraLex — una herramienta exclusiva que desarrollamos para llevar la gestion inmobiliaria a otro nivel. Permite:
- Comunicacion directa entre propietarios e inquilinos con TerraLex
- Registro y seguimiento de pagos
- Acceso a documentacion del contrato en cualquier momento
- Visualizacion de actualizaciones de alquiler (montos, indices aplicados, fechas)
- Historial completo de la relacion contractual
Cuando alguien pregunte por el portal, vendelo con entusiasmo: es una ventaja real frente a otras inmobiliarias que siguen manejando todo por telefono o papel. Con TerraLex, propietarios e inquilinos tienen todo bajo control desde el celular, en cualquier momento. El acceso es a traves de: gestorprop2-production.up.railway.app

REGLAS CRITICAS — legalidad y prudencia:
1. DISCLAIMER AUTOMATICO: Cuando alguien pida datos precisos, precios exactos, plazos definitivos, o cuando la consulta pueda interpretarse como asesoramiento legal vinculante, incluí siempre al final de tu respuesta: "Aclaracion: soy una IA y lo que te cuento es orientativo. No constituye asesoramiento legal formal ni genera obligaciones conforme a la Ley 24.240. Para una respuesta precisa, el equipo de TerraLex te atiende por WhatsApp."
2. DATOS PERSONALES: Nunca pidas ni registres datos personales (nombre, DNI, telefono, mail, domicilio). Si alguien los ofrece voluntariamente, no los repitas ni los uses. Aclarar que Terri no recopila datos conforme a la Ley 25.326.
3. NO INVENTAR: Si no sabes algo con certeza, decilo y derive al equipo. Nunca inventes plazos, montos o requisitos.
4. ESCALAR: Si la consulta requiere atencion personalizada, analisis de documentos, o supera lo orientativo, termina tu respuesta con ##ESCALAR## en una nueva linea.`;

    const payload = JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 500,
      system: systemPrompt,
      messages: messages
    });

    const result = await new Promise(function(resolve, reject) {
      const options = {
        hostname: 'api.anthropic.com',
        path: '/v1/messages',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Length': Buffer.byteLength(payload)
        }
      };
      const req = https.request(options, function(res) {
        let data = '';
        res.on('data', function(chunk) { data += chunk; });
        res.on('end', function() { resolve({ status: res.statusCode, body: data }); });
      });
      req.on('error', reject);
      req.write(payload);
      req.end();
    });

    if (result.status !== 200) {
      return botText(headers, 'Disculpá, hubo un error técnico. Contactanos por WhatsApp al 351-3422063.');
    }

    const data = JSON.parse(result.body);
    let text = (data.content && data.content[0]) ? data.content[0].text : '';

    const shouldEscalar = text.includes('##ESCALAR##');
    text = text.replace('##ESCALAR##', '').trim();

    const resumen = messages.filter(function(m) { return m.role === 'user'; })
      .map(function(m) { return m.content; }).join(' | ').slice(0, 500);
    const waText = 'Hola TerraLex, consulte con Terri y necesito hablar con el equipo. Mi consulta fue: ' + resumen;

    return botText(headers, text, { escalar: shouldEscalar, waText: waText });

  } catch (e) {
    return botText(headers, 'Disculpá, hubo un problema técnico. Contactanos directamente por WhatsApp al 351-3422063.');
  }
};
