import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/informe_semanal_record.dart';
import '../services/storage_service.dart';
import '../services/docx_builder.dart';
import '../services/firma_digital_service.dart';
import '../services/pdf_informe_builder.dart';
import '../services/web_download_stub.dart'
    if (dart.library.html) '../services/web_download_web.dart';
import '../widgets/firma_digital_dialog.dart';
import '../widgets/modal_password_firma_dialog.dart';
import 'historial_informes_screen.dart';

class AnexoPdfItem {
  final String nombre;
  final Uint8List bytes;
  final int paginas;

  AnexoPdfItem({
    required this.nombre,
    required this.bytes,
    required this.paginas,
  });
}

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
  final _correoInstitucionalController = TextEditingController();

  final List<AnexoPdfItem> _anexosAdjuntos = [];

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

  String _limpiarNombrePatio(String p) {
    var patioLimpio = p.trim().toUpperCase();
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*SANTO DOMINGO DE LOS TS[ÁA]CHILAS.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*SANTO DOMINGO.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*PICHINCHA.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*MANAB[IÍ].*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*GUAYAS.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*ESMERALDAS.*$', caseSensitive: false), '');
    return patioLimpio.isNotEmpty ? patioLimpio : p.trim().toUpperCase();
  }

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


    _tieneFirmaP12 = await FirmaDigitalService.tieneCertificado();
    final datosFirma = await FirmaDigitalService.obtenerDatosFirmante();

    _jefaturaController.text = StorageService.ultimaSubzona.isNotEmpty 
        ? StorageService.ultimaSubzona.toUpperCase() 
        : (jefaturaPerfil.isNotEmpty 
            ? jefaturaPerfil.toUpperCase() 
            : 'SANTO DOMINGO');
        
    final patioBase = StorageService.ultimoCrv.isNotEmpty 
        ? StorageService.ultimoCrv.toUpperCase() 
        : (patioPerfil.isNotEmpty ? patioPerfil.toUpperCase() : 'CONTROL 120');
    _patioController.text = _limpiarNombrePatio(patioBase);
        
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
        
    final patioActual = _patioController.text.trim();
    final configPatio = await StorageService.obtenerConfigInformePorPatio(patioActual);

    _oficioNroController.text = configPatio['oficioNro']!.isNotEmpty
        ? configPatio['oficioNro']!
        : (StorageService.ultimoOficioInformeNro.isNotEmpty 
            ? StorageService.ultimoOficioInformeNro 
            : 'PN-SZ-${_subzonaAbrevController.text}-JPCTSV-CRV-2026-0063-O');
        
    _asuntoOficioNroController.text = configPatio['asuntoOficioNro']!.isNotEmpty
        ? configPatio['asuntoOficioNro']!
        : (StorageService.ultimoAsuntoOficioNro.isNotEmpty 
            ? StorageService.ultimoAsuntoOficioNro 
            : 'PN-DNCTSV-SCRV-POL-20026-00080-O');
        
    _asuntoOficioFechaController.text = configPatio['asuntoOficioFecha']!.isNotEmpty
        ? configPatio['asuntoOficioFecha']!
        : (StorageService.ultimoAsuntoOficioFecha.isNotEmpty 
            ? StorageService.ultimoAsuntoOficioFecha 
            : '04 de junio del 2026');
        
    _destinatarioNombreController.text = configPatio['destinatarioNombre']!.isNotEmpty
        ? configPatio['destinatarioNombre']!
        : (StorageService.ultimoDestinatarioNombre.isNotEmpty 
            ? StorageService.ultimoDestinatarioNombre 
            : 'Wiliams Rodrigo Barreno Ramos');
        
    _destinatarioRangoController.text = configPatio['destinatarioRango']!.isNotEmpty
        ? configPatio['destinatarioRango']!
        : (StorageService.ultimoDestinatarioRango.isNotEmpty 
            ? StorageService.ultimoDestinatarioRango 
            : 'Coronel de Estado Mayor');

    final firmanteRaw = configPatio['firmanteNombre']!.isNotEmpty
        ? configPatio['firmanteNombre']!
        : (datosFirma['nombre']!.isNotEmpty
            ? datosFirma['nombre']!
            : (StorageService.ultimoFirmanteNombre.isNotEmpty
                ? StorageService.ultimoFirmanteNombre
                : 'Fausto Xavier Chasipanta Haro'));

    _firmanteNombreController.text = (firmanteRaw.isEmpty ||
            firmanteRaw.contains('@') ||
            firmanteRaw.toLowerCase().contains('google') ||
            firmanteRaw.toLowerCase().contains('xchasi') ||
            firmanteRaw.toLowerCase().contains('xavier xchasi'))
        ? 'Fausto Xavier Chasipanta Haro'
        : firmanteRaw;
            
    _firmanteRangoController.text = configPatio['firmanteRango']!.isNotEmpty
        ? configPatio['firmanteRango']!
        : (datosFirma['rango']!.isNotEmpty
            ? datosFirma['rango']!
            : (StorageService.ultimoFirmanteRango.isNotEmpty
                ? StorageService.ultimoFirmanteRango
                : 'Sargento Segundo De Policía'));

    _fechaOficioController.text = _formatoFecha(DateTime.now());
    _fechaLunesController.text = _formatoFecha(_lunes!);
    _fechaDomingoController.text = _formatoFecha(_domingo!);

    final conteo = await StorageService.contarLibertadesEnRango(_lunes!, _domingo!);
    _vehiculosController.text = conteo.vehiculos.toString();
    _motocicletasController.text = conteo.motocicletas.toString();

    final totalLiberados = conteo.vehiculos + conteo.motocicletas;
    // El usuario indicó sumar el informe (1 foja) a los formularios de salida (2 fojas por vehículo liberado)
    final fojasEstimadas = totalLiberados > 0 ? (totalLiberados * 2 + 1) : 1;
    _fojasController.text = fojasEstimadas.toString().padLeft(2, '0');

    _correoInstitucionalController.text = await StorageService.obtenerCorreoInstitucional();

    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _seleccionarPdfsSiipne() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      int nuevos = 0;
      for (final f in result.files) {
        Uint8List? bytes = f.bytes;
        if (bytes == null && f.path != null) {
          bytes = await File(f.path!).readAsBytes();
        }
        if (bytes == null || bytes.isEmpty) continue;

        int numPags = 1;
        try {
          final doc = sf.PdfDocument(inputBytes: bytes);
          numPags = doc.pages.count;
          doc.dispose();
        } catch (_) {}

        _anexosAdjuntos.add(AnexoPdfItem(
          nombre: f.name,
          bytes: bytes,
          paginas: numPags,
        ));
        nuevos++;
      }

      final totalPagsAnexos = _anexosAdjuntos.fold<int>(0, (s, it) => s + it.paginas);
      // Fojas: Páginas de los formularios SIIPNE 3W + 1 hoja del informe semanal
      _fojasController.text = (totalPagsAnexos + 1).toString().padLeft(2, '0');

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se adjuntaron $nuevos formulario(s) SIIPNE 3W ($totalPagsAnexos páginas + 1 informe = ${totalPagsAnexos + 1} fojas).'),
            backgroundColor: const Color(0xFF17356E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al adjuntar archivos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _eliminarAnexo(int index) {
    setState(() {
      _anexosAdjuntos.removeAt(index);
      final totalPagsAnexos = _anexosAdjuntos.fold<int>(0, (s, it) => s + it.paginas);
      final vCount = int.tryParse(_vehiculosController.text.trim()) ?? 0;
      final mCount = int.tryParse(_motocicletasController.text.trim()) ?? 0;
      final totalLiberados = vCount + mCount;
      final fojas = totalPagsAnexos > 0 ? (totalPagsAnexos + 1) : (totalLiberados > 0 ? (totalLiberados * 2 + 1) : 1);
      _fojasController.text = fojas.toString().padLeft(2, '0');
    });
  }

  String _construirNombreArchivo(String patio, String fecha, String extension) {
    final patioLimpio = patio.trim().isEmpty ? 'patio' : patio.trim().toLowerCase();
    final fechaLimpia = fecha.trim().isEmpty ? 'fecha' : fecha.trim();
    return 'informe semanal CRV $patioLimpio $fechaLimpia.$extension';
  }

  @override
  void dispose() {
    for (final c in [
      _jefaturaController, _patioController, _subzonaController, _subzonaAbrevController,
      _oficioNroController, _fechaOficioController, _asuntoOficioNroController,
      _asuntoOficioFechaController, _destinatarioNombreController, _destinatarioRangoController,
      _fechaLunesController, _fechaDomingoController, _vehiculosController,
      _motocicletasController, _fojasController, _observacionController, _firmanteNombreController,
      _firmanteRangoController, _correoInstitucionalController,
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

  Future<void> _generarYCompartirPdf({
    String? asuntoPersonalizado,
    String? correoDestino,
  }) async {
    await _guardarRecordados();
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
      incluirEstampaFirma: false,
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

    // Compilar con anexos SIIPNE 3W si existen
    if (_anexosAdjuntos.isNotEmpty) {
      finalPdfBytes = PdfInformeSemanalBuilder.compilarConAnexos(
        informePdfBytes: finalPdfBytes,
        anexosPdfBytes: _anexosAdjuntos.map((e) => e.bytes).toList(),
      );
    }

    await _registrarEnHistorial(firmadoDigitalmente: firmadoDigital);

    final nombreArchivo = _construirNombreArchivo(
      _patioController.text,
      _fechaOficioController.text,
      'pdf',
    );

    final patioLimpio = _limpiarNombrePatio(_patioController.text);
    final asuntoDefecto = 'Informe Semanal del CRV $patioLimpio de la fecha del día domingo ${_fechaDomingoController.text.trim()} al día lunes ${_fechaLunesController.text.trim()}';
    final asuntoFinal = asuntoPersonalizado?.isNotEmpty == true ? asuntoPersonalizado! : asuntoDefecto;
    final destinoFinal = correoDestino?.isNotEmpty == true ? correoDestino! : _correoInstitucionalController.text.trim();

    final textoEnvio = 'Estimados,\n\n'
        'Se remite adjunto el $asuntoFinal, '
        'junto con los formularios de salida del SIIPNE 3W adjuntos (total ${_fojasController.text} fojas).\n\n'
        'Destinatario: $destinoFinal\n\n'
        'Atentamente,\n'
        '${_firmanteNombreController.text.trim()}\n'
        '${_firmanteRangoController.text.trim()}\n'
        'ENCARGADO DEL CENTRO DE RETENCIÓN VEHICULAR “$patioLimpio”';

    if (kIsWeb) {
      descargarBytesEnNavegador(nombreArchivo, finalPdfBytes);
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$nombreArchivo');
      await file.writeAsBytes(finalPdfBytes, flush: true);

      final xFile = XFile(
        file.path,
        name: nombreArchivo,
        mimeType: 'application/pdf',
      );
      await Share.shareXFiles(
        [xFile],
        text: textoEnvio,
        subject: asuntoFinal,
      );
    }
  }


  Future<void> _generarYCompartirWord() async {
    await _guardarRecordados();

    List<int>? bytesPolicia;
    List<int>? bytesDireccion;

    try {
      final b1 = await rootBundle.load('assets/escudo_policia.jpg');
      bytesPolicia = b1.buffer.asUint8List();
    } catch (_) {}

    try {
      final b2 = await rootBundle.load('assets/logo_direccion_transito.png');
      bytesDireccion = b2.buffer.asUint8List();
    } catch (_) {}

    final bytes = DocxBuilder.buildInformeSemanal(
      escudoPoliciaBytes: bytesPolicia,
      logoDireccionBytes: bytesDireccion,
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
    );

    await _registrarEnHistorial(firmadoDigitalmente: false);

    final nombreArchivo = _construirNombreArchivo(
      _patioController.text,
      _fechaOficioController.text,
      'docx',
    );

    if (kIsWeb) {
      descargarBytesEnNavegador(nombreArchivo, bytes);
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$nombreArchivo');
      await file.writeAsBytes(bytes, flush: true);

      final xFile = XFile(
        file.path,
        name: nombreArchivo,
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      await Share.shareXFiles([xFile], text: nombreArchivo);
    }
  }

  String _incrementarOficioNro(String oficioActual) {
    final regExp = RegExp(r'^(.*?)(\d+)([^\d]*)$');
    final match = regExp.firstMatch(oficioActual);
    if (match != null) {
      final prefix = match.group(1)!;
      final numStr = match.group(2)!;
      final suffix = match.group(3)!;
      final nextNum = (int.tryParse(numStr) ?? 0) + 1;
      final paddedNum = nextNum.toString().padLeft(numStr.length, '0');
      return '$prefix$paddedNum$suffix';
    }
    return oficioActual;
  }

  Future<void> _guardarRecordados() async {
    final oficioActual = _oficioNroController.text.trim();
    final proximoOficio = _incrementarOficioNro(oficioActual);
    final patioActual = _patioController.text.trim();

    StorageService.ultimoOficioInformeNro = proximoOficio;
    StorageService.ultimoAsuntoOficioNro = _asuntoOficioNroController.text.trim();
    StorageService.ultimoAsuntoOficioFecha = _asuntoOficioFechaController.text.trim();
    StorageService.ultimoDestinatarioNombre = _destinatarioNombreController.text.trim();
    StorageService.ultimoDestinatarioRango = _destinatarioRangoController.text.trim();

    final fNombre = (_firmanteNombreController.text.contains('@') || _firmanteNombreController.text.toLowerCase().contains('google'))
        ? ''
        : _firmanteNombreController.text.trim();
    StorageService.ultimoFirmanteNombre = fNombre;
    StorageService.ultimoFirmanteRango = _firmanteRangoController.text.trim();

    final cInst = _correoInstitucionalController.text.trim();
    if (cInst.isNotEmpty) {
      await StorageService.guardarCorreoInstitucional(cInst);
    }

    await StorageService.guardarConfigInformePorPatio(
      patio: patioActual,
      oficioNro: proximoOficio,
      asuntoOficioNro: _asuntoOficioNroController.text.trim(),
      asuntoOficioFecha: _asuntoOficioFechaController.text.trim(),
      destinatarioNombre: _destinatarioNombreController.text.trim(),
      destinatarioRango: _destinatarioRangoController.text.trim(),
      firmanteNombre: fNombre,
      firmanteRango: _firmanteRangoController.text.trim(),
    );
  }

  Future<void> _mostrarDialogoEnviarCorreoInstitucional() async {
    final patioLimpio = _limpiarNombrePatio(_patioController.text);
    final asuntoDefault = 'Informe Semanal del CRV $patioLimpio de la fecha del día domingo ${_fechaDomingoController.text.trim()} al día lunes ${_fechaLunesController.text.trim()}';

    final correoCtrl = TextEditingController(text: _correoInstitucionalController.text.trim());
    final asuntoCtrl = TextEditingController(text: asuntoDefault);

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.mark_email_read_outlined, color: Color(0xFF17356E), size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Enviar a Correo Institucional',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El informe oficial y los formularios SIIPNE 3W adjuntos se compilarán en un único PDF listo para enviar.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: correoCtrl,
                decoration: InputDecoration(
                  labelText: 'Correo Institucional Destinatario',
                  hintText: 'ej. dnctsv.sec.crv@gmail.com',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.alternate_email),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copiar correo',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: correoCtrl.text.trim()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Correo copiado al portapapeles.')),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: asuntoCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Asunto Oficial del Correo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subject),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen del paquete PDF único:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('• 1 hoja: Informe Oficial (CRV $patioLimpio)', style: const TextStyle(fontSize: 12)),
                    Text(
                      _anexosAdjuntos.isNotEmpty
                          ? '• ${_anexosAdjuntos.length} formularios SIIPNE 3W anexados (${_anexosAdjuntos.fold<int>(0, (s, e) => s + e.paginas)} páginas)'
                          : '• Sin formularios anexados (solo informe oficial)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Divider(height: 10),
                    Text(
                      '• Total fojas a remitir: ${_fojasController.text} fojas',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF17356E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Compilar y Enviar'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF17356E)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      final cFin = correoCtrl.text.trim();
      final aFin = asuntoCtrl.text.trim();
      _correoInstitucionalController.text = cFin;
      await StorageService.guardarCorreoInstitucional(cFin);

      await _generarYCompartirPdf(
        asuntoPersonalizado: aFin,
        correoDestino: cFin,
      );
    }
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
          anexosCount: _anexosAdjuntos.length,
          anexosPaginas: _anexosAdjuntos.fold<int>(0, (s, e) => s + e.paginas),
          tieneFirmaP12: _tieneFirmaP12,
          onAbrirConfigFirma: _abrirConfigFirma,
          onGenerarYCompartirPdf: _generarYCompartirPdf,
          onEnviarCorreoInstitucional: _mostrarDialogoEnviarCorreoInstitucional,
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
                _seccionAnexosSiipne(),
                _seccion('Quién firma (datos del oficial del patio)', [
                  _campo(_firmanteNombreController, 'Nombre completo de quien firma'),
                  _campo(_firmanteRangoController, 'Rango de quien firma'),
                ]),
                const SizedBox(height: 16),

                FilledButton.icon(
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Enviar a Correo Institucional (PDF Compilado)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F5A47),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _mostrarDialogoEnviarCorreoInstitucional,
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
                const SizedBox(height: 8),

                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Ver Historial de Informes Semanales'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _abrirHistorial,
                ),
              ],
            ),
    );
  }

  Widget _seccionAnexosSiipne() {
    final totalPaginas = _anexosAdjuntos.fold<int>(0, (s, e) => s + e.paginas);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Color(0xFFC62828), size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Anexos SIIPNE 3W (Formularios de Salida)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(
                  '${_anexosAdjuntos.length} adjunto(s)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _anexosAdjuntos.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Adjunta los PDFs de salida descargados del SIIPNE 3W (2 hojas por vehículo liberado). '
              'El sistema los compilará automáticamente en un único PDF junto con el informe oficial.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: const Text('Subir Formularios SIIPNE 3W (Múltiples PDFs)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF17356E),
                side: const BorderSide(color: Color(0xFF17356E)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onPressed: _seleccionarPdfsSiipne,
            ),
            if (_anexosAdjuntos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green.shade800, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Total: ${_anexosAdjuntos.length} archivos | $totalPaginas hojas de salida + 1 informe = ${totalPaginas + 1} fojas.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: List.generate(_anexosAdjuntos.length, (index) {
                  final it = _anexosAdjuntos[index];
                  return Chip(
                    backgroundColor: Colors.grey.shade100,
                    avatar: const Icon(Icons.description, size: 16, color: Color(0xFFC62828)),
                    label: Text(
                      '${it.nombre} (${it.paginas}p)',
                      style: const TextStyle(fontSize: 11),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _eliminarAnexo(index),
                  );
                }),
              ),
            ],
          ],
        ),
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
  final int anexosCount;
  final int anexosPaginas;
  final bool tieneFirmaP12;
  final VoidCallback onAbrirConfigFirma;
  final VoidCallback onGenerarYCompartirPdf;
  final VoidCallback onEnviarCorreoInstitucional;
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
    this.anexosCount = 0,
    this.anexosPaginas = 0,
    required this.tieneFirmaP12,
    required this.onAbrirConfigFirma,
    required this.onGenerarYCompartirPdf,
    required this.onEnviarCorreoInstitucional,
    required this.onGenerarYCompartirWord,
  });


  String _saludoRango(String rango) {
    final r = rango.trim().toLowerCase();
    if (r.contains('coronel')) return 'Coronel';
    if (r.contains('mayor')) return 'Mayor';
    if (r.contains('general')) return 'General';
    if (r.contains('teniente coronel')) return 'Teniente Coronel';
    if (r.contains('capitán') || r.contains('capitan')) return 'Capitán';
    return rango.isEmpty ? 'Coronel' : (rango[0].toUpperCase() + rango.substring(1).toLowerCase());
  }

  String _limpiarNombrePatio(String p) {
    var patioLimpio = p.trim().toUpperCase();
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*SANTO DOMINGO DE LOS TS[ÁA]CHILAS.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*SANTO DOMINGO.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*PICHINCHA.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*MANAB[IÍ].*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*GUAYAS.*$', caseSensitive: false), '');
    patioLimpio = patioLimpio.replaceAll(RegExp(r'\s*ESMERALDAS.*$', caseSensitive: false), '');
    return patioLimpio.isNotEmpty ? patioLimpio : p.trim().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final saludo = _saludoRango(destinatarioRango);
    final strVehiculos = vehiculos.toString().padLeft(2, '0');
    final strMotocicletas = motocicletas.toString().padLeft(2, '0');
    final patioLimpio = _limpiarNombrePatio(patio);
    final jefaturaClean = jefaturaNombre
        .toUpperCase()
        .replaceAll('JEFATURA DE CONTROL DE TRÁNSITO', '')
        .replaceAll('JEFATURA DE TRÁNSITO', '')
        .trim();

    var firmanteClean = firmanteNombre.trim();
    if (firmanteClean.isEmpty ||
        firmanteClean.contains('@') ||
        firmanteClean.toLowerCase().contains('google') ||
        firmanteClean.toLowerCase().contains('xchasi') ||
        firmanteClean.toLowerCase().contains('xavier xchasi')) {
      firmanteClean = 'Fausto Xavier Chasipanta Haro';
    }
    final rangoFirmanteClean = firmanteRango.trim().isNotEmpty ? firmanteRango.trim() : 'Sargento Segundo De Policía';

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text('Vista Previa — CRV $patioLimpio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined),
            tooltip: 'Enviar a Correo Institucional',
            onPressed: () {
              Navigator.pop(context);
              onEnviarCorreoInstitucional();
            },
          ),
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
                            '“JEFATURA DE CONTROL DE TRÁNSITO $jefaturaClean” CENTRO DE RETENCIÓN VEHICULAR “$patioLimpio”',
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
                      'assets/logo_direccion_transito.png',
                      height: 55,
                      width: 55,
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
                  'o motocicletas en el Centro de Retención Vehicular de la Jefatura de Tránsito $jefaturaClean perteneciente a la Subzona $subzona.',
                  textAlign: TextAlign.justify,
                  style: const TextStyle(fontSize: 12, height: 1.5, fontFamily: 'Times New Roman'),
                ),
                const SizedBox(height: 14),

                SelectableText(
                  'Debo indicar que existió la libertad de $strVehiculos vehículos y $strMotocicletas motocicletas durante esas fechas.',
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
                const SizedBox(height: 14),
                const SelectableText(
                  'Adjunto los formularios descargados del SIIPNE 3W referente a la salida del vehículo.',
                  textAlign: TextAlign.justify,
                  style: TextStyle(fontSize: 12, height: 1.5, fontFamily: 'Times New Roman'),
                ),
                const SizedBox(height: 28),

                const Text('Atentamente,', style: TextStyle(fontSize: 12, fontFamily: 'Times New Roman')),
                const SizedBox(height: 16),
                const Text(
                  'VALOR, DISCIPLINA Y LEALTAD',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                // Espacio limpio sin QR preparado para FirmaEC
                const SizedBox(height: 50),

                Text(
                  'Sr. $firmanteClean',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                Text(
                  rangoFirmanteClean,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                Text(
                  'ENCARGADO DEL CENTRO DE RETENCIÓN VEHICULAR “$patioLimpio”',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                Text(
                  'PERTENECIENTE A LA JEFATURA DE TRÁNSITO SZ ${subzonaAbrev.toUpperCase()}.',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Times New Roman'),
                ),
                const SizedBox(height: 36),

                if (anexosCount > 0) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Formularios SIIPNE 3W anexados: $anexosCount archivos ($anexosPaginas páginas de salida). Total a remitir: $fojasStr fojas.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                    label: const Text('Enviar a Correo Institucional (PDF Compilado)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F5A47),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onEnviarCorreoInstitucional();
                    },
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Volver'),
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
