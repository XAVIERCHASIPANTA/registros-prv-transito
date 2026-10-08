// RUTA DE ARCHIVO: lib/screens/captura_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'home_screen.dart';
import 'formulario_screen.dart';
import 'formulario_libertad_screen.dart';
import 'seleccionar_vehiculo_screen.dart';
import 'ajustes_screen.dart';
import '../services/gemini_vision_service.dart';
import '../services/api_key_service.dart';
import '../services/pdf_parser_service.dart';
import '../services/pdf_respaldo_service.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import '../models/participante_vehiculo.dart';

class CapturaScreen extends StatefulWidget {
  final TipoParte tipo;

  /// Ingreso del que nace la Libertad (viene de "Liberar vehículo" en
  /// Buscar por placa / Ver ingresos). Solo se usa cuando tipo ==
  /// TipoParte.libertad — permite heredar placa/marca/color/hoja/
  /// causa y combinar esos datos con lo que Gemini extraiga de las
  /// fotos nuevas (memorando, oficio, orden de pago, comprobante).
  final CasoIngreso? ingresoBase;
  final File? pdfInicial;

  const CapturaScreen({super.key, required this.tipo, this.ingresoBase, this.pdfInicial});

  @override
  State<CapturaScreen> createState() => _CapturaScreenState();
}

class _CapturaScreenState extends State<CapturaScreen> {
  final List<File> _imagenes = [];
  final ImagePicker _picker = ImagePicker();
  bool _procesando = false;
  String? _ultimoErrorIA;

  String get _titulo => widget.tipo == TipoParte.ingreso
      ? 'Nuevo Ingreso'
      : (widget.ingresoBase != null ? 'Liberar vehículo — ${widget.ingresoBase!.placa}' : 'Nueva Libertad');

  @override
  void initState() {
    super.initState();
    if (widget.pdfInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _procesarBytesPdf(widget.pdfInicial!.readAsBytesSync());
      });
    }
  }

  Future<void> _tomarFoto() async {
    final foto = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (foto != null) setState(() => _imagenes.add(File(foto.path)));
  }

  Future<void> _elegirDeGaleria() async {
    final fotos = await _picker.pickMultiImage(imageQuality: 90);
    if (fotos.isNotEmpty) {
      setState(() => _imagenes.addAll(fotos.map((f) => File(f.path))));
    }
  }

  Future<void> _elegirPdf() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (resultado == null || resultado.files.single.bytes == null) return;
    final bytes = resultado.files.single.bytes!;

    unawaited(_respaldarPdfLocal(bytes, resultado.files.single.name));
    await _procesarBytesPdf(bytes);
  }

  Future<void> _procesarBytesPdf(Uint8List bytes) async {
    setState(() => _procesando = true);
    final apiKey = await ApiKeyService().obtenerApiKey();
    if (apiKey != null) {
      final huboExito = await _leerPdfConIA(bytes, apiKey);
      if (huboExito) {
        if (mounted) setState(() => _procesando = false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La IA no pudo leer este PDF (caerá a método sin conexión). Error: $_ultimoErrorIA'), duration: const Duration(seconds: 5)),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No has configurado la API Key de Gemini. Se usará el extractor antiguo (menos preciso).')),
        );
      }
    }
    if (mounted) {
      await _leerPdfSinConexion(bytes);
      setState(() => _procesando = false);
    }
  }

  /// Guarda una copia del PDF original en el almacenamiento propio de
  /// la app dentro del celular (no en la nube). Se usa el nombre
  /// original del archivo si viene disponible, para que sea
  /// reconocible en "PDFs guardados".
  Future<void> _respaldarPdfLocal(Uint8List bytes, String? nombreOriginal) async {
    try {
      final limpio = (nombreOriginal ?? '').replaceAll('.pdf', '').replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final base = limpio.trim().isEmpty ? 'parte' : limpio;
      final marca = DateTime.now().millisecondsSinceEpoch;
      await PdfRespaldoService.guardar(bytes, nombreSugerido: '${base}_$marca');
    } catch (_) {
      // Respaldo best-effort: si falla (poco espacio, permisos, etc.)
      // no se interrumpe la captura del parte.
    }
  }

  /// Rasteriza cada página del PDF a imagen (PNG) y las manda a
  /// Gemini Vision con un prompt propio para partes digitales (puede
  /// haber varios vehículos). Devuelve true si logró encontrar al
  /// menos un vehículo y ya navegó a la pantalla de selección.
  Future<bool> _leerPdfConIA(Uint8List bytes, String apiKey) async {
    setState(() => _procesando = true);
    try {
      final paginas = <Uint8List>[];
      // Máximo 8 páginas: los partes reales tienen 4-5, este límite
      // solo evita un PDF anormalmente largo demore de más o pese de
      // más para la conexión del celular.
      await for (final pagina in Printing.raster(bytes, dpi: 130)) {
        paginas.add(await pagina.toPng());
        if (paginas.length >= 8) break;
      }
      if (paginas.isEmpty) return false;

      final extraido = await GeminiVisionService().extraerParteDigital(paginas, apiKey);

      final participantes = extraido.vehiculos
          .map((v) => ParticipanteVehiculo(
                placa: v['placa'] ?? '',
                tipo: v['tipo'] ?? '',
                marca: v['marca'] ?? '',
                modelo: v['modelo'] ?? '',
                color: v['color'] ?? '',
                conductor: v['conductor'] ?? '',
                conductorCedula: v['conductorCedula'] ?? '',
                propietario: v['propietario'] ?? '',
                propietarioCedula: v['propietarioCedula'] ?? '',
                chasis: v['chasis'] ?? '',
                pais: v['pais'] ?? '',
                anio: v['anio'] ?? '',
                motor: v['motor'] ?? '',
              ))
          .where((p) => p.placa.trim().isNotEmpty)
          .toList();
      if (participantes.isEmpty) return false;

      final metadatos = MetadatosParte(
        parteNo: extraido.metadatos['parteNo'] ?? '',
        fechaHecho: extraido.metadatos['fechaHecho'] ?? '',
        horaHecho: extraido.metadatos['horaHecho'] ?? '',
        elaboradoPor: extraido.metadatos['policiaNombre'] ?? '',
        elaboradoPorCedula: extraido.metadatos['policiaCedula'] ?? '',
        circunstancias: extraido.metadatos['circunstancias'] ?? '',
      );

      if (!mounted) return true;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeleccionarVehiculoScreen(
            participantes: participantes,
            metadatos: metadatos,
            textoCompleto: 'Este parte se leyó con IA (Gemini Vision) a partir de imágenes de cada '
                'página del PDF — no queda un texto crudo único para mostrar aquí.',
          ),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Error en _leerPdfConIA: $e');
      _ultimoErrorIA = e.toString();
      return false;
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /// Respaldo sin conexión (o cuando la IA no encontró nada): lee el
  /// texto interno del PDF con Syncfusion y lo interpreta con
  /// expresiones regulares. Menos preciso que la IA porque depende de
  /// que el texto del PDF venga en un orden más o menos predecible.
  Future<void> _leerPdfSinConexion(Uint8List bytes) async {
    setState(() => _procesando = true);
    try {
      final parser = PdfParserService();
      final texto = parser.extraerTextoBytes(bytes);
      final metadatos = parser.extraerMetadatos(texto);
      final participantes = parser.extraerParticipantes(texto);

      if (!mounted) return;

      // Ronda 23: antes, si el bloque de vehículo/placa no calzaba con
      // ninguno de los 3 patrones conocidos, se perdían TAMBIÉN los
      // metadatos que sí se habían leído bien (N° Parte, Fecha/Hora del
      // hecho, Circunstancias) — eran datos ya extraídos con éxito y se
      // botaban junto con el vehículo fallido. Ahora, si no se detectó
      // ningún vehículo, se sigue igual a la pantalla de siempre pero
      // con UN participante en blanco (para llenar placa/marca/etc. a
      // mano), conservando los metadatos ya extraídos.
      final listaParticipantes = participantes.isEmpty
          ? [ParticipanteVehiculo(placa: '')]
          : participantes;

      if (participantes.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se detectó el vehículo en este PDF, pero sí se leyeron los demás datos '
                '(N° Parte, fecha, hora, circunstancias). Completa la placa y los datos del vehículo a mano.'),
            duration: Duration(seconds: 6),
          ),
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeleccionarVehiculoScreen(participantes: listaParticipantes, metadatos: metadatos, textoCompleto: texto),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo leer el PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _procesar() async {
    if (_imagenes.isEmpty) return;

    final apiKey = await ApiKeyService().obtenerApiKey();
    if (apiKey == null) {
      if (!mounted) return;
      final configurar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Falta configurar la IA'),
          content: const Text(
              'Todavía no has guardado tu API key gratuita de Gemini. Puedes configurarla ahora, '
              'o llenar el formulario a mano sin usar IA.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Llenar a mano')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Configurar ahora')),
          ],
        ),
      );
      if (configurar == true) {
        if (!mounted) return;
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const AjustesScreen()));
        return; // el usuario vuelve a tocar "Extraer datos" luego de configurar
      } else {
        _abrirFormularioVacio();
        return;
      }
    }

    setState(() => _procesando = true);
    final gemini = GeminiVisionService();
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      if (widget.tipo == TipoParte.ingreso) {
        final datos = await gemini.extraerIngreso(_imagenes, apiKey);
        final caso = CasoIngreso(
          id: id,
          hojaIngresoNro: datos['hojaIngresoNro'] ?? '',
          parteIngresoNro: datos['parteIngresoNro'] ?? '',
          crv: datos['crv'] ?? '',
          subzona: datos['subzona'] ?? '',
          fechaIngreso: datos['fechaIngreso'] ?? '',
          horaRetencion: datos['horaRetencion'] ?? '',
          tipoVehiculo: datos['tipoVehiculo'] ?? '',
          marca: datos['marca'] ?? '',
          modelo: datos['modelo'] ?? '',
          anioFabricacion: datos['anioFabricacion'] ?? '',
          color: datos['color'] ?? '',
          cilindraje: datos['cilindraje'] ?? '',
          chasis: datos['chasis'] ?? '',
          motor: datos['motor'] ?? '',
          placa: datos['placa'] ?? '',
          propietario: datos['propietario'] ?? '',
          cedulaPropietario: datos['cedulaPropietario'] ?? '',
          conductor: datos['conductor'] ?? '',
          cedulaConductor: datos['cedulaConductor'] ?? '',
          causaLegal: datos['causaLegal'] ?? '',
          detalleCausa: datos['detalleCausa'] ?? '',
          traslado: datos['traslado'] ?? '',
          custodioRecibeNombre: datos['custodioRecibeNombre'] ?? '',
          policiaNombre: datos['policiaNombre'] ?? '',
          policiaCedula: datos['policiaCedula'] ?? '',
        );
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FormularioIngresoScreen(caso: caso)));
      } else {
        final ingreso = widget.ingresoBase;
        // datos = lo que Gemini logre leer de las fotos nuevas
        // (memorando, oficio, juez que firma, orden de pago, comprobante...)
        final datos = await gemini.extraerLibertad(_imagenes, apiKey);

        final huboDatosDePago = (datos['ordenPagoNro'] ?? datos['comprobantePagoNro'] ?? datos['valor']) != null &&
            ((datos['ordenPagoNro'] ?? '').isNotEmpty ||
                (datos['comprobantePagoNro'] ?? '').isNotEmpty ||
                (datos['valor'] ?? '').isNotEmpty);

        final pagos = huboDatosDePago
            ? [
                PagoGaraje(
                  ordenPagoNro: datos['ordenPagoNro'] ?? '',
                  comprobantePagoNro: datos['comprobantePagoNro'] ?? '',
                  diasPagados: datos['diasPagados'] ?? '',
                  precioUnitario: datos['precioUnitario'] ?? '',
                  valor: datos['valor'] ?? '',
                  horaFechaPago: datos['horaFechaPago'] ?? '',
                  entidadFinanciera: datos['entidadFinanciera'] ?? '',
                ),
              ]
            : [PagoGaraje()];

        final observacionComision = (datos['valorTransaccionOComision'] ?? '').trim();

        final caso = CasoLibertad(
          id: id,
          // Heredado del Ingreso, con la extracción de Gemini como
          // respaldo si por algún motivo no viniera el ingreso base.
          hojaIngresoNro: ingreso?.hojaIngresoNro ?? datos['hojaIngresoNro'] ?? '',
          parteIngresoNro: ingreso?.parteIngresoNro ?? '',
          marca: ingreso?.marca ?? datos['marca'] ?? '',
          color: ingreso?.color ?? datos['color'] ?? '',
          placa: ingreso?.placa ?? datos['placa'] ?? '',
          tipoVehiculo: ingreso?.tipoVehiculo ?? '',
          crv: ingreso?.crv ?? '',
          causa: ingreso != null
              ? [ingreso.causaLegal, ingreso.detalleCausa].where((s) => s.trim().isNotEmpty).join(' - ')
              : '',
          fechaIngreso: ingreso?.fechaIngreso ?? datos['fechaIngreso'] ?? '',
          tipoServicioGaraje: datos['tipoServicioGaraje'] ?? '',
          // Genuinamente nuevo de Libertad: siempre viene de esta extracción.
          memorandoNro: datos['memorandoNro'] ?? '',
          memorandoFecha: datos['memorandoFecha'] ?? '',
          oficioDevolucionNro: datos['oficioDevolucionNro'] ?? '',
          oficioDevolucionFecha: datos['oficioDevolucionFecha'] ?? '',
          firmadoPor: datos['firmadoPor'] ?? '',
          retiradoPor: datos['retiradoPor'] ?? '',
          cedulaRetira: datos['cedulaRetira'] ?? '',
          fechaSalida: datos['fechaSalida'] ?? '',
          observaciones: observacionComision.isNotEmpty
              ? 'El comprobante muestra un valor de transacción/comisión de $observacionComision aparte del valor base.'
              : '',
          pagos: pagos,
        );
        if (!mounted) return;
        if (ingreso != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => FormularioLibertadScreen(ingreso: ingreso, existente: caso)),
          );
        } else {
          // No debería pasar en el flujo normal (siempre se viene de
          // un Ingreso ya guardado), pero se maneja por seguridad.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se encontró el Ingreso base para esta Libertad.')),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      final continuar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No se pudo escanear'),
          content: Text('Puede ser que no haya internet en este momento, o la API key sea inválida.\n\nDetalle: $e'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Reintentar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Llenar a mano')),
          ],
        ),
      );
      if (continuar == true) _abrirFormularioVacio();
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _abrirFormularioVacio() {
    if (widget.tipo == TipoParte.ingreso) {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FormularioIngresoScreen(caso: CasoIngreso(id: id))),
      );
    } else {
      final ingreso = widget.ingresoBase;
      if (ingreso == null) {
        Navigator.pop(context);
        return;
      }
      // FormularioLibertadScreen ya sabe construir un CasoLibertad
      // nuevo a partir del ingreso cuando no se le pasa "existente".
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FormularioLibertadScreen(ingreso: ingreso)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titulo)),
      body: Column(
        children: [
          if (widget.ingresoBase != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                'Ya se heredaron los datos del Ingreso (Hoja ${widget.ingresoBase!.hojaIngresoNro}). '
                'Toma fotos del oficio de devolución/memorando y de la orden de pago/comprobante para '
                'completar lo que falta.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          Expanded(
            child: _imagenes.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Toma una o varias fotos de los documentos del caso\n'
                        '(parte policial, hoja de ingreso, memorando, etc.)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _imagenes.length,
                    itemBuilder: (context, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_imagenes[i],
                              fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _imagenes.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Cámara'),
                          onPressed: _procesando ? null : _tomarFoto,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galería'),
                          onPressed: _procesando ? null : _elegirDeGaleria,
                        ),
                      ),
                    ],
                  ),
                  if (widget.tipo == TipoParte.ingreso) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Subir documento PDF (parte policial)'),
                        onPressed: _procesando ? null : _elegirPdf,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _procesando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.document_scanner),
                      label: Text(_procesando ? 'Procesando...' : 'Extraer datos (OCR)'),
                      onPressed: (_imagenes.isEmpty || _procesando) ? null : _procesar,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _procesando ? null : _abrirFormularioVacio,
                    child: const Text('Omitir fotos y llenar el resto a mano'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
