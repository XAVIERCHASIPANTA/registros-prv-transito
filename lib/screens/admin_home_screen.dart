// RUTA DE ARCHIVO: lib/screens/admin_home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'admin_acceso.dart';
import 'admin_accesos_screen.dart';
import 'admin_casos_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';
import 'admin_usuarios_screen.dart';

/// Home del panel de administrador. Se llega aquí desde el login de /admin
/// o desde el ícono de administrador de la app (solo si el usuario es admin).
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    await AuthService().cerrarSesion();
    AdminAcceso.aplicar(null);
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminAcceso.cargar(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Panel Nacional')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Esta cuenta no tiene permisos de administrador.',
                    textAlign: TextAlign.center),
              ),
            ),
          );
        }
        return _contenido(context);
      },
    );
  }

  Widget _contenido(BuildContext context) {
    final correo = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Nacional'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${AdminAcceso.etiqueta}  •  $correo',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              _botonGrande(
                context,
                icon: Icons.storage,
                titulo: 'Base de datos maestra',
                subtitulo: 'Todos los ingresos y libertades: filtrar, buscar y exportar a Excel/CSV',
                color: Colors.indigo.shade700,
                destino: const AdminCasosScreen(modo: ModoCasos.todos),
              ),
              const SizedBox(height: 14),
              _botonGrande(
                context,
                icon: Icons.assignment_turned_in,
                titulo: 'Placas liberadas',
                subtitulo: 'Vehículos con libertad registrada en cualquier patio',
                color: Colors.green.shade700,
                destino: const AdminCasosScreen(modo: ModoCasos.liberados),
              ),
              const SizedBox(height: 14),
              _botonGrande(
                context,
                icon: Icons.directions_car,
                titulo: 'Vehículos retenidos',
                subtitulo: 'Ingresos que todavía no tienen libertad (con días de permanencia)',
                color: Colors.red.shade700,
                destino: const AdminCasosScreen(modo: ModoCasos.retenidos),
              ),
              const SizedBox(height: 14),
              _botonGrande(
                context,
                icon: Icons.people,
                titulo: 'Usuarios',
                subtitulo: 'Aprobar, bloquear, cambiar patio y rol; ver último acceso e IP',
                color: Colors.blue.shade700,
                destino: const AdminUsuariosScreen(),
              ),
              if (AdminAcceso.esNacional) ...[
                const SizedBox(height: 14),
                _botonGrande(
                  context,
                  icon: Icons.history,
                  titulo: 'Registro de accesos',
                  subtitulo: 'Quién entró, cuándo, desde qué IP, dispositivo y versión',
                  color: Colors.deepPurple.shade600,
                  destino: const AdminAccesosScreen(),
                ),
              ],
              const SizedBox(height: 14),
              _botonGrande(
                context,
                icon: Icons.bar_chart,
                titulo: 'Dashboard',
                subtitulo: 'Productividad por CRV / patio',
                color: Colors.teal.shade700,
                destino: const AdminDashboardScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonGrande(
    BuildContext context, {
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required Color color,
    required Widget destino,
  }) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destino)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitulo, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
