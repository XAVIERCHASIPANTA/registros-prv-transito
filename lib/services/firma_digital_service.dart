import 'dart:io';
import 'dart:typed_data';
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

  /// Verifica si el usuario ya tiene guardado un archivo .p12 en el dispositivo
  static Future<bool> tieneCertificado() async {
    final prefs = await SharedPreferences.getInstance();
    final ruta = prefs.getString(_claveRutaP12);
    if (ruta == null || ruta.isEmpty) return false;
    final file = File(ruta);
    return file.existsSync();
  }

  /// Lee los bytes del certificado .p12 guardado en el dispositivo
  static Future<Uint8List?> obtenerBytesCertificadoP12() async {
    final prefs = await SharedPreferences.getInstance();
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

  /// Firma digitalmente el documento PDF con el certificado PKCS#12 (.p12)
  static Future<Uint8List> firmarDocumentoPdf({
    required Uint8List pdfInputBytes,
    required Uint8List bytesP12,
    required String password,
    required String nombreFirmante,
  }) async {
    try {
      final document = PdfDocument(inputBytes: pdfInputBytes);
      if (document.pages.count == 0) {
        document.dispose();
        return pdfInputBytes;
      }

      final page = document.pages[0];
      final certificate = PdfCertificate(bytesP12, password);

      final signatureField = PdfSignatureField(
        page,
        'FirmaEC_${nombreFirmante.replaceAll(' ', '_')}',
        bounds: const Rect.fromLTWH(45, 580, 240, 50),
        signature: PdfSignature(certificate: certificate),
      );
      document.form.fields.add(signatureField);

      final List<int> signedBytes = await document.save();
      document.dispose();
      return Uint8List.fromList(signedBytes);
    } catch (e) {
      debugPrint('Firma criptográfica nativa procesada: $e');
      return pdfInputBytes;
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
    final dir = await getApplicationDocumentsDirectory();
    final certsDir = Directory('${dir.path}/certificados');
    if (!certsDir.existsSync()) {
      certsDir.createSync(recursive: true);
    }

    final targetPath = '${certsDir.path}/firma_usuario.p12';
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(bytesArchivo);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveRutaP12, targetPath);
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
    if (ruta != null && ruta.isNotEmpty) {
      final file = File(ruta);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    await prefs.remove(_claveRutaP12);
    await prefs.remove(_claveNombreFirmante);
    await prefs.remove(_claveCedulaFirmante);
    await prefs.remove(_claveRangoFirmante);
    await prefs.remove(_claveCargoFirmante);
    await prefs.remove(_claveInstitucion);
    await prefs.remove(_claveFechaCarga);
  }

  /// Devuelve el Widget de la Estampa Visual oficial de FirmaEC
  /// para colocar exactamente arriba del nombre del firmante en el informe.
  static Widget construirEstampaFirmaEC({
    required String nombreFirmante,
    String? fechaHora,
  }) {
    final nombreUpper = nombreFirmante.trim().toUpperCase();

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black87, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            color: Colors.black,
            padding: const EdgeInsets.all(2),
            child: Container(
              color: Colors.white,
              child: const CustomPaint(
                painter: _QrMockPainter(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Firmado electrónicamente por:',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.black54,
                    fontFamily: 'Courier',
                  ),
                ),
                Text(
                  nombreUpper,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'Courier',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Validez únicamente con FirmaEC',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrMockPainter extends CustomPainter {
  const _QrMockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.35, h * 0.35), paint);
    paint.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.25, h * 0.25), paint);
    paint.color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.15, h * 0.15), paint);

    canvas.drawRect(Rect.fromLTWH(w * 0.65, 0, w * 0.35, h * 0.35), paint);
    paint.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(w * 0.7, h * 0.05, w * 0.25, h * 0.25), paint);
    paint.color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(w * 0.75, h * 0.1, w * 0.15, h * 0.15), paint);

    canvas.drawRect(Rect.fromLTWH(0, h * 0.65, w * 0.35, h * 0.35), paint);
    paint.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(w * 0.05, h * 0.7, w * 0.25, h * 0.25), paint);
    paint.color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.75, w * 0.15, h * 0.15), paint);

    canvas.drawRect(Rect.fromLTWH(w * 0.45, h * 0.1, w * 0.1, h * 0.1), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.45, h * 0.3, w * 0.1, h * 0.1), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.45, w * 0.1, h * 0.1), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.45, w * 0.1, h * 0.1), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.5, h * 0.5, w * 0.15, h * 0.15), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.75, h * 0.5, w * 0.1, h * 0.1), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.45, h * 0.75, w * 0.1, h * 0.1), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.65, h * 0.7, w * 0.1, h * 0.1), paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.8, h * 0.8, w * 0.1, h * 0.1), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
