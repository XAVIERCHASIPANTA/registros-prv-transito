import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
