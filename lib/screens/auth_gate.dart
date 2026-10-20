import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'identificacion_screen.dart';
import 'pendiente_screen.dart';
import 'home_screen.dart';
import 'terminos_screen.dart';
import '../services/acceso_service.dart';
import '../services/terminos_service.dart';

/// Controla el flujo de acceso: sin sesión -> Login; con sesión pero sin
/// perfil -> Identificación (pedir PRV); con perfil pero no aprobado ->
/// Pendiente; aprobado -> Home (la app de verdad).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().cambiosDeSesion,
      builder: (context, snapshotAuth) {
        if (snapshotAuth.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final usuario = snapshotAuth.data;
        if (usuario == null) return const LoginScreen();

        return StreamBuilder(
          stream: AuthService().observarPerfil(usuario.uid),
          builder: (context, snapshotPerfil) {
            if (snapshotPerfil.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final datos = snapshotPerfil.data?.data();
            if (datos == null) return IdentificacionScreen(usuario: usuario);

            // Cuenta bloqueada por un administrador.
            if (datos['bloqueado'] == true) return const _BloqueadoScreen();

            // Debe haber aceptado la versión vigente de los términos.
            if (datos['terminosVersion'] != TerminosService.version) {
              return TerminosScreen(uid: usuario.uid);
            }

            final aprobado = datos['aprobado'] == true;
            final Widget pantalla = aprobado
                ? const HomeScreen()
                : PendienteScreen(patio: datos['patio'] ?? '');

            // Registra (una vez por sesión) quién entró, desde qué IP y dispositivo.
            return _ConRegistroAcceso(
              uid: usuario.uid,
              nombre: (datos['nombre'] ?? usuario.displayName ?? '').toString(),
              correo: (datos['correo'] ?? usuario.email ?? '').toString(),
              patio: (datos['patio'] ?? '').toString(),
              zona: (datos['zona'] ?? '').toString(),
              child: pantalla,
            );
          },
        );
      },
    );
  }
}

/// Envuelve la pantalla principal y dispara el registro de acceso una sola vez.
class _ConRegistroAcceso extends StatefulWidget {
  final String uid, nombre, correo, patio, zona;
  final Widget child;
  const _ConRegistroAcceso({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.patio,
    required this.zona,
    required this.child,
  });

  @override
  State<_ConRegistroAcceso> createState() => _ConRegistroAccesoState();
}

class _ConRegistroAccesoState extends State<_ConRegistroAcceso> {
  @override
  void initState() {
    super.initState();
    AccesoService.registrarInicioSesion(
      uid: widget.uid,
      nombre: widget.nombre,
      correo: widget.correo,
      patio: widget.patio,
      zona: widget.zona,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BloqueadoScreen extends StatelessWidget {
  const _BloqueadoScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 72, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Acceso suspendido',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Un administrador suspendió el acceso de esta cuenta. '
                  'Comunícate con el administrador del sistema.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                  onPressed: () => AuthService().cerrarSesion(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
