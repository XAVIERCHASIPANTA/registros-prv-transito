import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:barcode/barcode.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Servicio para gestionar el certificado digital PKCS#12 (.p12 / .pfx) del usuario,
/// validar su contraseña y aplicar la firma digital oficial FirmaEC en el documento PDF.
class FirmaDigitalService {
  static const _claveRutaP12 = 'firma_p12_ruta';
  static const _claveNombreFirmante = 'firma_p12_nombre';
  static const _claveCedulaFirmante = 'firma_p12_cedula';
  static const _claveRangoFirmante = 'firma_p12_rango';
  static const _claveCargoFirmante = 'firma_p12_cargo';
  static const _claveInstitucion = 'firma_p12_institucion';
  static const _claveFechaCarga = 'firma_p12_fecha_carga';
  // 18/oct: en la versión web/PWA no existe sistema de archivos ni
  // path_provider (daba MissingPluginException al guardar), así que ahí
  // el .p12 se guarda en base64 dentro de SharedPreferences (localStorage
  // del navegador). En Android sigue guardándose como archivo, igual que antes.
  static const _claveP12Base64 = 'firma_p12_base64';

  /// Verifica si el usuario ya tiene guardado un archivo .p12 en el dispositivo
  static Future<bool> tieneCertificado() async {
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      final b64 = prefs.getString(_claveP12Base64);
      return b64 != null && b64.isNotEmpty;
    }
    final ruta = prefs.getString(_claveRutaP12);
    if (ruta == null || ruta.isEmpty) return false;
    final file = File(ruta);
    return file.existsSync();
  }

  /// Lee los bytes del certificado .p12 guardado en el dispositivo
  static Future<Uint8List?> obtenerBytesCertificadoP12() async {
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      final b64 = prefs.getString(_claveP12Base64);
      if (b64 == null || b64.isEmpty) return null;
      return base64Decode(b64);
    }
    final ruta = prefs.getString(_claveRutaP12);
    if (ruta == null || ruta.isEmpty) return null;
    final file = File(ruta);
    if (!file.existsSync()) return null;
    return await file.readAsBytes();
  }

  /// Devuelve los metadatos del firmante guardados
  static Future<Map<String, String>> obtenerDatosFirmante() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'ruta': prefs.getString(_claveRutaP12) ?? '',
      'nombre': prefs.getString(_claveNombreFirmante) ?? '',
      'cedula': prefs.getString(_claveCedulaFirmante) ?? '',
      'rango': prefs.getString(_claveRangoFirmante) ?? '',
      'cargo': prefs.getString(_claveCargoFirmante) ?? '',
      'institucion': prefs.getString(_claveInstitucion) ?? '',
      'fechaCarga': prefs.getString(_claveFechaCarga) ?? '',
    };
  }

  /// Valida si la contraseña ingresada abre correctamente el certificado .p12
  static bool validarClaveP12({
    required Uint8List bytesP12,
    required String password,
  }) {
    try {
      final cert = PdfCertificate(bytesP12, password);
      // Si el certificado se inicializa sin lanzar excepción, la clave es válida
      return cert.issuerName.isNotEmpty || cert.subjectName.isNotEmpty || true;
    } catch (e) {
      return false;
    }
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');

  /// Firma digitalmente el PDF con el certificado PKCS#12 (.p12) y dibuja un
  /// sello VISIBLE (estilo FirmaEC) justo encima del nombre del firmante.
  ///
  /// 18/oct: antes el campo de firma se creaba SIN apariencia (por eso la firma
  /// era invisible en el documento) y cualquier error se tragaba en silencio y
  /// se devolvía el PDF sin firmar como si estuviera firmado. Ahora, si algo
  /// falla, la excepción sube hasta el diálogo y se muestra el motivo real.
  static Future<Uint8List> firmarDocumentoPdf({
    required Uint8List pdfInputBytes,
    required Uint8List bytesP12,
    required String password,
    required String nombreFirmante,
  }) async {
    final document = PdfDocument(inputBytes: pdfInputBytes);
    try {
      if (document.pages.count == 0) {
        throw StateError('El PDF no tiene páginas para firmar.');
      }

      final datos = await obtenerDatosFirmante();
      final nombre = (datos['nombre'] ?? '').isNotEmpty
          ? datos['nombre']!
          : nombreFirmante.trim().toUpperCase();

      // Ubicar el espacio en blanco que deja el informe entre
      // "VALOR, DISCIPLINA Y LEALTAD" y el nombre del firmante. Si no se
      // encuentra el texto, se usa una posición fija como respaldo.
      int paginaIdx = 0;
      Rect rect = const Rect.fromLTWH(45, 600, 255, 40);
      try {
        final ultimaPagina = document.pages.count > 3 ? 2 : document.pages.count - 1;
        final encontrados = PdfTextExtractor(document).findText(
          <String>['LEALTAD'],
          startPageIndex: 0,
          endPageIndex: ultimaPagina,
        );
        if (encontrados.isNotEmpty) {
          final m = encontrados.first;
          paginaIdx = m.pageIndex;
          rect = Rect.fromLTWH(45, m.bounds.bottom + 3, 255, 40);
        }
      } catch (_) {
        // Si la búsqueda de texto falla, se queda la posición de respaldo.
      }

      final certificate = PdfCertificate(bytesP12, password);
      final page = document.pages[paginaIdx];

      final campo = PdfSignatureField(
        page,
        'FirmaEC_${nombre.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}',
        bounds: rect,
        signature: PdfSignature(
          certificate: certificate,
          signedName: nombre,
        ),
      );

      // Sello visible dentro del campo de firma.
      final g = campo.appearance.normal.graphics!;
      final fuente = PdfStandardFont(PdfFontFamily.helvetica, 8);
      final fuenteNegrita =
          PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold);
      final ahora = DateTime.now();
      final fecha = '${_dos(ahora.day)}/${_dos(ahora.month)}/${ahora.year} '
          '${_dos(ahora.hour)}:${_dos(ahora.minute)}';
      g.drawString(
        'Firmado electrónicamente por:',
        fuente,
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(0, 0, rect.width, 11),
      );
      g.drawString(
        nombre,
        fuenteNegrita,
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(0, 11, rect.width, 11),
      );
      g.drawString(
        'Fecha: $fecha',
        fuente,
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(0, 22, rect.width, 11),
      );

      // Código QR con los datos de la firma, a la derecha del sello (pegado al
      // margen derecho). Se dibuja sobre la página ANTES de guardar, así queda
      // cubierto por la firma criptográfica. El QR es informativo: la validez
      // real de la firma se comprueba abriendo el PDF en un lector (Adobe) o en
      // FirmaEC.
      final datosQr = 'FIRMADO POR: $nombre\n'
          'FECHA: $fecha\n'
          'FIRMA ELECTRONICA (.p12)\n'
          'VALIDAR EL PDF CON FIRMAEC';
      const double ladoQr = 62;
      final double qrX = page.size.width - 45 - ladoQr;
      final qr = Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium);
      for (final e in qr.make(datosQr, width: ladoQr, height: ladoQr)) {
        if (e is BarcodeBar && e.black) {
          page.graphics.drawRectangle(
            brush: PdfBrushes.black,
            bounds: Rect.fromLTWH(qrX + e.left, rect.top + e.top, e.width + 0.2, e.height + 0.2),
          );
        }
      }

      document.form.fields.add(campo);

      final List<int> signedBytes = await document.save();
      return Uint8List.fromList(signedBytes);
    } finally {
      document.dispose();
    }
  }

  /// Guarda el archivo .p12 en el directorio privado de la aplicación y registra sus datos
  static Future<void> guardarCertificado({
    required Uint8List bytesArchivo,
    required String nombreArchivo,
    required String nombreFirmante,
    required String cedula,
    required String rango,
    required String cargo,
    required String institucion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      await prefs.setString(_claveP12Base64, base64Encode(bytesArchivo));
      await prefs.setString(_claveRutaP12, 'navegador');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final certsDir = Directory('${dir.path}/certificados');
      if (!certsDir.existsSync()) {
        certsDir.createSync(recursive: true);
      }

      final targetPath = '${certsDir.path}/firma_usuario.p12';
      final targetFile = File(targetPath);
      await targetFile.writeAsBytes(bytesArchivo);
      await prefs.setString(_claveRutaP12, targetPath);
    }
    await prefs.setString(_claveNombreFirmante, nombreFirmante.trim().toUpperCase());
    await prefs.setString(_claveCedulaFirmante, cedula.trim());
    await prefs.setString(_claveRangoFirmante, rango.trim());
    await prefs.setString(_claveCargoFirmante, cargo.trim());
    await prefs.setString(_claveInstitucion, institucion.trim());
    await prefs.setString(_claveFechaCarga, DateTime.now().toIso8601String());
  }

  /// Elimina el certificado .p12 guardado
  static Future<void> eliminarCertificado() async {
    final prefs = await SharedPreferences.getInstance();
    final ruta = prefs.getString(_claveRutaP12);
    if (!kIsWeb && ruta != null && ruta.isNotEmpty) {
      final file = File(ruta);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    await prefs.remove(_claveRutaP12);
    await prefs.remove(_claveP12Base64);
    await prefs.remove(_claveNombreFirmante);
    await prefs.remove(_claveCedulaFirmante);
    await prefs.remove(_claveRangoFirmante);
    await prefs.remove(_claveCargoFirmante);
    await prefs.remove(_claveInstitucion);
    await prefs.remove(_claveFechaCarga);
  }

  /// Retorna un espacio en blanco reservado para la firma digital oficial de FirmaEC.
  static Widget construirEstampaFirmaEC({
    required String nombreFirmante,
    String? fechaHora,
  }) {
    return const SizedBox(height: 40);
  }
}
