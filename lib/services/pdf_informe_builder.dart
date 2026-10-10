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
    bool incluirEstampaFirma = true,
  }) async {
    final pdf = pw.Document();

    // Cargar imágenes de escudos desde los assets
    pw.MemoryImage? escudoPolicia;
    pw.MemoryImage? escudoMinisterio;

    try {
      final bytesPolicia = await rootBundle.load('assets/escudo_policia.jpg');
      escudoPolicia = pw.MemoryImage(bytesPolicia.buffer.asUint8List());
    } catch (_) {}

    try {
      final bytesMinisterio = await rootBundle.load('assets/escudo_ministerio.jpg');
      escudoMinisterio = pw.MemoryImage(bytesMinisterio.buffer.asUint8List());
    } catch (_) {}

    final saludo = _saludoRango(destinatarioRango);
    final strVehiculos = vehiculos.toString().padLeft(2, '0');
    final strMotocicletas = motocicletas.toString().padLeft(2, '0');
    final totalLiberados = vehiculos + motocicletas;
    final strTotal = totalLiberados.toString().padLeft(2, '0');
    final strFojas = fojasStr.isNotEmpty ? fojasStr.padLeft(2, '0') : (totalLiberados * 2).toString().padLeft(2, '0');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 45, vertical: 40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado oficial con los dos escudos
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (escudoPolicia != null)
                    pw.Image(escudoPolicia, width: 50, height: 50, fit: pw.BoxFit.contain)
                  else
                    pw.SizedBox(width: 50, height: 50),
                  pw.SizedBox(width: 10),
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
                          '“JEFATURA DE CONTROL DE TRÁNSITO ${jefaturaNombre.toUpperCase()}” CENTRO DE RETENCION VEHICULAR ${patio.toUpperCase()}”',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  if (escudoMinisterio != null)
                    pw.Image(escudoMinisterio, width: 65, height: 50, fit: pw.BoxFit.contain)
                  else
                    pw.SizedBox(width: 65, height: 50),
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
              pw.Text('En su Despacho. –', style: const pw.TextStyle(fontSize: 11)),
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
                    'al Oficio Nro. $asuntoOficioNro, de fecha $asuntoOficioFecha firmado electrónicamente por el señor '
                    'DIRECTOR NACIONAL DE CONTROL DE TRANSITO Y SEGURIDAD VIAL en el que se dispone remitir los formularios '
                    'generados por el sistema una vez ejecutada la salida de los vehículos, los mismos que deberán ser '
                    'consolidados por cada Centro de Retención Vehicular en un solo documento, indicando expresamente el CRV al que pertenecen.',
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
              pw.SizedBox(height: 8),

              // Cuerpo del informe (Párrafo 2)
              pw.Paragraph(
                text: 'Por los antes expuesto me permito remitir la información solicitada desde las 00H00 del día lunes '
                    '$fechaLunes hasta las 00H00 del día domingo $fechaDomingo, con relación a la salida de vehículos '
                    'o motocicletas en el Centro de Retención Vehicular de la Jefatura de Tránsito $jefaturaNombre perteneciente a la Subzona $subzona.',
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
              pw.SizedBox(height: 8),

              // Cuerpo del informe (Párrafo 3)
              pw.Paragraph(
                text: vehiculos > 0 && motocicletas > 0
                    ? 'Debo indicar que en dicha semana se realizó la liberación de $strVehiculos vehículos y $strMotocicletas motocicletas (total $strTotal liberaciones), por lo que adjunto $strFojas fojas de salida'
                    : 'Debo indicar que en dicha semana se realizó la liberación de $strTotal vehículos, por lo que adjunto $strFojas fojas de salida',
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
              pw.SizedBox(height: 20),

              // Despedida
              pw.Text('Atentamente,', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 12),
              pw.Text(
                'VALOR, DISCIPLINA Y LEALTAD',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),

              // Estampa de FirmaEC si está habilitada
              if (incluirEstampaFirma) ...[
                _construirEstampaPdfFirmaEC(firmanteNombre),
                pw.SizedBox(height: 8),
              ] else ...[
                pw.SizedBox(height: 45),
              ],

              // Pie de Firma
              pw.Text(
                'Sr. ${firmanteNombre.toUpperCase()}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                firmanteRango,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'ENCARGADO DEL CENTRO DE RETENCIÓN VEHICULAR $patio',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'PERTENECIENTE A LA JEFATURA DE TRÁNSITO SZ $subzonaAbrev.',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _construirEstampaPdfFirmaEC(String nombreFirmante) {
    return pw.Container(
      width: 230,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Cuadro visual del QR FirmaEC
          pw.Container(
            width: 38,
            height: 38,
            color: PdfColors.black,
            padding: const pw.EdgeInsets.all(2),
            child: pw.Container(
              color: PdfColors.white,
              child: pw.Center(
                child: pw.Text(
                  'QR',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'Firmado electrónicamente por:',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
                pw.Text(
                  nombreFirmante.trim().toUpperCase(),
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  maxLines: 2,
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'Validez únicamente con FirmaEC',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _saludoRango(String rango) {
    final r = rango.trim().toLowerCase();
    if (r.contains('coronel')) return 'coronel';
    if (r.contains('mayor')) return 'mayor';
    if (r.contains('general')) return 'general';
    if (r.contains('teniente')) return 'teniente coronel';
    return rango.isEmpty ? 'coronel' : rango.toLowerCase();
  }
}
