import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_acceso.dart';

/// Dashboard de productividad nacional: cuántos casos ha registrado
/// cada patio (CRV), con alerta si un patio lleva varios días sin
/// registrar ningún caso.
///
/// IMPORTANTE - Supuestos sobre la estructura de `casos_nacionales`
/// (ajusta la sección CAMPOS FIRESTORE si tus nombres reales difieren):
///   {
///     "patio": "Control 120 Santo Domingo de los Tsachilas",
///     "tipo": "ingreso" | "libertad",   // <- CONFIRMAR si existe este campo
///     "creado": Timestamp,
///     "placa": "ABC-1234",
///     ... resto de campos del caso ...
///   }
///
/// Si `casos_nacionales` NO tiene un campo que distinga ingreso de
/// libertad, deja `campoTipo` en null (abajo) y el dashboard mostrará
/// solo el total combinado por patio, sin desglose.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // ---------- CAMPOS FIRESTORE (ajustar aquí si difieren) ----------
  static const String coleccion = 'casos_nacionales';
  static const String campoPatio = 'patio';
  static const String? campoTipo = 'tipo'; // pon null si no existe
  static const String valorIngreso = 'ingreso';
  static const String valorLibertad = 'libertad';
  static const String campoFecha = 'creado';
  // -------------------------------------------------------------

  // Umbral de días sin actividad para marcar un patio como inactivo.
  static const int diasParaAlertaInactividad = 7;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _futureCasos;

  // NUEVO (30/ago): búsqueda por patio en el AppBar.
  bool _buscando = false;
  final _busquedaController = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _cargar() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(coleccion);
    // El administrador de zona solo puede consultar los casos de su zona.
    if (!AdminAcceso.esNacional) q = q.where('zona', isEqualTo: AdminAcceso.zona);
    _futureCasos = q.get().then((snap) => snap.docs);
  }

  Future<void> _refrescar() async {
    setState(_cargar);
    await _futureCasos;
  }

  void _alternarBusqueda() {
    setState(() {
      _buscando = !_buscando;
      if (!_buscando) {
        _busquedaController.clear();
        _filtro = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buscando
            ? TextField(
                controller: _busquedaController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar por patio...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                onChanged: (v) => setState(() => _filtro = v.trim().toLowerCase()),
              )
            : const Text('Productividad por CRV'),
        actions: [
          IconButton(
            icon: Icon(_buscando ? Icons.close : Icons.search),
            tooltip: _buscando ? 'Cerrar búsqueda' : 'Buscar por patio',
            onPressed: _alternarBusqueda,
          ),
          if (!_buscando)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: _refrescar,
            ),
        ],
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: _futureCasos,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!;
          if (docs.isEmpty) {
            return const Center(
              child: Text('Todavía no hay casos registrados a nivel nacional'),
            );
          }

          final resumen = _agruparPorPatio(docs);
          var lista = resumen.values.toList()
            ..sort((a, b) => b.total.compareTo(a.total));

          if (_filtro.isNotEmpty) {
            lista = lista.where((r) => r.patio.toLowerCase().contains(_filtro)).toList();
          }

          final totalNacional = lista.fold<int>(0, (s, r) => s + r.total);
          final patiosInactivos = lista.where((r) => r.inactivo).length;

          if (_filtro.isNotEmpty && lista.isEmpty) {
            return const Center(child: Text('Ningún patio coincide con esa búsqueda.'));
          }

          return RefreshIndicator(
            onRefresh: _refrescar,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_filtro.isEmpty)
                  _tarjetaResumenGeneral(
                    totalCasos: totalNacional,
                    totalPatios: lista.length,
                    patiosInactivos: patiosInactivos,
                  ),
                if (_filtro.isEmpty) const SizedBox(height: 16),
                const Text(
                  'Detalle por patio (ordenado de mayor a menor actividad)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...lista.map((r) => _tarjetaPatio(r)),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, _ResumenPatio> _agruparPorPatio(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, _ResumenPatio> resumen = {};
    final ahora = DateTime.now();

    for (final doc in docs) {
      final data = doc.data();
      final patio = (data[campoPatio] as String?)?.trim();
      if (patio == null || patio.isEmpty) continue;

      final r = resumen.putIfAbsent(patio, () => _ResumenPatio(patio));
      r.total++;

      if (campoTipo != null) {
        final tipo = data[campoTipo];
        if (tipo == valorIngreso) {
          r.ingresos++;
        } else if (tipo == valorLibertad) {
          r.libertades++;
        }
      }

      // "creado" se guarda como texto ISO; "actualizado" como Timestamp.
      final fecha = data['actualizado'] ?? data[campoFecha];
      DateTime? fechaCaso;
      if (fecha is Timestamp) {
        fechaCaso = fecha.toDate();
      } else if (fecha is String) {
        fechaCaso = DateTime.tryParse(fecha);
      }
      if (fechaCaso != null &&
          (r.ultimaActividad == null || fechaCaso.isAfter(r.ultimaActividad!))) {
        r.ultimaActividad = fechaCaso;
      }
    }

    for (final r in resumen.values) {
      if (r.ultimaActividad != null) {
        r.diasSinActividad = ahora.difference(r.ultimaActividad!).inDays;
        r.inactivo = r.diasSinActividad! >= diasParaAlertaInactividad;
      }
    }

    return resumen;
  }

  Widget _tarjetaResumenGeneral({
    required int totalCasos,
    required int totalPatios,
    required int patiosInactivos,
  }) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _estadistica('Casos totales', '$totalCasos'),
            _estadistica('Patios activos', '$totalPatios'),
            _estadistica(
              'Patios inactivos',
              '$patiosInactivos',
              alerta: patiosInactivos > 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadistica(String etiqueta, String valor, {bool alerta = false}) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: alerta ? Colors.red : null,
          ),
        ),
        Text(etiqueta, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _tarjetaPatio(_ResumenPatio r) {
    return Card(
      child: ListTile(
        title: Text(r.patio),
        subtitle: campoTipo != null
            ? Text('Ingresos: ${r.ingresos}   •   Libertades: ${r.libertades}')
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${r.total}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (r.inactivo)
              Text(
                'Sin actividad ${r.diasSinActividad} días',
                style: const TextStyle(color: Colors.red, fontSize: 11),
              )
            else if (r.ultimaActividad != null)
              const Text(
                'Activo',
                style: TextStyle(color: Colors.green, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResumenPatio {
  final String patio;
  int total = 0;
  int ingresos = 0;
  int libertades = 0;
  DateTime? ultimaActividad;
  int? diasSinActividad;
  bool inactivo = false;

  _ResumenPatio(this.patio);
}
