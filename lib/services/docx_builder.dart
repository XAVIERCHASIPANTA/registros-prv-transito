// RUTA DE ARCHIVO: lib/services/docx_builder.dart

import 'dart:convert';
import 'package:archive/archive.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';

/// Construye archivos .docx válidos (formato OOXML estándar) en UTF-8 nativo
/// garantizando compatibilidad total con MS Word, LibreOffice y visualizadores.
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
      'CAUSA LEGAL: ${c.situacionLegalFormateada}',
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

  static String generarTextoNarrativoLibertad(CasoLibertad l) {
    return 'Por medio del presente me permito poner en su conocimiento, que encontrándome como custodio del CRV ${l.crv}, se dio cumplimiento al Memorando Nro. ${l.memorandoNro}. '
        'De fecha ${l.memorandoFecha}, el mismo que tiene referencia al Oficio de DEVOLUCION DE VEHICULO Nro. ${l.oficioDevolucionNro} '
        'de fecha ${l.oficioDevolucionFecha} firmado por el ${l.firmadoPor}, por lo que se procede a dar la libertad del Vehículo, '
        'Marca ${l.marca}, de placas ${l.placa.toUpperCase()}, siendo retirando por su ${l.calidadRetira} el señor ${l.retiradoPor}, '
        'con C.C. ${l.cedulaRetira}, así mismo se detalla las novedades de ingreso del vehículo y datos de pagos por concepto de garaje.';
  }

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

  static List<int> buildLibertad(CasoLibertad l) {
    final parrafoPrincipal = generarTextoNarrativoLibertad(l);

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

  /// Construcción oficial e impecable del Informe Semanal en Microsoft Word (.docx).
  /// Genera un documento OOXML nativo en UTF-8 válido 100% según especificación OOXML.
  static List<int> buildInformeSemanal({
    List<int>? templateBytes,
    List<int>? escudoPoliciaBytes,
    List<int>? escudoMinisterioBytes,
    List<int>? logoDireccionBytes,
    required String jefaturaNombre,
    required String patio,
    required String subzona,
    required String subzonaAbrev,
    required String oficioNro,
    required String fechaOficio,
    required String asuntoOficioNro,
    required String asuntoOficioFecha,
    required String destinatarioNombre,
    required String destinatarioRango,
    required String fechaLunes,
    required String fechaDomingo,
    required int vehiculos,
    required int motocicletas,
    String fojasStr = '',
    String observacionAdicional = '',
    required String firmanteNombre,
    required String firmanteRango,
  }) {
    final archive = Archive();

    final tienePolicia = escudoPoliciaBytes != null && escudoPoliciaBytes.isNotEmpty;
    final bytesDerecha = (logoDireccionBytes != null && logoDireccionBytes.isNotEmpty) 
        ? logoDireccionBytes 
        : escudoMinisterioBytes;
    final tieneDerecha = bytesDerecha != null && bytesDerecha.isNotEmpty;

    if (tienePolicia) {
      archive.addFile(ArchiveFile('word/media/image1.jpeg', escudoPoliciaBytes.length, escudoPoliciaBytes));
    }
    if (tieneDerecha) {
      archive.addFile(ArchiveFile('word/media/image2.png', bytesDerecha.length, bytesDerecha));
    }

    final contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="jpeg" ContentType="image/jpeg"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

    final relsRoot = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    String rIdPolicia = 'rId2';
    String rIdDerecha = 'rId3';
    int relCount = 1;

    final docRelsBuf = StringBuffer();
    docRelsBuf.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    docRelsBuf.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n');
    docRelsBuf.write('  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\n');

    if (tienePolicia) {
      relCount++;
      rIdPolicia = 'rId$relCount';
      docRelsBuf.write('  <Relationship Id="$rIdPolicia" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.jpeg"/>\n');
    }
    if (tieneDerecha) {
      relCount++;
      rIdDerecha = 'rId$relCount';
      docRelsBuf.write('  <Relationship Id="$rIdDerecha" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image2.png"/>\n');
    }
    docRelsBuf.write('</Relationships>');

    final saludo = _saludoInforme(destinatarioRango);
    final strVehiculos = vehiculos.toString().padLeft(2, '0');
    final strMotocicletas = motocicletas.toString().padLeft(2, '0');

    final parrafoLiberaciones = fojasStr.trim().isNotEmpty
        ? 'Debo indicar que existió la libertad de $strVehiculos vehículos y $strMotocicletas motocicletas durante esas fechas, por lo que adjunto $fojasStr fojas de salida.'
        : 'Debo indicar que existió la libertad de $strVehiculos vehículos y $strMotocicletas motocicletas durante esas fechas.';

    var patioLimpio = patio.trim().toUpperCase();
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*SANTO DOMINGO DE LOS TS[ÁA]CHILAS.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*SANTO DOMINGO.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*PICHINCHA.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*MANAB[IÍ].*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*GUAYAS.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*ESMERALDAS.*$', caseSensitive: false), '');
    if (patioLimpio.isEmpty) patioLimpio = patio.trim().toUpperCase();

    var nombreFirmanteClean = firmanteNombre.trim();
    if (nombreFirmanteClean.isEmpty ||
        nombreFirmanteClean.contains('@') ||
        nombreFirmanteClean.toLowerCase().contains('google') ||
        nombreFirmanteClean.toLowerCase().contains('xchasi') ||
        nombreFirmanteClean.toLowerCase().contains('xavier xchasi')) {
      nombreFirmanteClean = 'Fausto Xavier Chasipanta Haro';
    }

    final rangoFirmante = firmanteRango.trim().isNotEmpty ? firmanteRango.trim() : 'Sargento Segundo De Policía';
    final subzonaAbrevUpper = subzonaAbrev.trim().toUpperCase();

    final docXml = _generarDocumentXmlInformeSemanal(
      tienePolicia: tienePolicia,
      tieneDerecha: tieneDerecha,
      rIdPolicia: rIdPolicia,
      rIdDerecha: rIdDerecha,
      jefaturaNombre: jefaturaNombre.trim().toUpperCase(),
      patio: patioLimpio,
      oficioNro: oficioNro.trim(),
      fechaOficio: fechaOficio.trim(),
      asuntoOficioNro: asuntoOficioNro.trim(),
      asuntoOficioFecha: asuntoOficioFecha.trim(),
      destinatarioNombre: destinatarioNombre.trim(),
      destinatarioRango: destinatarioRango.trim(),
      saludoRango: saludo,
      fechaLunes: fechaLunes.trim(),
      fechaDomingo: fechaDomingo.trim(),
      subzona: subzona.trim(),
      parrafoLiberaciones: parrafoLiberaciones,
      observacionAdicional: observacionAdicional.trim(),
      firmanteNombre: nombreFirmanteClean,
      firmanteRango: rangoFirmante,
      subzonaAbrev: subzonaAbrevUpper,
    );

    archive.addFile(_textFile('[Content_Types].xml', contentTypes));
    archive.addFile(_textFile('_rels/.rels', relsRoot));
    archive.addFile(_textFile('word/_rels/document.xml.rels', docRelsBuf.toString()));
    archive.addFile(_textFile('word/document.xml', docXml));
    archive.addFile(_textFile('word/styles.xml', _stylesXmlTimes));

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo .docx para el informe semanal');
    }
    return bytes;
  }

  static String _generarDocumentXmlInformeSemanal({
    required bool tienePolicia,
    required bool tieneDerecha,
    required String rIdPolicia,
    required String rIdDerecha,
    required String jefaturaNombre,
    required String patio,
    required String oficioNro,
    required String fechaOficio,
    required String asuntoOficioNro,
    required String asuntoOficioFecha,
    required String destinatarioNombre,
    required String destinatarioRango,
    required String saludoRango,
    required String fechaLunes,
    required String fechaDomingo,
    required String subzona,
    required String parrafoLiberaciones,
    required String observacionAdicional,
    required String firmanteNombre,
    required String firmanteRango,
    required String subzonaAbrev,
  }) {
    final imgPoliciaXml = tienePolicia ? '''<w:r><w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="685800" cy="685800"/>
        <wp:docPr id="1" name="EscudoPolicia"/>
        <wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:nvPicPr><pic:cNvPr id="1" name="EscudoPolicia"/><pic:cNvGraphicPr/></pic:nvPicPr>
              <pic:blipFill><a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="$rIdPolicia"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
              <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="685800" cy="685800"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing></w:r>''' : '';

    final imgDerechaXml = tieneDerecha ? '''<w:r><w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="685800" cy="685800"/>
        <wp:docPr id="2" name="LogoDireccionTransito"/>
        <wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:nvPicPr><pic:cNvPr id="2" name="LogoDireccionTransito"/><pic:cNvGraphicPr/></pic:nvPicPr>
              <pic:blipFill><a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="$rIdDerecha"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
              <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="685800" cy="685800"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing></w:r>''' : '';

    final jefaturaClean = jefaturaNombre
        .replaceAll('JEFATURA DE CONTROL DE TRÁNSITO', '')
        .replaceAll('JEFATURA DE TRÁNSITO', '')
        .trim();

    final lineasFirmante = '''
    ${_pTimes("Sr. " + _escape(firmanteNombre.trim()), negrita: true)}
    ${_pTimes(_escape(firmanteRango.trim()), negrita: true)}
    ${_pTimes("ENCARGADO DEL CENTRO DE RETENCIÓN VEHICULAR “" + _escape(patio) + "”", negrita: true)}
    ${_pTimes("PERTENECIENTE A LA JEFATURA DE TRÁNSITO SZ " + _escape(subzonaAbrev) + ".", negrita: true)}
''';

    final p1Text = 'Con el honor de dirigirme a usted, me permito expresar un atento y cordial saludo, '
        'a la vez desearle éxitos en el desarrollo de sus funciones, muy respetuosamente en cumplimiento '
        'al Oficio Nro. ${_escape(asuntoOficioNro)}, de fecha ${_escape(asuntoOficioFecha)}, emitido por la señora '
        'JEFA DE SECCION DE CENTROS DE RETENCION VEHICULAR DE LA DIRECCION NACIONAL DE CONTROL DE '
        'TRANSITO Y SEGURIDAD VIAL en el que se dispone remitir los formularios generados por el sistema una vez '
        'ejecutada la salida de los vehículos, los mismos que deberán ser consolidados por cada Centro de '
        'Retención Vehicular en un solo documento, indicando expresamente el CRV al que pertenecen.';

    final p2Text = 'Por los antes expuesto me permito remitir la información solicitada desde las 00H00 del día lunes '
        '${_escape(fechaLunes)} hasta las 00H00 del domingo ${_escape(fechaDomingo)}, con relación a la salida de vehículos '
        'o motocicletas en el Centro de Retención Vehicular de la Jefatura de Tránsito de la Subzona ${_escape(subzona)}.';

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
            xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
            xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
            xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="9360" w:type="dxa"/>
        <w:tblBorders>
          <w:top w:val="none"/><w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/>
          <w:insideH w:val="none"/><w:insideV w:val="none"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tblGrid>
        <w:gridCol w:w="1500"/>
        <w:gridCol w:w="6360"/>
        <w:gridCol w:w="1500"/>
      </w:tblGrid>
      <w:tr>
        <w:tc>
          <w:tcPr><w:tcW w:w="1500" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
          <w:p><w:pPr><w:jc w:val="center"/></w:pPr>$imgPoliciaXml</w:p>
        </w:tc>
        <w:tc>
          <w:tcPr><w:tcW w:w="6360" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
          <w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="40"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:b/><w:sz w:val="24"/></w:rPr><w:t>POLICÍA NACIONAL DEL ECUADOR</w:t></w:r></w:p>
          <w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="40"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:b/><w:u w:val="single"/><w:sz w:val="20"/></w:rPr><w:t>DIRECCIÓN NACIONAL DE CONTROL DE TRÁNSITO Y SEGURIDAD VIAL</w:t></w:r></w:p>
          <w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:b/><w:sz w:val="20"/></w:rPr><w:t>“JEFATURA DE CONTROL DE TRÁNSITO ${_escape(jefaturaClean)}” CENTRO DE RETENCIÓN VEHICULAR “${_escape(patio)}”</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:tcPr><w:tcW w:w="1500" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
          <w:p><w:pPr><w:jc w:val="center"/></w:pPr>$imgDerechaXml</w:p>
        </w:tc>
      </w:tr>
    </w:tbl>

    <w:p><w:pPr><w:spacing w:before="240" w:after="40"/></w:pPr></w:p>

    ${_pTimes("Oficio, " + _escape(oficioNro), alineacion: "right")}
    ${_pTimes("Fecha, " + _escape(fechaOficio), alineacion: "right")}

    <w:p><w:pPr><w:spacing w:before="120" w:after="120"/></w:pPr></w:p>

    ${_pTimes("ASUNTO: EN CUMPLIMIENTO AL OFICIO Nro. " + _escape(asuntoOficioNro), negrita: true)}

    <w:p><w:pPr><w:spacing w:before="120" w:after="120"/></w:pPr></w:p>

    ${_pTimes("Señor")}
    ${_pTimes(_escape(destinatarioNombre), negrita: true)}
    ${_pTimes(_escape(destinatarioRango))}
    ${_pTimes("DIRECTOR NACIONAL DE CONTROL DE TRÁNSITO Y SEGURIDAD VIAL POLICÍA NACIONAL", negrita: true)}
    ${_pTimes("En su Despacho. -")}

    <w:p><w:pPr><w:spacing w:before="120" w:after="120"/></w:pPr></w:p>

    ${_pTimes("Mi " + _escape(saludoRango) + ":")}

    <w:p><w:pPr><w:spacing w:before="120" w:after="80"/></w:pPr></w:p>

    ${_pTimes(p1Text, justificado: true)}
    ${_pTimes(p2Text, justificado: true)}
    ${_pTimes(_escape(parrafoLiberaciones), justificado: true)}
    ${observacionAdicional.isNotEmpty ? _pTimes(_escape(observacionAdicional), justificado: true) : ''}

    ${_pTimes("Adjunto los formularios descargados del SIIPNE 3W referente a la salida del vehículo.", justificado: true)}

    <w:p><w:pPr><w:spacing w:before="200" w:after="80"/></w:pPr></w:p>

    ${_pTimes("Atentamente,")}

    <w:p><w:pPr><w:spacing w:before="80" w:after="120"/></w:pPr></w:p>

    ${_pTimes("VALOR, DISCIPLINA Y LEALTAD", negrita: true)}

    <w:p><w:pPr><w:spacing w:before="720" w:after="120"/></w:pPr></w:p>

    $lineasFirmante

    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>''';
  }

  static String _saludoInforme(String rango) {
    final r = rango.trim().toLowerCase();
    if (r.contains('coronel')) return 'Coronel';
    if (r.contains('mayor')) return 'Mayor';
    if (r.contains('general')) return 'General';
    if (r.contains('teniente')) return 'Teniente Coronel';
    return rango.isEmpty ? 'Coronel' : rango;
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

  static String _pTimes(String texto, {bool negrita = false, String alineacion = "left", bool justificado = false}) {
    final jcVal = justificado ? "both" : alineacion;
    final bTag = negrita ? "<w:b/>" : "";
    return '<w:p><w:pPr><w:jc w:val="$jcVal"/><w:spacing w:after="80" w:line="240" w:lineRule="auto"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="es-ES"/>$bTag</w:rPr><w:t xml:space="preserve">$texto</w:t></w:r></w:p>';
  }

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

  static const _stylesXmlTimes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>
        <w:sz w:val="22"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
</w:styles>''';
}
