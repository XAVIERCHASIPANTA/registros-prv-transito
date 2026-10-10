import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CalculadoraDiasDialog extends StatefulWidget {
  final DateTime? fechaIngresoInicial;
  final DateTime? fechaSalidaInicial;
  final String? tipoVehiculoInicial;

  const CalculadoraDiasDialog({
    super.key,
    this.fechaIngresoInicial,
    this.fechaSalidaInicial,
    this.tipoVehiculoInicial,
  });

  /// Método estático utilitario para mostrar la calculadora como diálogo modal
  static Future<void> mostrar(
    BuildContext context, {
    DateTime? fechaIngreso,
    DateTime? fechaSalida,
    String? tipoVehiculo,
  }) {
    return showDialog(
      context: context,
      builder: (_) => CalculadoraDiasDialog(
        fechaIngresoInicial: fechaIngreso,
        fechaSalidaInicial: fechaSalida,
        tipoVehiculoInicial: tipoVehiculo,
      ),
    );
  }

  @override
  State<CalculadoraDiasDialog> createState() => _CalculadoraDiasDialogState();
}

class _CalculadoraDiasDialogState extends State<CalculadoraDiasDialog> {
  late DateTime _fechaIngreso;
  late DateTime _fechaSalida;

  // Categorías de tarifas
  final List<({String key, String label, double precio, IconData icon})> _categorias = const [
    (key: 'moto', label: 'Moto', precio: 1.00, icon: Icons.two_wheeler),
    (key: 'liviano', label: 'Liviano (<=3.5 TN)', precio: 3.00, icon: Icons.directions_car),
    (key: 'pesado', label: 'Pesado (3.51-12 TN)', precio: 9.00, icon: Icons.local_shipping),
    (key: 'extrapesado', label: 'Extra Pesado (>12 TN)', precio: 15.00, icon: Icons.fire_truck),
  ];

  late String _categoriaSeleccionada;
  final TextEditingController _precioPersonalizadoCtrl = TextEditingController();
  bool _usarPrecioPersonalizado = false;

  @override
  void initState() {
    super.initState();
    // Fecha de inicio: la que reciba o por defecto hoy
    _fechaIngreso = widget.fechaIngresoInicial ?? DateTime.now();
    // Fecha final / salida: premeditada con la fecha actual por defecto (hoy)
    _fechaSalida = widget.fechaSalidaInicial ?? DateTime.now();

    // Mapear tipoVehiculoInicial si viene especificado
    final tipoLower = (widget.tipoVehiculoInicial ?? '').toLowerCase();
    if (tipoLower.contains('moto')) {
      _categoriaSeleccionada = 'moto';
    } else if (tipoLower.contains('pesado') && (tipoLower.contains('extra') || tipoLower.contains('mas') || tipoLower.contains('más'))) {
      _categoriaSeleccionada = 'extrapesado';
    } else if (tipoLower.contains('pesado')) {
      _categoriaSeleccionada = 'pesado';
    } else {
      _categoriaSeleccionada = 'liviano';
    }

    final cat = _categorias.firstWhere((c) => c.key == _categoriaSeleccionada);
    _precioPersonalizadoCtrl.text = cat.precio.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _precioPersonalizadoCtrl.dispose();
    super.dispose();
  }

  String _formatoFecha(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  /// Abre el calendario para elegir fecha de inicio o fecha final
  Future<void> _abrirCalendario(bool esIngreso) async {
    final inicial = esIngreso ? _fechaIngreso : _fechaSalida;
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: esIngreso ? 'SELECCIONAR FECHA DE INGRESO' : 'SELECCIONAR FECHA FINAL',
      cancelText: 'CANCELAR',
      confirmText: 'SELECCIONAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF17356E),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (esIngreso) {
          _fechaIngreso = DateTime(picked.year, picked.month, picked.day);
        } else {
          _fechaSalida = DateTime(picked.year, picked.month, picked.day);
        }
      });
    }
  }

  int get _diasCalculados {
    final inicio = DateTime(_fechaIngreso.year, _fechaIngreso.month, _fechaIngreso.day);
    final fin = DateTime(_fechaSalida.year, _fechaSalida.month, _fechaSalida.day);
    if (fin.isBefore(inicio)) return 0;
    // Conteo inclusivo: desde el primer día se cuenta (Ej: Lunes a Viernes = 5 días)
    return fin.difference(inicio).inDays + 1;
  }

  double get _precioUnitario {
    if (_usarPrecioPersonalizado) {
      return double.tryParse(_precioPersonalizadoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    }
    final cat = _categorias.firstWhere(
      (c) => c.key == _categoriaSeleccionada,
      orElse: () => _categorias[1],
    );
    return cat.precio;
  }

  double get _totalCalculado => _diasCalculados * _precioUnitario;

  void _seleccionarCategoria(String key) {
    final cat = _categorias.firstWhere((c) => c.key == key);
    setState(() {
      _categoriaSeleccionada = key;
      _usarPrecioPersonalizado = false;
      _precioPersonalizadoCtrl.text = cat.precio.toStringAsFixed(2);
    });
  }

  void _copiarResultado() {
    final texto = 'Calculador de días de permanencia v1.1.5:\n'
        '• Fecha Inicio: ${_formatoFecha(_fechaIngreso)}\n'
        '• Fecha Final: ${_formatoFecha(_fechaSalida)}\n'
        '• Días de permanencia: $_diasCalculados día(s) (conteo inclusivo)\n'
        '• Tarifa diaria: \$${_precioUnitario.toStringAsFixed(2)}\n'
        '• TOTAL A PAGAR: \$${_totalCalculado.toStringAsFixed(2)}';
    
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cálculo copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dias = _diasCalculados;
    final total = _totalCalculado;
    final esFechaValida = !_fechaSalida.isBefore(_fechaIngreso);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17356E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calculate,
                      color: Color(0xFF17356E),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calculador de Días',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF17356E),
                          ),
                        ),
                        Text(
                          'Permanencia de vehículos en patio v1.1.5',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Banner aclaratorio de conteo inclusivo (Ej: Lunes a Viernes = 5 días)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade900, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El primer día se cuenta siempre. (Ej. Lunes a Viernes = 5 días).',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Selección de fechas (Botones interactivos que abren el calendario al presionar)
              Row(
                children: [
                  Expanded(
                    child: _buildBotonCalendario(
                      titulo: 'Fecha Inicio',
                      fecha: _fechaIngreso,
                      subtitulo: 'Toca para abrir calendario',
                      colorIcono: Colors.blue.shade700,
                      onTap: () => _abrirCalendario(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBotonCalendario(
                      titulo: 'Fecha Final',
                      fecha: _fechaSalida,
                      subtitulo: 'Premeditada hoy',
                      colorIcono: Colors.green.shade700,
                      onTap: () => _abrirCalendario(false),
                    ),
                  ),
                ],
              ),

              if (!esFechaValida) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠️ La fecha final no puede ser anterior a la de inicio',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],

              const SizedBox(height: 14),
              const Text(
                'Tipo de Vehículo / Peso:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),

              // Selector de tipo de vehículo (Chips)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _categorias.map((cat) {
                  final seleccionada = !_usarPrecioPersonalizado && _categoriaSeleccionada == cat.key;
                  return ChoiceChip(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    avatar: Icon(
                      cat.icon,
                      size: 16,
                      color: seleccionada ? Colors.white : const Color(0xFF17356E),
                    ),
                    label: Text(
                      '${cat.label} (\$${cat.precio.toStringAsFixed(2)})',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                        color: seleccionada ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: seleccionada,
                    selectedColor: const Color(0xFF17356E),
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (val) {
                      if (val) _seleccionarCategoria(cat.key);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),

              // Campo de tarifa por día (permite modificar si es necesario)
              Row(
                children: [
                  const Text('Valor por día (\$):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    height: 38,
                    child: TextField(
                      controller: _precioPersonalizadoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixText: '\$ ',
                      ),
                      onChanged: (val) {
                        setState(() {
                          _usarPrecioPersonalizado = true;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tarjeta de Resultados (Con protección anti-overflow FittedBox)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF17356E), Color(0xFF2351A2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF17356E).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Días de Permanencia:',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$dias día(s)',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Tarifa diaria:',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '\$${_precioUnitario.toStringAsFixed(2)} / día',
                            style: const TextStyle(color: Colors.white, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'TOTAL A PAGAR:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Botones de Acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Copiar Resumen'),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _copiarResultado,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Aceptar'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF17356E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotonCalendario({
    required String titulo,
    required DateTime fecha,
    required String subtitulo,
    required Color colorIcono,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF17356E).withValues(alpha: 0.3), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          color: Colors.blue.shade50.withValues(alpha: 0.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatoFecha(fecha),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF17356E)),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.calendar_month, size: 18, color: colorIcono),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
