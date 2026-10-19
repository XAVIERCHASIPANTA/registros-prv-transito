import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Generador del Informe Semanal en formato PDF Nativo oficial
/// con diagramación estandarizada para impresión y FirmaEC.
class PdfInformeSemanalBuilder {
  static Future<Uint8List> buildPdf({
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
    required String fojasStr,
    String observacionAdicional = '',
    required String firmanteNombre,
    required String firmanteRango,
    bool incluirEstampaFirma = false,
  }) async {
    final pdf = pw.Document();

    // Cargar imágenes oficiales desde los assets
    pw.MemoryImage? escudoPolicia;
    pw.MemoryImage? logoDireccionTransito;

    try {
      final bytesPolicia = await rootBundle.load('assets/escudo_policia.jpg');
      escudoPolicia = pw.MemoryImage(bytesPolicia.buffer.asUint8List());
    } catch (_) {}

    try {
      final bytesDireccion = await rootBundle.load('assets/logo_direccion_transito.png');
      logoDireccionTransito = pw.MemoryImage(bytesDireccion.buffer.asUint8List());
    } catch (_) {}

    final saludo = _saludoRango(destinatarioRango);
    final strVehiculos = vehiculos.toString().padLeft(2, '0');
    final strMotocicletas = motocicletas.toString().padLeft(2, '0');

    var patioLimpio = patio.trim().toUpperCase();
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*SANTO DOMINGO DE LOS TS[ÁA]CHILAS.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*SANTO DOMINGO.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*PICHINCHA.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*MANAB[IÍ].*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*GUAYAS.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*ESMERALDAS.*$', caseSensitive: false), '');
    if (patioLimpio.isEmpty) patioLimpio = patio.trim().toUpperCase();

    var firmanteClean = firmanteNombre.trim();
    if (firmanteClean.isEmpty ||
        firmanteClean.contains('@') ||
        firmanteClean.toLowerCase().contains('google') ||
        firmanteClean.toLowerCase().contains('xchasi') ||
        firmanteClean.toLowerCase().contains('xavier xchasi')) {
      firmanteClean = 'Fausto Xavier Chasipanta Haro';
    }

    final firmanteRangoClean = firmanteRango.trim().isNotEmpty ? firmanteRango.trim() : 'Sargento Segundo De Policía';

    final jefaturaClean = jefaturaNombre
        .toUpperCase()
        .replaceAll('JEFATURA DE CONTROL DE TRÁNSITO', '')
        .replaceAll('JEFATURA DE TRÁNSITO', '')
        .trim();

    // ── Tipografías: Liberation Serif/Sans (métricas idénticas a Times New Roman
    // y Arial de la plantilla de Word). Si no cargan, se usan las estándar.
    pw.Font serif = pw.Font.times();
    pw.Font serifB = pw.Font.timesBold();
    pw.Font sans = pw.Font.helvetica();
    try {
      serif = pw.Font.ttf(await rootBundle.load('assets/LiberationSerif-Regular.ttf'));
      serifB = pw.Font.ttf(await rootBundle.load('assets/LiberationSerif-Bold.ttf'));
      sans = pw.Font.ttf(await rootBundle.load('assets/LiberationSans-Regular.ttf'));
    } catch (_) {}

    // Color de los datos variables (en la plantilla oficial van en rojo).
    const rojo = PdfColor.fromInt(0xFFED0000);
    const negro = PdfColors.black;
    const gris = PdfColor.fromInt(0xFF5A5A5A);

    pw.TextSpan sp(String t, double size, {bool bold = false, PdfColor color = negro}) =>
        pw.TextSpan(
          text: t,
          style: pw.TextStyle(font: bold ? serifB : serif, fontSize: size, color: color),
        );

    pw.Widget linea(List<pw.TextSpan> spans,
            {pw.TextAlign align = pw.TextAlign.left, double spacing = 0}) =>
        pw.RichText(
          textAlign: align,
          text: pw.TextSpan(
            children: spans,
            style: pw.TextStyle(font: serif, lineSpacing: spacing),
          ),
        );

    pw.Widget rect(double x, double top, double w, double h, PdfColor c) =>
        pw.Positioned(
          left: x,
          top: top,
          child: pw.Container(width: w, height: h, color: c),
        );

    const double mIzq = 85.05;
    const double anchoTexto = 426.9; // 597 - 2 * 85.05 (márgenes de 3 cm)
    const double sp11 = 0.85; // interlineado de las líneas de 11 pt (≈13 pt)

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // ── Franja inferior (azul y grises) ──
              rect(80.1, 778.0, 37.5, 50.25, const PdfColor(0.624, 0.624, 0.624)),
              rect(55.35, 769.77, 37.5, 40.5, const PdfColor(0, 0.216, 0.573)),
              rect(117.63, 768.3, 466.44, 60.0, const PdfColor(0, 0.216, 0.573)),
              rect(31.35, 796.0, 37.5, 30.0, const PdfColor(0.624, 0.624, 0.624)),

              // ── Escudos ──
              if (escudoPolicia != null)
                pw.Positioned(
                  left: 32,
                  top: 32,
                  child: pw.Image(escudoPolicia, width: 62.6, height: 62.5, fit: pw.BoxFit.fill),
                ),
              if (logoDireccionTransito != null)
                pw.Positioned(
                  left: 495,
                  top: 31,
                  child: pw.Image(logoDireccionTransito, width: 74, height: 71.9, fit: pw.BoxFit.fill),
                ),

              // ── Encabezado ──
              pw.Positioned(
                left: 85,
                top: 63.1,
                child: pw.SizedBox(
                  width: 427,
                  child: pw.Text(
                    'POLICÍA  NACIONAL  DEL  ECUADOR',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: sans, fontSize: 11, color: gris),
                  ),
                ),
              ),
              pw.Positioned(
                left: 85,
                top: 76.1,
                child: pw.SizedBox(
                  width: 427,
                  child: pw.Text(
                    'DIRECCIÓN NACIONAL DE CONTROL DE TRÁNSITO Y SEGURIDAD VIAL',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: sans, fontSize: 11, color: negro),
                  ),
                ),
              ),
              rect(110.05, 86.6, 378.72, 1.4, negro),
              pw.Positioned(
                left: 110.05,
                top: 101.5,
                child: pw.SizedBox(
                  width: 378.72,
                  child: pw.Column(
                    children: [
                      linea([
                        sp('“', 10),
                        sp('JEFATURA DE CONTROL DE ', 10, color: rojo),
                        sp('TRÁNSITO $jefaturaClean', 9, color: rojo),
                        sp('” CENTRO DE RETENCION', 10),
                      ], align: pw.TextAlign.center, spacing: 0.5),
                      linea([
                        sp('VEHICULAR “', 10),
                        sp(patioLimpio, 10, color: rojo),
                        sp('”', 10),
                      ], align: pw.TextAlign.center, spacing: 0.5),
                    ],
                  ),
                ),
              ),

              // ── Oficio y fecha (alineados a la derecha) ──
              pw.Positioned(
                left: 300,
                top: 146.2,
                child: pw.SizedBox(
                  width: 215.9,
                  child: linea([
                    sp('Oficio, ', 11),
                    sp(oficioNro, 11, color: rojo),
                  ], align: pw.TextAlign.right),
                ),
              ),
              pw.Positioned(
                left: 300,
                top: 171.6,
                child: pw.SizedBox(
                  width: 214.5,
                  child: linea([
                    sp('Fecha, ', 11),
                    sp(fechaOficio, 11, color: rojo),
                  ], align: pw.TextAlign.right),
                ),
              ),

              // ── Asunto ──
              pw.Positioned(
                left: mIzq,
                top: 209.4,
                child: pw.SizedBox(
                  width: anchoTexto,
                  child: linea([
                    sp('ASUNTO: ', 11),
                    sp('EN CUMPLIMIENTO AL  OFICIO Nro. ', 11, bold: true),
                    sp(asuntoOficioNro, 11, bold: true, color: rojo),
                  ]),
                ),
              ),

              // ── Destinatario, cuerpo y despedida (flujo continuo) ──
              pw.Positioned(
                left: mIzq,
                top: 235.0,
                child: pw.SizedBox(
                  width: anchoTexto,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      linea([sp('Señor', 11)], spacing: sp11),
                      linea([sp(destinatarioNombre, 11, color: rojo)], spacing: sp11),
                      linea([
                        sp(destinatarioRango, 11, color: rojo),
                      ], spacing: sp11),
                      linea([
                        sp('DIRECTOR NACIONAL DE CONTROL DE TRÁNSITO Y SEGURIDAD VIAL POLICÍA NACIONAL', 11),
                      ], spacing: sp11),
                      pw.SizedBox(height: 26.5 - 1.0),
                      linea([sp('En su Despacho. –', 11)]),
                      pw.SizedBox(height: 8.8),
                      linea([
                        sp('Mi ', 11),
                        sp(saludo, 11, color: rojo),
                        sp(':', 11),
                      ]),
                      pw.SizedBox(height: 8.3),

                      // Párrafos (justificados, Times 10 pt)
                      linea([
                        sp('Con el honor de dirigirme a usted, me permito expresar un atento y cordial saludo, '
                            'a la vez desearle éxitos en el desarrollo de sus funciones, muy respetuosamente en cumplimiento '
                            'al Oficio Nro. $asuntoOficioNro, de fecha $asuntoOficioFecha, emitido por la señora '
                            'JEFA DE SECCION DE CENTROS DE RETENCION VEHICULAR DE LA DIRECCION NACIONAL DE CONTROL DE '
                            'TRANSITO Y SEGURIDAD VIAL en el que se dispone remitir los formularios generados por el sistema una vez '
                            'ejecutada la salida de los vehículos, los mismos que deberán ser consolidados por cada Centro de '
                            'Retención Vehicular en un solo documento, indicando expresamente el CRV al que pertenecen. '
                            'Por los antes expuesto me permito remitir la información solicitada desde las 00H00 del día lunes ', 10),
                        sp(fechaLunes, 10, color: rojo),
                        sp(' hasta las 00H00 del domingo ', 10),
                        sp(fechaDomingo, 10, color: rojo),
                        sp(', con relación a la salida de vehículos o motocicletas en el Centro de Retención Vehicular de ', 10),
                        sp('la Jefatura de Tránsito de la Subzona $subzona', 10, color: rojo),
                        sp('.', 10),
                      ], align: pw.TextAlign.justify, spacing: 0.4),
                      pw.SizedBox(height: 6.6),
                      linea([
                        sp('Debo indicar que existió la libertad de ', 10),
                        sp(strVehiculos, 10, color: rojo),
                        sp(' vehículos y ', 10),
                        sp(strMotocicletas, 10, color: rojo),
                        sp(fojasStr.trim().isNotEmpty
                            ? ' motocicletas durante esas fechas, por lo que adjunto $fojasStr fojas de salida.'
                            : ' motocicletas durante esas fechas.', 10),
                      ], align: pw.TextAlign.justify, spacing: 0.4),
                      if (observacionAdicional.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 6.6),
                        linea([sp(observacionAdicional.trim(), 10)],
                            align: pw.TextAlign.justify, spacing: 0.4),
                      ],
                      pw.SizedBox(height: 8.2),
                      linea([
                        sp('Adjunto los formularios descargados del SIIPNE 3W referente a la salida del vehículo.', 10),
                      ], align: pw.TextAlign.justify, spacing: 0.4),
                      pw.SizedBox(height: 8.5),

                      // Despedida
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 2.4),
                        child: linea([sp('Atentamente,', 11)]),
                      ),
                      pw.SizedBox(height: 17.2),
                      linea([sp('VALOR, DISCIPLINA Y LEALTAD', 11, bold: true)]),

                      // Espacio libre para el sello/QR de firma electrónica
                      pw.SizedBox(height: 113.3),

                      // Pie de firma
                      linea([
                        sp('Sr. ', 11, bold: true),
                        sp(firmanteClean, 11, bold: true, color: rojo),
                      ], spacing: 1.2),
                      linea([sp(firmanteRangoClean, 11, bold: true, color: rojo)], spacing: 1.2),
                      linea([
                        sp('ENCARGADO DEL CENTRO DE RETENCIÓN VEHICULAR “', 11, bold: true),
                        sp(patioLimpio, 11, bold: true, color: rojo),
                        sp('”', 11, bold: true),
                      ], spacing: 1.2),
                      linea([
                        sp('PERTENECIENTE A LA JEFATURA DE TRÁNSITO ', 11, bold: true),
                        sp('SZ ${subzonaAbrev.toUpperCase()}', 11, bold: true, color: rojo),
                        sp('.', 11, bold: true),
                      ], spacing: 1.2),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Compila el documento del informe oficial con los anexos en formato PDF (formularios SIIPNE 3W).
  /// Genera un único archivo vectorial de alta definición donde la primera página es el oficio
  /// y las siguientes son cada una de las páginas de los formularios anexados.
  static Uint8List compilarConAnexos({
    required Uint8List informePdfBytes,
    required List<Uint8List> anexosPdfBytes,
  }) {
    if (anexosPdfBytes.isEmpty) return informePdfBytes;

    final docBase = sf.PdfDocument(inputBytes: informePdfBytes);

    for (final anexoBytes in anexosPdfBytes) {
      sf.PdfDocument? docAnexo;
      try {
        docAnexo = sf.PdfDocument(inputBytes: anexoBytes);
        for (int i = 0; i < docAnexo.pages.count; i++) {
          final template = docAnexo.pages[i].createTemplate();
          final page = docBase.pages.add();
          page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
        }
      } catch (_) {
        // En caso de PDF anexo corrupto, se omite para no invalidar el informe
      } finally {
        docAnexo?.dispose();
      }
    }

    final mergedBytes = Uint8List.fromList(docBase.saveSync());
    docBase.dispose();
    return mergedBytes;
  }

  static String _saludoRango(String rango) {
    final r = rango.trim().toLowerCase();
    if (r.contains('coronel')) return 'Coronel';
    if (r.contains('mayor')) return 'Mayor';
    if (r.contains('general')) return 'General';
    if (r.contains('teniente')) return 'Teniente Coronel';
    return rango.isEmpty ? 'Coronel' : 'Coronel';
  }
}

