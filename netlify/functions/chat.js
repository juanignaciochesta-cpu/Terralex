const https = require('https');

exports.handler = async function(event) {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  var apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ content: [{ type: 'text', text: 'ERROR: API key no encontrada.' }] })
    };
  }

  try {
    var body = JSON.parse(event.body);
    var messages = (body.messages || []).slice(-8);

    var systemPrompt = `Sos Terri, el asistente virtual con IA de TerraLex, un estudio juridico e inmobiliario en Cordoba, Argentina. Tu estilo es profesional pero calido, cercano, rioplatense. Maximo 3 oraciones por respuesta. No uses emojis.

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

    var payload = JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 500,
      system: systemPrompt,
      messages: messages
    });

    var result = await new Promise(function(resolve, reject) {
      var options = {
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
      var req = https.request(options, function(res) {
        var data = '';
        res.on('data', function(chunk) { data += chunk; });
        res.on('end', function() { resolve({ status: res.statusCode, body: data }); });
      });
      req.on('error', reject);
      req.write(payload);
      req.end();
    });

    if (result.status !== 200) {
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ content: [{ type: 'text', text: 'Disculpa, hubo un error tecnico. Contactanos por WhatsApp al 351-3422063.' }] })
      };
    }

    var data = JSON.parse(result.body);
    var text = (data.content && data.content[0]) ? data.content[0].text : '';

    var shouldEscalar = text.includes('##ESCALAR##');
    text = text.replace('##ESCALAR##', '').trim();

    var resumen = messages.filter(function(m) { return m.role === 'user'; })
      .map(function(m) { return m.content; }).join(' | ');
    var waText = 'Hola TerraLex, consulte con Terri y necesito hablar con el equipo. Mi consulta fue: ' + resumen;

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({
        content: [{ type: 'text', text: text }],
        escalar: shouldEscalar,
        waText: waText
      })
    };

  } catch(e) {
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ content: [{ type: 'text', text: 'Disculpa, hubo un problema tecnico. Contactanos por WhatsApp al 351-3422063.' }] })
    };
  }
};
