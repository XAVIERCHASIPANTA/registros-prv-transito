// RUTA DE ARCHIVO: lib/services/docx_builder.dart

import 'dart:convert';
import 'package:archive/archive.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';

/// Construye un archivo .docx válido (formato OOXML mínimo) a partir de
/// una lista de "bloques" de texto, cada uno representando un caso.
class DocxBuilder {
  static List<int> build({
    required String titulo,
    required List<List<String>> bloques,
  }) {
    final archive = Archive();

    archive.addFile(_textFile('[Content_Types].xml', _contentTypesXml));
    archive.addFile(_textFile('_rels/.rels', _relsXml));
    archive.addFile(_textFile('word/_rels/document.xml.rels', _documentRelsXml));
    archive.addFile(_textFile('word/document.xml', _documentXml(titulo, bloques)));
    archive.addFile(_textFile('word/styles.xml', _stylesXml));

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo .docx (ZipEncoder devolvió null)');
    }
    return bytes;
  }

  /// Construye el documento Word específico para un Registro de Ingreso
  static List<int> buildIngreso(CasoIngreso c) {
    final lineas = [
      'SUBZONA: ${c.subzona} | CRV: ${c.crv}',
      'HOJA DE INGRESO N°: ${c.hojaIngresoNro}',
      'PARTE POLICIAL N°: ${c.parteIngresoNro}',
      'FECHA DE INGRESO: ${c.fechaIngreso} - HORA: ${c.horaRetencion}',
      'TIPO OPERATIVO: ${c.tipoOperativo}'
          '${c.tipoOperativo == 'OPERATIVO N°' && c.numeroOperativo.isNotEmpty ? ' ${c.numeroOperativo}' : ''}',
      'PLACA: ${c.placa.toUpperCase()} | TIPO: ${c.tipoVehiculo}',
      'MARCA: ${c.marca} | MODELO: ${c.modelo} | AÑO: ${c.anioFabricacion} | COLOR: ${c.color}',
      if (c.tipoVehiculo == 'MOTOCICLETA')
        'CILINDRAJE: ${c.cilindraje}'
      else
        'CHASIS/VIN: ${c.chasis} | MOTOR: ${c.motor}',
      if (c.tipoVehiculo != 'MOTOCICLETA' && c.tonelaje.isNotEmpty) 'TONELAJE: ${c.tonelaje} TN',
      'TIPO COBRO PARQUEO: ${c.tipoCobroParqueo}',
      'CAUSA LEGAL: ${c.causaLegal}${c.detalleCausa.isNotEmpty ? ' - ${c.detalleCausa}' : ''}',
      'AUTORIDAD QUE CONOCE: ${c.autoridadRequirente}',
      'PRUEBA DE ALCOHOLEMIA: ${c.aplicaAlcohotest ? 'N° Prueba ${c.numeroPruebaAlcoholemia} - Resultado ${c.resultadoAlcoholemia} g/L - Sancionado: ${c.nombreSancionado} (C.I.: ${c.cedulaSancionado})${c.citacionNro.isNotEmpty ? ' - Citación N° ${c.citacionNro}' : ''}' : 'NO APLICA'}',
      'PROPIETARIO: ${c.propietario} (C.I.: ${c.cedulaPropietario})',
      'CONDUCTOR: ${c.conductor} (C.I.: ${c.cedulaConductor})',
      'TRASLADO: ${c.traslado}',
      if (c.traslado == 'PARTICULAR')
        'GRÚA PARTICULAR: ${c.nombreGruaParticular} - Tel: ${c.telefonoGruaParticular} - Valor: \$${c.valorGrua}',
      if (c.traslado == 'GRÚA POLICIAL' && c.kmGrua.isNotEmpty) 'KM. GRÚA POLICIAL: ${c.kmGrua}',
      if (c.traslado == 'GRÚA POLICIAL' && c.conductorGrua.isNotEmpty)
        'CONDUCTOR DE LA GRÚA: ${c.conductorGrua}',
      'RECIBE LA CUSTODIA: ${c.custodioRecibeNombre}',
      'PARTE ELABORADO POR: ${c.policiaNombre} (C.I.: ${c.policiaCedula})',
      'ESTADO FÍSICO: ${c.estadoVehiculo}',
      'OBSERVACIONES: ${c.observaciones}',
    ];

    return build(
      titulo: 'REGISTRO OFICIAL DE INGRESO A PATIO DE RETENCIÓN',
      bloques: [lineas],
    );
  }

  static List<int> buildMasterIngresos(List<CasoIngreso> ingresos) {
    final bloques = <List<String>>[];
    for (final c in ingresos) {
      final textoBase = generarTextoNarrativoIngreso(c);
      final lineasTexto = textoBase.split('\n');
      bloques.add([
        'HOJA N° ${c.hojaIngresoNro}',
        ...lineasTexto,
      ]);
    }
    return build(
      titulo: 'MATRIZ MÁSTER DE HOJAS DE INGRESO',
      bloques: bloques,
    );
  }


  /// Saludo interno según a quién se eleva el parte (coincide con el
  /// campo "Parte elevado al Sr/a" de los partes reales: MAYR / TCNL.).
  static String _saludo(String grado) {
    final g = grado.trim().toLowerCase();
    if (g.contains('no aplica')) return '';
    if (g.contains('coronel') || g.contains('tcrnl') || g.contains('tnte')) {
      return 'Tcrnl.';
    }
    if (g.isEmpty) return 'Mayor';
    return grado;
  }

  /// Texto narrativo oficial de la Libertad (el párrafo que va al Parte
  /// Web / Acta de Salida). Público para que las pantallas puedan mostrarlo
  /// y copiarlo al portapapeles sin tener que generar el .docx completo.
  static String generarTextoNarrativoLibertad(CasoLibertad l) {
    return 'Por medio del presente me permito poner en su conocimiento, que encontrándome como custodio del CRV ${l.crv}, se dio cumplimiento al Memorando Nro. ${l.memorandoNro}. '
        'De fecha ${l.memorandoFecha}, el mismo que tiene referencia al Oficio de DEVOLUCION DE VEHICULO Nro. ${l.oficioDevolucionNro} '
        'de fecha ${l.oficioDevolucionFecha} firmado por el ${l.firmadoPor}, por lo que se procede a dar la libertad del Vehículo, '
        'Marca ${l.marca}, de placas ${l.placa.toUpperCase()}, siendo retirando por su ${l.calidadRetira} el señor ${l.retiradoPor}, '
        'con C.C. ${l.cedulaRetira}, así mismo se detalla las novedades de ingreso del vehículo y datos de pagos por concepto de garaje.';
  }

  /// Texto narrativo del Ingreso (el párrafo que va al Parte Web).
  /// Público para que las pantallas puedan mostrarlo y copiarlo al
  /// portapapeles sin tener que generar el .docx completo.
  static String generarTextoNarrativoIngreso(CasoIngreso c) {
    String causa = c.causaLegal.trim();
    if (causa.toLowerCase().contains('accidente de tránsito') || causa.toLowerCase().contains('accidente de transito')) {
      causa = 'Accidente de Tránsito';
    } else if (causa.contains('/')) {
      causa = causa.split('/')[0].trim();
    }
    
    String concepto = causa.isNotEmpty ? causa : 'retención vehicular';
    if (c.detalleCausa.trim().isNotEmpty && causa != 'Accidente de Tránsito') {
      concepto += ' (' + c.detalleCausa.trim() + ')';
    }

    return 'Por medio del presente me permito poner en su conocimiento, '
        'que encontrándome de servicio como custodio del CRV "${c.crv}" '
        'en el lugar y hora antes indicada se procedió al ingreso del vehículo '
        'Tipo ${c.tipoVehiculo} Marca ${c.marca}, Modelo ${c.modelo}, Año ${c.anioFabricacion}, '
        'color ${c.color} de placas ${c.placa.toUpperCase()}, Chasis ${c.chasis}, Motor ${c.motor}, '
        'de propiedad del señor ${c.propietario} por concepto de: $concepto, '
        'con hoja de ingreso N° ${c.hojaIngresoNro} y parte N° ${c.parteIngresoNro}; '
        'quien es trasladado hasta los patios por ${c.traslado.toLowerCase()}; toma procedimiento el señor ${c.policiaNombre}\n'
        'Sin mayor novedad\n'
        'Particular que me permito poner en su conocimiento, para los fines pertinentes.';
  }

  /// Construye el documento Word específico para una Orden de Libertad /
  /// Devolución, calcando EXACTAMENTE el texto real de LIBERTADES_2026.rtf.
  static List<int> buildLibertad(CasoLibertad l) {
    final saludo = _saludo(l.gradoDestinatario);
    final parrafoPrincipal = generarTextoNarrativoLibertad(l);
    final finalSaludo = saludo.isNotEmpty ? ' Mi $saludo' : '';

    final lineas = <String>[
      parrafoPrincipal,
      '',
      'Hoja de Ingreso Nro.: ${l.hojaIngresoNro}',
      'Parte de ingreso Nro: ${l.parteIngresoNro}',
      'Fecha de ingreso: ${l.fechaIngreso}',
      '',
      'Causa: ${l.causa}',
      '',
      'Días de permanencia en el CRV: ${l.diasPermanencia}',
      '',
      ...l.pagosParaWord(),
      'Particular que me permito poner en su conocimiento para los fines pertinentes.',
    ];

    return build(
      titulo: 'ACTA DE LIBERTAD Y DEVOLUCIÓN DE VEHÍCULO',
      bloques: [lineas],
    );
  }

  static List<int> buildMasterLibertades(List<CasoLibertad> libertades) {
    final bloques = <List<String>>[];
    for (final l in libertades) {
      final parrafoPrincipal = generarTextoNarrativoLibertad(l);
      final lineasTexto = parrafoPrincipal.split('\n');
      bloques.add([
        'HOJA N° ${l.hojaIngresoNro}',
        ...lineasTexto,
        '',
        'Hoja de Ingreso Nro.: ${l.hojaIngresoNro}',
        'Parte de ingreso Nro: ${l.parteIngresoNro}',
        'Fecha de ingreso: ${l.fechaIngreso}',
        '',
        'Causa: ${l.causa}',
        '',
        'Días de permanencia en el CRV: ${l.diasPermanencia}',
        'Vehículo tipo: ${l.tipoVehiculo}',
        '',
        ...l.pagosParaWord(),
        'Particular que me permito poner en su conocimiento, para los fines pertinentes.',
      ]);
    }
    return build(
      titulo: 'MATRIZ MÁSTER DE HOJAS DE LIBERTAD',
      bloques: bloques,
    );
  }


  /// Datos para generar el Informe Semanal de salida de vehículos/motos.
  /// Todo es editable en la pantalla — este objeto solo transporta lo que
  /// el oficial ya confirmó antes de generar el Word.
  static List<int> buildInformeSemanal({
    required String jefaturaNombre, // Ej: "SANTO DOMINGO"
    required String patio, // Ej: "CONTROL 120"
    required String subzona, // Ej: "Santo Domingo de los Tsáchilas"
    required String subzonaAbrev, // Ej: "SDT"
    required String oficioNro,
    required String fechaOficio, // Ej: "06 de julio de 2026"
    required String asuntoOficioNro,
    required String asuntoOficioFecha, // Ej: "04 de junio del 2026"
    required String destinatarioNombre,
    required String destinatarioRango, // Ej: "Coronel de E.M"
    required String fechaLunes, // Ej: "29 de junio del 2026"
    required String fechaDomingo, // Ej: "05 de julio del 2026"
    required int vehiculos,
    required int motocicletas,
    String observacionAdicional = '',
    required String firmanteNombre,
    required String firmanteRango,
  }) {
    final saludoRango = _saludoInforme(destinatarioRango);

    final parrafoCumplimiento = 'Con el honor de dirigirme a usted, me permito expresar un '
        'atento y cordial saludo, a la vez desearle éxitos en el desarrollo de sus '
        'funciones, muy respetuosamente en cumplimiento al Oficio Nro. $asuntoOficioNro, '
        'de fecha $asuntoOficioFecha, emitido por la señora JEFA DE SECCION DE CENTROS DE '
        'RETENCION VEHICULAR DE LA DIRECCION NACIONAL DE CONTROL DE TRANSITO Y SEGURIDAD '
        'VIAL en el que se dispone remitir los formularios generados por el sistema una vez '
        'ejecutada la salida de los vehículos, los mismos que deberán ser consolidados por '
        'cada Centro de Retención Vehicular en un solo documento, indicando expresamente el '
        'CRV al que pertenecen. Por los antes expuesto me permito remitir la información '
        'solicitada desde las 00H00 del día lunes $fechaLunes hasta las 00H00 del domingo '
        '$fechaDomingo, con relación a la salida de vehículos o motocicletas en el Centro de '
        'Retención Vehicular de la Jefatura de Tránsito de la Subzona $subzona.';

    final lineas = <String>[
      'POLICÍA NACIONAL DEL ECUADOR',
      'DIRECCIÓN NACIONAL DE CONTROL DE TRÁNSITO Y SEGURIDAD VIAL "JEFATURA DE CONTROL DE '
          'TRÁNSITO $jefaturaNombre" CENTRO DE RETENCION VEHICULAR $patio"',
      '',
      'Oficio, $oficioNro',
      'Fecha, $fechaOficio',
      '',
      'ASUNTO: EN CUMPLIMIENTO AL OFICIO Nro. $asuntoOficioNro',
      '',
      'Señor',
      '$destinatarioNombre $destinatarioRango',
      'DIRECTOR NACIONAL DE CONTROL DE TRÁNSITO Y SEGURIDAD VIAL POLICÍA NACIONAL',
      'En su Despacho. –',
      '',
      'Mi $saludoRango:',
      parrafoCumplimiento,
      'Debo indicar que existió la salida de $vehiculos vehículos y $motocicletas '
          'motocicletas durante esas fechas.',
      if (observacionAdicional.trim().isNotEmpty) observacionAdicional.trim(),
      'Adjunto los formularios descargados del SIIPNE 3W referente a la salida del vehículo.',
      '',
      'Atentamente,',
      '',
      'VALOR, DISCIPLINA Y LEALTAD',
      '',
      'Sr. $firmanteNombre',
      firmanteRango,
      'ENCARGADO DEL CENTRO DE RETENCIÓN VEHICULAR $patio PERTENECIENTE A LA JEFATURA DE '
          'TRÁNSITO SZ $subzonaAbrev.',
    ];

    return build(
      titulo: 'INFORME SEMANAL DE SALIDA DE VEHÍCULOS',
      bloques: [lineas],
    );
  }

  static String _saludoInforme(String rango) {
    final r = rango.trim().toLowerCase();
    if (r.contains('coronel')) return 'coronel';
    if (r.contains('mayor')) return 'mayor';
    if (r.contains('general')) return 'general';
    return rango.isEmpty ? 'coronel' : rango;
  }

  static ArchiveFile _textFile(String path, String content) {
    final data = utf8.encode(content);
    return ArchiveFile(path, data.length, data);
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _parrafo(String texto, {bool negrita = false, double? tamano}) {
    final esIndexado = texto.startsWith('HOJA N°');
    final pPr = esIndexado ? '<w:pPr><w:outlineLvl w:val="0"/></w:pPr>' : '';

    final rPr = StringBuffer();
    if (negrita || esIndexado) rPr.write('<w:b/>');
    if (tamano != null) {
      rPr.write('<w:sz w:val="${(tamano * 2).round()}"/>');
    } else if (esIndexado) {
      rPr.write('<w:sz w:val="26"/>');
    }
    final rPrXml = rPr.isEmpty ? '' : '<w:rPr>${rPr}</w:rPr>';
    return '<w:p>${pPr}<w:r>${rPrXml}<w:t xml:space="preserve">${_escape(texto)}</w:t></w:r></w:p>';
  }

  static String _documentXml(String titulo, List<List<String>> bloques) {
    final body = StringBuffer();
    body.write(_parrafo(titulo, negrita: true, tamano: 14));
    body.write(_parrafo(''));

    for (var i = 0; i < bloques.length; i++) {
      body.write('<w:p><w:pPr><w:pBdr><w:top w:val="single" w:sz="6" w:space="4" w:color="999999"/></w:pBdr></w:pPr></w:p>');
      for (final linea in bloques[i]) {
        body.write(_parrafo(linea));
      }
      body.write(_parrafo(''));
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $body
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>''';
  }

  static const _contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

  static const _relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  static const _documentRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

  static const _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
        <w:sz w:val="22"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
</w:styles>''';
}
