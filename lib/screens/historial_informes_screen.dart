import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/informe_semanal_record.dart';
import '../services/storage_service.dart';
import '../services/pdf_informe_builder.dart';
import '../services/docx_builder.dart';

class HistorialInformesScreen extends StatefulWidget {
  const HistorialInformesScreen({super.key});

  @override
  State<HistorialInformesScreen> createState() => _HistorialInformesScreenState();
}

class _HistorialInformesScreenState extends State<HistorialInformesScreen> {
  final _busquedaCtrl = TextEditingController();
  List<InformeSemanalRecord> _historialCompleto = [];
  List<InformeSemanalRecord> _historialFiltrado = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    final lista = await StorageService.obtenerHistorialInformesSemanales();
    if (mounted) {
      setState(() {
        _historialCompleto = lista;
        _historialFiltrado = List.from(lista);
        _cargando = false;
      });
    }
  }

  void _filtrar(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _historialFiltrado = List.from(_historialCompleto);
      } else {
        _historialFiltrado = _historialCompleto.where((r) {
          return r.firmanteNombre.toLowerCase().contains(q) ||
              r.oficioNro.toLowerCase().contains(q) ||
              r.patio.toLowerCase().contains(q) ||
              r.subzona.toLowerCase().contains(q) ||
              r.fechaOficio.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _reexportarPdf(InformeSemanalRecord r) async {
    final pdfBytes = await PdfInformeSemanalBuilder.buildPdf(
      jefaturaNombre: r.jefatura,
      patio: r.patio,
      subzona: r.subzona,
      subzonaAbrev: r.subzonaAbrev,
      oficioNro: r.oficioNro,
      fechaOficio: r.fechaOficio,
      asuntoOficioNro: 'PN-DNT-SCRV-QX-2025-045-O',
      asuntoOficioFecha: '30 de abril del 2025',
      destinatarioNombre: 'Cristian German Barreiros Tumipamba',
      destinatarioRango: 'Coronel de E.M',
      fechaLunes: r.semanaLunes,
      fechaDomingo: r.semanaDomingo,
      vehiculos: r.vehiculosCount,
      motocicletas: r.motocicletasCount,
      fojasStr: r.fojasCount.toString(),
      firmanteNombre: r.firmanteNombre,
      firmanteRango: r.firmanteRango,
      incluirEstampaFirma: true,
    );

    final xFile = XFile.fromData(
      pdfBytes,
      name: 'Informe semanal CRV ${r.patio}.pdf',
      mimeType: 'application/pdf',
    );
    await Share.shareXFiles([xFile], text: 'Informe Semanal Oficial (Historial) - CRV ${r.patio}');
  }

  Future<void> _reexportarWord(InformeSemanalRecord r) async {
    final bytes = DocxBuilder.buildInformeSemanal(
      jefaturaNombre: r.jefatura,
      patio: r.patio,
      subzona: r.subzona,
      subzonaAbrev: r.subzonaAbrev,
      oficioNro: r.oficioNro,
      fechaOficio: r.fechaOficio,
      asuntoOficioNro: 'PN-DNT-SCRV-QX-2025-045-O',
      asuntoOficioFecha: '30 de abril del 2025',
      destinatarioNombre: 'Cristian German Barreiros Tumipamba',
      destinatarioRango: 'Coronel de E.M',
      fechaLunes: r.semanaLunes,
      fechaDomingo: r.semanaDomingo,
      vehiculos: r.vehiculosCount,
      motocicletas: r.motocicletasCount,
      firmanteNombre: r.firmanteNombre,
      firmanteRango: r.firmanteRango,
    );

    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: 'Informe semanal CRV ${r.patio}.docx',
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    await Share.shareXFiles([xFile], text: 'Informe Semanal Word (Historial) - CRV ${r.patio}');
  }

  void _mostrarDetalle(InformeSemanalRecord r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detalle de Informe N° ${r.oficioNro}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _filaDetalle('Oficio:', r.oficioNro),
              _filaDetalle('Fecha Oficio:', r.fechaOficio),
              _filaDetalle('CRV / Patio:', r.patio),
              _filaDetalle('Subzona:', r.subzona),
              _filaDetalle('Semana Reportada:', '${r.semanaLunes} → ${r.semanaDomingo}'),
              _filaDetalle('Vehículos Liberados:', '${r.vehiculosCount}'),
              _filaDetalle('Motocicletas Liberadas:', '${r.motocicletasCount}'),
              _filaDetalle('Total Liberaciones:', '${r.totalLiberaciones}'),
              _filaDetalle('Fojas Adjuntas:', '${r.fojasCount}'),
              const Divider(),
              _filaDetalle('Elaborado / Firmado por:', r.firmanteNombre),
              _filaDetalle('Rango / Grado:', r.firmanteRango),
              _filaDetalle('Firma Digital (.p12):', r.estaFirmadoDigitalmente ? 'SÍ (FirmaEC Activa)' : 'No registrada'),
              _filaDetalle('Fecha de Registro:', r.fechaGeneracion.toString().substring(0, 19)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('Compartir PDF'),
            onPressed: () {
              Navigator.pop(ctx);
              _reexportarPdf(r);
            },
          ),
        ],
      ),
    );
  }

  Widget _filaDetalle(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          children: [
            TextSpan(text: '$titulo ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Informes Semanales'),
        backgroundColor: const Color(0xFF17356E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF17356E),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por oficial firmante, oficio o fecha...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          _filtrar('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filtrar,
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _historialFiltrado.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No hay informes semanales en el historial.',
                              style: TextStyle(fontSize: 15, color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _historialFiltrado.length,
                        itemBuilder: (context, i) {
                          final r = _historialFiltrado[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.description_outlined, color: Color(0xFF17356E)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Oficio: ${r.oficioNro}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Fecha: ${r.fechaOficio} • CRV ${r.patio}',
                                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (r.estaFirmadoDigitalmente)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.verified, size: 14, color: Colors.green.shade800),
                                              const SizedBox(width: 4),
                                              Text(
                                                'FirmaEC',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Divider(height: 16),

                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 16, color: Colors.black54),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Firmante: ${r.firmanteNombre} (${r.firmanteRango})',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  Row(
                                    children: [
                                      const Icon(Icons.date_range, size: 16, color: Colors.black54),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Semana: ${r.semanaLunes} al ${r.semanaDomingo}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  Row(
                                    children: [
                                      Chip(
                                        label: Text('${r.vehiculosCount} Vehículos'),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 6),
                                      Chip(
                                        label: Text('${r.motocicletasCount} Motos'),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 6),
                                      Chip(
                                        label: Text('${r.fojasCount} Fojas'),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.info_outline, size: 16),
                                        label: const Text('Ver Detalle'),
                                        onPressed: () => _mostrarDetalle(r),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                        tooltip: 'Re-exportar PDF',
                                        onPressed: () => _reexportarPdf(r),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.description, color: Colors.blue),
                                        tooltip: 'Re-exportar Word',
                                        onPressed: () => _reexportarWord(r),
                                      ),
                                    ],
                                  ),
                                ],
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
