// RUTA DE ARCHIVO: lib/screens/admin_casos_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/exportar_service.dart';
import 'admin_acceso.dart';

enum ModoCasos { todos, liberados, retenidos }

/// Base de datos maestra: todos los ingresos y libertades de todos los patios
/// (el administrador de zona solo ve su zona). Permite filtrar, buscar una
/// placa en todos los centros y exportar lo filtrado a Excel o CSV.
class AdminCasosScreen extends StatefulWidget {
  final ModoCasos modo;
  const AdminCasosScreen({super.key, this.modo = ModoCasos.todos});

  @override
  State<AdminCasosScreen> createState() => _AdminCasosScreenState();
}

class _Fila {
  final Map<String, dynamic> d;
  final bool esIngreso;
  Map<String, dynamic>? libertad; // libertad asociada (solo para ingresos)
  bool liberado;
  DateTime? fecha; // fecha del evento (ingreso o salida)
  int? dias; // días de permanencia

  _Fila(this.d, this.esIngreso, {this.liberado = false});

  String s(String k) => (d[k] ?? '').toString();
  String get placa => s('placa').toUpperCase();
  String get patio => s('patio');
  String get zona => s('zona');
}

class _AdminCasosScreenState extends State<AdminCasosScreen> {
  bool _cargando = true;
  String? _error;
  List<_Fila> _todas = [];

  final _busquedaCtrl = TextEditingController();
  String _texto = '';
  String _patio = '';
  String _zona = '';
  String _estado = 'todos'; // todos | retenidos | liberados (solo modo todos)
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  static DateTime? _parseFecha(String t) {
    final v = t.trim();
    if (v.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})').firstMatch(v);
    if (m != null) {
      return DateTime.tryParse(
          '${m.group(3)}-${m.group(2)!.padLeft(2, '0')}-${m.group(1)!.padLeft(2, '0')}');
    }
    return DateTime.tryParse(v);
  }

  static String _fmt(DateTime? f) {
    if (f == null) return '';
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(f.day)}/${d2(f.month)}/${f.year}';
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('casos_nacionales');
      // El admin de zona SOLO puede consultar su zona (lo exigen las reglas).
      if (!AdminAcceso.esNacional) q = q.where('zona', isEqualTo: AdminAcceso.zona);
      final snap = await q.get();

      final ingresos = <_Fila>[];
      final libertades = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['tipo'] == 'libertad') {
          libertades.add(d);
        } else {
          ingresos.add(_Fila(d, true));
        }
      }

      final usadas = <Map<String, dynamic>>{};
      for (final ing in ingresos) {
        final placa = ing.placa;
        final hoja = ing.s('hojaIngresoNro').trim();
        for (final l in libertades) {
          final lp = (l['placa'] ?? '').toString().toUpperCase();
          final lh = (l['hojaIngresoNro'] ?? '').toString().trim();
          if (lp == placa && (hoja.isEmpty || lh == hoja)) {
            ing.libertad = l;
            ing.liberado = true;
            usadas.add(l);
            break;
          }
        }
        ing.fecha = _parseFecha(ing.s('fechaIngreso')) ?? _parseFecha(ing.s('creado'));
        final fin = ing.liberado
            ? _parseFecha((ing.libertad!['fechaSalida'] ?? '').toString())
            : DateTime.now();
        if (ing.fecha != null && fin != null) {
          ing.dias = fin.difference(ing.fecha!).inDays;
        }
      }

      final filas = <_Fila>[...ingresos];
      // Libertades sin ingreso asociado en la base (casos importados, etc.).
      for (final l in libertades) {
        if (usadas.contains(l)) continue;
        final f = _Fila(l, false, liberado: true);
        f.fecha = _parseFecha((l['fechaSalida'] ?? '').toString()) ??
            _parseFecha((l['creado'] ?? '').toString());
        final dp = int.tryParse((l['diasPermanencia'] ?? '').toString());
        f.dias = dp;
        filas.add(f);
      }

      filas.sort((a, b) {
        final fa = a.fecha, fb = b.fecha;
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fb.compareTo(fa);
      });

      if (!mounted) return;
      setState(() {
        _todas = filas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  List<_Fila> get _filtradas {
    final t = _texto.toLowerCase();
    return _todas.where((f) {
      // Modo de la pantalla.
      if (widget.modo == ModoCasos.liberados && !f.liberado) return false;
      if (widget.modo == ModoCasos.retenidos && f.liberado) return false;
      if (widget.modo == ModoCasos.todos) {
        if (_estado == 'retenidos' && f.liberado) return false;
        if (_estado == 'liberados' && !f.liberado) return false;
      }
      if (_patio.isNotEmpty && f.patio != _patio) return false;
      if (_zona.isNotEmpty && f.zona != _zona) return false;
      if (_desde != null && (f.fecha == null || f.fecha!.isBefore(_desde!))) return false;
      if (_hasta != null &&
          (f.fecha == null || f.fecha!.isAfter(_hasta!.add(const Duration(days: 1))))) {
        return false;
      }
      if (t.isNotEmpty) {
        final base = '${f.placa} ${f.s('marca')} ${f.s('color')} ${f.s('propietario')} '
                '${f.s('conductor')} ${f.s('hojaIngresoNro')} ${f.s('parteIngresoNro')} '
                '${f.s('chasis')} ${f.s('motor')} ${f.s('retiradoPor')} ${f.patio}'
            .toLowerCase();
        if (!base.contains(t)) return false;
      }
      return true;
    }).toList();
  }

  String get _titulo {
    switch (widget.modo) {
      case ModoCasos.liberados:
        return 'Placas liberadas';
      case ModoCasos.retenidos:
        return 'Vehículos retenidos';
      case ModoCasos.todos:
        return 'Base de datos maestra';
    }
  }

  // ----------------------------- Exportación -------------------------------

  /// Columnas = unión de las claves de los casos, con las más usadas primero.
  List<String> _columnas(Iterable<Map<String, dynamic>> datos, List<String> primeras) {
    final todas = <String>{};
    for (final d in datos) {
      todas.addAll(d.keys);
    }
    todas.remove('actualizado');
    final orden = <String>[
      ...primeras.where(todas.contains),
      ...(todas.where((k) => !primeras.contains(k)).toList()..sort()),
    ];
    return orden;
  }

  Future<void> _exportar(bool xlsx) async {
    final filas = _filtradas;
    if (filas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar con estos filtros.')),
      );
      return;
    }
    try {
      final ingresos = filas.where((f) => f.esIngreso).toList();
      final libertades = <Map<String, dynamic>>[
        for (final f in filas)
          if (f.esIngreso && f.libertad != null) f.libertad!,
        for (final f in filas)
          if (!f.esIngreso) f.d,
      ];

      const primIng = [
        'patio', 'zona', 'placa', 'marca', 'modelo', 'color', 'tipoVehiculo', 'anioFabricacion',
        'chasis', 'motor', 'hojaIngresoNro', 'parteIngresoNro', 'fechaIngreso', 'horaRetencion',
        'propietario', 'cedulaPropietario', 'conductor', 'cedulaConductor', 'causaLegal',
        'detalleCausa',
      ];
      const primLib = [
        'patio', 'zona', 'placa', 'marca', 'color', 'hojaIngresoNro', 'parteIngresoNro',
        'fechaIngreso', 'fechaSalida', 'diasPermanencia', 'memorandoNro', 'memorandoFecha',
        'oficioDevolucionNro', 'oficioDevolucionFecha', 'firmadoPor', 'retiradoPor',
        'cedulaRetira', 'pagos',
      ];

      final colIng = _columnas(ingresos.map((f) => f.d), primIng);
      final colLib = _columnas(libertades, primLib);

      final hojaIng = <List<String>>[
        [...colIng, 'ESTADO', 'FECHA SALIDA', 'DIAS PERMANENCIA'],
        for (final f in ingresos)
          [
            ...colIng.map((k) => ExportarService.texto(f.d[k])),
            f.liberado ? 'LIBERADO' : 'RETENIDO',
            f.liberado ? (f.libertad?['fechaSalida'] ?? '').toString() : '',
            f.dias?.toString() ?? '',
          ],
      ];
      final hojaLib = <List<String>>[
        colLib,
        for (final l in libertades) colLib.map((k) => ExportarService.texto(l[k])).toList(),
      ];

      final marca = DateTime.now();
      String d2(int n) => n.toString().padLeft(2, '0');
      final sello = '${marca.year}${d2(marca.month)}${d2(marca.day)}_${d2(marca.hour)}${d2(marca.minute)}';
      final base = 'PRV_${_titulo.replaceAll(' ', '_')}_$sello';

      if (xlsx) {
        final bytes = ExportarService.generarXlsx({
          'INGRESOS': hojaIng,
          'LIBERTADES': hojaLib,
        });
        await ExportarService.entregar('$base.xlsx', bytes);
      } else {
        // CSV: una sola tabla con los ingresos y su estado.
        await ExportarService.entregar('$base.csv', ExportarService.generarCsv(hojaIng));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportados ${filas.length} registros.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo exportar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Los casos guardados antes de esta versión no tienen el campo "zona".
  /// Esto se lo agrega tomándolo del perfil de los usuarios de cada patio.
  Future<void> _completarZonas() async {
    try {
      final db = FirebaseFirestore.instance;
      final usuarios = await db.collection('usuarios').get();
      final zonaDePatio = <String, String>{};
      for (final u in usuarios.docs) {
        final p = (u.data()['patio'] ?? '').toString();
        final z = (u.data()['zona'] ?? '').toString();
        if (p.isNotEmpty && z.isNotEmpty) zonaDePatio[p] = z;
      }
      final casos = await db.collection('casos_nacionales').get();
      var lote = db.batch();
      var enLote = 0;
      var total = 0;
      for (final c in casos.docs) {
        final d = c.data();
        if ((d['zona'] ?? '').toString().isNotEmpty) continue;
        final z = zonaDePatio[(d['patio'] ?? '').toString()];
        if (z == null) continue;
        lote.update(c.reference, {'zona': z});
        enLote++;
        total++;
        if (enLote >= 400) {
          await lote.commit();
          lote = db.batch();
          enLote = 0;
        }
      }
      if (enLote > 0) await lote.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zona completada en $total casos.')),
        );
      }
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --------------------------------- UI ------------------------------------

  Future<void> _elegirFecha(bool desde) async {
    final r = await showDatePicker(
      context: context,
      initialDate: (desde ? _desde : _hasta) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (r != null) setState(() => desde ? _desde = r : _hasta = r);
  }

  void _verDetalle(_Fila f) {
    final claves = f.d.keys.where((k) => k != 'actualizado').toList()..sort();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${f.placa} — ${f.liberado ? 'LIBERADO' : 'RETENIDO'}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.esIngreso ? 'DATOS DEL INGRESO' : 'DATOS DE LA LIBERTAD',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                for (final k in claves)
                  if (ExportarService.texto(f.d[k]).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SelectableText('$k: ${ExportarService.texto(f.d[k])}',
                          style: const TextStyle(fontSize: 13)),
                    ),
                if (f.libertad != null) ...[
                  const Divider(),
                  const Text('DATOS DE LA LIBERTAD', style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final k in (f.libertad!.keys.where((k) => k != 'actualizado').toList()..sort()))
                    if (ExportarService.texto(f.libertad![k]).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: SelectableText('$k: ${ExportarService.texto(f.libertad![k])}',
                            style: const TextStyle(fontSize: 13)),
                      ),
                ],
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  Widget _filtros(List<String> patios, List<String> zonas) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _busquedaCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Placa, marca, nombre, hoja, chasis...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _texto = v.trim()),
            ),
          ),
          if (AdminAcceso.esNacional && zonas.isNotEmpty)
            _desplegable('Zona', _zona, zonas, (v) => setState(() => _zona = v)),
          _desplegable('Patio', _patio, patios, (v) => setState(() => _patio = v)),
          if (widget.modo == ModoCasos.todos)
            DropdownButton<String>(
              value: _estado,
              items: const [
                DropdownMenuItem(value: 'todos', child: Text('Todos los estados')),
                DropdownMenuItem(value: 'retenidos', child: Text('Retenidos')),
                DropdownMenuItem(value: 'liberados', child: Text('Liberados')),
              ],
              onChanged: (v) => setState(() => _estado = v ?? 'todos'),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(_desde == null ? 'Desde' : 'Desde ${_fmt(_desde)}'),
            onPressed: () => _elegirFecha(true),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(_hasta == null ? 'Hasta' : 'Hasta ${_fmt(_hasta)}'),
            onPressed: () => _elegirFecha(false),
          ),
          TextButton(
            onPressed: () => setState(() {
              _busquedaCtrl.clear();
              _texto = '';
              _patio = '';
              _zona = '';
              _estado = 'todos';
              _desde = null;
              _hasta = null;
            }),
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }

  Widget _desplegable(String etiqueta, String valor, List<String> opciones, void Function(String) cambio) {
    return DropdownButton<String>(
      value: opciones.contains(valor) ? valor : '',
      items: [
        DropdownMenuItem(value: '', child: Text('$etiqueta: todos')),
        for (final o in opciones) DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => cambio(v ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patios = (_todas.map((f) => f.patio).where((p) => p.isNotEmpty).toSet().toList())..sort();
    final zonas = (_todas.map((f) => f.zona).where((z) => z.isNotEmpty).toSet().toList())..sort();
    final filas = _cargando ? <_Fila>[] : _filtradas;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _cargar),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar lo filtrado',
            onSelected: (v) {
              if (v == 'xlsx') _exportar(true);
              if (v == 'csv') _exportar(false);
              if (v == 'zonas') _completarZonas();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'xlsx', child: Text('Exportar a Excel (.xlsx)')),
              const PopupMenuItem(value: 'csv', child: Text('Exportar a CSV')),
              if (AdminAcceso.esNacional)
                const PopupMenuItem(value: 'zonas', child: Text('Completar zona en casos antiguos')),
            ],
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No se pudo cargar la base de datos:\n$_error', textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    _filtros(patios, zonas),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${filas.length} registros (de ${_todas.length})',
                            style: const TextStyle(color: Colors.black54)),
                      ),
                    ),
                    Expanded(
                      child: filas.isEmpty
                          ? const Center(child: Text('Sin resultados'))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                              itemCount: filas.length,
                              itemBuilder: (context, i) {
                                final f = filas[i];
                                final color = f.liberado ? Colors.green.shade700 : Colors.red.shade700;
                                final salida = f.libertad != null
                                    ? (f.libertad!['fechaSalida'] ?? '').toString()
                                    : (f.esIngreso ? '' : f.s('fechaSalida'));
                                return Card(
                                  child: ListTile(
                                    onTap: () => _verDetalle(f),
                                    leading: Icon(
                                      f.liberado ? Icons.check_circle : Icons.directions_car,
                                      color: color,
                                    ),
                                    title: Text(
                                      '${f.placa}  —  ${f.s('marca')} ${f.s('color')}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '${f.patio}${f.zona.isEmpty ? '' : '  •  ${f.zona}'}\n'
                                      'Ingreso: ${f.esIngreso ? f.s('fechaIngreso') : f.s('fechaIngreso')}'
                                      '${salida.isEmpty ? '' : '   •   Salida: $salida'}'
                                      '${f.dias != null ? '   •   ${f.dias} días' : ''}',
                                    ),
                                    isThreeLine: true,
                                    trailing: Text(
                                      f.liberado ? 'LIBERADO' : 'RETENIDO',
                                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
