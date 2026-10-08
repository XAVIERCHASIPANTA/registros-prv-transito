// RUTA DE ARCHIVO: lib/services/pdf_parser_service.dart

import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../data/causa_legal_catalogo.dart';
import '../models/participante_vehiculo.dart';

/// Lee un PDF de "Parte Policial / Noticia del Incidente" (sistema Ecu911).
/// A diferencia de las fotos de la hoja física, este es texto digital
/// real: no hace falta OCR, solo extraer el texto y separarlo con
/// expresiones regulares.
///
/// REGLAS DE EXTRACCIÓN (confirmadas por Xavier el 08/sep, contra 7
/// partes reales):
///  - Hora de retención  <- "Hora aproximada del Hecho"
///  - Fecha de retención <- "Fecha del Hecho" (mismo casillero que
///    antes se llamaba "Fecha de ingreso")
///  - Nombre/cédula del policía <- el de MAYOR GRADO dentro del bloque
///    "Personal policial que participó en el hecho" (su cédula está en
///    la columna "Firma" de esa tabla). Formato de salida: "Grado.
///    NOMBRE COMPLETO" (ej. "Sgos. PACA PILCO ANGEL HERIBERTO").
///  - Conductor <- primero el bloque "Información de los
///    aprehendidos/detenidos" (existe cuando el conductor fue
///    aprehendido); si no existe ese bloque, se busca en
///    "Circunstancias del hecho" con frases típicas ("quien
///    conducía", "se identificó como conductor", "estaba manejando").
///  - Propietario <- por defecto, el mismo dato que el conductor
///    (tentativo — muchas veces coincide), pero queda editable porque
///    puede no ser la misma persona.
///  - Placa y datos técnicos del vehículo (marca/chasis/país/año) <-
///    bloque "Objetos registrados como indicios". Solo se extraen ahí
///    los campos que tienen un patrón inconfundible sin importar el
///    orden en que salga el bloque (chasis = VIN de 17 caracteres,
///    país = nombre de país conocido, año = 4 dígitos en rango
///    plausible, marca = primera palabra después de la placa). Motor y
///    color NO se sacan de este bloque todavía: en las muestras
///    revisadas el orden de esos dos específicamente salía demasiado
///    revuelto como para mapearlos con confianza.
///  - Causa legal / Detalle causa <- todo el bloque "Circunstancias
///    del hecho"; si dentro de ese texto aparece una cita de artículo
///    ("art. 385 numeral 1", etc.) se usa esa cita como detalle.
///
/// RONDA 23 — 17 partes reales convertidos a Markdown por Xavier
/// (carpeta RECURSOS/PARTES DE INGRESO del repo), usados para probar
/// este parser contra variedad real sin depender solo de los 3
/// formatos de bloque documentados arriba. Simulando la lógica real
/// (regex por regex) contra los 17, se confirmó un bug real: la
/// detección de "Placa" era case-sensitive (solo reconocía "Placa:"/
/// "Placas:"), así que un parte que trae la etiqueta en MAYÚSCULAS
/// ("PLACA:", confirmado en un parte real de accidente con
/// aprehendidos) hacía que el parser devolviera CERO vehículos aunque
/// el dato sí estaba ahí. Ya corregido (caseSensitive: false en las 3
/// detecciones de placa). Con este solo fix, los 17 partes de prueba
/// pasaron de 8 con "cero vehículos" a 0.
///
/// Hallazgo aparte (no corregido todavía, pendiente de decidir con
/// Xavier si se aborda): 6 de los 17 partes de prueba NO eran del
/// tipo "accidente/Noticia del Incidente" que este parser espera, sino
/// un tipo de documento distinto — el "Oficio de Devolución de
/// Vehículo" que se genera al dar la LIBERTAD de un carro, con
/// prosa libre en vez de etiquetas "Campo: valor" (ej. "Marca Jac,
/// color Blanco, de placas GTI1610"). Ese formato trae, ya redactados
/// en el mismo párrafo, TODOS los datos que hoy se llenan a mano en el
/// formulario de Libertad: Hoja de Ingreso Nro., Parte de ingreso Nro,
/// Fecha de ingreso, Causa, Días de permanencia, Vehículo tipo, N° de
/// orden de pago/comprobante de Garaje, Valor, fecha de pago y Entidad
/// financiera — además de placa/marca/color y el propietario con
/// cédula. Es una oportunidad real de auto-rellenar el formulario de
/// LIBERTAD (no el de Ingreso) a partir de este documento, con un
/// extractor dedicado — se necesita un método nuevo, no un parche a
/// los de arriba, porque el formato es prosa libre y no bloques.
class PdfParserService {
  String? _buscar(String texto, RegExp regex, {int grupo = 1}) {
    final m = regex.firstMatch(texto);
    if (m == null) return null;
    final valor = m.group(grupo)?.trim();
    return (valor == null || valor.isEmpty) ? null : valor;
  }

  /// Busca la fecha/hora asociada a una etiqueta, tolerando que
  /// Syncfusion extraiga esta sección de tabla con TODAS las
  /// etiquetas juntas primero y TODOS los valores juntos después (en
  /// vez de "Etiqueta: valor" pegados), confirmado con partes reales
  /// en la ronda 13 vía "Ver texto reconocido" (por eso "Hora de
  /// retención" salía vacía pese a que el dato sí estaba en el PDF).
  /// En vez de exigir el valor pegado a la etiqueta, se toma la
  /// ventana desde la etiqueta hasta el siguiente encabezado de
  /// sección y se busca ahí el primer patrón de fecha/hora — es el
  /// único que hay en esa sección, sin importar cuántas líneas de
  /// distancia haya.
  String? _fechaOHoraCercaDeEtiqueta(String texto, RegExp etiqueta, {required bool esHora}) {
    final m = etiqueta.firstMatch(texto);
    if (m == null) return null;
    final resto = texto.substring(m.end);
    final finBloque = RegExp(
      r'Informaci[oó]n geogr[áa]fica|Clasificaci[oó]n del lugar|Intersecci[oó]n:',
      caseSensitive: false,
    ).firstMatch(resto);
    final ventana = finBloque == null ? resto.substring(0, resto.length.clamp(0, 600)) : resto.substring(0, finBloque.start);
    final patron = esHora ? RegExp(r'\d{1,2}:\d{2}') : RegExp(r'\d{2}/\d{2}/\d{4}');
    return patron.firstMatch(ventana)?.group(0);
  }

  /// Extrae todo el texto del PDF, página por página, a partir de sus bytes.
  String extraerTextoBytes(Uint8List bytes) {
    final documento = PdfDocument(inputBytes: bytes);
    final texto = PdfTextExtractor(documento).extractText();
    documento.dispose();
    return texto;
  }

  /// Limpia asteriscos de énfasis (sin valor semántico), normaliza
  /// TODOS los tipos de salto de línea a un espacio simple (algunos
  /// PDFs usan \r o separadores unicode en vez de \n cuando el texto
  /// de una celda se envuelve, y eso pegaba nombres largos sin
  /// espacio), y quita el encabezado/pie que Ecu911 repite en CADA
  /// página ("Parte No. ... Fecha y hora de impresión...",
  /// "REPÚBLICA DEL ECUADOR...", "Página X de Y"). Sin esto, un
  /// bloque de texto que cruza dos páginas queda partido a la mitad
  /// por ese repetido.
  String _limpiar(String texto) {
    // Normaliza CUALQUIER variante de salto de línea (\r\n de Windows,
    // \r suelto, separadores unicode) a un solo \n ANTES de todo lo
    // demás. Sin esto, un regex que busca literalmente "\n" para saber
    // dónde termina un campo se rompe silenciosamente cuando el PDF
    // real usa \r\n — y lo hace de forma inconsistente (un campo sí
    // sale, el de al lado no), que es justo lo que se venía viendo.
    var t = texto.replaceAll(RegExp(r'\r\n|\r|\u2028|\u2029'), '\n');
    t = t.replaceAll('*', '');
    t = t.replaceAll(
      RegExp(r'Parte\s*No\.?\s*\d+\s*Fecha y hora de impresi[oó]n:\s*\d{2}/\d{2}/\d{4}\s*\d{1,2}:\d{2}'),
      ' ',
    );
    t = t.replaceAll(RegExp(r'REP[ÚU]BLICA DEL ECUADOR MINISTERIO DEL INTERIOR'), ' ');
    t = t.replaceAll(RegExp(r'NOTICIA DEL INCIDENTE'), ' ');
    t = t.replaceAll(RegExp(r'P[áa]gina\s*\d+\s*de\s*\d+'), ' ');
    return t;
  }

  /// Junta todo salto de línea/espacio raro en un solo espacio, para
  /// las búsquedas que necesitan el texto "en una sola línea".
  String _unaLinea(String texto) =>
      texto.replaceAll(RegExp(r'[\r\n\u2028\u2029\t]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');

  /// Deja solo la parte de "crudo" (lo capturado por un regex de placa,
  /// que a veces arrastra texto de más cuando el PDF pega dos líneas
  /// sin espacio, ej. "TDL0101Marca" -> capturaba "TDL0101M") que de
  /// verdad tiene forma de placa ecuatoriana.
  String _normalizarPlaca(String crudo) {
    final limpio = crudo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    // Autos/camionetas/buses/camiones: 3 letras + 4 dígitos exactos,
    // sin letra sobrante al final (la causa del bug "TDL0101M").
    final auto = RegExp(r'^([A-Z]{3}\d{4})').firstMatch(limpio);
    if (auto != null) return auto.group(1)!;
    // Motocicletas u otros formatos: letras + 3 dígitos + posible 1
    // letra final (ej. KH039Z).
    final moto = RegExp(r'^([A-Z]{1,3}\d{3}[A-Z]?)').firstMatch(limpio);
    if (moto != null) return moto.group(1)!;
    // Si no calza en ninguno de los dos formatos de placa ecuatoriana,
    // solo se acepta como placa "cruda" si trae al menos un dígito —
    // una placa real siempre tiene números. Sin este filtro, una
    // palabra sin números como "CHEVROLET" (la Marca que en el bloque
    // revuelto de "Objetos registrados como indicios" queda pegada
    // justo después de la etiqueta "Placa:") se cuela como si fuera
    // una placa y arma un vehículo fantasma (confirmado en ronda 13:
    // fue el "3er vehículo" que salió de más en un parte de 2
    // vehículos reales).
    return RegExp(r'\d').hasMatch(limpio) ? limpio : '';
  }

  /// Corre [accion] y, si algo sale mal con una estructura de PDF que
  /// no se esperaba, devuelve null en vez de tumbar toda la
  /// extracción — así un casillero raro no impide seguir leyendo el
  /// resto del parte. Pedido explícito de Xavier en la ronda 13: más
  /// vale un dato vacío que un parte que "no lee nada".
  T? _intentar<T>(T Function() accion) {
    try {
      return accion();
    } catch (_) {
      return null;
    }
  }

  // ---------- Personal policial (jerarquía) ----------

  /// Orden de antigüedad policial, de MAYOR a MENOR grado.
  static const List<String> _jerarquiaPolicial = [
    'CRNL', 'TCRNL', 'MAYR', 'CPTN', 'TNTE', 'SBTE',
    'SBOM', 'SBOP', 'SBOS', 'SGOP', 'SGOS', 'CBOP', 'CBOS', 'POLI',
  ];

  /// Algunos partes abrevian distinto el mismo grado (ej. "TCNL." en
  /// vez de "TCRNL.", "MYOR" en vez de "MAYR"). Se normalizan al
  /// nombre usado en _jerarquiaPolicial antes de comparar.
  static const Map<String, String> _sinonimosGrado = {
    'TCNL': 'TCRNL',
    'MYOR': 'MAYR',
  };

  /// "Función" que casi siempre aparece pegada entre el nombre y la
  /// cédula en esa tabla (AGENTE APREHENSOR, CONDUCTOR, GUARDIA...) —
  /// se recorta del nombre ya capturado para que quede limpio.
  String _quitarFuncion(String nombre) {
    return nombre
        .replaceAll(
          RegExp(r'\s*(AGENTE\s*APREHENSOR|JEFE\s*DE\s*PATRULLA|CONDUCTOR|GUARDIA|AUXILIAR|AGENTE)\s*$'),
          '',
        )
        .trim();
  }

  /// "SGOS" -> "Sgos.", "CRNL" -> "Crnl.", etc. — el formato exacto
  /// que pidió Xavier para el nombre del policía.
  String _gradoTitulo(String grado) {
    if (grado.isEmpty) return '';
    return '${grado[0]}${grado.substring(1).toLowerCase()}.';
  }

  /// Recorta el texto completo a solo el bloque "Personal policial que
  /// participó en el hecho" (hasta "Realizado por:" o el final del
  /// documento), para no confundir con otros "GRADO NOMBRE" que
  /// aparecen en otras partes del parte (ej. "Parte elevado al Sr/a",
  /// que es a quien se DIRIGE el parte, no quien toma procedimiento).
  String? _bloquePersonalPolicial(String texto) {
    final inicio = RegExp(r'Personal polic[ií]al que particip[oó]?\s*en el hecho', caseSensitive: false)
        .firstMatch(texto);
    if (inicio == null) return null;
    final desde = texto.substring(inicio.end);
    final fin = RegExp(r'Realizado por:', caseSensitive: false).firstMatch(desde);
    return fin == null ? desde : desde.substring(0, fin.start);
  }

  /// Busca, dentro del bloque de personal policial, a quien tenga el
  /// grado más alto junto con su cédula (columna "Firma"). Devuelve el
  /// nombre YA con el grado antepuesto: "Sgos. PACA PILCO ANGEL
  /// HERIBERTO".
  ({String nombre, String cedula})? _personalMasAntiguoConCedula(String texto) {
    // Si no se encuentra el encabezado del bloque, se prefiere no
    // buscar en todo el documento (podría toparse con "Parte elevado
    // al Sr/a", que es a quien se DIRIGE el parte, no quien lo
    // elabora) — mejor devolver null y dejar que "Realizado por:"
    // sea el respaldo.
    final bloqueTexto = _bloquePersonalPolicial(texto);
    if (bloqueTexto == null) return null;
    final bloque = _unaLinea(bloqueTexto);

    final regexLinea = RegExp(
      r'\b(CRNL|TCRNL|TCNL|MAYR|MYOR|CPTN|TNTE|SBTE|SBOM|SBOP|SBOS|SGOP|SGOS|CBOP|CBOS|POLI)\.?\s+'
      r'([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ .]+?)\s+'
      r'(?:C\.?C\.?|C\.?I\.?)\.?:?\s*(\d{9,10})',
    );

    final candidatosPorGrado = <String, ({String nombre, String cedula})>{};
    for (final m in regexLinea.allMatches(bloque.toUpperCase())) {
      final grado = _sinonimosGrado[m.group(1)!] ?? m.group(1)!;
      candidatosPorGrado.putIfAbsent(
        grado,
        () => (nombre: '${_gradoTitulo(grado)} ${_quitarFuncion(m.group(2)!.trim())}', cedula: m.group(3)!),
      );
    }

    for (final grado in _jerarquiaPolicial) {
      final candidato = candidatosPorGrado[grado];
      if (candidato != null) return candidato;
    }
    return null;
  }

  // ---------- Metadatos generales ----------

  MetadatosParte extraerMetadatos(String texto) {
    final limpio = _limpiar(texto);
    final t = _unaLinea(limpio);

    // Se toma primero a quien tenga el grado más alto en la tabla
    // "Personal policial que participó en el hecho" — esa es la regla
    // real que indicó Xavier, y no siempre coincide con "Realizado
    // por:" (que puede ser cualquiera de los que llenó el parte
    // digital, no necesariamente el de mayor grado). "Realizado por:"
    // queda solo como respaldo si el documento no trae esa tabla.
    String elaboradoPor = '';
    String elaboradoPorCedula = '';
    final masAntiguo = _personalMasAntiguoConCedula(limpio);
    if (masAntiguo != null) {
      elaboradoPor = masAntiguo.nombre;
      elaboradoPorCedula = masAntiguo.cedula;
    } else {
      final realizadoPor = _buscar(
        t,
        RegExp(r'Realizado por:\s*([A-ZÁÉÍÓÚñÑ]+\.?\s*[A-ZÁÉÍÓÚñÑ][A-ZÁÉÍÓÚñÑ .]{2,60}?)(?:\.\s|Anexos|$)'),
      );
      if (realizadoPor != null) {
        elaboradoPor = realizadoPor.trim();
      }
    }

    return MetadatosParte(
      parteNo: _buscar(t, RegExp(r'Parte Policial No\.?\s*(\d+)')) ??
          _buscar(t, RegExp(r'Parte No\.?\s*(\d+)')) ??
          '',
      fechaHecho: _fechaOHoraCercaDeEtiqueta(t, RegExp(r'Fecha del Hecho:'), esHora: false) ?? '',
      horaHecho: _fechaOHoraCercaDeEtiqueta(t, RegExp(r'Hora aproximada del\s*Hecho:'), esHora: true) ?? '',
      direccion: _buscar(t, RegExp(r'Direcci[oó]n:\s*([A-Za-zÁÉÍÓÚáéíóúñÑ0-9 ]+?)(?:Intersecci[oó]n|N[uú]mero de Casa)')) ??
          '',
      // El relato del hecho viene bajo la etiqueta "Circunstancias del
      // hecho" en TODOS los formatos revisados — se lee completo, tal
      // como pidió Xavier, para que "Causa legal"/"Detalle causa" lo
      // aprovechen entero.
      circunstancias: _buscar(
              t,
              RegExp(
                  r'Circunstancias del hecho:?\s*\.?\s*(.+?)'
                  r'(?:Anexos\b|Objetos registrados|Garantias b[áa]sicas|Personal polic[íi]al que particip)',
                  dotAll: true)) ??
          '',
      elaboradoPor: elaboradoPor,
      elaboradoPorCedula: elaboradoPorCedula,
    );
  }

  /// Sugiere una de las opciones REALES de "Causa legal" (catálogo de
  /// SIIPNE 3W) según palabras clave dentro de "Circunstancias del
  /// hecho". Devuelve '' si no hay pista clara — mejor dejar que el
  /// oficial elija a mano que forzar una categoría equivocada.
  String sugerirCausaLegal(String circunstancias) {
    final c = circunstancias.toUpperCase();
    if (c.contains('EMBRIAGUEZ') ||
        c.contains('ALCOTEST') ||
        c.contains('ALCOHOL') ||
        c.contains('LLANTA') ||
        c.contains('LICENCIA') ||
        c.contains('ESTUPEFACIENTE')) {
      return 'Contravenciones de Tránsito /Artículos que permiten en el COIP la retención de los vehículos';
    }
    if (c.contains('SINIESTRO') || c.contains('CHOQUE') || c.contains('COLISI') || c.contains('ACCIDENTE')) {
      return CausaLegalCatalogo.causaAccidenteTransito;
    }
    if (c.contains('ORDEN JUDICIAL') || c.contains('JUEZ') || c.contains('JUZGADO') || c.contains('FISCAL')) {
      return CausaLegalCatalogo.causaOrdenJudicial;
    }
    if (c.contains('TOQUE DE QUEDA') || c.contains('SALVOCONDUCTO') || c.contains('RESTRICCIÓN VEHICULAR')) {
      return 'Acuerdo Ministerial 00004 /ACUERDO MINISTERIAL 10';
    }
    if (c.contains('MATRÍCULA') || c.contains('MATRICULA') || c.contains('TÍTULO HABILITANTE') || c.contains('TITULO HABILITANTE')) {
      return 'Reglamento a la LTTTSV /Artículos del Reglamento de Tránsito que estipulan la retención del vehículo.';
    }
    return '';
  }

  /// Dentro de las opciones reales de "Detalle causa" para la causa ya
  /// elegida, busca si "Circunstancias del hecho" menciona un artículo
  /// (y numeral) que coincida — ej. "art. 385 numeral 1" -> "Artículo
  /// 385.1". Devuelve null si no hay ninguna coincidencia clara (mejor
  /// dejar el desplegable en blanco que adivinar mal un artículo).
  String? sugerirDetalleCausa(String causaLegal, String circunstancias) {
    final opciones = CausaLegalCatalogo.detalles[causaLegal] ?? [];
    if (opciones.isEmpty) return null;

    final m = RegExp(r'art[íi]?culos?\.?\s*(\d+)(?:[.\s]*(?:numeral)?\s*(\d))?', caseSensitive: false)
        .firstMatch(circunstancias);
    if (m == null) return null;
    final numeroBase = m.group(1)!;
    final numeral = m.group(2);
    final buscado = numeral != null ? '$numeroBase.$numeral' : numeroBase;

    for (final op in opciones) {
      if (op.toUpperCase().contains('ARTÍCULO $buscado'.toUpperCase())) return op;
    }
    for (final op in opciones) {
      if (op.toUpperCase().contains('ARTÍCULO $numeroBase'.toUpperCase())) return op;
    }
    return null;
  }

  // ---------- Información de los aprehendidos/detenidos ----------

  /// Lista de (nombre, cédula) del bloque "Información de los
  /// aprehendidos/detenidos" — ese bloque solo existe cuando el
  /// conductor (u otra persona) fue aprehendido, y es la fuente más
  /// confiable para "Conductor" cuando está presente.
  List<({String nombre, String cedula})> _aprehendidos(String texto) {
    final inicio =
        RegExp(r'Informaci[oó]n de los aprehendidos\s*/?\s*detenidos', caseSensitive: false).firstMatch(texto);
    if (inicio == null) return [];
    final desde = texto.substring(inicio.end);
    final fin = RegExp(r'Informaci[oó]n general', caseSensitive: false).firstMatch(desde);
    final bloque = _unaLinea(fin == null ? desde : desde.substring(0, fin.start));

    final regex = RegExp(r'([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ ]{4,50}?)\s+(\d{9,10})\s+\d{2}/\d{2}/\d{4}\s+\d{1,2}:\d{2}');
    final resultado = <({String nombre, String cedula})>[];
    for (final m in regex.allMatches(bloque.toUpperCase())) {
      resultado.add((nombre: m.group(1)!.trim(), cedula: m.group(2)!));
    }
    return resultado;
  }

  /// Cuando NO hay bloque de aprehendidos, se busca en las
  /// "Circunstancias del hecho" con las frases que Xavier confirmó que
  /// suelen usarse: "quien conducía", "estaba conduciendo", "se
  /// identificó como conductor", "estaba manejando".
  ({String nombre, String? cedula})? _conductorEnCircunstancias(String circunstancias) {
    if (circunstancias.trim().isEmpty) return null;
    final c = circunstancias;

    final patrones = [
      r'identific[aá]ndose\s+c[oó]mo\s+([A-ZÁÉÍÓÚÑ][A-Za-zÁÉÍÓÚÑáéíóúñ ]{4,50})',
      r'se\s+identific[oó]\s+c[oó]mo\s+conductor[^,]*,\s*([A-ZÁÉÍÓÚÑ][A-Za-zÁÉÍÓÚÑáéíóúñ ]{4,50})',
      r'qui[eé]n\s+manifest[oó]\s+ser\s+el\s+conductor[^,]*,\s*([A-ZÁÉÍÓÚÑ][A-Za-zÁÉÍÓÚÑáéíóúñ ]{4,50})',
      r'conductor[,:]?\s+([A-ZÁÉÍÓÚÑ][A-Za-zÁÉÍÓÚÑáéíóúñ ]{4,50}),?\s*(?:con\s+)?C\.?C',
      r'estaba\s+manejando[^,]*,?\s*([A-ZÁÉÍÓÚÑ][A-Za-zÁÉÍÓÚÑáéíóúñ ]{4,50})',
    ];

    for (final patron in patrones) {
      final m = RegExp(patron, caseSensitive: false).firstMatch(c);
      final nombre = m?.group(1)?.trim();
      if (nombre != null && nombre.isNotEmpty) {
        final idx = c.toUpperCase().indexOf(nombre.toUpperCase());
        final ventana = idx == -1 ? c : c.substring(idx, (idx + nombre.length + 80).clamp(0, c.length));
        final cedula = _buscar(ventana, RegExp(r'C\.?C\.?:?\s*(\d{9,10})'));
        return (nombre: nombre.toUpperCase(), cedula: cedula);
      }
    }
    return null;
  }

  /// Reparte cada aprehendido a la placa más cercana en el texto (en
  /// caracteres de distancia) — solo hace falta cuando hay más de un
  /// vehículo y más de un aprehendido; con uno de cada, se asignan
  /// directo.
  Map<String, ({String nombre, String cedula})> _asignarAprehendidosAPlacas(
    String texto,
    List<({String nombre, String cedula})> aprehendidos,
    List<String> placas,
  ) {
    if (aprehendidos.isEmpty || placas.isEmpty) return {};
    if (aprehendidos.length == 1 && placas.length == 1) {
      return {placas.first: aprehendidos.first};
    }

    final mayus = texto.toUpperCase();
    final resultado = <String, ({String nombre, String cedula})>{};
    final placasUsadas = <String>{};

    for (final ap in aprehendidos) {
      final idxNombre = mayus.indexOf(ap.nombre);
      if (idxNombre == -1) continue;
      String? mejorPlaca;
      var mejorDistancia = 1 << 30;
      for (final placa in placas) {
        if (placasUsadas.contains(placa)) continue;
        final idxPlaca = mayus.indexOf(placa);
        if (idxPlaca == -1) continue;
        final distancia = (idxPlaca - idxNombre).abs();
        if (distancia < mejorDistancia) {
          mejorDistancia = distancia;
          mejorPlaca = placa;
        }
      }
      if (mejorPlaca != null) {
        resultado[mejorPlaca] = ap;
        placasUsadas.add(mejorPlaca);
      }
    }
    return resultado;
  }

  // ---------- Objetos registrados como indicios (datos técnicos) ----------

  /// Datos técnicos (chasis/país/año) sacados del bloque "Objetos
  /// registrados como indicios", UNO por cada vehículo listado ahí.
  ///
  /// IMPORTANTE (confirmado con partes reales en la ronda 13, viendo
  /// el texto real de Syncfusion vía "Ver texto reconocido"): en esta
  /// sección Syncfusion también revuelve etiquetas y valores — la
  /// placa real aparece ANTES de la palabra "Placa:", y lo que queda
  /// pegado justo después de "Placa:" es en realidad el valor de
  /// "Marca" (ej. texto real: "...GSO9232 Placa: KIA Objeto en
  /// calidad Objeto: Marca: Modelo:..."). Por eso NO se intenta leer
  /// la placa de este bloque (antes se leía mal y contaminaba el
  /// cruce de datos con una placa falsa como "CHEVROLET"). En cambio,
  /// esa Marca pegada a "Placa:" SÍ se guarda como 'marcaHint' — sirve
  /// para saber a qué vehículo pertenece cada entrada de este bloque
  /// comparándola contra la Marca ya extraída de la narrativa, en vez
  /// de asumir que el orden de este bloque es el mismo que el de la
  /// narrativa (NO lo es siempre: confirmado en ronda 14 con un parte
  /// real donde el 2º vehículo de la narrativa aparecía PRIMERO en
  /// este bloque, y por eso el chasis les salía cruzado entre los 2
  /// vehículos).
  /// Datos técnicos (placa, chasis, motor, color, país, año) sacados del bloque
  /// "Objetos registrados como indicios", uno por cada vehículo listado ahí.
  List<Map<String, String>> _extraerIndicios(String texto) {
    final resultado = <Map<String, String>>[];
    final inicio = RegExp(r'Objetos registrados como indicios', caseSensitive: false).firstMatch(texto);
    if (inicio == null) return resultado;

    var bloque = texto.substring(inicio.end);
    final fin = RegExp(
      r'Garantias b[áa]sicas|Personal polic[íi]al que particip|El agente aprehensor|Presuntos victimarios',
      caseSensitive: false,
    ).firstMatch(bloque);
    if (fin != null) bloque = bloque.substring(0, fin.start);

    final separador = RegExp(
      r'(\b[A-Z0-9-]{5,10}\s*Placas?:|\|\s*Objeto en calidad\s*\||\bObjeto en calidad\s+RETENIDO)',
      caseSensitive: false,
    );
    final cortes = separador.allMatches(bloque).toList();
    if (cortes.isEmpty) return resultado;

    for (var i = 0; i < cortes.length; i++) {
      try {
        final start = cortes[i].start;
        final end = i + 1 < cortes.length ? cortes[i + 1].start : bloque.length;
        final chunk = bloque.substring(start, end);

        // 1. Placa
        var placaCruda = RegExp(r'([A-Z0-9-]{5,10})\s*Placas?:', caseSensitive: false).firstMatch(chunk)?.group(1) ??
            RegExp(r'Placas?:?\s*\|?\s*([A-Z0-9-]{5,10})', caseSensitive: false).firstMatch(chunk)?.group(1) ??
            '';
        final placa = _normalizarPlaca(placaCruda);

        // 2. Chasis directo o etiquetado
        var chasis = RegExp(r'Chasis:?\s*\|?\s*([A-HJ-NPR-Z0-9]{10,20})', caseSensitive: false)
            .firstMatch(chunk)?.group(1);
        if (chasis != null && chasis.toUpperCase().contains('RETENIDO')) chasis = null;

        // 3. Motor directo o etiquetado
        var motor = RegExp(r'Motor:?\s*\|?\s*([A-Za-z0-9]{5,20})', caseSensitive: false)
            .firstMatch(chunk)?.group(1);

        // 4. Si faltan motor o chasis (caso tabla desalineada de Syncfusion)
        if (chasis == null || motor == null) {
          final idxPais = chunk.toUpperCase().indexOf('PAÍS') != -1
              ? chunk.toUpperCase().indexOf('PAÍS')
              : chunk.toUpperCase().indexOf('PAIS');
          final zonaSeriales = idxPais != -1 ? chunk.substring(0, idxPais) : chunk;

          final lineas = zonaSeriales
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty && !l.startsWith('`') && !l.startsWith('|'))
              .toList();

          final tokensSeriales = <String>[];
          for (final l in lineas.reversed) {
            final limpio = l.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
            final u = limpio.toUpperCase();
            if (u.isEmpty ||
                u.contains('COLOR') ||
                u.contains('BLANCO') ||
                u.contains('NEGRO') ||
                u.contains('AZUL') ||
                u.contains('ROJO') ||
                u.contains('PLATA') ||
                u.contains('PLOMO') ||
                u.contains('VERDE') ||
                u.contains('NARANJA') ||
                u.contains('RETENIDO') ||
                u.contains('CHASIS') ||
                u.contains('MOTOR') ||
                u.contains('MODELO') ||
                u.contains('OBJETO') ||
                u.contains('MARCA') ||
                u.contains('CAMION') ||
                u.contains('AUTOMOVIL') ||
                u.contains('JEEP') ||
                u.contains('BUS') ||
                u == placa) {
              continue;
            }
            if (limpio.length >= 5 && limpio.length <= 19 && RegExp(r'\d').hasMatch(limpio)) {
              tokensSeriales.add(limpio);
              if (tokensSeriales.length >= 2) break;
            }
          }

          if (tokensSeriales.isNotEmpty) {
            if (tokensSeriales.length >= 2) {
              final t1 = tokensSeriales[0];
              final t2 = tokensSeriales[1];
              if (t1.length >= 17) {
                chasis ??= t1;
                motor ??= t2;
              } else if (t2.length >= 17) {
                chasis ??= t2;
                motor ??= t1;
              } else {
                chasis ??= t1;
                motor ??= t2;
              }
            } else if (tokensSeriales.length == 1) {
              if (tokensSeriales[0].length >= 17) {
                chasis ??= tokensSeriales[0];
              } else {
                motor ??= tokensSeriales[0];
              }
            }
          }
        }

        // 5. Color
        var color = RegExp(r'Color(?:\s*principal)?:?\s*\|?\s*([A-Za-zÁÉÍÓÚñÑ]+)', caseSensitive: false)
            .firstMatch(chunk)?.group(1);
        if (color == null ||
            color.toUpperCase() == 'PRINCIPAL' ||
            color.toUpperCase() == 'SECUNDARIO' ||
            color.toUpperCase() == 'COLOR') {
          color = RegExp(
            r'\b(BLANCO|NEGRO|ROJO|AZUL|PLATA|PLATEADO|GRIS|AMARILLO|VERDE|CAFE|MARR[OÓ]N|NARANJA|VINO|BEIGE|PLOMO)\b',
            caseSensitive: false,
          ).firstMatch(chunk)?.group(1);
        }

        // 6. País
        final pais = _buscar(
          chunk,
          RegExp(
            r'\b(ECUADOR|JAPON|JAPÓN|COLOMBIA|PERU|PERÚ|CHINA(?:\s*\(REPUBLICA\s*POPULAR\s*DE\))?|COREA(?:\s*DEL\s*SUR)?|ESTADOS UNIDOS|ALEMANIA|BRASIL|MEXICO|MÉXICO|INDIA)\b',
            caseSensitive: false,
          ),
        );

        // 7. Año
        var anio = RegExp(r'A[ñn]o:?\s*\|?\s*(\d{4})', caseSensitive: false).firstMatch(chunk)?.group(1);
        if (anio == null) {
          final anios = RegExp(r'\b(19[7-9]\d|20[0-2]\d)\b').allMatches(chunk).map((m) => m.group(1)!).toList();
          if (anios.isNotEmpty) anio = anios.last;
        }

        // 8. Marca hint
        var marcaHint = _buscar(chunk, RegExp(r'(?:[A-Z0-9-]{5,10}\s*Placas?:|Placas?:[^\n]*)\s*\n\s*([A-Za-zÁÉÍÓÚñÑ]{3,20})'));
        if (marcaHint == null) {
          marcaHint = _buscar(chunk, RegExp(r'Marca:?\s*\|?\s*([A-Za-zÁÉÍÓÚñÑ]{3,20})', caseSensitive: false));
        }

        // 9. Modelo
        var modelo = _buscar(chunk, RegExp(r'Modelo:?\s*\|?\s*([A-Za-z0-9ÁÉÍÓÚñÑ .\-]+?)(?:\s*\||Color|\n|$)', caseSensitive: false));
        if (modelo != null) {
          modelo = modelo
              .replaceAll(RegExp(r'^(?:Objeto:|Marca:|Modelo:|Color\s*principal:|Motor:|Chasis:|RETENIDO|\s)+', caseSensitive: false), '')
              .replaceAll(RegExp(r'[`|]'), '')
              .trim();
        }

        if (placa.isEmpty && chasis == null && motor == null && anio == null) continue;

        resultado.add({
          if (placa.isNotEmpty) 'placa': placa,
          if (chasis != null) 'chasis': chasis,
          if (motor != null) 'motor': motor,
          if (color != null) 'color': color,
          if (pais != null) 'pais': pais,
          if (anio != null) 'anio': anio,
          if (marcaHint != null) 'marcaHint': marcaHint,
          if (modelo != null && modelo.isNotEmpty) 'modelo': modelo,
        });
      } catch (_) {
        continue;
      }
    }
    return resultado;
  }

  // ---------- Bloques de participantes/vehículos (narrativa) ----------

  /// Extrae los campos comunes (tipo/marca/color/conductor+cédula/
  /// propietario+cédula) de un bloque de texto que ya sabemos que
  /// corresponde a UN vehículo. Tolera etiquetas con o sin dos puntos,
  /// "Placa"/"Placas", "Color"/"Color principal", etc.
  Map<String, String> _camposDeBloque(String bloque) {
    final tipo = _buscar(
      bloque,
      RegExp(r'Tipo:?\s*([A-Za-zÁÉÍÓÚáéíóúñÑ ]+?)(?:\n|;|,|Marca)', caseSensitive: false),
    );
    final marca = _buscar(
      bloque,
      RegExp(r'Marca:?\s*([A-Za-zÁÉÍÓÚáéíóúñÑ ]+?)(?:\n|;|,|Modelo|Placas?|Color)', caseSensitive: false),
    );
    // Modelo directo del bloque narrativo
    final modelo = _buscar(
      bloque,
      RegExp(r'Modelo:?\s*([A-Za-z0-9ÁÉÍÓÚáéíóúñÑ .\-]+?)(?:\n|;|,|Color|Placas?)', caseSensitive: false),
    );
    final color = _buscar(
      bloque,
      RegExp(r'Color(?:\s*principal)?:?\s*([A-Za-zÁÉÍÓÚáéíóúñÑ ]+?)(?:\n|;|,|de\s+Placas?|Placas?|Propietari|Conductor)', caseSensitive: false),
    );

    final combinado = _buscar(
        bloque, RegExp(r'Conductor\s*/?\s*y\s*Propietari[oa]\s*([A-Za-zÁÉÍÓÚáéíóúñÑ .]+?)(?:\n|C\.?C)'));

    String conductor = combinado ??
        _buscar(bloque, RegExp(r'Conductor:?\s*([A-Za-zÁÉÍÓÚáéíóúñÑ .]+?)(?:\s*\(|\n|C\.?C|Propietari)')) ??
        _buscar(bloque, RegExp(r'Nombres:?\s*([A-Za-zÁÉÍÓÚáéíóúñÑ .]+?)(?:\n|C\.C)')) ??
        '';
    String propietario = combinado ??
        _buscar(bloque, RegExp(r'Propietari[oa]:?\s*([A-Za-zÁÉÍÓÚáéíóúñÑ .]+?)(?:\.|\n|C\.?C|Vehículo|VEHICULO)')) ??
        '';

    final conductorCedula = _buscar(bloque, RegExp(r'C\.?C\.?:?\s*(\d{9,10})'));
    final todasLasCedulas = RegExp(r'C\.?C\.?:?\s*(\d{9,10})').allMatches(bloque).map((m) => m.group(1)!).toList();
    final propietarioCedula =
        propietario.isNotEmpty && propietario != conductor && todasLasCedulas.length > 1 ? todasLasCedulas[1] : '';

    String limpiarCampo(String? s) {
      if (s == null) return '';
      return s
          .replaceAll(RegExp(r'\s+de$', caseSensitive: false), '')
          .replaceAll(RegExp(r'[,;.-]+$'), '')
          .trim();
    }

    return {
      'tipo': limpiarCampo(tipo),
      'marca': limpiarCampo(marca),
      'modelo': limpiarCampo(modelo),
      'color': limpiarCampo(color),
      'conductor': limpiarCampo(conductor),
      'conductorCedula': conductorCedula ?? '',
      'propietario': limpiarCampo(propietario),
      'propietarioCedula': propietarioCedula,
    };
  }

  List<ParticipanteVehiculo> _extraerPorBloquesParticipante(String texto) {
    final resultado = <ParticipanteVehiculo>[];
    final bloques = texto.split(RegExp(r'Participante[^\d\n]{0,15}\d+'));

    for (final bloque in bloques.skip(1)) {
      try {
        final placaCruda = _buscar(bloque, RegExp(r'Placas?:?\s*([A-Z0-9\- ]{5,10})', caseSensitive: false));
        if (placaCruda == null) continue;
        final placa = _normalizarPlaca(placaCruda);
        if (placa.length < 5) continue;

        final campos = _camposDeBloque(bloque);
        resultado.add(ParticipanteVehiculo(
          placa: placa,
          tipo: campos['tipo']!,
          marca: campos['marca']!,
          modelo: campos['modelo']!,
          color: campos['color']!,
          conductor: campos['conductor']!,
          conductorCedula: campos['conductorCedula']!,
          propietario: campos['propietario']!,
          propietarioCedula: campos['propietarioCedula']!,
        ));
      } catch (_) {
        // Este bloque en particular no se pudo leer bien (estructura
        // inesperada) — se salta y se sigue con el resto del parte,
        // en vez de perder todos los vehículos ya encontrados.
        continue;
      }
    }
    return resultado;
  }

  List<ParticipanteVehiculo> _extraerPorBloquesVehiculo(String texto) {
    final resultado = <ParticipanteVehiculo>[];
    // Tolera "Vehículo N.° 1" / "VEHICULO No. 1" además de "VEHICULO 1"
    // — antes solo el segundo formato separaba bien en bloques; el
    // primero caía al método de ventana (_extraerFlexible), que puede
    // mezclar datos entre vehículos cercanos (confirmado en ronda 14:
    // 2 vehículos de un parte real salieron con la MISMA marca/color
    // por esto).
    final bloques = texto.split(RegExp(r'\bVEH[IÍ]CULOS?\s*(?:N[°º.]*\s*)?\d+\b', caseSensitive: false));

    for (final bloque in bloques.skip(1)) {
      try {
        final placaCruda = _buscar(bloque, RegExp(r'Placas?:?\s*([A-Z0-9\- ]{5,10})', caseSensitive: false));
        if (placaCruda == null) continue;
        final placa = _normalizarPlaca(placaCruda);
        if (placa.length < 5) continue;

        final campos = _camposDeBloque(bloque);
        resultado.add(ParticipanteVehiculo(
          placa: placa,
          tipo: campos['tipo']!,
          marca: campos['marca']!,
          modelo: campos['modelo']!,
          color: campos['color']!,
          conductor: campos['conductor']!,
          conductorCedula: campos['conductorCedula']!,
          propietario: campos['propietario']!,
          propietarioCedula: campos['propietarioCedula']!,
        ));
      } catch (_) {
        continue;
      }
    }
    return resultado;
  }

  List<ParticipanteVehiculo> _extraerFlexible(String texto) {
    final resultado = <ParticipanteVehiculo>[];
    final regexPlaca = RegExp(r'Placas?:?\s*([A-Z0-9\- ]{5,10})', caseSensitive: false);
    final placasVistas = <String>{};
    final coincidencias = regexPlaca.allMatches(texto).toList();

    for (var i = 0; i < coincidencias.length; i++) {
      final m = coincidencias[i];
      try {
        final placa = _normalizarPlaca(m.group(1)!);
        if (placa.length < 5 || !placasVistas.add(placa)) continue;

        // La ventana de ±300 caracteres NUNCA cruza hacia la "Placa:"
        // anterior o siguiente. Sin este límite, cuando 2 vehículos
        // están descritos a menos de 300 caracteres uno del otro (caso
        // común: "Tipo/Marca/Color/Placa" corto por vehículo), la
        // ventana de uno se metía en el texto del otro y los dos
        // terminaban con la misma marca/color (confirmado en ronda 14
        // con un parte real de 2 vehículos).
        final limiteAnterior = i > 0 ? coincidencias[i - 1].end : 0;
        final limiteSiguiente = i < coincidencias.length - 1 ? coincidencias[i + 1].start : texto.length;
        final inicioVentana = (m.start - 300 < limiteAnterior ? limiteAnterior : m.start - 300).clamp(0, texto.length);
        final finVentana = (m.end + 300 > limiteSiguiente ? limiteSiguiente : m.end + 300).clamp(0, texto.length);
        final ventana = texto.substring(inicioVentana, finVentana);
        final campos = _camposDeBloque(ventana);

        resultado.add(ParticipanteVehiculo(
          placa: placa,
          tipo: campos['tipo']!,
          marca: campos['marca']!,
          modelo: campos['modelo']!,
          color: campos['color']!,
          conductor: campos['conductor']!,
          conductorCedula: campos['conductorCedula']!,
          propietario: campos['propietario']!,
          propietarioCedula: campos['propietarioCedula']!,
        ));
      } catch (_) {
        continue;
      }
    }
    return resultado;
  }

  // ---------- Punto de entrada ----------

  /// Detecta cada vehículo del parte y arma un ParticipanteVehiculo por
  /// cada uno, combinando las tres fuentes: bloques narrativos
  /// (Participante N / VEHÍCULO N / respaldo flexible) para
  /// tipo/color/marca, "Objetos registrados como indicios" para
  /// chasis/país/año, y aprehendidos/detenidos (o circunstancias) para
  /// el conductor real.
  List<ParticipanteVehiculo> extraerParticipantes(String texto) {
    final limpio = _limpiar(texto);

    var lista = _intentar(() => _extraerPorBloquesParticipante(limpio)) ?? [];
    if (lista.isEmpty) lista = _intentar(() => _extraerPorBloquesVehiculo(limpio)) ?? [];
    if (lista.isEmpty) lista = _intentar(() => _extraerFlexible(limpio)) ?? [];

    final indicios = _intentar(() => _extraerIndicios(limpio)) ?? [];

    // Si la narrativa no trajo bloques pero indicios sí, inicializar participantes desde indicios
    if (lista.isEmpty && indicios.isNotEmpty) {
      lista = indicios
          .where((ind) => ind['placa'] != null && ind['placa']!.isNotEmpty)
          .map((ind) => ParticipanteVehiculo(
                placa: ind['placa']!,
                marca: ind['marcaHint'] ?? '',
                modelo: ind['modelo'] ?? '',
                color: ind['color'] ?? '',
                chasis: ind['chasis'] ?? '',
                motor: ind['motor'] ?? '',
                pais: ind['pais'] ?? '',
                anio: ind['anio'] ?? '',
              ))
          .toList();
    }
    if (lista.isEmpty) return lista;

    // Emparejar cada vehículo con SU indicio por PLACA (evita cruces)
    final indiciosPorPlaca = <String, Map<String, String>>{};
    for (final ind in indicios) {
      if (ind['placa'] != null && ind['placa']!.isNotEmpty) {
        indiciosPorPlaca[ind['placa']!] = ind;
      }
    }

    final usados = <int>{};
    lista = lista.asMap().entries.map((entry) {
      final i = entry.key;
      final p = entry.value;

      // 1. Por coincidencia exacta de placa
      Map<String, String>? ind = indiciosPorPlaca[p.placa];
      if (ind != null) {
        final idx = indicios.indexOf(ind);
        if (idx != -1) usados.add(idx);
      }

      // 2. Por marca si no hubo coincidencia de placa
      if (ind == null && p.marca.isNotEmpty) {
        final idx = indicios.indexWhere((indItem) =>
            !usados.contains(indicios.indexOf(indItem)) &&
            indItem['marcaHint'] != null &&
            indItem['marcaHint']!.toUpperCase() == p.marca.toUpperCase());
        if (idx != -1) {
          usados.add(idx);
          ind = indicios[idx];
        }
      }

      // 3. Respaldo posicional
      if (ind == null && i < indicios.length && !usados.contains(i)) {
        usados.add(i);
        ind = indicios[i];
      }

      if (ind == null) return p;

      return p.copyWith(
        modelo: p.modelo.isNotEmpty ? null : ind['modelo'],
        color: p.color.isNotEmpty ? null : ind['color'],
        chasis: ind['chasis'],
        motor: ind['motor'],
        pais: ind['pais'],
        anio: ind['anio'],
      );
    }).toList();

    // Conductor real: primero "Información de los aprehendidos", y
    // si no hay ese bloque, se busca en "Circunstancias del hecho".
    final aprehendidos = _aprehendidos(limpio);
    final placas = lista.map((p) => p.placa).toList();

    if (aprehendidos.isNotEmpty) {
      final asignados = _asignarAprehendidosAPlacas(limpio, aprehendidos, placas);
      lista = lista.map((p) {
        final ap = asignados[p.placa];
        if (ap == null) return p;
        return p.copyWith(conductor: ap.nombre, conductorCedula: ap.cedula);
      }).toList();
    } else if (lista.length == 1 && lista.first.conductor.isEmpty) {
      final circunstancias = extraerMetadatos(limpio).circunstancias;
      final encontrado = _conductorEnCircunstancias(circunstancias);
      if (encontrado != null) {
        lista[0] = lista[0].copyWith(
          conductor: encontrado.nombre,
          conductorCedula: encontrado.cedula ?? lista[0].conductorCedula,
        );
      }
    }

    // Propietario tentativo: si el bloque narrativo no distinguió un
    // propietario aparte, se usa el mismo dato del conductor como
    // punto de partida editable (muchas veces coincide, pero puede
    // cambiar y el casillero queda abierto para corregirlo).
    lista = lista
        .map((p) => p.propietario.isNotEmpty
            ? p
            : p.copyWith(propietario: p.conductor, propietarioCedula: p.conductorCedula))
        .toList();

    return lista;
  }
}
