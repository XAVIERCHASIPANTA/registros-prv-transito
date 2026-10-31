import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda la API key de Gemini.
///
/// La API key es GRATUITA: se obtiene en https://aistudio.google.com/apikey
/// con cualquier cuenta de Google, sin tarjeta de crédito, para el nivel
/// gratuito de Gemini.
///
/// IMPORTANTE (31/oct): antes la clave se guardaba SOLO en un archivo de texto
/// con path_provider. En la versión web/PWA eso no existe (lanza
/// MissingPluginException) y la pantalla de Ajustes se quedaba girando para
/// siempre. Ahora se guarda en SharedPreferences (funciona en web y Android);
/// en Android además se lee el archivo antiguo si ya había una clave guardada.
class ApiKeyService {
  static const _archivo = 'gemini_api_key.txt';
  static const _clavePrefs = 'gemini_api_key';

  Future<String?> obtenerApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardada = (prefs.getString(_clavePrefs) ?? '').trim();
      if (guardada.isNotEmpty) return guardada;
    } catch (_) {}

    if (kIsWeb) return null;
    try {
      // Compatibilidad: clave guardada por versiones anteriores en archivo.
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_archivo');
      if (!await file.exists()) return null;
      final contenido = (await file.readAsString()).trim();
      return contenido.isEmpty ? null : contenido;
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clavePrefs, apiKey.trim());
  }

  /// Comprueba la clave contra Google. Devuelve null si es válida, o un
  /// mensaje explicando el problema.
  Future<String?> verificarApiKey(String apiKey) async {
    try {
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?pageSize=1&key=${apiKey.trim()}');
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) return null;
      String detalle = '';
      try {
        detalle = (jsonDecode(r.body)['error']?['message'] ?? '').toString();
      } catch (_) {}
      if (r.statusCode == 400 || r.statusCode == 403) {
        return 'Google rechazó la clave. Revisa que esté copiada completa (empieza con "AIza"). $detalle';
      }
      return 'Google respondió ${r.statusCode}. $detalle';
    } catch (e) {
      return 'No se pudo comprobar la clave (¿sin internet?). Se guardó igual: $e';
    }
  }
}
