import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Envía una o varias fotos a Google Gemini (modelo con visión) y le pide
/// que devuelva directamente los datos del formulario en JSON.
///
/// A diferencia del OCR local (que falla mucho con letra manuscrita),
/// un modelo de IA con visión "entiende" la imagen completa como lo
/// haría una persona, así que interpreta bastante mejor la letra a
/// mano — a costa de necesitar internet y una API key.
///
/// La API key es gratuita: se obtiene en https://aistudio.google.com/apikey
/// Resultado de leer un parte digital con IA: metadatos comunes del
/// incidente + la lista de vehículos involucrados (puede tener 1 o
/// varios elementos).
class ParteDigitalExtraido {
  final Map<String, String> metadatos;
  final List<Map<String, String>> vehiculos;
  ParteDigitalExtraido({required this.metadatos, required this.vehiculos});
}

class GeminiVisionService {
  static const _modelo = 'gemini-3.8-flash';
  static const _modeloFallback = 'gemini-3.6-flash';
  static const _endpointBase =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const _camposIngreso = [
    'hojaIngresoNro',
    'parteIngresoNro',
    'crv',
    'subzona',
    'fechaIngreso',
    'horaRetencion',
    'tipoVehiculo',
    'marca',
    'modelo',
    'anioFabricacion',
    'color',
    'cilindraje',
    'chasis',
    'motor',
    'placa',
    'propietario',
    'cedulaPropietario',
    'conductor',
    'cedulaConductor',
    'causaLegal',
    'detalleCausa',
    'traslado',
    'custodioRecibeNombre',
    'policiaNombre',
    'policiaCedula',
  ];

  /// Campos de Libertad — ahora cubren TODOS los documentos posibles:
  /// hoja física de salida, oficio judicial de devolución/memorando,
  /// y orden de pago + comprobante bancario/Datafast.
  static const _camposLibertad = [
    // De la hoja física de salida (si se fotografía también):
    'hojaIngresoNro',
    'marca',
    'color',
    'placa',
    'fechaIngreso',
    'fechaSalida',
    'retiradoPor',
    'cedulaRetira',
    // Del oficio judicial de devolución / memorando:
    'memorandoNro',
    'memorandoFecha',
    'oficioDevolucionNro',
    'oficioDevolucionFecha',
    'firmadoPor',
    // De la Orden de Pago (Agencia Nacional de Tránsito):
    'ordenPagoNro',
    'diasPagados',
    'precioUnitario',
    'tipoServicioGaraje',
    // Del comprobante bancario / Datafast:
    'comprobantePagoNro',
    'valor',
    'valorTransaccionOComision',
    'horaFechaPago',
    'entidadFinanciera',
  ];

  Future<Map<String, String>> extraerIngreso(List<File> imagenes, String apiKey) =>
      _extraer(imagenes, apiKey, _camposIngreso, _promptIngreso);

  Future<Map<String, String>> extraerLibertad(List<File> imagenes, String apiKey) =>
      _extraer(imagenes, apiKey, _camposLibertad, _promptLibertad);

  /// Lee un parte policial de tránsito DIGITAL (PDF de Ecu911) a partir
  /// de imágenes ya rasterizadas de cada una de sus páginas — mismo
  /// principio que extraerIngreso/extraerLibertad, pero con un prompt
  /// propio porque un parte puede describir VARIOS vehículos a la vez.
  ///
  /// Este es ahora el camino PRINCIPAL para leer un PDF: a diferencia
  /// de extraer el texto interno del PDF y aplicarle expresiones
  /// regulares (ver PdfParserService, que queda como respaldo sin
  /// conexión), la IA "lee" cada página como lo haría una persona, sin
  /// depender de en qué orden haya quedado el texto dentro del PDF —
  /// eso varía de un patio a otro y de una versión de Ecu911 a otra,
  /// cosa que ningún conjunto fijo de expresiones regulares puede
  /// cubrir por completo.
  Future<ParteDigitalExtraido> extraerParteDigital(List<Uint8List> paginasPng, String apiKey) async {
    final parts = <Map<String, dynamic>>[
      {'text': _promptParteDigital}
    ];
    for (final png in paginasPng) {
      parts.add({
        'inline_data': {'mime_type': 'image/png', 'data': base64Encode(png)}
      });
    }

    final body = jsonEncode({
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {'response_mime_type': 'application/json'},
    });

    final respuesta = await _llamarGemini(body, apiKey, const Duration(seconds: 60));

    final data = jsonDecode(respuesta.body);
    final texto = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    if (texto == null) {
      throw Exception('Respuesta inesperada de Gemini: ${respuesta.body}');
    }

    var jsonLimpio = texto.trim();
    if (jsonLimpio.startsWith('```')) {
      jsonLimpio = jsonLimpio.replaceAll(RegExp(r'^```(json)?\s*|\s*```$'), '').trim();
    }
    final json = jsonDecode(jsonLimpio) as Map<String, dynamic>;
    const metaCampos = [
      'parteNo', 'fechaHecho', 'horaHecho', 'policiaNombre', 'policiaCedula', 'causaLegal', 'circunstancias',
    ];
    final metadatos = {for (final c in metaCampos) c: (json[c] ?? '').toString()};

    const vehCampos = [
      'placa', 'tipo', 'marca', 'modelo', 'color', 'chasis', 'motor', 'pais', 'anio',
      'conductor', 'conductorCedula', 'propietario', 'propietarioCedula',
    ];
    final vehiculosJson = (json['vehiculos'] as List?) ?? const [];
    final vehiculos = vehiculosJson.whereType<Map<String, dynamic>>().map((v) {
      return {for (final c in vehCampos) c: (v[c] ?? '').toString()};
    }).toList();

    return ParteDigitalExtraido(metadatos: metadatos, vehiculos: vehiculos);
  }

  static const _promptIngreso = '''
Eres un asistente que digitaliza hojas de "RECEPCIÓN DEL VEHÍCULO EN EL PATIO DE RETENCIÓN VEHICULAR DE TRÁNSITO" de la Policía Nacional del Ecuador.
La hoja tiene texto impreso (etiquetas) y datos llenados a mano (a veces con letra cursiva difícil).
Extrae SOLO los siguientes datos de la parte SUPERIOR de la hoja (ingreso), en JSON, sin explicaciones, sin markdown:
- hojaIngresoNro: el número impreso en rojo en la esquina superior derecha (7 dígitos aprox., ej. "0002099")
- parteIngresoNro: número de parte policial, si aparece
- crv: el nombre del control/CRV (ej. "Control 120")
- subzona: la subzona si se menciona (ej. "Santo Domingo")
- fechaIngreso: fecha de ingreso en formato dd/mm/aaaa
- horaRetencion: hora de la retención/ingreso si aparece
- tipoVehiculo: uno de AUTOMÓVIL, CAMIONETA, CAMIÓN, BUS, MOTOCICLETA, PLATAFORMA u OTRO
- marca: marca del vehículo (ej. "SINOTRUCK")
- modelo: modelo del vehículo si aparece
- anioFabricacion: año de fabricación si aparece
- color: color del vehículo
- cilindraje: solo si es MOTOCICLETA (ej. "150cc"), si no aplica deja ""
- chasis: número de chasis/VIN si aparece (no aplica a motocicletas)
- motor: número de motor si aparece (no aplica a motocicletas)
- placa: placas del vehículo (formato ecuatoriano, 3 letras + números, ej. "PAD-1978")
- propietario: nombre completo del propietario
- cedulaPropietario: número de cédula del propietario. Búscalo primero junto al nombre del propietario en la parte superior; si no aparece ahí, búscalo en la sección inferior "RECIBE CONFORME" o junto a la palabra "Yo" (quien retira el vehículo).
- conductor: nombre del conductor si aparece y es distinto del propietario
- cedulaConductor: cédula del conductor si aparece
- causaLegal: una descripción corta de la causa de la detención (ej. "Accidente de tránsito", "Infracción de tránsito")
- detalleCausa: el detalle textual completo de la causa/artículo, tal como aparece escrito
- traslado: cómo llegó el vehículo — "SUS PROPIOS MEDIOS", "PARTICULAR" (grúa particular) o "GRÚA POLICIAL"
- custodioRecibeNombre: quién recibe físicamente la custodia del vehículo
- policiaNombre: grado y nombre de quien elabora/toma el procedimiento
- policiaCedula: cédula de quien elabora el procedimiento, si aparece
Si un dato no aparece o no se puede leer con confianza, usa "" (cadena vacía). NUNCA inventes datos.
Responde ÚNICAMENTE el objeto JSON con esas claves.''';

  static const _promptLibertad = '''
Eres un asistente que digitaliza documentos para la LIBERTAD (devolución) de un vehículo retenido, de la Policía Nacional del Ecuador. Vas a recibir VARIAS fotos que pueden ser de HASTA TRES documentos distintos — no todas las fotos son del mismo documento, así que revisa cada una por separado antes de decidir de dónde sale cada dato:

DOCUMENTO A — Hoja física de control (sección inferior "SALIDA DEL VEHÍCULO DEL PATIO DE RETENCIÓN DE TRÁNSITO", llenada a mano/esfero):
- hojaIngresoNro: número impreso en rojo en la esquina superior derecha de la hoja
- marca, color, placa: datos del vehículo (arriba de la hoja)
- fechaIngreso: fecha de ingreso (arriba) en formato dd/mm/aaaa
- fechaSalida: fecha de salida (sección inferior) en formato dd/mm/aaaa
- retiradoPor: el nombre que sigue a la palabra "Yo" en la sección de salida
- cedulaRetira: número de cédula en la sección "RECIBE CONFORME" de abajo

DOCUMENTO B — Oficio/memorando judicial de devolución de vehículo (documento de un Juez o Fiscal, con membrete de una Unidad Judicial o Fiscalía):
- memorandoNro: número que aparece después de "Memorando Nro." o similar
- memorandoFecha: fecha de ese memorando, formato dd/mm/aaaa
- oficioDevolucionNro: número después de "Oficio de DEVOLUCIÓN DE VEHÍCULO Nro." o similar
- oficioDevolucionFecha: fecha de ese oficio, formato dd/mm/aaaa
- firmadoPor: nombre completo y cargo de quien firma el oficio (ej. "Dr. Fulano de Tal, Juez de la Unidad Judicial de Tránsito de...")

DOCUMENTO C1 — Orden de Pago (formato "SOLICITUD DE PAGO" / "ORDEN DE PAGO No." de la Agencia Nacional de Tránsito):
- ordenPagoNro: número después de "ORDEN DE PAGO No."
- diasPagados: el número de la columna "Cantidad" (cantidad de días)
- precioUnitario: el número de la columna "Precio Unitario", sin símbolo de dólar
- tipoServicioGaraje: el texto completo de la fila "Rubro"/"Servicio" tal como aparece impreso (ej. "SERVICIO DE GARAJE PESADOS (DE 3,51 TN HASTA 12 TN)") — transcríbelo literal, no lo resumas ni lo interpretes

DOCUMENTO C2 — Comprobante bancario o de Datafast (recibo de pago):
- comprobantePagoNro: número de comprobante/referencia/autorización del pago
- valor: el monto TOTAL realmente cobrado en el comprobante, sin símbolo de dólar (incluye cualquier comisión si aparece sumada)
- valorTransaccionOComision: si el comprobante muestra por separado un "valor de la transacción" o comisión, colócalo aquí; si no aparece, usa ""
- horaFechaPago: fecha y hora del pago tal como aparecen
- entidadFinanciera: nombre del banco o entidad

REGLAS IMPORTANTES:
- Si no ves el Documento A en las fotos, igual intenta llenar los campos de marca/color/placa si aparecen en cualquier otro documento (a veces el comprobante o el oficio también los mencionan); si no aparecen en ninguna foto, usa "".
- Si un dato no aparece en NINGUNA de las fotos o no se puede leer con confianza, usa "" (cadena vacía). NUNCA inventes ni calcules valores.
- No confundas el "valor" del comprobante bancario con el "precioUnitario" de la Orden de Pago: son documentos distintos.
Responde ÚNICAMENTE el objeto JSON con las claves: hojaIngresoNro, marca, color, placa, fechaIngreso, fechaSalida, retiradoPor, cedulaRetira, memorandoNro, memorandoFecha, oficioDevolucionNro, oficioDevolucionFecha, firmadoPor, ordenPagoNro, diasPagados, precioUnitario, tipoServicioGaraje, comprobantePagoNro, valor, valorTransaccionOComision, horaFechaPago, entidadFinanciera.''';

  static const _promptParteDigital = '''
Eres un asistente que digitaliza partes policiales de tránsito DIGITALES (emitidos por el sistema Ecu911 de Ecuador), que vas a recibir como una imagen de cada página del PDF, en orden.
Un mismo parte describe un incidente y puede tener UNO o VARIOS vehículos involucrados.

Devuelve ÚNICAMENTE un objeto JSON (sin markdown, sin explicación) con esta forma exacta:
{
  "parteNo": "número de 'Parte Policial No.' en la sección 'Información general'",
  "fechaHecho": "fecha del hecho, formato dd/mm/aaaa",
  "horaHecho": "hora aproximada del hecho, formato hh:mm",
  "policiaNombre": "Grado. NOMBRE COMPLETO del policía de MAYOR GRADO en la tabla 'Personal policial que participó en el hecho' (si esa tabla no existe, usa el de 'Realizado por')",
  "policiaCedula": "cédula de ese mismo policía",
  "causaLegal": "resumen corto de la causa/circunstancia (ej. Accidente de tránsito)",
  "circunstancias": "el texto completo de la sección 'Circunstancias del hecho', tal como aparece escrito",
  "vehiculos": [
    {
      "placa": "placa de este vehículo",
      "tipo": "tipo de vehículo (ej. Automóvil, Camioneta, Camión, Bus, Jeep, Furgón, Motocicleta)",
      "marca": "marca",
      "modelo": "modelo/versión si aparece",
      "color": "color de ESTE vehículo específico (no mezcles el color de otro vehículo del mismo parte)",
      "chasis": "número de chasis/VIN si aparece (normalmente 17 caracteres), suele estar en 'Objetos registrados como indicios'",
      "motor": "número de motor si aparece",
      "pais": "país de fabricación si aparece",
      "anio": "año de fabricación si aparece",
      "conductor": "nombre del conductor de ESTE vehículo",
      "conductorCedula": "cédula del conductor",
      "propietario": "nombre del propietario de ESTE vehículo (si el parte no distingue propietario de conductor, repite el nombre del conductor)",
      "propietarioCedula": "cédula del propietario"
    }
  ]
}

REGLAS IMPORTANTES:
- Incluye una entrada en "vehiculos" por CADA vehículo descrito como involucrado/retenido (secciones "VEHÍCULOS INVOLUCRADOS" o "Participante N"). NO incluyas vehículos que solo se mencionan de paso en el relato sin ser parte del incidente (ej. la ambulancia, el vehículo policial que acude, la grúa, el vehículo de Medicina Legal).
- No repitas ni mezcles datos entre vehículos distintos: cada uno tiene su propia marca/color/chasis/conductor, aunque estén descritos muy cerca uno del otro en el texto.
- En los PDF de Ecu911 es normal que, dentro de una tabla, las etiquetas de las columnas y sus valores no queden alineados visualmente en el mismo orden — interpreta el CONTENIDO real de cada dato según el contexto, no la posición del texto en la página.
- Si un dato no aparece o no se puede leer con confianza, usa "" (cadena vacía). NUNCA inventes ni calcules datos.
Responde ÚNICAMENTE el objeto JSON descrito arriba.''';

  Future<Map<String, String>> _extraer(
    List<File> imagenes,
    String apiKey,
    List<String> campos,
    String prompt,
  ) async {
    final parts = <Map<String, dynamic>>[
      {'text': prompt}
    ];

    for (final img in imagenes) {
      final bytes = await img.readAsBytes();
      parts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': base64Encode(bytes),
        }
      });
    }

    final body = jsonEncode({
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {'response_mime_type': 'application/json'},
    });

    final respuesta = await _llamarGemini(body, apiKey, const Duration(seconds: 45));

    final data = jsonDecode(respuesta.body);
    final texto = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    if (texto == null) {
      throw Exception('Respuesta inesperada de Gemini: ${respuesta.body}');
    }

    var jsonLimpio = texto.trim();
    if (jsonLimpio.startsWith('```')) {
      jsonLimpio = jsonLimpio.replaceAll(RegExp(r'^```(json)?\s*|\s*```$'), '').trim();
    }
    final json = jsonDecode(jsonLimpio) as Map<String, dynamic>;
    return {for (final campo in campos) campo: (json[campo] ?? '').toString()};
  }

  Future<http.Response> _llamarGemini(String body, String apiKey, Duration timeout) async {
    final modelosATestar = [
      'gemini-3.8-flash',
      'gemini-4.0-flash',
      'gemini-3.6-flash',
      'gemini-3.5-flash',
      'gemini-2.5-flash',
    ];

    final errores = <String>[];

    for (final modelo in modelosATestar) {
      final uri = Uri.parse('$_endpointBase/$modelo:generateContent?key=$apiKey');
      final respuesta = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout);

      if (respuesta.statusCode == 200) {
        return respuesta;
      }
      
      final err = 'Modelo $modelo falló con ${respuesta.statusCode}: ${respuesta.body}';
      errores.add(err);
      
      if (respuesta.statusCode == 503 || respuesta.statusCode == 500) {
        continue; // El servidor está saturado o falló internamente para este modelo, probamos el siguiente
      }
      
      if (respuesta.statusCode != 404) {
        final bodyLower = respuesta.body.toLowerCase();
        final esErrorDeModelo = bodyLower.contains('not found') || bodyLower.contains('not supported');
        if (respuesta.statusCode != 400 || !esErrorDeModelo) {
          // Es un error grave (ej. payload muy grande o key inválida), no tiene sentido probar más modelos
          throw Exception(errores.join(' | '));
        }
      }
    }

    throw Exception('Ningún modelo funcionó. Historial: ${errores.join(' | ')}');
  }
}
