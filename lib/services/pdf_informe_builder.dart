import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 45, vertical: 40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado oficial
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (escudoPolicia != null)
                    pw.Image(escudoPolicia, width: 55, height: 55, fit: pw.BoxFit.contain)
                  else
                    pw.SizedBox(width: 55, height: 55),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'POLICÍA NACIONAL DEL ECUADOR',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'DIRECCIÓN NACIONAL DE CONTROL DE TRÁNSITO Y SEGURIDAD VIAL',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '"JEFATURA DE CONTROL DE TRÁNSITO $jefaturaClean" CENTRO DE RETENCIÓN VEHICULAR "$patioLimpio"',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  if (logoDireccionTransito != null)
                    pw.Image(logoDireccionTransito, width: 55, height: 55, fit: pw.BoxFit.contain)
                  else
                    pw.SizedBox(width: 55, height: 55),
                ],
              ),
              pw.SizedBox(height: 20),

              // Oficio y Fecha alineados a la derecha
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Oficio, $oficioNro', style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 3),
                    pw.Text('Fecha, $fechaOficio', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // ASUNTO
              pw.Text(
                'ASUNTO: EN CUMPLIMIENTO AL OFICIO Nro. $asuntoOficioNro',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),

              // Destinatario
              pw.Text('Señor', style: const pw.TextStyle(fontSize: 11)),
              pw.Text(
                destinatarioNombre,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(destinatarioRango, style: const pw.TextStyle(fontSize: 11)),
              pw.Text(
                'DIRECTOR NACIONAL DE CONTROL DE TRÁNSITO Y SEGURIDAD VIAL POLICÍA NACIONAL',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('En su Despacho. -', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 14),

              // Saludo
              pw.Text(
                'Mi $saludo:',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 10),

              // Cuerpo del informe (Párrafo 1)
              pw.Paragraph(
                text: 'Con el honor de dirigirme a usted, me permito expresar un atento y cordial saludo, '
                    'a la vez desearle éxitos en el desarrollo de sus funciones, muy respetuosamente en cumplimiento '
                    'al Oficio Nro. $asuntoOficioNro, de fecha $asuntoOficioFecha, emitido por la señora '
                    'JEFA DE SECCION DE CENTROS DE RETENCION VEHICULAR DE LA DIRECCION NACIONAL DE CONTROL DE '
                    'TRANSITO Y SEGURIDAD VIAL en el que se dispone remitir los formularios generados por el sistema una vez '
                    'ejecutada la salida de los vehículos, los mismos que deberán ser consolidados por cada Centro de '
                    'Retención Vehicular en un solo documento, indicando expresamente el CRV al que pertenecen.',
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
              pw.SizedBox(height: 8),

              // Cuerpo del informe (Párrafo 2)
              pw.Paragraph(
                text: 'Por los antes expuesto me permito remitir la información solicitada desde las 00H00 del día lunes '
                    '$fechaLunes hasta las 00H00 del domingo $fechaDomingo, con relación a la salida de vehículos '
                    'o motocicletas en el Centro de Retención Vehicular de la Jefatura de Tránsito de la Subzona $subzona.',
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
              pw.SizedBox(height: 8),

              // Cuerpo del informe (Párrafo 3)
              pw.Paragraph(
                text: 'Debo indicar que existió la libertad de $strVehiculos vehículos y $strMotocicletas motocicletas durante esas fechas.',
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
              if (observacionAdicional.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Paragraph(
                  text: observacionAdicional.trim(),
                  textAlign: pw.TextAlign.justify,
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
                ),
              ],
              pw.SizedBox(height: 8),
              pw.Paragraph(
                text: 'Adjunto los formularios descargados del SIIPNE 3W referente a la salida del vehículo.',
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
              pw.SizedBox(height: 18),

              // Despedida
              pw.Text('Atentamente,', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 12),
              pw.Text(
                'VALOR, DISCIPLINA Y LEALTAD',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              
              // Espacio limpio sin QR ni estampas ficticias para FirmaEC
              pw.SizedBox(height: 45),

              // Pie de Firma
              pw.Text(
                'Sr. $firmanteClean',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                firmanteRangoClean,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'ENCARGADO DEL CENTRO DE RETENCIÓN VEHICULAR "$patioLimpio"',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'PERTENECIENTE A LA JEFATURA DE TRÁNSITO SZ ${subzonaAbrev.toUpperCase()}.',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
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
