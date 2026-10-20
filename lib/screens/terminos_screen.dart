// RUTA DE ARCHIVO: lib/screens/terminos_screen.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/terminos_service.dart';

/// Muestra el texto completo de los términos. Se usa de dos formas:
///  - Como pantalla obligatoria (uid != null) cuando el usuario aún no aceptó
///    la versión vigente: debe aceptar o cerrar sesión.
///  - Solo lectura (uid == null), desde el enlace de la pantalla de login.
class TerminosScreen extends StatefulWidget {
  final String? uid;
  const TerminosScreen({super.key, this.uid});

  @override
  State<TerminosScreen> createState() => _TerminosScreenState();
}

class _TerminosScreenState extends State<TerminosScreen> {
  bool _acepto = false;
  bool _guardando = false;
  String? _error;

  Future<void> _aceptar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await TerminosService.registrarAceptacion(widget.uid!);
      // El AuthGate se actualiza solo al cambiar el perfil.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo guardar la aceptación: $e';
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final soloLectura = widget.uid == null;
    return Scaffold(
      appBar: AppBar(title: const Text(TerminosService.titulo)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(
                  TerminosService.texto,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ),
            if (!soloLectura)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      value: _acepto,
                      onChanged: _guardando ? null : (v) => setState(() => _acepto = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'He leído y acepto los términos y condiciones, incluido el registro de mi dirección IP y actividad.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _guardando ? null : () => AuthService().cerrarSesion(),
                            child: const Text('No acepto (salir)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: (_acepto && !_guardando) ? _aceptar : null,
                            child: Text(_guardando ? 'Guardando...' : 'Aceptar y continuar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
