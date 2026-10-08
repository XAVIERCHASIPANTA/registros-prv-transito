// RUTA DE ARCHIVO: lib/screens/documento_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'home_screen.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import '../services/storage_service.dart';
import 'buscar_placa_screen.dart' show EstadoVehiculoIcon;
import 'formulario_screen.dart';
import 'formulario_libertad_screen.dart';
import 'captura_screen.dart';
import '../services/docx_builder.dart';

/// 02/sep: sello grande tipo "estampado" (rojo = todavía en el patio,
/// verde = ya liberado) — Xavier pidió aprovechar el espacio libre debajo
/// de cada caso encontrado para que el estado se note de un vistazo,
/// como un sello de goma. Reutilizable en cualquier pantalla que liste
/// ingresos/libertades.
///
/// 14/sep (ronda 22): vuelve a ser el ESTADO REAL del vehículo (no un
/// texto fijo por pantalla) — es justo lo que Xavier quiere: si busca una
/// placa (ya sea en "Ingresos guardados" o en "Buscar por placa") y el
/// vehículo YA tiene una Libertad registrada, el sello debe decir
/// "LIBERADO" en verde; si todavía no la tiene, debe decir "INGRESADO"
/// en rojo. El modo fijo `.ingresado()` de la ronda 21 quedó retirado
/// porque contradecía esto (siempre mostraba "INGRESADO" aunque el
/// vehículo ya hubiera salido).
enum _EstadoSello { ingresado, liberado }

class SelloEstadoGrande extends StatelessWidget {
  final _EstadoSello _estado;

  const SelloEstadoGrande({super.key, required bool liberado})
      : _estado = liberado ? _EstadoSello.liberado : _EstadoSello.ingresado;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String texto;
    late final IconData icono;
    switch (_estado) {
      case _EstadoSello.liberado:
        color = Colors.green.shade700;
        texto = 'LIBERADO';
        icono = Icons.check_circle_outline;
        break;
      case _EstadoSello.ingresado:
        color = Colors.red.shade700;
        texto = 'INGRESADO';
        icono = Icons.assignment_turned_in_outlined;
        break;
    }
    return Center(
      child: Transform.rotate(
        angle: -0.08,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: color, size: 26),
              const SizedBox(width: 8),
              Text(
                texto,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ya no existe un solo .docx con "todos los ingresos juntos" (eso era
/// de la arquitectura vieja). Ahora esta pantalla simplemente lista
/// todos los casos guardados de un tipo, y cada uno se comparte por
/// separado. El consolidado de TODOS los casos es el Excel (botón
/// "EXPORTAR MATRIZ COMPLETA" en la pantalla principal).
class DocumentoScreen extends StatefulWidget {
  final TipoParte tipo;
  const DocumentoScreen({super.key, required this.tipo});

  @override
  State<DocumentoScreen> createState() => _DocumentoScreenState();
}

class _DocumentoScreenState extends State<DocumentoScreen> {
  List<CasoIngreso> _ingresos = [];
  List<CasoLibertad> _libertades = [];
  bool _cargando = true;

  bool get _esIngreso => widget.tipo == TipoParte.ingreso;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    // 02/sep: ahora SIEMPRE se cargan ambas listas (antes solo se cargaba
    // una u otra según la pestaña) — se necesita cruzar ingresos con
    // libertades para saber el estado REAL de cada vehículo (antes el
    // ícono quedaba fijo en rojo aunque ya estuviera liberado).
    final ingresos = await StorageService.obtenerIngresos();
    ingresos.sort((a, b) => b.creado.compareTo(a.creado));
    final libertades = await StorageService.obtenerLibertades();
    libertades.sort((a, b) => b.creado.compareTo(a.creado));
    if (mounted) {
      setState(() {
        _ingresos = ingresos;
        _libertades = libertades;
        _cargando = false;
      });
    }
  }

  bool _yaTieneLibertad(CasoIngreso ingreso) {
    return _libertades.any((l) =>
        l.placa == ingreso.placa &&
        (ingreso.hojaIngresoNro.isEmpty || l.hojaIngresoNro == ingreso.hojaIngresoNro));
  }

  /// 13/sep (ronda 21): para poder editar una Libertad ya guardada hace
  /// falta su Ingreso de origen (FormularioLibertadScreen lo requiere).
  /// Puede dar null si el ingreso correspondiente ya no está en la
  /// lista local (caso raro); en ese caso simplemente no se muestra el
  /// botón de editar para esa tarjeta.
  CasoIngreso? _ingresoDe(CasoLibertad libertad) {
    for (final ingreso in _ingresos) {
      if (ingreso.placa == libertad.placa &&
          (libertad.hojaIngresoNro.isEmpty || ingreso.hojaIngresoNro == libertad.hojaIngresoNro)) {
        return ingreso;
      }
    }
    return null;
  }

  void _liberarVehiculo(CasoIngreso ingreso) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CapturaScreen(tipo: TipoParte.libertad, ingresoBase: ingreso),
      ),
    ).then((_) => _cargar());
  }

  Future<void> _compartirIngreso(CasoIngreso c) async {
    final bytes = StorageService.generarWordIngreso(c);
    final nombre = StorageService.obtenerNombreArchivoWord(placa: c.placa, esIngreso: true, hojaIngresoNro: c.hojaIngresoNro);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: nombre,
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    await Share.shareXFiles([xFile], text: 'Ingreso ${c.placa} - REGISTROS PRV TRANSITO');
  }

  Future<void> _compartirLibertad(CasoLibertad c) async {
    final bytes = StorageService.generarWordLibertad(c);
    final nombre = StorageService.obtenerNombreArchivoWord(placa: c.placa, esIngreso: false);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: nombre,
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    await Share.shareXFiles([xFile], text: 'Libertad ${c.placa} - REGISTROS PRV TRANSITO');
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _esIngreso ? 'Ingresos guardados' : 'Libertades guardadas';
    final total = _esIngreso ? _ingresos.length : _libertades.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          if (_esIngreso && _ingresos.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.visibility),
              tooltip: 'Vista Previa Máster',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => VistaPreviaMasterScreen(ingresos: _ingresos)));
              },
            ),
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: 'Descargar Matriz Máster (Word)',
              onPressed: () async {
                final bytes = await StorageService.generarWordMasterIngresos();
                final xFile = XFile.fromData(Uint8List.fromList(bytes), name: 'Master_Ingresos.docx', mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
                await Share.shareXFiles([xFile], text: 'MATRIZ MÁSTER DE HOJAS DE INGRESO');
              },
            ),
          ],
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : total == 0
              ? const Center(child: Text('Todavía no hay registros guardados'))
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: _esIngreso
                      ? _ingresos
                          .map((c) {
                            final tieneLibertad = _yaTieneLibertad(c);
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListTile(
                                    leading: EstadoVehiculoIcon(liberado: tieneLibertad),
                                    title: Text('${c.placa} — ${c.marca} ${c.color}'),
                                    subtitle: Text('Hoja ${c.hojaIngresoNro} — ${c.fechaIngreso}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.share_outlined),
                                          tooltip: 'Compartir / Descargar',
                                          onPressed: () => _compartirIngreso(c),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          tooltip: 'Editar',
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => FormularioIngresoScreen(caso: c, esEdicion: true),
                                            ),
                                          ).then((_) => _cargar()),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 02/sep: sello grande visible + botón "Liberar
                                  // vehículo" — Xavier pidió aprovechar el
                                  // espacio libre debajo de cada caso.
                                  // 14/sep (ronda 22): el sello ahora refleja el
                                  // estado REAL (tieneLibertad), no un texto fijo.
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                                    child: Column(
                                      children: [
                                        SelloEstadoGrande(liberado: tieneLibertad),
                                        if (!tieneLibertad) ...[
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: FilledButton.tonalIcon(
                                              icon: const Icon(Icons.logout),
                                              label: const Text('Liberar vehículo'),
                                              onPressed: () => _liberarVehiculo(c),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList()
                      : _libertades
                          .map((c) {
                            final ingresoOrigen = _ingresoDe(c);
                            return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ListTile(
                                      leading: const EstadoVehiculoIcon(liberado: true),
                                      title: Text('${c.placa} — ${c.marca} ${c.color}'),
                                      subtitle: Text('Hoja ${c.hojaIngresoNro} — Salida ${c.fechaSalida}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.share_outlined),
                                            tooltip: 'Compartir / Descargar',
                                            onPressed: () => _compartirLibertad(c),
                                          ),
                                          if (ingresoOrigen != null)
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              tooltip: 'Editar',
                                              onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => FormularioLibertadScreen(
                                                    ingreso: ingresoOrigen,
                                                    existente: c,
                                                  ),
                                                ),
                                              ).then((_) => _cargar()),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(12, 4, 12, 14),
                                      child: SelloEstadoGrande(liberado: true),
                                    ),
                                  ],
                                ),
                              );
                          })
                          .toList(),
                ),
    );
  }
}


class VistaPreviaMasterScreen extends StatelessWidget {
  final List<CasoIngreso> ingresos;
  const VistaPreviaMasterScreen({super.key, required this.ingresos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vista Previa Máster')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: ingresos.length,
        separatorBuilder: (_, __) => const Divider(height: 32, thickness: 2),
        itemBuilder: (context, index) {
          final c = ingresos[index];
          final textoNarrativo = DocxBuilder.generarTextoNarrativoIngreso(c);
          final textoBase = 'HOJA N° ${c.hojaIngresoNro}\n${textoNarrativo}';
          return SelectableText(
            textoBase,
            style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
          );
        },
      ),
    );
  }
}
