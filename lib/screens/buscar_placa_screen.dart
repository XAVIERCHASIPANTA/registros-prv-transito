// RUTA DE ARCHIVO: lib/screens/buscar_placa_screen.dart

import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import 'formulario_screen.dart';
import 'formulario_libertad_screen.dart';
import 'captura_screen.dart';
import 'home_screen.dart' show TipoParte;
import 'documento_screen.dart' show SelloEstadoGrande;

/// Ícono de estado (rojo = en el patio, verde = liberado), reutilizado
/// en documento_screen.dart y en la tarjeta de datos heredados de
/// formulario_libertad_screen.dart.
class EstadoVehiculoIcon extends StatelessWidget {
  final bool liberado;
  final double size;
  const EstadoVehiculoIcon({super.key, required this.liberado, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final color = liberado ? Colors.green.shade700 : Colors.red.shade700;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(
        liberado ? Icons.check_circle_outline : Icons.lock_outline,
        color: color,
        size: size * 0.65,
      ),
    );
  }
}

class BuscarPlacaScreen extends StatefulWidget {
  const BuscarPlacaScreen({super.key});

  @override
  State<BuscarPlacaScreen> createState() => _BuscarPlacaScreenState();
}

class _BuscarPlacaScreenState extends State<BuscarPlacaScreen> {
  final _controller = TextEditingController();
  List<CasoIngreso> _ingresos = [];
  List<CasoLibertad> _libertades = [];
  bool _buscando = false;
  bool _yaSeBusco = false;

  Future<void> _buscar() async {
    final placa = _controller.text.trim();
    if (placa.isEmpty) return;
    setState(() => _buscando = true);

    final ingresos = await StorageService.buscarIngresosPorPlaca(placa);
    final libertades = await StorageService.buscarLibertadesPorPlaca(placa);

    if (mounted) {
      setState(() {
        _ingresos = ingresos;
        _libertades = libertades;
        _buscando = false;
        _yaSeBusco = true;
      });
    }
  }

  /// True si ya existe un caso de Libertad para la misma hoja de ingreso.
  bool _yaTieneLibertad(CasoIngreso ingreso) {
    return _libertades.any((l) =>
        l.placa == ingreso.placa &&
        (ingreso.hojaIngresoNro.isEmpty || l.hojaIngresoNro == ingreso.hojaIngresoNro));
  }

  void _liberarVehiculo(CasoIngreso ingreso) {
    // Primero se ofrece tomar fotos del oficio de devolución/memorando
    // y de la orden de pago/comprobante (Gemini las lee); desde ahí
    // mismo se puede "Omitir fotos y llenar el resto a mano" si se
    // prefiere ir directo al formulario.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CapturaScreen(tipo: TipoParte.libertad, ingresoBase: ingreso),
      ),
    ).then((_) => _buscar());
  }

  @override
  Widget build(BuildContext context) {
    final sinResultados = _yaSeBusco && _ingresos.isEmpty && _libertades.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar por placa')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Placa',
                      hintText: 'Ej. PAD1978',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _buscando ? null : _buscar,
                  child: _buscando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                ),
              ],
            ),
          ),
          if (sinResultados)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No se encontró ningún caso con esa placa.', textAlign: TextAlign.center),
            ),
          Expanded(
            child: ListView(
              children: [
                ..._ingresos.map((c) {
                  final tieneLibertad = _yaTieneLibertad(c);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          leading: EstadoVehiculoIcon(liberado: tieneLibertad),
                          title: Text('${c.placa} — ${c.marca} ${c.color}'),
                          subtitle: Text('Hoja ${c.hojaIngresoNro}'),
                          trailing: const Icon(Icons.edit),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FormularioIngresoScreen(caso: c, esEdicion: true),
                            ),
                          ).then((_) => _buscar()),
                        ),
                        // 14/sep (ronda 22): mismo sello grande de "Ingresos
                        // guardados", con el estado REAL del vehículo — así
                        // buscar una placa dice de un vistazo si sigue
                        // ingresado o si ya fue liberado.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                }),
                ..._libertades.map((c) {
                  CasoIngreso? ingresoDeEsta;
                  for (final ing in _ingresos) {
                    if (ing.placa == c.placa &&
                        (c.hojaIngresoNro.isEmpty || ing.hojaIngresoNro == c.hojaIngresoNro)) {
                      ingresoDeEsta = ing;
                      break;
                    }
                  }
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      leading: const EstadoVehiculoIcon(liberado: true),
                      title: Text('LIBERTAD — ${c.placa}'),
                      subtitle: Text('${c.marca} ${c.color} — Hoja ${c.hojaIngresoNro}'),
                      trailing: ingresoDeEsta == null ? null : const Icon(Icons.edit),
                      onTap: ingresoDeEsta == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FormularioLibertadScreen(ingreso: ingresoDeEsta!, existente: c),
                                ),
                              ).then((_) => _buscar()),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
