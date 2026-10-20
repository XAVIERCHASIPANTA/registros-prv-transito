// RUTA DE ARCHIVO: lib/screens/admin_acceso.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Rol del administrador que tiene la sesión abierta.
///  - Administrador nacional: usuarios/{uid}.esAdmin == true  -> ve todo.
///  - Administrador de zona : usuarios/{uid}.rol == 'admin_zona' (+ aprobado
///    y campo "zona")                                        -> solo su zona.
/// Las reglas de Firestore (firestore.rules) hacen cumplir esto en el servidor;
/// aquí solo se adapta la pantalla.
class AdminAcceso {
  static bool esNacional = false;
  static bool esZona = false;
  static String zona = '';
  static String nombre = '';

  static bool get esAdmin => esNacional || esZona;

  static String get etiqueta =>
      esNacional ? 'Administrador nacional' : 'Administrador de zona $zona';

  /// Lee el perfil de la sesión actual. Devuelve true si es administrador.
  static Future<bool> cargar() async {
    esNacional = false;
    esZona = false;
    zona = '';
    nombre = '';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    return aplicar(doc.data());
  }

  static bool aplicar(Map<String, dynamic>? d) {
    esNacional = d?['esAdmin'] == true;
    esZona = !esNacional &&
        d?['rol'] == 'admin_zona' &&
        d?['aprobado'] == true &&
        (d?['zona'] ?? '').toString().isNotEmpty;
    zona = esZona ? (d?['zona'] ?? '').toString() : '';
    nombre = (d?['nombre'] ?? '').toString();
    return esAdmin;
  }
}
