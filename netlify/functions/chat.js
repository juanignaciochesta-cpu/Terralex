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

    var payload = JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 500,
      system: 'Sos Terri, el asistente virtual con IA de TerraLex, un estudio juridico e inmobiliario en Cordoba, Argentina. Responde consultas de manera amable, clara y profesional. Informacion: Direccion: Tucuman 335, Planta Alta, Cordoba Capital. WhatsApp: 351-3422063. Horarios: Lunes a Viernes 9 a 17hs. Servicios: contratos, alquileres, compraventa de inmuebles, derecho de familia, laboral, sucesiones, defensa del consumidor, tasaciones, administracion de propiedades. IMPORTANTE: Si la consulta requiere atencion personalizada o no podes responderla con certeza, termina tu respuesta exactamente con la palabra clave ##ESCALAR## en una nueva linea. Responde en castellano rioplatense, maximo 3 oraciones. No uses emojis.',
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

    // Detectar si hay que escalar y limpiar la palabra clave
    var shouldEscalar = text.includes('##ESCALAR##');
    text = text.replace('##ESCALAR##', '').trim();

    // Armar resumen de la conversacion para WhatsApp
    var waText = '';
    if (shouldEscalar) {
      var resumen = messages.filter(function(m) { return m.role === 'user'; })
        .map(function(m) { return m.content; }).join(' | ');
      waText = 'Hola TerraLex, fui atendido por Terri y necesito hablar con el equipo. Mi consulta: ' + resumen;
    }

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
