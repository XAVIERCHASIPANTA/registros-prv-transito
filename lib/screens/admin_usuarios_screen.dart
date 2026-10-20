// RUTA DE ARCHIVO: lib/screens/admin_usuarios_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_acceso.dart';

/// Administración de usuarios: aprobar, bloquear, cambiar patio y rol, y ver
/// último acceso / IP / versión / aceptación de términos.
///
/// Campos reales del documento usuarios/{uid}: nombre, correo, patio, zona,
/// aprobado, bloqueado, esAdmin, rol ('admin_zona' o vacío), creado,
/// ultimoAcceso, ultimaIp, appVersion, plataforma, terminosVersion/Fecha.
class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  final _busquedaCtrl = TextEditingController();
  String _filtro = '';

  Query<Map<String, dynamic>> get _consulta {
    final col = FirebaseFirestore.instance.collection('usuarios');
    // El administrador de zona solo puede consultar usuarios de su zona.
    if (!AdminAcceso.esNacional) {
      return col.where('zona', isEqualTo: AdminAcceso.zona);
    }
    return col;
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _actualizar(String uid, Map<String, dynamic> cambios, String mensaje) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update(cambios);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool> _confirmar(String titulo, String texto, String boton) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(boton)),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _cambiarPatio(String uid, String actual) async {
    final ctrl = TextEditingController(text: actual);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar patio asignado'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Patio (CRV)',
            helperText: 'Escríbelo igual que aparece en los casos (ej. CONTROL 120).',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (nuevo != null && nuevo.isNotEmpty && nuevo != actual) {
      await _actualizar(uid, {'patio': nuevo}, 'Patio actualizado');
    }
  }

  Future<void> _cambiarRol(String uid, Map<String, dynamic> d) async {
    final zonaCtrl = TextEditingController(text: (d['zona'] ?? '').toString());
    String rol = d['esAdmin'] == true
        ? 'admin_nacional'
        : (d['rol'] == 'admin_zona' ? 'admin_zona' : 'operador');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Rol del usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: 'operador',
                groupValue: rol,
                title: const Text('Policía (operador)'),
                subtitle: const Text('Solo ve y registra casos de su patio'),
                onChanged: (v) => setSt(() => rol = v!),
              ),
              RadioListTile<String>(
                value: 'admin_zona',
                groupValue: rol,
                title: const Text('Administrador de zona'),
                subtitle: const Text('Ve los casos y usuarios de su zona'),
                onChanged: (v) => setSt(() => rol = v!),
              ),
              RadioListTile<String>(
                value: 'admin_nacional',
                groupValue: rol,
                title: const Text('Administrador nacional'),
                subtitle: const Text('Ve y gestiona TODO'),
                onChanged: (v) => setSt(() => rol = v!),
              ),
              if (rol == 'admin_zona')
                TextField(
                  controller: zonaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Zona',
                    helperText: 'Igual que en el perfil del usuario (ej. ZONA 4).',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (rol == 'admin_zona' && zonaCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indica la zona del administrador de zona.')),
        );
      }
      return;
    }
    await _actualizar(
      uid,
      {
        'esAdmin': rol == 'admin_nacional',
        'rol': rol == 'admin_zona' ? 'admin_zona' : '',
        if (rol == 'admin_zona') 'zona': zonaCtrl.text.trim(),
      },
      'Rol actualizado',
    );
  }

  String _fmt(dynamic v) {
    if (v is Timestamp) {
      final f = v.toDate();
      String d2(int n) => n.toString().padLeft(2, '0');
      return '${d2(f.day)}/${d2(f.month)}/${f.year} ${d2(f.hour)}:${d2(f.minute)}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Usuarios'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pendientes'),
              Tab(text: 'Aprobados'),
              Tab(text: 'Bloqueados'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                controller: _busquedaCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por nombre, correo o patio...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filtro = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _consulta.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final todos = snap.data!.docs.where((d) {
                    if (_filtro.isEmpty) return true;
                    final x = d.data();
                    final texto = '${x['nombre']} ${x['correo']} ${x['patio']} ${x['zona']}'.toLowerCase();
                    return texto.contains(_filtro);
                  }).toList()
                    ..sort((a, b) {
                      final ta = a.data()['creado'];
                      final tb = b.data()['creado'];
                      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
                      return 0;
                    });

                  bool bloq(d) => d.data()['bloqueado'] == true;
                  bool apro(d) => d.data()['aprobado'] == true && !bloq(d);
                  final pendientes = todos.where((d) => !apro(d) && !bloq(d)).toList();
                  final aprobados = todos.where(apro).toList();
                  final bloqueados = todos.where(bloq).toList();

                  return TabBarView(
                    children: [
                      _lista(pendientes, 'No hay usuarios pendientes', _accionesPendiente),
                      _lista(aprobados, 'Todavía no hay usuarios aprobados', _accionesAprobado),
                      _lista(bloqueados, 'No hay usuarios bloqueados', _accionesBloqueado),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String vacio,
    List<Widget> Function(QueryDocumentSnapshot<Map<String, dynamic>>) acciones,
  ) {
    if (docs.isEmpty) return Center(child: Text(vacio));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final doc = docs[i];
        final d = doc.data();
        final esAdmin = d['esAdmin'] == true;
        final rolTxt = esAdmin
            ? 'Admin nacional'
            : (d['rol'] == 'admin_zona' ? 'Admin de zona' : 'Policía');
        final acepto = d['terminosVersion'] != null;
        final ultimo = _fmt(d['ultimoAcceso']);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (d['nombre'] ?? '(sin nombre)').toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    Chip(
                      label: Text(rolTxt, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                Text((d['correo'] ?? '').toString(), style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 6),
                Text('Patio: ${d['patio'] ?? '-'}   •   Zona: ${(d['zona'] ?? '').toString().isEmpty ? '-' : d['zona']}'),
                Text('Registrado: ${_fmt(d['creado'])}'),
                Text(
                  'Último acceso: ${ultimo.isEmpty ? 'sin registro' : ultimo}'
                  '${(d['ultimaIp'] ?? '').toString().isNotEmpty ? '   •   IP: ${d['ultimaIp']}' : ''}',
                ),
                Text(
                  'App: ${d['appVersion'] ?? '-'} (${d['plataforma'] ?? '-'})   •   '
                  'Términos: ${acepto ? 'aceptados' : 'NO aceptados'}',
                  style: TextStyle(color: acepto ? Colors.black87 : Colors.orange.shade800),
                ),
                const SizedBox(height: 4),
                Wrap(spacing: 4, children: acciones(doc)),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _accionesPendiente(QueryDocumentSnapshot<Map<String, dynamic>> doc) => [
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Aprobar'),
          onPressed: () => _actualizar(doc.id, {'aprobado': true, 'bloqueado': false}, 'Usuario aprobado'),
        ),
        TextButton.icon(
          icon: const Icon(Icons.edit_location_alt),
          label: const Text('Patio'),
          onPressed: () => _cambiarPatio(doc.id, (doc.data()['patio'] ?? '').toString()),
        ),
        TextButton.icon(
          icon: const Icon(Icons.block, color: Colors.red),
          label: const Text('Bloquear'),
          onPressed: () async {
            if (await _confirmar('Bloquear usuario', 'No podrá entrar a la app hasta que lo desbloquees.', 'Bloquear')) {
              await _actualizar(doc.id, {'aprobado': false, 'bloqueado': true}, 'Usuario bloqueado');
            }
          },
        ),
      ];

  List<Widget> _accionesAprobado(QueryDocumentSnapshot<Map<String, dynamic>> doc) => [
        TextButton.icon(
          icon: const Icon(Icons.edit_location_alt),
          label: const Text('Patio'),
          onPressed: () => _cambiarPatio(doc.id, (doc.data()['patio'] ?? '').toString()),
        ),
        if (AdminAcceso.esNacional)
          TextButton.icon(
            icon: const Icon(Icons.admin_panel_settings),
            label: const Text('Rol'),
            onPressed: () => _cambiarRol(doc.id, doc.data()),
          ),
        TextButton.icon(
          icon: const Icon(Icons.block, color: Colors.red),
          label: const Text('Bloquear'),
          onPressed: () async {
            if (await _confirmar('Bloquear usuario', 'Dejará de poder entrar a la app inmediatamente.', 'Bloquear')) {
              await _actualizar(doc.id, {'aprobado': false, 'bloqueado': true}, 'Usuario bloqueado');
            }
          },
        ),
      ];

  List<Widget> _accionesBloqueado(QueryDocumentSnapshot<Map<String, dynamic>> doc) => [
        FilledButton.icon(
          icon: const Icon(Icons.lock_open),
          label: const Text('Desbloquear y aprobar'),
          onPressed: () => _actualizar(doc.id, {'aprobado': true, 'bloqueado': false}, 'Usuario desbloqueado'),
        ),
      ];
}
