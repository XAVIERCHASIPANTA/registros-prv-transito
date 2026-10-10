import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/informe_semanal_record.dart';
import '../services/storage_service.dart';
import '../services/docx_builder.dart';
import '../services/firma_digital_service.dart';
import '../services/pdf_informe_builder.dart';
import '../widgets/firma_digital_dialog.dart';
import '../widgets/modal_password_firma_dialog.dart';
import 'historial_informes_screen.dart';

class InformeSemanalScreen extends StatefulWidget {
  const InformeSemanalScreen({super.key});

  @override
  State<InformeSemanalScreen> createState() => _InformeSemanalScreenState();
}

class _InformeSemanalScreenState extends State<InformeSemanalScreen> {
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  final _jefaturaController = TextEditingController();
  final _patioController = TextEditingController();
  final _subzonaController = TextEditingController();
  final _subzonaAbrevController = TextEditingController();
  final _oficioNroController = TextEditingController();
  final _fechaOficioController = TextEditingController();
  final _asuntoOficioNroController = TextEditingController();
  final _asuntoOficioFechaController = TextEditingController();
  final _destinatarioNombreController = TextEditingController();
  final _destinatarioRangoController = TextEditingController();
  final _fechaLunesController = TextEditingController();
  final _fechaDomingoController = TextEditingController();
  final _vehiculosController = TextEditingController();
  final _motocicletasController = TextEditingController();
  final _fojasController = TextEditingController();
  final _observacionController = TextEditingController();
  final _firmanteNombreController = TextEditingController();
  final _firmanteRangoController = TextEditingController();

  bool _cargando = true;
  bool _tieneFirmaP12 = false;
  DateTime? _lunes;
  DateTime? _domingo;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  String _formatoFecha(DateTime d) => '${d.day.toString().padLeft(2, '0')} de ${_meses[d.month - 1]} de ${d.year}';

  ({DateTime lunes, DateTime domingo}) _calcularUltimaSemana() {
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final diasDesdeDomingo = hoySinHora.weekday % 7;
    final diff = diasDesdeDomingo == 0 ? 7 : diasDesdeDomingo;
    final domingo = hoySinHora.subtract(Duration(days: diff));
    final lunes = domingo.subtract(const Duration(days: 6));
    return (lunes: lunes, domingo: domingo);
  }

  Future<void> _inicializar() async {
    final semana = _calcularUltimaSemana();
    _lunes = semana.lunes;
    _domingo = semana.domingo;

    final perfilUsuario = await StorageService.obtenerPerfilCompletoUsuario();
    final patioPerfil = perfilUsuario['patio'] ?? '';
    final jefaturaPerfil = perfilUsuario['jefatura'] ?? '';
    final subzonaPerfil = perfilUsuario['subzona'] ?? '';
    final nombrePerfil = perfilUsuario['nombre'] ?? '';
    final rangoPerfil = perfilUsuario['rango'] ?? '';

    _tieneFirmaP12 = await FirmaDigitalService.tieneCertificado();
    final datosFirma = await FirmaDigitalService.obtenerDatosFirmante();

    _jefaturaController.text = StorageService.ultimaSubzona.isNotEmpty 
        ? StorageService.ultimaSubzona.toUpperCase() 
        : (jefaturaPerfil.isNotEmpty 
            ? jefaturaPerfil.toUpperCase() 
            : (subzonaPerfil.isNotEmpty ? subzonaPerfil.toUpperCase() : 'SANTO DOMINGO'));
        
    _patioController.text = StorageService.ultimoCrv.isNotEmpty 
        ? StorageService.ultimoCrv.toUpperCase() 
        : (patioPerfil.isNotEmpty ? patioPerfil.toUpperCase() : 'CONTROL 120');
        
    _subzonaController.text = StorageService.ultimaSubzona.isNotEmpty 
        ? StorageService.ultimaSubzona 
        : (subzonaPerfil.isNotEmpty ? subzonaPerfil : 'Santo Domingo de los Tsáchilas');
        
    if (subzonaPerfil.toLowerCase().contains('esmeraldas')) {
      _subzonaAbrevController.text = 'ESM';
    } else if (subzonaPerfil.toLowerCase().contains('manabí') || subzonaPerfil.toLowerCase().contains('manabi')) {
      _subzonaAbrevController.text = 'MAN';
    } else if (subzonaPerfil.toLowerCase().contains('pichincha')) {
      _subzonaAbrevController.text = 'PICH';
    } else if (subzonaPerfil.toLowerCase().contains('guayas')) {
      _subzonaAbrevController.text = 'GUA';
    } else if (subzonaPerfil.toLowerCase().contains('azuay')) {
      _subzonaAbrevController.text = 'AZU';
    } else if (subzonaPerfil.toLowerCase().contains('loja')) {
      _subzonaAbrevController.text = 'LOJ';
    } else {
      _subzonaAbrevController.text = 'SDT';
    }
        
    _oficioNroController.text = StorageService.ultimoOficioInformeNro.isNotEmpty 
        ? StorageService.ultimoOficioInformeNro 
        : 'PN-SZ-${_subzonaAbrevController.text}-JPCTSV-CRV-2026-001-O';
        
    _asuntoOficioNroController.text = StorageService.ultimoAsuntoOficioNro.isNotEmpty 
        ? StorageService.ultimoAsuntoOficioNro 
        : 'PN-DNT-SCRV-QX-2025-045-O';
        
    _asuntoOficioFechaController.text = StorageService.ultimoAsuntoOficioFecha.isNotEmpty 
        ? StorageService.ultimoAsuntoOficioFecha 
        : '30 de abril del 2025';
        
    _destinatarioNombreController.text = StorageService.ultimoDestinatarioNombre.isNotEmpty 
        ? StorageService.ultimoDestinatarioNombre 
        : 'Cristian German Barreiros Tumipamba';
        
    _destinatarioRangoController.text = StorageService.ultimoDestinatarioRango.isNotEmpty 
        ? StorageService.ultimoDestinatarioRango 
        : 'Coronel de E.M';
        
    _firmanteNombreController.text = datosFirma['nombre']!.isNotEmpty
        ? datosFirma['nombre']!
        : (StorageService.ultimoFirmanteNombre.isNotEmpty
            ? StorageService.ultimoFirmanteNombre
            : (nombrePerfil.isNotEmpty ? nombrePerfil : 'Fausto Xavier Chasipanta Haro'));
            
    _firmanteRangoController.text = datosFirma['rango']!.isNotEmpty
        ? datosFirma['rango']!
        : (StorageService.ultimoFirmanteRango.isNotEmpty
            ? StorageService.ultimoFirmanteRango
            : (rangoPerfil.isNotEmpty ? rangoPerfil : 'Sargento Segundo De Policía'));

    _fechaOficioController.text = _formatoFecha(DateTime.now());
    _fechaLunesController.text = _formatoFecha(_lunes!);
    _fechaDomingoController.text = _formatoFecha(_domingo!);

    final conteo = await StorageService.contarLibertadesEnRango(_lunes!, _domingo!);
    _vehiculosController.text = conteo.vehiculos.toString();
    _motocicletasController.text = conteo.motocicletas.toString();

    final totalLiberados = conteo.vehiculos + conteo.motocicletas;
    _fojasController.text = (totalLiberados * 2).toString().padLeft(2, '0');

    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    for (final c in [
      _jefaturaController, _patioController, _subzonaController, _subzonaAbrevController,
      _oficioNroController, _fechaOficioController, _asuntoOficioNroController,
      _asuntoOficioFechaController, _destinatarioNombreController, _destinatarioRangoController,
      _fechaLunesController, _fechaDomingoController, _vehiculosController,
      _motocicletasController, _fojasController, _observacionController, _firmanteNombreController,
      _firmanteRangoController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _abrirConfigFirma() async {
    await FirmaDigitalDialog.mostrar(
      context,
      firmanteNombreInicial: _firmanteNombreController.text,
      firmanteRangoInicial: _firmanteRangoController.text,
    );
    final tiene = await FirmaDigitalService.tieneCertificado();
    final datos = await FirmaDigitalService.obtenerDatosFirmante();
    if (mounted) {
      setState(() {
        _tieneFirmaP12 = tiene;
        if (datos['nombre']!.isNotEmpty) {
          _firmanteNombreController.text = datos['nombre']!;
        }
        if (datos['rango']!.isNotEmpty) {
          _firmanteRangoController.text = datos['rango']!;
        }
      });
    }
  }

  Future<void> _registrarEnHistorial({required bool firmadoDigitalmente}) async {
    final vCount = int.tryParse(_vehiculosController.text.trim()) ?? 0;
    final mCount = int.tryParse(_motocicletasController.text.trim()) ?? 0;
    final fCount = int.tryParse(_fojasController.text.trim()) ?? 0;

    final record = InformeSemanalRecord(
      id: 'INF_${DateTime.now().millisecondsSinceEpoch}',
      oficioNro: _oficioNroController.text.trim(),
      fechaOficio: _fechaOficioController.text.trim(),
      patio: _patioController.text.trim(),
      jefatura: _jefaturaController.text.trim(),
      subzona: _subzonaController.text.trim(),
      subzonaAbrev: _subzonaAbrevController.text.trim(),
      semanaLunes: _fechaLunesController.text.trim(),
      semanaDomingo: _fechaDomingoController.text.trim(),
      vehiculosCount: vCount,
      motocicletasCount: mCount,
      totalLiberaciones: vCount + mCount,
      fojasCount: fCount,
      firmanteNombre: _firmanteNombreController.text.trim(),
      firmanteRango: _firmanteRangoController.text.trim(),
      estaFirmadoDigitalmente: firmadoDigitalmente,
      fechaGeneracion: DateTime.now(),
    );

    await StorageService.guardarInformeSemanalRecord(record);
  }

  Future<void> _generarYCompartirPdf() async {
    _guardarRecordados();
    final pdfUnsignedBytes = await PdfInformeSemanalBuilder.buildPdf(
      jefaturaNombre: _jefaturaController.text.trim(),
      patio: _patioController.text.trim(),
      subzona: _subzonaController.text.trim(),
      subzonaAbrev: _subzonaAbrevController.text.trim(),
      oficioNro: _oficioNroController.text.trim(),
      fechaOficio: _fechaOficioController.text.trim(),
      asuntoOficioNro: _asuntoOficioNroController.text.trim(),
      asuntoOficioFecha: _asuntoOficioFechaController.text.trim(),
      destinatarioNombre: _destinatarioNombreController.text.trim(),
      destinatarioRango: _destinatarioRangoController.text.trim(),
      fechaLunes: _fechaLunesController.text.trim(),
      fechaDomingo: _fechaDomingoController.text.trim(),
      vehiculos: int.tryParse(_vehiculosController.text.trim()) ?? 0,
      motocicletas: int.tryParse(_motocicletasController.text.trim()) ?? 0,
      fojasStr: _fojasController.text.trim(),
      observacionAdicional: _observacionController.text,
      firmanteNombre: _firmanteNombreController.text.trim(),
      firmanteRango: _firmanteRangoController.text.trim(),
      incluirEstampaFirma: true,
    );

    Uint8List? finalPdfBytes = pdfUnsignedBytes;
    bool firmadoDigital = false;

    if (mounted) {
      final resBytes = await ModalPasswordFirmaDialog.solicitarYFirmar(
        context,
        pdfUnsignedBytes: pdfUnsignedBytes,
        nombreFirmante: _firmanteNombreController.text.trim(),
      );
      if (resBytes != null) {
        finalPdfBytes = resBytes;
        firmadoDigital = true;
      } else {
        return;
      }
    }

    await _registrarEnHistorial(firmadoDigitalmente: firmadoDigital);

    final patioLimpio = _patioController.text.trim();
    final nombreArchivo = 'Informe semanal CRV $patioLimpio.pdf';

    final xFile = XFile.fromData(
      finalPdfBytes,
      name: nombreArchivo,
      mimeType: 'application/pdf',
    );
    await Share.shareXFiles([xFile], text: 'Informe semanal oficial PDF del CRV $patioLimpio');
  }

  Future<void> _generarYCompartirWord() async {
    _guardarRecordados();

    ByteData? templateData;
    try {
      templateData = await rootBundle.load('assets/informe_semanal_template.docx');
    } catch (e) {
      debugPrint('No se pudo cargar el asset del template: $e');
    }

    final bytes = DocxBuilder.buildInformeSemanal(
      templateBytes: templateData?.buffer.asUint8List(),
      jefaturaNombre: _jefaturaController.text.trim(),
      patio: _patioController.text.trim(),
      subzona: _subzonaController.text.trim(),
      subzonaAbrev: _subzonaAbrevController.text.trim(),
      oficioNro: _oficioNroController.text.trim(),
      fechaOficio: _fechaOficioController.text.trim(),
      asuntoOficioNro: _asuntoOficioNroController.text.trim(),
      asuntoOficioFecha: _asuntoOficioFechaController.text.trim(),
      destinatarioNombre: _destinatarioNombreController.text.trim(),
      destinatarioRango: _destinatarioRangoController.text.trim(),
      fechaLunes: _fechaLunesController.text.trim(),
      fechaDomingo: _fechaDomingoController.text.trim(),
      vehiculos: int.tryParse(_vehiculosController.text.trim()) ?? 0,
      motocicletas: int.tryParse(_motocicletasController.text.trim()) ?? 0,
      observacionAdicional: _observacionController.text,
      firmanteNombre: _firmanteNombreController.text.trim(),
      firmanteRango: _firmanteRangoController.text.trim(),
    );

    await _registrarEnHistorial(firmadoDigitalmente: false);

    final patioLimpio = _patioController.text.trim();
    final nombreArchivo = 'Informe semanal del CRV $patioLimpio.docx';

    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: nombreArchivo,
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    await Share.shareXFiles([xFile], text: 'Informe semanal del CRV $patioLimpio');
  }

  void _guardarRecordados() {
    StorageService.ultimoOficioInformeNro = _oficioNroController.text.trim();
    StorageService.ultimoAsuntoOficioNro = _asuntoOficioNroController.text.trim();
    StorageService.ultimoAsuntoOficioFecha = _asuntoOficioFechaController.text.trim();
    StorageService.ultimoDestinatarioNombre = _destinatarioNombreController.text.trim();
    StorageService.ultimoDestinatarioRango = _destinatarioRangoController.text.trim();
    StorageService.ultimoFirmanteNombre = _firmanteNombreController.text.trim();
    StorageService.ultimoFirmanteRango = _firmanteRangoController.text.trim();
  }

  void _abrirHistorial() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistorialInformesScreen()),
    );
  }

  void _abrirVistaPrevia() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VistaPreviaInformeSemanalScreen(
          jefaturaNombre: _jefaturaController.text.trim(),
          patio: _patioController.text.trim(),
          subzona: _subzonaController.text.trim(),
          subzonaAbrev: _subzonaAbrevController.text.trim(),
          oficioNro: _oficioNroController.text.trim(),
          fechaOficio: _fechaOficioController.text.trim(),
          asuntoOficioNro: _asuntoOficioNroController.text.trim(),
          asuntoOficioFecha: _asuntoOficioFechaController.text.trim(),
          destinatarioNombre: _destinatarioNombreController.text.trim(),
          destinatarioRango: _destinatarioRangoController.text.trim(),
          fechaLunes: _fechaLunesController.text.trim(),
          fechaDomingo: _fechaDomingoController.text.trim(),
          vehiculos: int.tryParse(_vehiculosController.text.trim()) ?? 0,
          motocicletas: int.tryParse(_motocicletasController.text.trim()) ?? 0,
          fojasStr: _fojasController.text.trim(),
          observacionAdicional: _observacionController.text,
          firmanteNombre: _firmanteNombreController.text.trim(),
          firmanteRango: _firmanteRangoController.text.trim(),
          tieneFirmaP12: _tieneFirmaP12,
          onAbrirConfigFirma: _abrirConfigFirma,
          onGenerarYCompartirPdf: _generarYCompartirPdf,
          onGenerarYCompartirWord: _generarYCompartirWord,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informe Semanal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial de Informes',
            onPressed: _abrirHistorial,
          ),
          IconButton(
            icon: Icon(
              _tieneFirmaP12 ? Icons.verified : Icons.badge_outlined,
              color: _tieneFirmaP12 ? Colors.green.shade300 : null,
            ),
            tooltip: _tieneFirmaP12 ? 'Firma Digital Configurada (.p12)' : 'Configurar Firma Digital (.p12)',
            onPressed: _abrirConfigFirma,
          ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'Vista Previa del Informe',
            onPressed: _abrirVistaPrevia,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Semana calculada automáticamente: lunes ${_fechaLunesController.text} '
                      '00H00 → domingo ${_fechaDomingoController.text} 00H00. '
                      'El conteo de vehículos/motos se tomó de tus Libertades guardadas en ese rango.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Card(
                  color: _tieneFirmaP12 ? Colors.green.shade50 : Colors.amber.shade50,
                  child: ListTile(
                    leading: Icon(
                      _tieneFirmaP12 ? Icons.verified : Icons.warning_amber_rounded,
                      color: _tieneFirmaP12 ? Colors.green.shade700 : Colors.amber.shade900,
                      size: 30,
                    ),
                    title: Text(
                      _tieneFirmaP12 ? 'Firma Digital .p12 Activa' : 'Firma Digital .p12 no configurada',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _tieneFirmaP12 ? Colors.green.shade900 : Colors.amber.shade900,
                      ),
                    ),
                    subtitle: Text(
                      _tieneFirmaP12
                          ? 'Se solicitará la clave para firmar digitalmente el PDF.'
                          : 'Toca aquí para subir tu archivo .p12 y firmar electrónicamente.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _abrirConfigFirma,
                  ),
                ),
                const SizedBox(height: 16),

                _seccion('Encabezado (cambia poco — se recuerda)', [
                  _campo(_jefaturaController, 'Jefatura de Tránsito (Ej. SANTO DOMINGO)'),
                  _campo(_patioController, 'Patio / CRV (Ej. CONTROL 120)'),
                  _campo(_subzonaController, 'Subzona completa (Ej. Santo Domingo de los Tsáchilas)'),
                  _campo(_subzonaAbrevController, 'Abreviatura de Subzona (Ej. SDT)'),
                ]),
                _seccion('Oficio de este informe (cambia cada semana)', [
                  _campo(_oficioNroController, 'N° de Oficio de este informe'),
                  _campo(_fechaOficioController, 'Fecha del oficio'),
                ]),
                _seccion('Oficio de referencia (ASUNTO — rara vez cambia)', [
                  _campo(_asuntoOficioNroController, 'N° de Oficio de referencia'),
                  _campo(_asuntoOficioFechaController, 'Fecha del oficio de referencia'),
                ]),
                _seccion('Destinatario (cambia solo si hay nuevo jefe)', [
                  _campo(_destinatarioNombreController, 'Nombre completo del Director'),
                  _campo(_destinatarioRangoController, 'Rango (Ej. Coronel de E.M)'),
                ]),
                _seccion('Semana reportada', [
                  _campo(_fechaLunesController, 'Desde (lunes)'),
                  _campo(_fechaDomingoController, 'Hasta (domingo)'),
                ]),
                _seccion('Conteo de la semana y fojas (auto, editable)', [
                  Row(
                    children: [
                      Expanded(child: _campo(_vehiculosController, 'N° Vehículos', tipo: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _campo(_motocicletasController, 'N° Motocicletas', tipo: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _campo(_fojasController, 'N° Fojas', tipo: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _campo(_observacionController, 'Observación adicional (opcional, para casos especiales)', lineas: 3),
                ]),
                _seccion('Quién firma (datos del oficial del patio)', [
                  _campo(_firmanteNombreController, 'Nombre completo de quien firma'),
                  _campo(_firmanteRangoController, 'Rango de quien firma'),
                ]),
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Ver Historial de Informes Semanales'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _abrirHistorial,
                ),
                const SizedBox(height: 10),

                FilledButton.icon(
                  icon: const Icon(Icons.draw),
                  label: const Text('Generar y Firmar Informe PDF (.p12)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF17356E),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _generarYCompartirPdf,
                ),
                const SizedBox(height: 8),

                OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Generar Word (.docx)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _generarYCompartirWord,
                ),
              ],
            ),
    );
  }

  Widget _seccion(String titulo, List<Widget> hijos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
}

/// Pantalla de Vista Previa visual interna del Informe Semanal.
class VistaPreviaInformeSemanalScreen extends StatelessWidget {
  final String jefaturaNombre;
  final String patio;
  final String subzona;
  final String subzonaAbrev;
  final String oficioNro;
  final String fechaOficio;
  final String asuntoOficioNro;
  final String asuntoOficioFecha;
  final String destinatarioNombre;
  final String destinatarioRango;
  final String fechaLunes;
  final String fechaDomingo;
  final int vehiculos;
  final int motocicletas;
  final String fojasStr;
  final String observacionAdicional;
  final String firmanteNombre;
  final String firmanteRango;
  final bool tieneFirmaP12;
  final VoidCallback onAbrirConfigFirma;
  final VoidCallback onGenerarYCompartirPdf;
  final VoidCallback onGenerarYCompartirWord;

  const VistaPreviaInformeSemanalScreen({
    super.key,
    required this.jefaturaNombre,
    required this.patio,
    required this.subzona,
    required this.subzonaAbrev,
    required this.oficioNro,
    required this.fechaOficio,
    required this.asuntoOficioNro,
    required this.asuntoOficioFecha,
    required this.destinatarioNombre,
    required this.destinatarioRango,
    required this.fechaLunes,
    required this.fechaDomingo,
    required this.vehiculos,
    required this.motocicletas,
    required this.fojasStr,
    required this.observacionAdicional,
    required this.firmanteNombre,
    required this.firmanteRango,
    required this.tieneFirmaP12,
    required this.onAbrirConfigFirma,
    required this.onGenerarYCompartirPdf,
    required this.onGenerarYCompartirWord,
  });

  String _saludoRango(String rango) {
    final r = rango.trim().toLowerCase();
    if (r.contains('coronel')) return 'coronel';
    if (r.contains('mayor')) return 'mayor';
    if (r.contains('general')) return 'general';
    if (r.contains('teniente')) return 'teniente coronel';
    return rango.isEmpty ? 'coronel' : rango.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final saludo = _saludoRango(destinatarioRango);
    final strVehiculos = vehiculos.toString().padLeft(2, '0');
    final strMotocicletas = motocicletas.toString().padLeft(2, '0');
    final totalLiberados = vehiculos + motocicletas;
    final strTotal = totalLiberados.toString().padLeft(2, '0');
    final strFojas = fojasStr.isNotEmpty ? fojasStr.padLeft(2, '0') : (totalLiberados * 2).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text('Vista Previa — CRV $patio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.draw),
            tooltip: 'Generar y Firmar PDF',
            onPressed: () {
              Navigator.pop(context);
              onGenerarYCompartirPdf();
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Generar Word',
            onPressed: () {
              Navigator.pop(context);
              onGenerarYCompartirWord();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 750),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/escudo_policia.jpg',
                      height: 55,
                      width: 55,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset('assets/sello_prv.png', height: 55, width: 55),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'POLICÍA NACIONAL DEL ECUADOR',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Times New Roman',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'DIRECCIÓN NACIONAL DE CONTROL DE TRÁNSITO Y SEGURIDAD VIAL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Times New Roman',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '“JEFATURA DE CONTROL DE TRÁNSITO $jefaturaNombre” CENTRO DE RETENCION VEHICULAR $patio”',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Times New Roman',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Image.asset(
                      'assets/escudo_ministerio.jpg',
                      height: 55,
                      width: 70,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset('assets/sello_prv.png', height: 55, width: 55),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Oficio, $oficioNro', style: const TextStyle(fontSize: 12, fontFamily: 'Times New Roman')),
                      const SizedBox(height: 4),
                      Text('Fecha, $fechaOficio', style: const TextStyle(fontSize: 12, fontFamily: 'Times New Roman')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'ASUNTO: EN CUMPLIMIENTO AL OFICIO Nro. $asuntoOficioNro',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                const SizedBox(height: 20),

                const Text('Señor', style: TextStyle(fontSize: 12, fontFamily: 'Times New Roman')),
                Text(
                  destinatarioNombre,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                Text(
                  destinatarioRango,
                  style: const TextStyle(fontSize: 12, fontFamily: 'Times New Roman'),
                ),
                const Text(
                  'DIRECTOR NACIONAL DE CONTROL DE TRÁNSITO Y SEGURIDAD VIAL POLICÍA NACIONAL',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                const Text('En su Despacho. –', style: TextStyle(fontSize: 12, fontFamily: 'Times New Roman')),
                const SizedBox(height: 16),

                Text(
                  'Mi $saludo:',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Times New Roman'),
                ),
                const SizedBox(height: 12),

                SelectableText(
                  'Con el honor de dirigirme a usted, me permito expresar un atento y cordial saludo, '
                  'a la vez desearle éxitos en el desarrollo de sus funciones, muy respetuosamente en cumplimiento '
                  'al Oficio Nro. $asuntoOficioNro, de fecha $asuntoOficioFecha firmado electrónicamente por el señor '
                  'DIRECTOR NACIONAL DE CONTROL DE TRANSITO Y SEGURIDAD VIAL en el que se dispone remitir los formularios '
                  'generados por el sistema una vez ejecutada la salida de los vehículos, los mismos que deberán ser '
                  'consolidados por cada Centro de Retención Vehicular en un solo documento, indicando expresamente el CRV al que pertenecen.',
                  textAlign: TextAlign.justify,
                  style: const TextStyle(fontSize: 12, height: 1.5, fontFamily: 'Times New Roman'),
                ),
                const SizedBox(height: 14),

                SelectableText(
                  'Por los antes expuesto me permito remitir la información solicitada desde las 00H00 del día lunes '
                  '$fechaLunes hasta las 00H00 del día domingo $fechaDomingo, con relación a la salida de vehículos '
                  'o motocicletas en el Centro de Retención Vehicular de la Jefatura de Tránsito $jefaturaNombre perteneciente a la Subzona $subzona.',
                  textAlign: TextAlign.justify,
                  style: const TextStyle(fontSize: 12, height: 1.5, fontFamily: 'Times New Roman'),
                ),
                const SizedBox(height: 14),

                SelectableText(
                  vehiculos > 0 && motocicletas > 0
                      ? 'Debo indicar que en dicha semana se realizó la liberación de $strVehiculos vehículos y $strMotocicletas motocicletas (total $strTotal liberaciones), por lo que adjunto $strFojas fojas de salida'
                      : 'Debo indicar que en dicha semana se realizó la liberación de $strTotal vehículos, por lo que adjunto $strFojas fojas de salida',
                  textAlign: TextAlign.justify,
                  style: const TextStyle(fontSize: 12, height: 1.5, fontFamily: 'Times New Roman'),
                ),
                if (observacionAdicional.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SelectableText(
                    observacionAdicional.trim(),
                    textAlign: TextAlign.justify,
                    style: const TextStyle(fontSize: 12, height: 1.5, fontFamily: 'Times New Roman'),
                  ),
                ],
                const SizedBox(height: 28),

                const Text('Atentamente,', style: TextStyle(fontSize: 12, fontFamily: 'Times New Roman')),
                const SizedBox(height: 16),
                const Text(
                  'VALOR, DISCIPLINA Y LEALTAD',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                const SizedBox(height: 24),

                GestureDetector(
                  onTap: onAbrirConfigFirma,
                  child: Tooltip(
                    message: 'Toca para configurar tu archivo .p12 de FirmaEC',
                    child: FirmaDigitalService.construirEstampaFirmaEC(
                      nombreFirmante: firmanteNombre,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Sr. $firmanteNombre',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                Text(
                  firmanteRango,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                Text(
                  'ENCARGADO DEL CENTRO DE RETENCIÓN VEHICULAR $patio',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                Text(
                  'PERTENECIENTE A LA JEFATURA DE TRÁNSITO SZ $subzonaAbrev.',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                const SizedBox(height: 36),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Volver y ajustar'),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.draw, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Firmar PDF (.p12)'),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF17356E),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onGenerarYCompartirPdf();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Generar Word'),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onGenerarYCompartirWord();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
