// RUTA DE ARCHIVO: lib/screens/admin_accesos_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/exportar_service.dart';
import 'admin_acceso.dart';

/// Registro de accesos: quién entró, cuándo, desde qué IP, dispositivo y
/// versión de la app. Se llena solo desde AccesoService en cada inicio de
/// sesión. Muestra los últimos 500 accesos.
class AdminAccesosScreen extends StatefulWidget {
  const AdminAccesosScreen({super.key});

  @override
  State<AdminAccesosScreen> createState() => _AdminAccesosScreenState();
}

class _AdminAccesosScreenState extends State<AdminAccesosScreen> {
  final _busquedaCtrl = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> get _consulta {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('registro_accesos');
    if (!AdminAcceso.esNacional) q = q.where('zona', isEqualTo: AdminAcceso.zona);
    // Con filtro de zona no se ordena en el servidor (evita pedir un índice);
    // se ordena aquí abajo.
    return AdminAcceso.esNacional ? q.orderBy('fecha', descending: true).limit(500) : q.limit(500);
  }

  static String _fmt(dynamic v) {
    if (v is Timestamp) {
      final f = v.toDate();
      String d2(int n) => n.toString().padLeft(2, '0');
      return '${d2(f.day)}/${d2(f.month)}/${f.year} ${d2(f.hour)}:${d2(f.minute)}';
    }
    return '';
  }

  Future<void> _exportar(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final filas = <List<String>>[
      ['FECHA', 'NOMBRE', 'CORREO', 'PATIO', 'ZONA', 'IP', 'PLATAFORMA', 'VERSION APP'],
      for (final d in docs)
        [
          _fmt(d.data()['fecha']),
          (d.data()['nombre'] ?? '').toString(),
          (d.data()['correo'] ?? '').toString(),
          (d.data()['patio'] ?? '').toString(),
          (d.data()['zona'] ?? '').toString(),
          (d.data()['ip'] ?? '').toString(),
          (d.data()['plataforma'] ?? '').toString(),
          (d.data()['appVersion'] ?? '').toString(),
        ],
    ];
    await ExportarService.entregar('PRV_registro_accesos.csv', ExportarService.generarCsv(filas));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de accesos')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _consulta.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs.where((d) {
            if (_filtro.isEmpty) return true;
            final x = d.data();
            return '${x['nombre']} ${x['correo']} ${x['patio']} ${x['ip']} ${x['zona']}'
                .toLowerCase()
                .contains(_filtro);
          }).toList()
            ..sort((a, b) {
              final ta = a.data()['fecha'], tb = b.data()['fecha'];
              if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
              return 0;
            });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _busquedaCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Nombre, correo, patio o IP...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _filtro = v.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('CSV'),
                      onPressed: docs.isEmpty ? null : () => _exportar(docs),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${docs.length} accesos (últimos 500)',
                      style: const TextStyle(color: Colors.black54)),
                ),
              ),
              Expanded(
                child: docs.isEmpty
                    ? const Center(child: Text('Todavía no hay accesos registrados'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final x = docs[i].data();
                          final ip = (x['ip'] ?? '').toString();
                          return Card(
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.login),
                              title: Text('${x['nombre'] ?? ''}  •  ${_fmt(x['fecha'])}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${x['correo'] ?? ''}\n'
                                'Patio: ${x['patio'] ?? '-'}   •   IP: ${ip.isEmpty ? 'no disponible' : ip}\n'
                                '${x['plataforma'] ?? '-'}   •   App ${x['appVersion'] ?? '-'}',
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
