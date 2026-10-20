// RUTA DE ARCHIVO: lib/services/acceso_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:http/http.dart' as http;
import '../version.dart';

/// Registra cada inicio de sesión (quién, desde qué IP, desde qué dispositivo)
/// en la colección "registro_accesos" y actualiza el "último acceso" del
/// usuario. Solo los administradores pueden leer ese registro.
///
/// NOTA SOBRE LA IP: aquí la IP la reporta el propio dispositivo (consultando
/// un servicio público de IP). Sirve para auditoría, pero un usuario avanzado
/// podría alterarla. La IP "oficial" a prueba de manipulación se obtiene con
/// una Cloud Function (requiere plan Blaze) — previsto para la Fase 2.
class AccesoService {
  /// Pon en false para dejar de consultar la IP (se guardaría solo el resto).
  static const bool consultarIp = true;

  static bool _registrado = false;

  static void reiniciar() => _registrado = false;

  static String get plataforma => kIsWeb ? 'web' : defaultTargetPlatform.name;

  static Future<String> _obtenerIp() async {
    if (!consultarIp) return '';
    try {
      final r = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final ip = (jsonDecode(r.body) as Map)['ip']?.toString() ?? '';
        return ip;
      }
    } catch (_) {}
    return '';
  }

  /// Se llama una vez por sesión de la app. Nunca lanza errores.
  static Future<void> registrarInicioSesion({
    required String uid,
    required String nombre,
    required String correo,
    required String patio,
    required String zona,
  }) async {
    if (_registrado) return;
    _registrado = true;
    try {
      final ip = await _obtenerIp();
      final db = FirebaseFirestore.instance;
      await db.collection('registro_accesos').add({
        'uid': uid,
        'nombre': nombre,
        'correo': correo,
        'patio': patio,
        'zona': zona,
        'ip': ip,
        'ipFuente': ip.isEmpty ? '' : 'cliente',
        'plataforma': plataforma,
        'appVersion': appVersion,
        'evento': 'inicio_sesion',
        'fecha': FieldValue.serverTimestamp(),
      });
      await db.collection('usuarios').doc(uid).update({
        'ultimoAcceso': FieldValue.serverTimestamp(),
        'ultimaIp': ip,
        'appVersion': appVersion,
        'plataforma': plataforma,
      });
    } catch (_) {
      // El registro es "mejor esfuerzo": jamás debe impedir usar la app.
    }
  }
}
