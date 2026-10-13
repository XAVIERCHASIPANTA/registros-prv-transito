import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import '../services/storage_service.dart';
import '../services/web_download_stub.dart'
    if (dart.library.html) '../services/web_download_web.dart';

class MatrizExcelScreen extends StatefulWidget {
  const MatrizExcelScreen({super.key});

  @override
  State<MatrizExcelScreen> createState() => _MatrizExcelScreenState();
}

class _MatrizExcelScreenState extends State<MatrizExcelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _busquedaCtrl = TextEditingController();

  List<CasoIngreso> _ingresos = [];
  List<CasoLibertad> _libertades = [];
  bool _cargando = true;
  String _filtroTexto = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final ing = await StorageService.obtenerIngresos();
      final lib = await StorageService.obtenerLibertades();
      if (mounted) {
        setState(() {
          _ingresos = ing;
          _libertades = lib;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  CasoLibertad? _libertadDe(CasoIngreso ingreso) {
    for (final l in _libertades) {
      if (l.hojaIngresoNro.isNotEmpty && l.hojaIngresoNro == ingreso.hojaIngresoNro) {
        return l;
      }
    }
    for (final l in _libertades) {
      if (l.placa.trim().toUpperCase() == ingreso.placa.trim().toUpperCase()) {
        return l;
      }
    }
    return null;
  }

  int? _calcularDias(String fechaIngreso, String fechaSalida) {
    final f1 = _parseFecha(fechaIngreso);
    final f2 = _parseFecha(fechaSalida);
    if (f1 == null || f2 == null) return null;
    return f2.difference(f1).inDays + 1;
  }

  DateTime? _parseFecha(String texto) {
    final partes = texto.trim().split('/');
    if (partes.length != 3) {
      final partesGuion = texto.trim().split('-');
      if (partesGuion.length == 3) {
        return DateTime.tryParse(texto.trim());
      }
      return null;
    }
    final d = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    final y = int.tryParse(partes[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  double _tarifaDiaria(String tipoCobro) {
    switch (tipoCobro.trim().toUpperCase()) {
      case 'MOTOCICLETA':
        return 1.0;
      case 'LIVIANO':
        return 3.0;
      case 'PESADO':
        return 9.0;
      case 'EXTRAPESADO':
      case 'EXTRA PESADO':
        return 15.0;
      default:
        return 0.0;
    }
  }

  Future<void> _exportarOCompartirExcel({required bool descargarDirecto}) async {
    try {
      final bytes = await StorageService.generarExcelConsolidado();
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay registros suficientes para exportar la matriz.')),
          );
        }
        return;
      }

      final nombreArchivo = 'MATRIZ_GENERAL_PATIO_${DateTime.now().year}.xlsx';

      if (descargarDirecto && kIsWeb) {
        descargarBytesEnNavegador(nombreArchivo, bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Descargando $nombreArchivo...')),
          );
        }
        return;
      }

      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: nombreArchivo,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      await Share.shareXFiles([xFile], text: 'Matriz General Consolidada de Patio (.xlsx)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar archivo Excel: $e')),
        );
      }
    }
  }

  List<CasoIngreso> _filtrarLista(bool esMoto) {
    final lista = _ingresos.where((i) {
      final moto = i.tipoVehiculo.trim().toUpperCase() == 'MOTOCICLETA';
      return esMoto ? moto : !moto;
    }).toList();

    if (_filtroTexto.trim().isEmpty) return lista;

    final q = _filtroTexto.trim().toUpperCase();
    return lista.where((i) {
      final lib = _libertadDe(i);
      return i.placa.toUpperCase().contains(q) ||
          i.hojaIngresoNro.toUpperCase().contains(q) ||
          i.propietario.toUpperCase().contains(q) ||
          i.marca.toUpperCase().contains(q) ||
          i.modelo.toUpperCase().contains(q) ||
          (lib?.oficioDevolucionNro.toUpperCase().contains(q) ?? false) ||
          (lib?.retiradoPor.toUpperCase().contains(q) ?? false);
    }).toList();
  }

  void _verDetalleCompleto(CasoIngreso ing, CasoLibertad? lib, int ord, bool esMoto) {
    final dias = lib != null ? _calcularDias(ing.fechaIngreso, lib.fechaSalida) : null;
    final tipoCobro = ing.tipoCobroParqueo.isNotEmpty ? ing.tipoCobroParqueo : (lib?.tipoServicioGaraje ?? '');
    final tarifa = _tarifaDiaria(tipoCobro);
    final valorTotal = (dias != null && tarifa > 0) ? (dias * tarifa) : null;
    final primerPago = (lib != null && lib.pagos.isNotEmpty) ? lib.pagos.first : null;
    final banco = primerPago != null
        ? (primerPago.entidadFinancieraOficial.isNotEmpty
            ? primerPago.entidadFinancieraOficial
            : primerPago.entidadFinanciera)
        : '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF132B59),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.table_view_rounded, color: Colors.purpleAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registro ORD. #$ord: ${ing.placa.toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              lib != null ? 'ESTADO: SALIDO / LIBERTAD' : 'ESTADO: EN PATIO',
                              style: TextStyle(
                                color: lib != null ? Colors.greenAccent : Colors.amberAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),

                  _seccionTitulo('1. DATOS DE INGRESO AL CRV'),
                  _itemDetalle('Subzona', ing.subzona.isNotEmpty ? ing.subzona : 'SANTO DOMINGO'),
                  _itemDetalle('Centro de Retención (CRV)', ing.crv.isNotEmpty ? ing.crv : 'CONTROL 120'),
                  _itemDetalle('Fecha de Ingreso', ing.fechaIngreso),
                  _itemDetalle('N° Formulario Ingreso', ing.hojaIngresoNro),
                  _itemDetalle('N° de Parte Policial', ing.parteIngresoNro),
                  _itemDetalle('Parte Elaborado Por', ing.policiaNombre),
                  _itemDetalle('Servidor Policial Custodio Recibe', ing.custodioRecibeNombre),

                  _seccionTitulo('2. IDENTIFICACIÓN DEL VEHÍCULO'),
                  _itemDetalle('Placa', ing.placa.toUpperCase()),
                  _itemDetalle('Marca', ing.marca),
                  if (!esMoto) _itemDetalle('Tipo de Vehículo', ing.tipoVehiculo),
                  _itemDetalle('Modelo', ing.modelo),
                  _itemDetalle('Color', ing.color),
                  _itemDetalle('Año de Fabricación', ing.anioFabricacion),
                  _itemDetalle('Número de Chasis', ing.chasis),
                  _itemDetalle('Número de Motor', ing.motor),
                  _itemDetalle('Propietario / Responsable', ing.propietario),

                  _seccionTitulo('3. SITUACIÓN LEGAL Y TRASLADO'),
                  _itemDetalle('Situación Legal', ing.causaLegal.isNotEmpty ? '${ing.causaLegal} - ${ing.detalleCausa}' : ing.causaPrincipal),
                  _itemDetalle('Autoridad que Conoce', ing.autoridadRequirente.isNotEmpty ? ing.autoridadRequirente : 'NO APLICA'),
                  _itemDetalle('Placa Grúa', lib?.placaGrua.isNotEmpty == true ? lib!.placaGrua : (ing.placaGrua.isNotEmpty ? ing.placaGrua : 'N/A')),
                  _itemDetalle('Conductor Grúa', ing.conductorGrua.isNotEmpty ? ing.conductorGrua : (ing.nombreGruaParticular.isNotEmpty ? ing.nombreGruaParticular : 'N/A')),

                  _seccionTitulo('4. SALIDA Y ORDEN DE LIBERTAD'),
                  _itemDetalle('Fecha de Egreso', lib?.fechaSalida ?? 'Pendiente'),
                  _itemDetalle('N° Formulario Egreso', lib != null ? ing.hojaIngresoNro : 'Pendiente'),
                  _itemDetalle('Orden de Libertad Autoridad', lib?.oficioDevolucionNro ?? 'N/A'),
                  _itemDetalle('Señor Jefe que Emite Libertad', lib?.firmadoPor ?? 'N/A'),
                  _itemDetalle('Persona a quien se Entrega', lib?.retiradoPor ?? 'N/A'),
                  _itemDetalle('Cédula de quien Retira', lib?.cedulaRetira ?? 'N/A'),
                  _itemDetalle('Servidor Policial Custodio Entrega', lib?.custodioEntregaNombre ?? 'N/A'),

                  _seccionTitulo('5. LIQUIDACIÓN DE GARAJE / VALORES'),
                  if (!esMoto) _itemDetalle('Tipo de Trámite / Proceso', tipoCobro.isNotEmpty ? tipoCobro : 'N/A'),
                  _itemDetalle('Días de Permanencia', dias != null ? '$dias días' : 'Pendiente'),
                  if (!esMoto) _itemDetalle('Tarifa Diaria', tarifa > 0 ? '\$$tarifa / día' : '\$0'),
                  _itemDetalle('Valor Cancelado Parqueo', valorTotal != null ? '\$${valorTotal.toStringAsFixed(2)}' : (lib != null ? '\$${lib.valorTotalGaraje}' : '\$0.00')),
                  _itemDetalle('N° Orden de Pago Garaje', primerPago?.ordenPagoNro ?? 'N/A'),
                  _itemDetalle('Fecha de Pago en Entidad', primerPago?.horaFechaPago ?? 'N/A'),
                  _itemDetalle('N° Comprobante de Pago', primerPago?.comprobantePagoNro ?? 'N/A'),
                  _itemDetalle('Institución Financiera', banco.isNotEmpty ? banco : 'N/A'),

                  _seccionTitulo('6. ALCOHOCHECK E INVESTIGACIÓN PERICIAL'),
                  _itemDetalle('N° Orden Pago Alcohocheck', lib?.ordenPagoAlcohocheckNro.isNotEmpty == true ? lib!.ordenPagoAlcohocheckNro : (ing.ordenPagoAlcohocheckNro.isNotEmpty ? ing.ordenPagoAlcohocheckNro : 'N/A')),
                  _itemDetalle('Valor Cancelado Alcohocheck', lib?.valorAlcohocheck.isNotEmpty == true ? '\$${lib!.valorAlcohocheck}' : (ing.valorAlcohocheck.isNotEmpty ? '\$${ing.valorAlcohocheck}' : 'N/A')),
                  _itemDetalle('Pericias Realizadas', lib?.periciaRealizada.isNotEmpty == true ? lib!.periciaRealizada : 'N/A'),
                  _itemDetalle('Nombre del Perito', lib?.peritoNombre.isNotEmpty == true ? lib!.peritoNombre : 'N/A'),
                  _itemDetalle('Fecha de Pago Peritaje', lib?.horaFechaPagoAlcohocheck.isNotEmpty == true ? lib!.horaFechaPagoAlcohocheck : 'N/A'),
                  _itemDetalle('N° Comprobante Peritaje', lib?.comprobantePagoAlcohocheckNro.isNotEmpty == true ? lib!.comprobantePagoAlcohocheckNro : 'N/A'),
                  const SizedBox(height: 18),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _seccionTitulo(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        titulo,
        style: const TextStyle(
          color: Color(0xFF5BA3F5),
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _itemDetalle(String label, String valor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              valor.isEmpty ? 'N/A' : valor,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabla(bool esMoto) {
    final registros = _filtrarLista(esMoto);

    if (registros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              _filtroTexto.isNotEmpty
                  ? 'No se encontraron resultados para "$_filtroTexto"'
                  : 'No hay registros cargados en esta categoría.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Indicador de ayuda al usuario
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                'Mostrando ${registros.length} registros',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              const Icon(Icons.touch_app_outlined, color: Colors.cyanAccent, size: 14),
              const SizedBox(width: 4),
              const Text(
                'Toca una fila para ver los 45 casilleros',
                style: TextStyle(color: Colors.cyanAccent, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.white12,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF0F2347)),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return Colors.white.withValues(alpha: 0.08);
                    }
                    return Colors.transparent;
                  }),
                  headingTextStyle: const TextStyle(
                    color: Color(0xFF5BA3F5),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  dataTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  columnSpacing: 18,
                  horizontalMargin: 12,
                  columns: [
                    const DataColumn(label: Text('ORD.')),
                    const DataColumn(label: Text('ESTADO')),
                    const DataColumn(label: Text('PLACA')),
                    const DataColumn(label: Text('F. INGRESO')),
                    const DataColumn(label: Text('HOJA / FORM.')),
                    const DataColumn(label: Text('MARCA')),
                    if (!esMoto) const DataColumn(label: Text('TIPO')),
                    const DataColumn(label: Text('MODELO')),
                    const DataColumn(label: Text('COLOR')),
                    const DataColumn(label: Text('PROPIETARIO')),
                    const DataColumn(label: Text('F. EGRESO')),
                    const DataColumn(label: Text('DÍAS')),
                    if (!esMoto) const DataColumn(label: Text('TARIFA')),
                    const DataColumn(label: Text('TOTAL')),
                    const DataColumn(label: Text('ORDEN PAGO')),
                    const DataColumn(label: Text('BANCO')),
                  ],
                  rows: List<DataRow>.generate(registros.length, (index) {
                    final ing = registros[index];
                    final lib = _libertadDe(ing);
                    final dias = lib != null ? _calcularDias(ing.fechaIngreso, lib.fechaSalida) : null;
                    final tipoCobro = ing.tipoCobroParqueo.isNotEmpty ? ing.tipoCobroParqueo : (lib?.tipoServicioGaraje ?? '');
                    final tarifa = _tarifaDiaria(tipoCobro);
                    final valorTotal = (dias != null && tarifa > 0) ? (dias * tarifa) : null;
                    final primerPago = (lib != null && lib.pagos.isNotEmpty) ? lib.pagos.first : null;
                    final banco = primerPago != null
                        ? (primerPago.entidadFinancieraOficial.isNotEmpty
                            ? primerPago.entidadFinancieraOficial
                            : primerPago.entidadFinanciera)
                        : '';

                    final enPatio = lib == null;

                    return DataRow(
                      onSelectChanged: (_) => _verDetalleCompleto(ing, lib, index + 1, esMoto),
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: enPatio ? Colors.amber.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: enPatio ? Colors.amber : Colors.greenAccent),
                            ),
                            child: Text(
                              enPatio ? 'EN PATIO' : 'SALIDA',
                              style: TextStyle(
                                color: enPatio ? Colors.amberAccent : Colors.greenAccent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(ing.placa.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(ing.fechaIngreso)),
                        DataCell(Text(ing.hojaIngresoNro)),
                        DataCell(Text(ing.marca)),
                        if (!esMoto) DataCell(Text(ing.tipoVehiculo)),
                        DataCell(Text(ing.modelo)),
                        DataCell(Text(ing.color)),
                        DataCell(Text(ing.propietario)),
                        DataCell(Text(lib?.fechaSalida ?? '-')),
                        DataCell(Text(dias != null ? '$dias' : '-')),
                        if (!esMoto) DataCell(Text(tarifa > 0 ? '\$$tarifa' : '-')),
                        DataCell(Text(valorTotal != null ? '\$${valorTotal.toStringAsFixed(0)}' : '-')),
                        DataCell(Text(primerPago?.ordenPagoNro ?? '-')),
                        DataCell(Text(banco.isNotEmpty ? banco : '-')),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17356E),
      appBar: AppBar(
        title: const Text('Matriz General de Ingresos y Salidas'),
        backgroundColor: const Color(0xFF132B59),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar datos',
            onPressed: _cargarDatos,
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Descargar archivo Excel (.xlsx)',
            onPressed: () => _exportarOCompartirExcel(descargarDirecto: true),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Compartir matriz (.xlsx)',
            onPressed: () => _exportarOCompartirExcel(descargarDirecto: false),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car_rounded), text: 'VEHÍCULOS'),
            Tab(icon: Icon(Icons.two_wheeler_rounded), text: 'MOTOCICLETAS'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF132B59), Color(0xFF17356E)],
          ),
        ),
        child: _cargando
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.purpleAccent),
                    SizedBox(height: 16),
                    Text(
                      'Cargando registros de la matriz...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Barra de búsqueda rápida
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _busquedaCtrl,
                      onChanged: (val) => setState(() => _filtroTexto = val),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar por placa, propietario o N° de hoja...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent, size: 20),
                        suffixIcon: _filtroTexto.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                                onPressed: () {
                                  _busquedaCtrl.clear();
                                  setState(() => _filtroTexto = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purpleAccent),
                        ),
                      ),
                    ),
                  ),

                  // Contenido de las pestañas
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabla(false),
                        _buildTabla(true),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
