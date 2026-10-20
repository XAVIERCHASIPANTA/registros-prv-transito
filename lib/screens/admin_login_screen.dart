import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_acceso.dart';
import 'admin_home_screen.dart';

/// Login exclusivo de administrador. Se llega aquí solo por la ruta
/// "/admin" (ver instrucciones para main.dart), NUNCA desde el flujo
/// normal de los policías.
///
/// Usa correo + contraseña (no Google) para que sea un acceso
/// claramente distinto del login normal. Requiere que en Firebase
/// Authentication esté habilitado el proveedor "Correo electrónico/
/// Contraseña" (ver pasos aparte).
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;

  Future<void> _iniciarSesion() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      final uid = cred.user!.uid;
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = 'No existe documento en "usuarios" para el UID $uid.';
        });
        return;
      }

      final esAdmin = AdminAcceso.aplicar(doc.data());
      if (!esAdmin) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = 'Esta cuenta no tiene permisos de administrador.';
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'user-not-found' => 'No existe una cuenta con ese correo.',
          'wrong-password' => 'Contraseña incorrecta.',
          'invalid-credential' => 'Correo o contraseña incorrectos.',
          _ => e.message ?? 'Error al iniciar sesión.',
        };
      });
    } catch (e) {
      setState(() {
        _error = 'Error inesperado: $e';
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _olvideContrasena() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = 'Escribe tu correo arriba primero, luego toca "¿Olvidaste tu contraseña?".';
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Correo enviado'),
          content: Text(
            'Te enviamos un enlace a $email para crear tu contraseña. '
            'Ábrelo, define tu contraseña, y luego vuelve aquí a ingresar con '
            'ese correo y la contraseña que elegiste.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'user-not-found' => 'No existe una cuenta con ese correo.',
          _ => e.message ?? 'No se pudo enviar el correo.',
        };
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2B4E),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings, size: 56),
                  const SizedBox(height: 8),
                  const Text(
                    'Panel Nacional',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Acceso exclusivo de administrador',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    onSubmitted: (_) => _iniciarSesion(),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _iniciarSesion,
                      child: _cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Ingresar'),
                    ),
                  ),
                  TextButton(
                    onPressed: _cargando ? null : _olvideContrasena,
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
