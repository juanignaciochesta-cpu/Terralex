const https = require('https');

exports.handler = async function(event) {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  try {
    var body = JSON.parse(event.body);
    var messages = (body.messages || []).slice(-8);

    var payload = JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 400,
      system: 'Sos el asistente virtual de TerraLex, un estudio juridico e inmobiliario en Cordoba, Argentina. Tu rol es responder consultas de manera amable, clara y profesional. Informacion clave: Direccion: Tucuman 335, Planta Alta, Cordoba Capital. Telefono/WhatsApp: 351-3422063. Horarios: Lunes a Viernes 9 a 17hs. Servicios: contratos, alquileres, compraventa de inmuebles, derecho de familia, laboral, sucesiones, defensa del consumidor, tasaciones, administracion de propiedades. Si no podes responder con certeza, invita a contactar al equipo por WhatsApp. Responde en castellano rioplatense, de forma concisa (maximo 3 oraciones). No uses emojis.',
      messages: messages
    });

    var result = await new Promise(function(resolve, reject) {
      var options = {
        hostname: 'api.anthropic.com',
        path: '/v1/messages',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': process.env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
          'Content-Length': Buffer.byteLength(payload)
        }
      };

      var req = https.request(options, function(res) {
        var data = '';
        res.on('data', function(chunk) { data += chunk; });
        res.on('end', function() { resolve(data); });
      });

      req.on('error', reject);
      req.write(payload);
      req.end();
    });

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: result
    };

  } catch(e) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: e.message })
    };
  }
};
