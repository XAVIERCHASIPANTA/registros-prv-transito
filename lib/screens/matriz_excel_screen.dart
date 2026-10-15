import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import '../services/storage_service.dart';
import '../services/excel_importer_service.dart';
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
  String _filtroOrigen = 'todos'; // 'todos', 'excel', 'app'
  bool _vistaCompleta = true; // true: 45/37 columnas oficiales, false: 16 columnas resumen

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
      var ing = await StorageService.obtenerIngresos();
      var lib = await StorageService.obtenerLibertades();
      if (ing.length < 20) {
        await StorageService.cargarMatrizHistoricaExcel();
        ing = await StorageService.obtenerIngresos();
        lib = await StorageService.obtenerLibertades();
      }
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

  Future<void> _subirMatrizExcel() async {
    try {
      final res = await ExcelImporterService.seleccionarYProcesarExcel();
      if (res == null) return;

      if (!mounted) return;
      final accion = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF132B59),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.upload_file_rounded, color: Colors.greenAccent),
              SizedBox(width: 10),
              Text('Matriz Excel Detectada', style: TextStyle(color: Colors.white, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (res.patioDetectado.isNotEmpty) ...[
                Text(
                  'CRV / Patio: ${res.patioDetectado}',
                  style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
              ],
              if (res.subzonaDetectada.isNotEmpty) ...[
                Text('Subzona: ${res.subzonaDetectada}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
              ],
              Text('• ${res.vehiculosCount} vehículos en hoja VEHÍCULOS', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text('• ${res.motosCount} motocicletas en hoja MOTOCICLETAS', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text('• Total de ingresos: ${res.ingresos.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('• Registros con salida: ${res.libertades.length}', style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
              const Divider(color: Colors.white24, height: 24),
              const Text(
                '¿Cómo deseas importar esta matriz?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 6),
              const Text(
                '• "REEMPLAZAR" es ideal para iniciar un nuevo patio (ej. CRV La Marujita), limpiando los datos previos.\n'
                '• "COMBINAR" conserva tus datos actuales y añade los nuevos sin duplicar placas.',
                style: TextStyle(color: Colors.white60, fontSize: 11.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancelar'),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E5BB0)),
              onPressed: () => Navigator.pop(ctx, 'combinar'),
              child: const Text('COMBINAR', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
              onPressed: () => Navigator.pop(ctx, 'reemplazar'),
              child: const Text('REEMPLAZAR (Nuevo Patio)', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (accion == 'combinar' || accion == 'reemplazar') {
        setState(() => _cargando = true);
        final reemplazar = accion == 'reemplazar';
        await StorageService.aplicarImportacionExcel(
          nuevosIngresos: res.ingresos,
          nuevasLibertades: res.libertades,
          reemplazar: reemplazar,
        );
        await _cargarDatos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                reemplazar
                    ? '¡Matriz reemplazada con éxito! Se cargaron ${res.ingresos.length} registros del patio.'
                    : '¡Matriz combinada con éxito! Se verificaron ${res.ingresos.length} registros.',
              ),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir matriz Excel: $e')),
        );
      }
    }
  }

  Future<void> _desincronizarMatriz() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132B59),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('¿Desincronizar Matriz?', style: TextStyle(color: Colors.white, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Esta acción vacía los registros locales de la matriz para que puedas cargar la matriz de otro patio desde cero (ejemplo: CRV La Marujita con 1.120 motos).\n\n¿Estás seguro de continuar?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('VACIAR MATRIZ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _cargando = true);
      await StorageService.vaciarMatrizLocal();
      await _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Matriz vaciada. Puedes subir un nuevo archivo Excel o comenzar nuevos registros.'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    }
  }

  Future<void> _recargarMatrizHistorica() async {
    setState(() => _cargando = true);
    try {
      final nuevos = await StorageService.cargarMatrizHistoricaExcel();
      final ing = await StorageService.obtenerIngresos();
      final lib = await StorageService.obtenerLibertades();
      if (mounted) {
        setState(() {
          _ingresos = ing;
          _libertades = lib;
          _cargando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevos > 0
                  ? '¡Se sincronizaron $nuevos registros de la matriz Excel con éxito!'
                  : 'Todos los registros de la matriz Excel están al día (${_ingresos.length} registros).',
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al recargar matriz: $e')),
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
    // 1. Separar por tipo (vehículo vs moto) y origen
    final lista = _ingresos.where((i) {
      final moto = i.tipoVehiculo.trim().toUpperCase() == 'MOTOCICLETA';
      final coincideTipo = esMoto ? moto : !moto;
      if (!coincideTipo) return false;

      if (_filtroOrigen == 'excel') return i.esDeExcel;
      if (_filtroOrigen == 'app') return i.esDeApp;
      return true;
    }).toList();

    // Ordenar de forma natural: primero registros históricos de Excel y luego los registros de la App
    lista.sort((a, b) {
      if (a.esDeExcel && !b.esDeExcel) return -1;
      if (!a.esDeExcel && b.esDeExcel) return 1;
      return a.creado.compareTo(b.creado);
    });

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
                          color: ing.esDeApp
                              ? Colors.cyanAccent.withValues(alpha: 0.2)
                              : Colors.purpleAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          ing.esDeApp ? Icons.phone_android_rounded : Icons.table_view_rounded,
                          color: ing.esDeApp ? Colors.cyanAccent : Colors.purpleAccent,
                          size: 24,
                        ),
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
                            Row(
                              children: [
                                Text(
                                  lib != null ? 'ESTADO: SALIDO / LIBERTAD' : 'ESTADO: EN PATIO',
                                  style: TextStyle(
                                    color: lib != null ? Colors.greenAccent : Colors.amberAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ing.esDeApp ? Colors.cyan.withValues(alpha: 0.2) : Colors.white12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    ing.esDeApp ? '📱 Registrado por App' : '📁 Matriz Excel',
                                    style: TextStyle(
                                      color: ing.esDeApp ? Colors.cyanAccent : Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
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
                  _itemDetalle('Situación Legal', ing.situacionLegalFormateada),
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

  // Construcción de la tabla completa (todas las 45 columnas para carros, 37 para motos)
  Widget _buildTabla(bool esMoto) {
    final registros = _filtrarLista(esMoto);

    // Contadores para chips informativos
    final totalCategoria = _ingresos.where((i) {
      final moto = i.tipoVehiculo.trim().toUpperCase() == 'MOTOCICLETA';
      return esMoto ? moto : !moto;
    }).length;

    final excelCount = _ingresos.where((i) {
      final moto = i.tipoVehiculo.trim().toUpperCase() == 'MOTOCICLETA';
      return (esMoto ? moto : !moto) && i.esDeExcel;
    }).length;

    final appCount = _ingresos.where((i) {
      final moto = i.tipoVehiculo.trim().toUpperCase() == 'MOTOCICLETA';
      return (esMoto ? moto : !moto) && i.esDeApp;
    }).length;

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
                  : 'No hay registros en esta categoría.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _subirMatrizExcel,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Subir Archivo Excel (.xlsx)'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E5BB0)),
            ),
          ],
        ),
      );
    }

    // Buscamos si hay transición entre Excel y App en la lista filtrada
    int primerIndiceApp = -1;
    for (int i = 0; i < registros.length; i++) {
      if (registros[i].esDeApp) {
        primerIndiceApp = i;
        break;
      }
    }

    return Column(
      children: [
        // Barra de estado y filtros de origen
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF10254C),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chipOrigen('todos', 'Todos ($totalCategoria)', Icons.format_list_bulleted),
                          const SizedBox(width: 8),
                          _chipOrigen('excel', '📁 Matriz Excel ($excelCount)', Icons.table_chart_rounded),
                          const SizedBox(width: 8),
                          _chipOrigen('app', '📱 Registrados con App ($appCount)', Icons.phone_android_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón para alternar 45 columnas / 16 columnas
                  InkWell(
                    onTap: () => setState(() => _vistaCompleta = !_vistaCompleta),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _vistaCompleta ? Colors.purpleAccent.withValues(alpha: 0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _vistaCompleta ? Colors.purpleAccent : Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _vistaCompleta ? Icons.view_column_rounded : Icons.table_rows_rounded,
                            color: _vistaCompleta ? Colors.purpleAccent : Colors.white70,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _vistaCompleta
                                ? (esMoto ? '37 Columnas' : '45 Columnas')
                                : 'Vista Resumen',
                            style: TextStyle(
                              color: _vistaCompleta ? Colors.purpleAccent : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Banner distintivo si hay vehículos registrados con la aplicación en la vista
        if (appCount > 0 && _filtroOrigen == 'todos')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade900.withValues(alpha: 0.6),
                  Colors.indigo.shade900.withValues(alpha: 0.6),
                ],
              ),
              border: const Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.cyanAccent, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Se muestran $excelCount vehículos históricos de Excel y $appCount registrados desde la App.',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

        // Tabla scrollable
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.white12),
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
                    fontSize: 11.5,
                  ),
                  dataTextStyle: const TextStyle(color: Colors.white, fontSize: 11.5),
                  columnSpacing: 16,
                  horizontalMargin: 12,
                  columns: _generarColumnas(esMoto),
                  rows: List<DataRow>.generate(registros.length, (index) {
                    final ing = registros[index];
                    final lib = _libertadDe(ing);
                    final esPrimerRegistroApp = (index == primerIndiceApp && _filtroOrigen == 'todos');

                    return _generarFila(
                      ing: ing,
                      lib: lib,
                      ord: index + 1,
                      esMoto: esMoto,
                      esPrimerApp: esPrimerRegistroApp,
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

  Widget _chipOrigen(String clave, String label, IconData icono) {
    final seleccionado = _filtroOrigen == clave;
    return InkWell(
      onTap: () => setState(() => _filtroOrigen = clave),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: seleccionado ? const Color(0xFF1E5BB0) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: seleccionado ? Colors.blueAccent : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: seleccionado ? Colors.white : Colors.white60),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: seleccionado ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataColumn> _generarColumnas(bool esMoto) {
    if (!_vistaCompleta) {
      // Vista resumen de 16 columnas
      return [
        const DataColumn(label: Text('ORD.')),
        const DataColumn(label: Text('ORIGEN')),
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
      ];
    }

    if (!esMoto) {
      // 45 Columnas Oficiales para VEHÍCULOS
      return const [
        DataColumn(label: Text('1. ORD.')),
        DataColumn(label: Text('2. SUBZONA')),
        DataColumn(label: Text('3. CENTRO DE RETENCIÓN')),
        DataColumn(label: Text('4. FECHA DE INGRESO')),
        DataColumn(label: Text('5. N° FORMULARIO INGRESO')),
        DataColumn(label: Text('6. PLACA')),
        DataColumn(label: Text('7. MARCA')),
        DataColumn(label: Text('8. TIPO')),
        DataColumn(label: Text('9. MODELO')),
        DataColumn(label: Text('10. COLOR')),
        DataColumn(label: Text('11. AÑO FABRICACIÓN')),
        DataColumn(label: Text('12. N° CHASIS')),
        DataColumn(label: Text('13. N° MOTOR')),
        DataColumn(label: Text('14. N° PARTE')),
        DataColumn(label: Text('15. PARTE ELABORADO POR')),
        DataColumn(label: Text('16. PROPIETARIO / RESPONSABLE')),
        DataColumn(label: Text('17. SITUACIÓN LEGAL')),
        DataColumn(label: Text('18. AUTORIDAD QUE CONOCE')),
        DataColumn(label: Text('19. PLACA-GRÚA')),
        DataColumn(label: Text('20. CONDUCTOR GRÚA')),
        DataColumn(label: Text('21. CUSTODIO RECIBE')),
        DataColumn(label: Text('22. FECHA EGRESO')),
        DataColumn(label: Text('23. ORDEN DE LIBERTAD')),
        DataColumn(label: Text('24. JEFE EMITE LIBERTAD')),
        DataColumn(label: Text('25. PERSONA ENTREGA')),
        DataColumn(label: Text('26. CÉDULA RETIRA')),
        DataColumn(label: Text('27. N° ORDEN PAGO GARAJE')),
        DataColumn(label: Text('28. TIPO TRÁMITE / PROCESO')),
        DataColumn(label: Text('29. DÍAS PERMANENCIA')),
        DataColumn(label: Text('30. TARIFA DIARIA')),
        DataColumn(label: Text('31. VALOR PARQUEO')),
        DataColumn(label: Text('32. N° ORDEN PAGO')),
        DataColumn(label: Text('33. FECHA PAGO BANCO')),
        DataColumn(label: Text('34. N° COMPROBANTE PAGO')),
        DataColumn(label: Text('35. INSTITUCIÓN FINANCIERA')),
        DataColumn(label: Text('36. NOMBRE INST. FINANCIERA')),
        DataColumn(label: Text('37. N° FORMULARIO EGRESO')),
        DataColumn(label: Text('38. CUSTODIO ENTREGA')),
        DataColumn(label: Text('39. N° ORDEN ALCOHOCHECK')),
        DataColumn(label: Text('40. VALOR ALCOHOCHECK')),
        DataColumn(label: Text('41. PERICIAS REALIZADAS')),
        DataColumn(label: Text('42. NOMBRE DEL PERITO')),
        DataColumn(label: Text('43. FECHA PAGO PERITAJE')),
        DataColumn(label: Text('44. N° COMPROBANTE PERITAJE')),
        DataColumn(label: Text('45. INST. FINANCIERA PERITAJE')),
      ];
    } else {
      // 37 Columnas Oficiales para MOTOCICLETAS
      return const [
        DataColumn(label: Text('1. ORD.')),
        DataColumn(label: Text('2. SUBZONA')),
        DataColumn(label: Text('3. CENTRO DE RETENCIÓN')),
        DataColumn(label: Text('4. FECHA DE INGRESO')),
        DataColumn(label: Text('5. N° FORMULARIO INGRESO')),
        DataColumn(label: Text('6. PLACA')),
        DataColumn(label: Text('7. MARCA')),
        DataColumn(label: Text('8. MODELO')),
        DataColumn(label: Text('9. COLOR')),
        DataColumn(label: Text('10. AÑO FABRICACIÓN')),
        DataColumn(label: Text('11. N° CHASIS')),
        DataColumn(label: Text('12. N° MOTOR')),
        DataColumn(label: Text('13. N° PARTE')),
        DataColumn(label: Text('14. PARTE ELABORADO POR')),
        DataColumn(label: Text('15. PROPIETARIO / RESPONSABLE')),
        DataColumn(label: Text('16. SITUACIÓN LEGAL')),
        DataColumn(label: Text('17. AUTORIDAD QUE CONOCE')),
        DataColumn(label: Text('18. PLACA-GRÚA')),
        DataColumn(label: Text('19. CONDUCTOR GRÚA')),
        DataColumn(label: Text('20. CUSTODIO RECIBE')),
        DataColumn(label: Text('21. FECHA EGRESO')),
        DataColumn(label: Text('22. ORDEN DE LIBERTAD')),
        DataColumn(label: Text('23. JEFE EMITE LIBERTAD')),
        DataColumn(label: Text('24. PERSONA ENTREGA')),
        DataColumn(label: Text('25. CÉDULA RETIRA')),
        DataColumn(label: Text('26. N° ORDEN PAGO GARAJE')),
        DataColumn(label: Text('27. DÍAS PARQUEO')),
        DataColumn(label: Text('28. VALOR PARQUEO')),
        DataColumn(label: Text('29. N° FORMULARIO EGRESO')),
        DataColumn(label: Text('30. CUSTODIO ENTREGA')),
        DataColumn(label: Text('31. N° ORDEN ALCOHOCHECK')),
        DataColumn(label: Text('32. VALOR ALCOHOCHECK')),
        DataColumn(label: Text('33. PERICIAS REALIZADAS')),
        DataColumn(label: Text('34. NOMBRE DEL PERITO')),
        DataColumn(label: Text('35. FECHA PAGO PERITAJE')),
        DataColumn(label: Text('36. N° COMPROBANTE PERITAJE')),
        DataColumn(label: Text('37. INST. FINANCIERA PERITAJE')),
      ];
    }
  }

  DataRow _generarFila({
    required CasoIngreso ing,
    required CasoLibertad? lib,
    required int ord,
    required bool esMoto,
    required bool esPrimerApp,
  }) {
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

    final situacionLegal = ing.situacionLegalFormateada;

    final autoridad = ing.autoridadRequirente.isNotEmpty
        ? ing.autoridadRequirente
        : (lib?.firmadoPor.isNotEmpty == true ? 'FISCALIA' : 'N/A');

    final placaGrua = lib?.placaGrua.isNotEmpty == true
        ? lib!.placaGrua
        : (ing.placaGrua.isNotEmpty ? ing.placaGrua : 'N/A');

    final conductorGrua = ing.conductorGrua.isNotEmpty
        ? ing.conductorGrua
        : (ing.nombreGruaParticular.isNotEmpty ? ing.nombreGruaParticular : 'N/A');

    final ordenPagoGaraje = primerPago?.ordenPagoNro ?? '';
    final comprobanteGaraje = primerPago?.comprobantePagoNro ?? '';
    final fechaPagoGaraje = primerPago?.horaFechaPago ?? '';

    final ordenPagoAlcoho = lib?.ordenPagoAlcohocheckNro.isNotEmpty == true
        ? lib!.ordenPagoAlcohocheckNro
        : (ing.ordenPagoAlcohocheckNro.isNotEmpty ? ing.ordenPagoAlcohocheckNro : 'N/A');

    final valorAlcoho = lib?.valorAlcohocheck.isNotEmpty == true
        ? lib!.valorAlcohocheck
        : (ing.valorAlcohocheck.isNotEmpty ? ing.valorAlcohocheck : 'N/A');

    final pericia = lib?.periciaRealizada.isNotEmpty == true ? lib!.periciaRealizada : 'N/A';
    final perito = lib?.peritoNombre.isNotEmpty == true ? lib!.peritoNombre : 'N/A';
    final fechaPagoPericia = lib?.horaFechaPagoAlcohocheck.isNotEmpty == true
        ? lib!.horaFechaPagoAlcohocheck
        : fechaPagoGaraje;
    final compPagoPericia = lib?.comprobantePagoAlcohocheckNro.isNotEmpty == true
        ? lib!.comprobantePagoAlcohocheckNro
        : comprobanteGaraje;
    final bancoPericia = banco;

    final enPatio = lib == null;

    if (!_vistaCompleta) {
      // 16 celdas resumen
      return DataRow(
        onSelectChanged: (_) => _verDetalleCompleto(ing, lib, ord, esMoto),
        cells: [
          DataCell(Text('$ord')),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ing.esDeApp ? Colors.cyan.withValues(alpha: 0.15) : Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ing.esDeApp ? '📱 App' : '📁 Excel',
                style: TextStyle(
                  color: ing.esDeApp ? Colors.cyanAccent : Colors.white70,
                  fontSize: 10,
                ),
              ),
            ),
          ),
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
    }

    if (!esMoto) {
      // 45 celdas para VEHÍCULOS
      return DataRow(
        onSelectChanged: (_) => _verDetalleCompleto(ing, lib, ord, esMoto),
        cells: [
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$ord'),
              if (ing.esDeApp)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.phone_android_rounded, size: 12, color: Colors.cyanAccent),
                ),
            ],
          )),
          DataCell(Text(ing.subzona.isNotEmpty ? ing.subzona : 'SANTO DOMINGO')),
          DataCell(Text(ing.crv.isNotEmpty ? ing.crv : 'CONTROL 120')),
          DataCell(Text(ing.fechaIngreso)),
          DataCell(Text(ing.hojaIngresoNro)),
          DataCell(Text(ing.placa.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent))),
          DataCell(Text(ing.marca)),
          DataCell(Text(ing.tipoVehiculo)),
          DataCell(Text(ing.modelo)),
          DataCell(Text(ing.color)),
          DataCell(Text(ing.anioFabricacion)),
          DataCell(Text(ing.chasis)),
          DataCell(Text(ing.motor)),
          DataCell(Text(ing.parteIngresoNro)),
          DataCell(Text(ing.policiaNombre)),
          DataCell(Text(ing.propietario)),
          DataCell(Text(situacionLegal)),
          DataCell(Text(autoridad)),
          DataCell(Text(placaGrua)),
          DataCell(Text(conductorGrua)),
          DataCell(Text(ing.custodioRecibeNombre)),
          DataCell(Text(lib?.fechaSalida ?? '-')),
          DataCell(Text(lib?.oficioDevolucionNro ?? '-')),
          DataCell(Text(lib?.firmadoPor ?? '-')),
          DataCell(Text(lib?.retiradoPor ?? '-')),
          DataCell(Text(lib?.cedulaRetira ?? '-')),
          DataCell(Text(ordenPagoGaraje.isNotEmpty ? ordenPagoGaraje : '-')),
          DataCell(Text(tipoCobro.isNotEmpty ? tipoCobro : '-')),
          DataCell(Text(dias != null ? '$dias' : '-')),
          DataCell(Text(tarifa > 0 ? '\$$tarifa' : '-')),
          DataCell(Text(valorTotal != null ? '\$${valorTotal.toStringAsFixed(2)}' : (lib != null ? '\$${lib.valorTotalGaraje}' : '-'))),
          DataCell(Text(ordenPagoGaraje.isNotEmpty ? ordenPagoGaraje : '-')),
          DataCell(Text(fechaPagoGaraje.isNotEmpty ? fechaPagoGaraje : '-')),
          DataCell(Text(comprobanteGaraje.isNotEmpty ? comprobanteGaraje : '-')),
          DataCell(Text(banco.isNotEmpty ? banco : '-')),
          DataCell(Text(banco.isNotEmpty ? banco : '-')),
          DataCell(Text(lib != null ? ing.hojaIngresoNro : '-')),
          DataCell(Text(lib?.custodioEntregaNombre ?? '-')),
          DataCell(Text(ordenPagoAlcoho)),
          DataCell(Text(valorAlcoho.isNotEmpty ? '\$$valorAlcoho' : '-')),
          DataCell(Text(pericia)),
          DataCell(Text(perito)),
          DataCell(Text(fechaPagoPericia.isNotEmpty ? fechaPagoPericia : '-')),
          DataCell(Text(compPagoPericia.isNotEmpty ? compPagoPericia : '-')),
          DataCell(Text(bancoPericia.isNotEmpty ? bancoPericia : '-')),
        ],
      );
    } else {
      // 37 celdas para MOTOCICLETAS
      return DataRow(
        onSelectChanged: (_) => _verDetalleCompleto(ing, lib, ord, esMoto),
        cells: [
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$ord'),
              if (ing.esDeApp)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.phone_android_rounded, size: 12, color: Colors.cyanAccent),
                ),
            ],
          )),
          DataCell(Text(ing.subzona.isNotEmpty ? ing.subzona : 'SANTO DOMINGO')),
          DataCell(Text(ing.crv.isNotEmpty ? ing.crv : 'CONTROL 120')),
          DataCell(Text(ing.fechaIngreso)),
          DataCell(Text(ing.hojaIngresoNro)),
          DataCell(Text(ing.placa.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent))),
          DataCell(Text(ing.marca)),
          DataCell(Text(ing.modelo)),
          DataCell(Text(ing.color)),
          DataCell(Text(ing.anioFabricacion)),
          DataCell(Text(ing.chasis)),
          DataCell(Text(ing.motor)),
          DataCell(Text(ing.parteIngresoNro)),
          DataCell(Text(ing.policiaNombre)),
          DataCell(Text(ing.propietario)),
          DataCell(Text(situacionLegal)),
          DataCell(Text(autoridad)),
          DataCell(Text(placaGrua)),
          DataCell(Text(conductorGrua)),
          DataCell(Text(ing.custodioRecibeNombre)),
          DataCell(Text(lib?.fechaSalida ?? '-')),
          DataCell(Text(lib?.oficioDevolucionNro ?? '-')),
          DataCell(Text(lib?.firmadoPor ?? '-')),
          DataCell(Text(lib?.retiradoPor ?? '-')),
          DataCell(Text(lib?.cedulaRetira ?? '-')),
          DataCell(Text(ordenPagoGaraje.isNotEmpty ? ordenPagoGaraje : '-')),
          DataCell(Text(dias != null ? '$dias' : '-')),
          DataCell(Text(valorTotal != null ? '\$${valorTotal.toStringAsFixed(2)}' : (lib != null ? '\$${lib.valorTotalGaraje}' : '-'))),
          DataCell(Text(lib != null ? ing.hojaIngresoNro : '-')),
          DataCell(Text(lib?.custodioEntregaNombre ?? '-')),
          DataCell(Text(ordenPagoAlcoho)),
          DataCell(Text(valorAlcoho.isNotEmpty ? '\$$valorAlcoho' : '-')),
          DataCell(Text(pericia)),
          DataCell(Text(perito)),
          DataCell(Text(fechaPagoPericia.isNotEmpty ? fechaPagoPericia : '-')),
          DataCell(Text(compPagoPericia.isNotEmpty ? compPagoPericia : '-')),
          DataCell(Text(bancoPericia.isNotEmpty ? bancoPericia : '-')),
        ],
      );
    }
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
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Subir archivo Excel .xlsx (Nuevo Patio o Combinar)',
            onPressed: _subirMatrizExcel,
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Descargar archivo Excel (.xlsx)',
            onPressed: () => _exportarOCompartirExcel(descargarDirecto: true),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: const Color(0xFF132B59),
            tooltip: 'Más opciones',
            onSelected: (val) {
              if (val == 'subir') _subirMatrizExcel();
              if (val == 'vaciar') _desincronizarMatriz();
              if (val == 'sync_seed') _recargarMatrizHistorica();
              if (val == 'toggle_vista') setState(() => _vistaCompleta = !_vistaCompleta);
              if (val == 'descargar') _exportarOCompartirExcel(descargarDirecto: true);
              if (val == 'compartir') _exportarOCompartirExcel(descargarDirecto: false);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'subir',
                child: Row(
                  children: [
                    const Icon(Icons.upload_file_rounded, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 10),
                    const Text('Subir Matriz Excel (.xlsx)', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_vista',
                child: Row(
                  children: [
                    Icon(
                      _vistaCompleta ? Icons.table_rows_rounded : Icons.view_column_rounded,
                      color: Colors.purpleAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _vistaCompleta ? 'Cambiar a Vista Resumen' : 'Cambiar a 45 Columnas',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sync_seed',
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 10),
                    const Text('Restaurar 65 vehículos de plantilla', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'vaciar',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    const Text('Desincronizar / Vaciar matriz', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(color: Colors.white24),
              PopupMenuItem(
                value: 'descargar',
                child: Row(
                  children: [
                    const Icon(Icons.download_rounded, color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    const Text('Descargar matriz (.xlsx)', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'compartir',
                child: Row(
                  children: [
                    const Icon(Icons.share_rounded, color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    const Text('Compartir matriz (.xlsx)', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
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
