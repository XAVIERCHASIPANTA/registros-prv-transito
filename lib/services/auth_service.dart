import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'acceso_service.dart';
import 'terminos_service.dart';

/// Maneja el inicio de sesión con Google y el estado de aprobación del
/// usuario dentro de Firestore (colección "usuarios").
class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // IMPORTANTE: en web NUNCA se crea el objeto GoogleSignIn(), porque su
  // plugin intenta autoinicializarse apenas se instancia y truena con
  // "Null check operator used on a null value" si falta configuración
  // web adicional que aquí no usamos (usamos signInWithPopup en su lugar).
  final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn();

  User? get usuarioActual => _auth.currentUser;

  Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

  Future<User?> iniciarSesionConGoogle() async {
    if (kIsWeb) {
      // Flujo específico para Flutter Web
      final googleProvider = GoogleAuthProvider();
      final resultado = await _auth.signInWithPopup(googleProvider);
      return resultado.user;
    } else {
      // Flujo nativo para Android / iOS
      final cuentaGoogle = await _googleSignIn!.signIn();
      if (cuentaGoogle == null) return null; // el usuario canceló

      final auth = await cuentaGoogle.authentication;
      final credencial = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      final resultado = await _auth.signInWithCredential(credencial);
      return resultado.user;
    }
  }

  Future<void> cerrarSesion() async {
    AccesoService.reiniciar();
    TerminosService.aceptadoEnLogin = false;
    if (!kIsWeb) {
      await _googleSignIn?.signOut();
    }
    await _auth.signOut();
  }

  /// Devuelve el documento del usuario en Firestore, o null si es su
  /// primer inicio de sesión y todavía no existe.
  Future<Map<String, dynamic>?> obtenerPerfil(String uid) async {
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    return doc.data();
  }

  /// Crea el documento de usuario la primera vez, con el patio (PRV)
  /// que escribió y aprobado=false hasta que el administrador lo revise.
  ///
  /// NUEVO (30/ago): además del patio (obligatorio), se guardan los
  /// datos OPCIONALES de la estructura jerárquica institucional
  /// (Zona/Subzona/Distrito/Circuito/Subcircuito/Jefatura de
  /// Tránsito/Subjefatura de Tránsito) que se capturan una sola vez en
  /// identificacion_screen.dart. Cualquiera de estos que venga vacío
  /// simplemente se guarda como cadena vacía — no son obligatorios.
  Future<void> crearPerfil({
    required String uid,
    required String nombre,
    required String correo,
    required String patio,
    String zona = '',
    String subzona = '',
    String distrito = '',
    String circuito = '',
    String subcircuito = '',
    String jefaturaTransito = '',
    String subjefaturaTransito = '',
  }) async {
    await _firestore.collection('usuarios').doc(uid).set({
      'nombre': nombre,
      'correo': correo,
      'patio': patio,
      'zona': zona,
      'subzona': subzona,
      'distrito': distrito,
      'circuito': circuito,
      'subcircuito': subcircuito,
      'jefaturaTransito': jefaturaTransito,
      'subjefaturaTransito': subjefaturaTransito,
      'aprobado': false,
      'creado': FieldValue.serverTimestamp(),
      // Si la persona marcó la casilla de términos en el login, se guarda la
      // aceptación desde el primer momento.
      if (TerminosService.aceptadoEnLogin) ...{
        'terminosAceptados': true,
        'terminosVersion': TerminosService.version,
        'terminosFecha': FieldValue.serverTimestamp(),
      },
    });
  }

  /// Vuelve a consultar el perfil.
  Stream<DocumentSnapshot<Map<String, dynamic>>> observarPerfil(String uid) {
    return _firestore.collection('usuarios').doc(uid).snapshots();
  }
}
