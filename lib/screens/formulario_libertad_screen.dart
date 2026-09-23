// RUTA DE ARCHIVO: lib/screens/formulario_libertad_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import '../services/docx_builder.dart';
import '../services/storage_service.dart';
import '../services/entidad_financiera_service.dart';
import 'buscar_placa_screen.dart' show EstadoVehiculoIcon;

/// Pantalla real para registrar/editar la LIBERTAD de un vehículo que ya
/// está ingresado. Recibe el [ingreso] del que nace (hereda placa, marca,
/// color, tipo, hoja/parte, causa) y opcionalmente [existente] si se está
/// editando una libertad ya guardada.
class FormularioLibertadScreen extends StatefulWidget {
  final CasoIngreso ingreso;
  final CasoLibertad? existente;

  const FormularioLibertadScreen({
    super.key,
    required this.ingreso,
    this.existente,
  });

  @override
  State<FormularioLibertadScreen> createState() => _FormularioLibertadScreenState();
}

class _FormularioLibertadScreenState extends State<FormularioLibertadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  late CasoLibertad _caso;

  final _memorandoNroCtrl = TextEditingController();
  final _memorandoFechaCtrl = TextEditingController();
  final _oficioNroCtrl = TextEditingController();
  final _oficioFechaCtrl = TextEditingController();
  final _firmadoPorCtrl = TextEditingController();
  final _retiradoPorCtrl = TextEditingController();
  final _cedulaRetiraCtrl = TextEditingController();
  final _fechaSalidaCtrl = TextEditingController();
  final _diasCtrl = TextEditingController();
  final _causaCtrl = TextEditingController();
  final _custodioEntregaCtrl = TextEditingController();
  final _placaGruaCtrl = TextEditingController();
  final _numeroParteWebSalidaCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _periciaRealizadaCtrl = TextEditingController();
  final _peritoNombreCtrl = TextEditingController();
  final _ordenAlcohocheckCtrl = TextEditingController();
  final _comprobanteAlcohocheckCtrl = TextEditingController();
  final _valorAlcohocheckCtrl = TextEditingController();
  final _horaFechaAlcohocheckCtrl = TextEditingController();

  static const _gradosDestinatario = ['Mayor', 'Tcrnl.', 'Coronel'];
  String _gradoDestinatario = 'Mayor';

  static const _tiposServicioGaraje = [
    'SERVICIO DE GARAJE LIVIANOS',
    'SERVICIO DE GARAJE PESADOS',
    'SERVICIO DE GARAJE MOTOCICLETA',
    'SERVICIO DE GARAJE EXTRA PESADOS',
  ];
  String? _tipoServicioGaraje;

  /// Traduce el valor corto de "Tipo de cobro" del Ingreso (LIVIANO,
  /// PESADO, MOTOCICLETA, EXTRAPESADO) al texto largo exacto que usa
  /// el dropdown de "Tipo de servicio de garaje" de esta pantalla.
  /// Si el valor heredado no calza con ninguno conocido, devuelve null
  /// en vez de un texto inválido (evita el crash del DropdownButtonFormField).
  static String? _mapearTipoCobroAServicioGaraje(String tipoCobro) {
    switch (tipoCobro) {
      case 'LIVIANO':
        return 'SERVICIO DE GARAJE LIVIANOS';
      case 'PESADO':
        return 'SERVICIO DE GARAJE PESADOS';
      case 'MOTOCICLETA':
        return 'SERVICIO DE GARAJE MOTOCICLETA';
      case 'EXTRAPESADO':
        return 'SERVICIO DE GARAJE EXTRA PESADOS';
      default:
        return null;
    }
  }

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    final ing = widget.ingreso;

    _caso = e ??
        CasoLibertad(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          marca: ing.marca,
          color: ing.color,
          placa: ing.placa,
          tipoVehiculo: ing.tipoVehiculo,
          hojaIngresoNro: ing.hojaIngresoNro,
          parteIngresoNro: ing.parteIngresoNro,
          fechaIngreso: ing.fechaIngreso,
          causa: [ing.causaLegal, ing.detalleCausa]
              .where((s) => s.trim().isNotEmpty)
              .join(' - '),
          fechaSalida: _dateFmt.format(DateTime.now()),
        );

    _memorandoNroCtrl.text = _caso.memorandoNro;
    _memorandoFechaCtrl.text = _caso.memorandoFecha;
    _oficioNroCtrl.text = _caso.oficioDevolucionNro;
    _oficioFechaCtrl.text = _caso.oficioDevolucionFecha;
    _firmadoPorCtrl.text = _caso.firmadoPor;
    _retiradoPorCtrl.text = _caso.retiradoPor;
    _cedulaRetiraCtrl.text = _caso.cedulaRetira;
    _fechaSalidaCtrl.text = _caso.fechaSalida;
    _diasCtrl.text = _caso.diasPermanencia;
    _causaCtrl.text = _caso.causa;
    _custodioEntregaCtrl.text = _caso.custodioEntregaNombre;
    _placaGruaCtrl.text = _caso.placaGrua;
    _numeroParteWebSalidaCtrl.text = _caso.numeroParteWebSalida;
    _observacionesCtrl.text = _caso.observaciones;
    _periciaRealizadaCtrl.text = _caso.periciaRealizada;
    _peritoNombreCtrl.text = _caso.peritoNombre;
    _ordenAlcohocheckCtrl.text = _caso.ordenPagoAlcohocheckNro;
    _comprobanteAlcohocheckCtrl.text = _caso.comprobantePagoAlcohocheckNro;
    _valorAlcohocheckCtrl.text = _caso.valorAlcohocheck;
    _horaFechaAlcohocheckCtrl.text = _caso.horaFechaPagoAlcohocheck;
    _gradoDestinatario = _gradosDestinatario.contains(_caso.gradoDestinatario)
        ? _caso.gradoDestinatario
        : 'Mayor';
    _tipoServicioGaraje = _caso.tipoServicioGaraje.isNotEmpty
        ? _caso.tipoServicioGaraje
        : (ing.tipoCobroParqueo.isNotEmpty
            ? _mapearTipoCobroAServicioGaraje(ing.tipoCobroParqueo)
            : null);

    if (e == null) {
      _recalcularDias();
    }
  }

  @override
  void dispose() {
    _memorandoNroCtrl.dispose();
    _memorandoFechaCtrl.dispose();
    _oficioNroCtrl.dispose();
    _oficioFechaCtrl.dispose();
    _firmadoPorCtrl.dispose();
    _retiradoPorCtrl.dispose();
    _cedulaRetiraCtrl.dispose();
    _fechaSalidaCtrl.dispose();
    _diasCtrl.dispose();
    _causaCtrl.dispose();
    _custodioEntregaCtrl.dispose();
    _placaGruaCtrl.dispose();
    _numeroParteWebSalidaCtrl.dispose();
    _observacionesCtrl.dispose();
    _periciaRealizadaCtrl.dispose();
    _peritoNombreCtrl.dispose();
    _ordenAlcohocheckCtrl.dispose();
    _comprobanteAlcohocheckCtrl.dispose();
    _valorAlcohocheckCtrl.dispose();
    _horaFechaAlcohocheckCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseFecha(String s) {
    final p = s.trim().split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  void _recalcularDias() {
    final ingreso = _parseFecha(widget.ingreso.fechaIngreso);
    final salida = _parseFecha(_fechaSalidaCtrl.text);
    if (ingreso == null || salida == null) return;
    final dias = salida.difference(ingreso).inDays + 1; // inclusivo
    if (dias >= 0) {
      setState(() => _diasCtrl.text = dias.toString());
    }
  }

  Future<void> _elegirFecha(TextEditingController ctrl, {VoidCallback? luego}) async {
    final actual = _parseFecha(ctrl.text) ?? DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null) {
      setState(() => ctrl.text = _dateFmt.format(elegida));
      luego?.call();
    }
  }

  void _agregarPago() {
    setState(() => _caso.pagos.add(PagoGaraje()));
  }

  void _quitarPago(int index) {
    if (_caso.pagos.length <= 1) return;
    setState(() => _caso.pagos.removeAt(index));
  }

  void _aplicarCambiosACaso() {
    _caso
      ..memorandoNro = _memorandoNroCtrl.text.trim()
      ..memorandoFecha = _memorandoFechaCtrl.text.trim()
      ..oficioDevolucionNro = _oficioNroCtrl.text.trim()
      ..oficioDevolucionFecha = _oficioFechaCtrl.text.trim()
      ..firmadoPor = _firmadoPorCtrl.text.trim()
      ..retiradoPor = _retiradoPorCtrl.text.trim()
      ..cedulaRetira = _cedulaRetiraCtrl.text.trim()
      ..fechaSalida = _fechaSalidaCtrl.text.trim()
      ..diasPermanencia = _diasCtrl.text.trim()
      ..causa = _causaCtrl.text.trim()
      ..gradoDestinatario = _gradoDestinatario
      ..custodioEntregaNombre = _custodioEntregaCtrl.text.trim()
      ..placaGrua = _placaGruaCtrl.text.trim()
      ..numeroParteWebSalida = _numeroParteWebSalidaCtrl.text.trim()
      ..observaciones = _observacionesCtrl.text.trim()
      ..periciaRealizada = _periciaRealizadaCtrl.text.trim()
      ..peritoNombre = _peritoNombreCtrl.text.trim()
      ..ordenPagoAlcohocheckNro = widget.ingreso.aplicaAlcohotest ? _ordenAlcohocheckCtrl.text.trim() : ''
      ..comprobantePagoAlcohocheckNro = widget.ingreso.aplicaAlcohotest ? _comprobanteAlcohocheckCtrl.text.trim() : ''
      ..valorAlcohocheck = widget.ingreso.aplicaAlcohotest ? _valorAlcohocheckCtrl.text.trim() : ''
      ..horaFechaPagoAlcohocheck = widget.ingreso.aplicaAlcohotest ? _horaFechaAlcohocheckCtrl.text.trim() : ''
      ..tipoServicioGaraje = _tipoServicioGaraje ?? '';
  }

  /// Mismo criterio que en formulario_screen.dart (ronda 19): ya no
  /// bloquea en silencio, avisa y deja decidir completar ahora o
  /// guardar el avance y completar después.
  Future<bool> _puedeContinuar() async {
    final valido = _formKey.currentState!.validate();
    if (valido) return true;
    if (!mounted) return false;
    final continuar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Faltan campos obligatorios'),
        content: const Text(
          'Hay campos obligatorios vacíos (marcados en rojo en el formulario). '
          'Puedes bajar a completarlos ahora, o guardar el avance y llenarlos más tarde.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Completar campos')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar de todas formas')),
        ],
      ),
    );
    return continuar ?? false;
  }

  Future<void> _guardar({bool compartirDespues = false}) async {
    if (!await _puedeContinuar()) return;
    setState(() => _guardando = true);

    _aplicarCambiosACaso();

    await StorageService.guardarCasoLibertad(_caso);

    if (!mounted) return;
    setState(() => _guardando = false);

    if (compartirDespues) {
      await _compartir();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Libertad guardada correctamente.')),
      );
      Navigator.pop(context, true);
    }
  }

  // 31/ago: Xavier pidió recuperar el flujo de Vista previa → Descargar /
  // Enviar por WhatsApp. IMPORTANTE — límite técnico honesto: esta app no
  // guarda archivos directamente al almacenamiento del teléfono (no usa
  // dart:io/path_provider, ver storage_service.dart), así que tanto
  // "Descargar" como "Enviar por WhatsApp" abren la misma bandeja nativa
  // para compartir; la diferencia es que en "Descargar" se sugiere elegir
  // "Guardar en archivos"/Drive, y en "WhatsApp" elegir la app de WhatsApp
  // en esa misma bandeja. Si más adelante se quiere guardar de verdad en
  // el dispositivo sin pasar por la bandeja, hay que agregar path_provider.
  Future<void> _verVistaPrevia() async {
    if (!await _puedeContinuar()) return;
    _aplicarCambiosACaso();

    final accion = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _VistaPreviaLibertadScreen(caso: _caso, ingreso: widget.ingreso),
      ),
    );
    if (accion == null || !mounted) return;

    setState(() => _guardando = true);
    await StorageService.guardarCasoLibertad(_caso);
    if (!mounted) return;
    setState(() => _guardando = false);

    if (accion == 'whatsapp') {
      await _compartir(mensajeWhatsapp: true);
    } else if (accion == 'descargar') {
      await _compartir();
    }
  }

  Future<void> _compartir({bool mensajeWhatsapp = false}) async {
    final bytes = StorageService.generarWordLibertad(_caso);
    final nombre = StorageService.obtenerNombreArchivoWord(placa: _caso.placa, esIngreso: false);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: nombre,
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    await Share.shareXFiles(
      [xFile],
      text: mensajeWhatsapp
          ? 'Libertad ${_caso.placa} - REGISTROS PRV TRANSITO (elige WhatsApp en la bandeja para enviarlo)'
          : 'Libertad ${_caso.placa} - REGISTROS PRV TRANSITO',
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final ing = widget.ingreso;

    return Scaffold(
      appBar: AppBar(
        title: Text('Libertad — ${ing.placa.toUpperCase()}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copiar texto para Parte Web / Acta',
            onPressed: () {
              _aplicarCambiosACaso();
              final texto = DocxBuilder.generarTextoNarrativoLibertad(_caso);
              Clipboard.setData(ClipboardData(text: texto));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Texto de Libertad copiado al portapapeles'),
                  backgroundColor: Color(0xFF17356E),
                ),
              );
            },
          ),
          if (!_guardando)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Guardar y compartir Word',
              onPressed: () => _guardar(compartirDespues: true),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          // Mismo fix que en formulario_screen.dart: deja espacio de
          // más abajo para que el botón no quede tapado por la barra
          // de navegación del sistema.
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          children: [
            _tarjetaDatosHeredados(ing),
            const SizedBox(height: 16),
            _seccion('Documento de devolución', [
              _campo(_memorandoNroCtrl, 'N° de Memorando'),
              _campoFecha(_memorandoFechaCtrl, 'Fecha del Memorando'),
              _campo(_oficioNroCtrl, 'N° de Oficio de Devolución'),
              _campoFecha(_oficioFechaCtrl, 'Fecha del Oficio'),
              _campo(_firmadoPorCtrl, 'Firmado por (fiscal/juez/autoridad)'),
              DropdownButtonFormField<String>(
                initialValue: _gradoDestinatario,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Parte elevado al Sr/a (grado)'),
                items: _gradosDestinatario
                    .map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _gradoDestinatario = v ?? 'Mayor'),
              ),
            ]),
            const SizedBox(height: 12),
            _seccion('Persona que retira', [
              _campo(_retiradoPorCtrl, 'Nombre completo de quien retira'),
              _campo(_cedulaRetiraCtrl, 'C.I. / C.C.'),
            ]),
            const SizedBox(height: 12),
            _seccion('Salida y garaje', [
              _campoFecha(_fechaSalidaCtrl, 'Fecha de Salida', luego: _recalcularDias),
              Row(
                children: [
                  Expanded(child: _campo(_diasCtrl, 'Días de permanencia en el CRV', tipo: TextInputType.number)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Recalcular días',
                    onPressed: _recalcularDias,
                  ),
                ],
              ),
              _campo(_causaCtrl, 'Causa (se muestra en el Word)', lineas: 2),
              DropdownButtonFormField<String>(
                initialValue: _tipoServicioGaraje,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo de servicio de garaje'),
                items: _tiposServicioGaraje
                    .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _tipoServicioGaraje = v),
              ),
              _campo(_numeroParteWebSalidaCtrl, 'Nro. Parte Web de salida (SIIPNE 3W)'),
              _campo(_custodioEntregaCtrl, 'Custodio que entrega el vehículo'),
              _campo(_placaGruaCtrl, 'Placa de grúa en la salida (si aplica)'),
            ]),
            const SizedBox(height: 12),
            _seccionPagos(),
            // 31/ago: "Pago Alcohocheck" solo se muestra si el Ingreso
            // tuvo activado el módulo de alcoholemia — mismo patrón que
            // los demás comprobantes de pago (Xavier pidió que viva
            // aquí, no en el Ingreso).
            if (widget.ingreso.aplicaAlcohotest) ...[
              const SizedBox(height: 12),
              _seccion('Pago Alcohocheck', [
                _campo(_ordenAlcohocheckCtrl, 'N° Orden de Pago Alcohocheck'),
                _campo(_comprobanteAlcohocheckCtrl, 'N° Comprobante de Pago'),
                Row(
                  children: [
                    Expanded(
                      child: _campo(_valorAlcohocheckCtrl, 'Valor (\$)', tipo: const TextInputType.numberWithOptions(decimal: true)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _campo(_horaFechaAlcohocheckCtrl, 'Hora y fecha de pago'),
                    ),
                  ],
                ),
              ]),
            ],
            const SizedBox(height: 12),
            // 31/ago: "Investigación / Pericias" se movió aquí (Salida),
            // ya no está en la hoja de Ingreso.
            _seccion('Investigación / Pericias', [
              _campo(_periciaRealizadaCtrl, 'Pericia realizada (Ej. N/A, Informe Técnico Pericial...)'),
              _campo(_peritoNombreCtrl, 'Nombre del Perito (si aplica)'),
            ]),
            const SizedBox(height: 12),
            _seccion('Observaciones', [
              _campo(_observacionesCtrl, 'Observación de salida', lineas: 3),
            ]),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: _guardando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.visibility_outlined),
              label: Text(_guardando ? 'Procesando...' : 'Vista previa'),
              onPressed: _guardando ? null : _verVistaPrevia,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar avance'),
              onPressed: _guardando ? null : () => _guardar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaDatosHeredados(CasoIngreso ing) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const EstadoVehiculoIcon(liberado: true, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${ing.placa.toUpperCase()} — ${ing.marca} ${ing.color}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${ing.tipoVehiculo} · Hoja ${ing.hojaIngresoNro} · Parte ${ing.parteIngresoNro}'),
                  Text('Ingresó: ${ing.fechaIngreso}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String titulo, List<Widget> hijos) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...hijos.map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w)),
          ],
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, {int lineas = 1, TextInputType? tipo}) {
    return TextFormField(
      controller: ctrl,
      maxLines: lineas,
      keyboardType: tipo,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Widget _campoFecha(TextEditingController ctrl, String label, {VoidCallback? luego}) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () => _elegirFecha(ctrl, luego: luego),
    );
  }

  Widget _seccionPagos() {
    final total = _caso.valorTotalGaraje;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pagos por garaje', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Total: \$${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _caso.pagos.length; i++)
              _PagoCard(
                key: ValueKey(_caso.pagos[i]),
                indice: i,
                pago: _caso.pagos[i],
                puedeQuitar: _caso.pagos.length > 1,
                onQuitar: () => _quitarPago(i),
                onCambio: () => setState(() {}),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar otro pago'),
              onPressed: _agregarPago,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de un pago individual. El desplegable de banco oficial y el
/// aprendizaje de alias usan EXACTAMENTE entidad_financiera_service.dart
/// tal como está (5 bancos fijos de SIIPNE 3W) — no se modificó ese
/// enfoque.
class _PagoCard extends StatefulWidget {
  final int indice;
  final PagoGaraje pago;
  final bool puedeQuitar;
  final VoidCallback onQuitar;
  final VoidCallback onCambio;

  const _PagoCard({
    super.key,
    required this.indice,
    required this.pago,
    required this.puedeQuitar,
    required this.onQuitar,
    required this.onCambio,
  });

  @override
  State<_PagoCard> createState() => _PagoCardState();
}

class _PagoCardState extends State<_PagoCard> {
  late final TextEditingController _ordenCtrl;
  late final TextEditingController _comprobanteCtrl;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _horaFechaCtrl;
  late final TextEditingController _entidadLiteralCtrl;
  String? _sugerencia;

  @override
  void initState() {
    super.initState();
    final p = widget.pago;
    _ordenCtrl = TextEditingController(text: p.ordenPagoNro);
    _comprobanteCtrl = TextEditingController(text: p.comprobantePagoNro);
    _valorCtrl = TextEditingController(text: p.valor);
    _horaFechaCtrl = TextEditingController(text: p.horaFechaPago);
    _entidadLiteralCtrl = TextEditingController(text: p.entidadFinanciera);
  }

  @override
  void dispose() {
    _ordenCtrl.dispose();
    _comprobanteCtrl.dispose();
    _valorCtrl.dispose();
    _horaFechaCtrl.dispose();
    _entidadLiteralCtrl.dispose();
    super.dispose();
  }

  Future<void> _onEntidadLiteralChanged(String texto) async {
    widget.pago.entidadFinanciera = texto;
    final sugerido = await EntidadFinancieraService.sugerirOficial(texto);
    if (!mounted) return;
    setState(() => _sugerencia = sugerido);
    if (sugerido != null && widget.pago.entidadFinancieraOficial.isEmpty) {
      setState(() => widget.pago.entidadFinancieraOficial = sugerido);
      widget.onCambio();
    }
  }

  Future<void> _onOficialElegido(String? oficial) async {
    if (oficial == null) return;
    setState(() => widget.pago.entidadFinancieraOficial = oficial);
    // Si el oficial elige manualmente y no coincide con lo sugerido,
    // la app "aprende" ese alias para la próxima vez.
    if (_entidadLiteralCtrl.text.trim().isNotEmpty && oficial != _sugerencia) {
      await EntidadFinancieraService.aprenderAlias(_entidadLiteralCtrl.text, oficial);
    }
    widget.onCambio();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pago N° ${widget.indice + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (widget.puedeQuitar)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: widget.onQuitar,
                ),
            ],
          ),
          TextFormField(
            controller: _ordenCtrl,
            decoration: const InputDecoration(labelText: 'N° Orden de pago Garaje'),
            onChanged: (v) {
              widget.pago.ordenPagoNro = v;
              widget.onCambio();
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _comprobanteCtrl,
            decoration: const InputDecoration(labelText: 'N° Comprobante de pago'),
            onChanged: (v) {
              widget.pago.comprobantePagoNro = v;
              widget.onCambio();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _valorCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor (\$)'),
                  onChanged: (v) {
                    widget.pago.valor = v;
                    widget.onCambio();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _horaFechaCtrl,
                  decoration: const InputDecoration(labelText: 'Hora y fecha de pago'),
                  onChanged: (v) => widget.pago.horaFechaPago = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _entidadLiteralCtrl,
            decoration: const InputDecoration(
              labelText: 'Entidad financiera (tal como dice el recibo)',
              hintText: 'Ej. Pichincha Mi Vecino',
            ),
            onChanged: _onEntidadLiteralChanged,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: widget.pago.entidadFinancieraOficial.isNotEmpty
                ? widget.pago.entidadFinancieraOficial
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Banco oficial (SIIPNE 3W)',
              helperText: _sugerencia != null && widget.pago.entidadFinancieraOficial == _sugerencia
                  ? 'Sugerido automáticamente por el texto del recibo'
                  : null,
            ),
            items: EntidadFinancieraService.oficiales
                .map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: _onOficialElegido,
            validator: (v) => (v == null || v.isEmpty) ? 'Elige el banco oficial' : null,
          ),
        ],
      ),
    );
  }
}

/// NUEVO (31/ago): pantalla de Vista Previa que Xavier pidió recuperar.
/// Muestra un resumen de solo lectura de todo lo que se va a generar en
/// el Word antes de guardar. Al elegir "Descargar" o "Enviar por
/// WhatsApp" se devuelve esa acción a FormularioLibertadScreen, que
/// guarda el caso y abre la bandeja de compartir (ver nota técnica en
/// _verVistaPrevia sobre por qué ambos botones usan la misma bandeja).
class _VistaPreviaLibertadScreen extends StatelessWidget {
  final CasoLibertad caso;
  final CasoIngreso ingreso;

  const _VistaPreviaLibertadScreen({required this.caso, required this.ingreso});

  Widget _fila(String etiqueta, String valor) {
    if (valor.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(text: '$etiqueta: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(String titulo, List<Widget> filas) {
    final visibles = filas.where((w) => w is! SizedBox).toList();
    if (visibles.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            ...filas,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textoNarrativo = DocxBuilder.generarTextoNarrativoLibertad(caso);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista Previa — Libertad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copiar texto para Parte Web / Acta',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: textoNarrativo));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Texto de Libertad copiado al portapapeles'),
                  backgroundColor: Color(0xFF17356E),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${ingreso.placa.toUpperCase()} — ${ingreso.marca} ${ingreso.color}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 14),
          Card(
            color: const Color(0xFFF0F5FD),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF17356E), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.assignment_outlined, color: Color(0xFF17356E)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Texto Oficial para Parte Web / Acta de Salida',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF17356E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFC7D7EE)),
                  const SizedBox(height: 6),
                  SelectableText(
                    textoNarrativo,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF1C2D42),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF17356E),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar texto para Parte Web / Acta'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: textoNarrativo));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Texto narrativo copiado! Listo para pegar en Parte Web.'),
                          backgroundColor: Color(0xFF17356E),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _tarjeta('Documento de devolución', [
            _fila('N° de Memorando', caso.memorandoNro),
            _fila('Fecha del Memorando', caso.memorandoFecha),
            _fila('N° de Oficio de Devolución', caso.oficioDevolucionNro),
            _fila('Fecha del Oficio', caso.oficioDevolucionFecha),
            _fila('Firmado por', caso.firmadoPor),
            _fila('Parte elevado al Sr/a', caso.gradoDestinatario),
          ]),
          _tarjeta('Persona que retira', [
            _fila('Nombre', caso.retiradoPor),
            _fila('Cédula', caso.cedulaRetira),
          ]),
          _tarjeta('Salida y garaje', [
            _fila('Fecha de Salida', caso.fechaSalida),
            _fila('Días de permanencia', caso.diasPermanencia),
            _fila('Causa', caso.causa),
            _fila('Tipo de servicio de garaje', caso.tipoServicioGaraje),
            _fila('Nro. Parte Web de salida', caso.numeroParteWebSalida),
            _fila('Custodio que entrega', caso.custodioEntregaNombre),
            _fila('Placa de grúa', caso.placaGrua),
          ]),
          _tarjeta('Pagos por garaje', [
            for (var i = 0; i < caso.pagos.length; i++) ...[
              _fila('Pago ${i + 1} — Orden', caso.pagos[i].ordenPagoNro),
              _fila('Pago ${i + 1} — Comprobante', caso.pagos[i].comprobantePagoNro),
              _fila('Pago ${i + 1} — Valor', caso.pagos[i].valor),
              _fila('Pago ${i + 1} — Banco', caso.pagos[i].entidadFinancieraOficial),
            ],
          ]),
          if (ingreso.aplicaAlcohotest)
            _tarjeta('Pago Alcohocheck', [
              _fila('N° Orden de Pago', caso.ordenPagoAlcohocheckNro),
              _fila('N° Comprobante', caso.comprobantePagoAlcohocheckNro),
              _fila('Valor', caso.valorAlcohocheck),
              _fila('Hora y fecha de pago', caso.horaFechaPagoAlcohocheck),
            ]),
          _tarjeta('Investigación / Pericias', [
            _fila('Pericia realizada', caso.periciaRealizada),
            _fila('Nombre del Perito', caso.peritoNombre),
          ]),
          _tarjeta('Observaciones', [
            _fila('Observación de salida', caso.observaciones),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.download_outlined),
            label: const Text('Descargar'),
            onPressed: () => Navigator.pop(context, 'descargar'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.share_outlined),
            label: const Text('Enviar por WhatsApp'),
            onPressed: () => Navigator.pop(context, 'whatsapp'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Volver a editar'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
