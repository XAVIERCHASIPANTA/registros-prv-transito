import 'package:shared_preferences/shared_preferences.dart';

/// Guarda la API key de Gemini usando SharedPreferences (funciona en
/// web, Android e iOS sin depender de dart:io).
///
/// La API key es GRATUITA: se obtiene en https://aistudio.google.com/apikey
/// con cualquier cuenta de Google, sin tarjeta de crédito, para el nivel
/// gratuito de Gemini.
class ApiKeyService {
  static const _prefKey = 'gemini_api_key';

  Future<String?> obtenerApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final contenido = prefs.getString(_prefKey)?.trim();
    return (contenido == null || contenido.isEmpty) ? null : contenido;
  }

  Future<void> guardarApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, apiKey.trim());
  }
}
