import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/firma_digital_service.dart';

class FirmaDigitalDialog extends StatefulWidget {
  final String? firmanteNombreInicial;
  final String? firmanteRangoInicial;

  const FirmaDigitalDialog({
    super.key,
    this.firmanteNombreInicial,
    this.firmanteRangoInicial,
  });

  static Future<void> mostrar(
    BuildContext context, {
    String? firmanteNombreInicial,
    String? firmanteRangoInicial,
  }) {
    return showDialog(
      context: context,
      builder: (_) => FirmaDigitalDialog(
        firmanteNombreInicial: firmanteNombreInicial,
        firmanteRangoInicial: firmanteRangoInicial,
      ),
    );
  }

  @override
  State<FirmaDigitalDialog> createState() => _FirmaDigitalDialogState();
}

class _FirmaDigitalDialogState extends State<FirmaDigitalDialog> {
  final _nombreCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _rangoCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  final _institucionCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  PlatformFile? _archivoSeleccionado;
  Uint8List? _bytesArchivo;
  bool _cargando = true;
  bool _tieneCertificadoPrevio = false;
  String _fechaCargaStr = '';
  String _mensajeError = '';

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    _tieneCertificadoPrevio = await FirmaDigitalService.tieneCertificado();
    final datos = await FirmaDigitalService.obtenerDatosFirmante();

    _nombreCtrl.text = datos['nombre']!.isNotEmpty
        ? datos['nombre']!
        : (widget.firmanteNombreInicial?.toUpperCase() ?? '');
    _cedulaCtrl.text = datos['cedula']!;
    _rangoCtrl.text = datos['rango']!.isNotEmpty
        ? datos['rango']!
        : (widget.firmanteRangoInicial ?? 'Sargento Segundo De Policía');
    _cargoCtrl.text = datos['cargo']!.isNotEmpty
        ? datos['cargo']!
        : 'ENCARGADO DEL CENTRO DE RETENCIÓN VEHICULAR CONTROL 120';
    _institucionCtrl.text = datos['institucion']!.isNotEmpty
        ? datos['institucion']!
        : 'PERTENECIENTE A LA JEFATURA DE TRÁNSITO SZ SDT.';
    _fechaCargaStr = datos['fechaCarga']!;

    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cedulaCtrl.dispose();
    _rangoCtrl.dispose();
    _cargoCtrl.dispose();
    _institucionCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarArchivoP12() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['p12', 'pfx'],
        withData: true,
      );

      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        Uint8List? bytes = file.bytes;

        if (bytes == null && file.path != null) {
          final f = File(file.path!);
          if (f.existsSync()) {
            bytes = await f.readAsBytes();
          }
        }

        if (bytes != null) {
          setState(() {
            _archivoSeleccionado = file;
            _bytesArchivo = bytes;
            _mensajeError = '';
          });
        }
      }
    } catch (e) {
      setState(() => _mensajeError = 'Error al seleccionar archivo: $e');
    }
  }

  Future<void> _guardarCertificado() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _mensajeError = 'Ingrese el nombre completo del firmante.');
      return;
    }

    if (!_tieneCertificadoPrevio && _bytesArchivo == null) {
      setState(() => _mensajeError = 'Debe seleccionar su archivo de certificado (.p12).');
      return;
    }

    setState(() => _cargando = true);

    try {
      if (_bytesArchivo != null) {
        await FirmaDigitalService.guardarCertificado(
          bytesArchivo: _bytesArchivo!,
          nombreArchivo: _archivoSeleccionado?.name ?? 'firma.p12',
          nombreFirmante: nombre,
          cedula: _cedulaCtrl.text.trim(),
          rango: _rangoCtrl.text.trim(),
          cargo: _cargoCtrl.text.trim(),
          institucion: _institucionCtrl.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificado digital guardado correctamente.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _cargando = false;
        _mensajeError = 'No se pudo guardar el certificado: $e';
      });
    }
  }

  Future<void> _eliminarCertificado() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Firma Digital?'),
        content: const Text('Se quitará el archivo .p12 de la aplicación. Podrá volver a cargarlo en cualquier momento.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirmaDigitalService.eliminarCertificado();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificado eliminado.')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(20),
        child: _cargando
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_outlined, color: Colors.blue, size: 28),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Configuración de Firma Digital (.p12)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Estado actual del certificado
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _tieneCertificadoPrevio ? Colors.green.shade50 : Colors.orange.shade50,
                        border: Border.all(
                          color: _tieneCertificadoPrevio ? Colors.green.shade300 : Colors.orange.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _tieneCertificadoPrevio ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: _tieneCertificadoPrevio ? Colors.green.shade700 : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _tieneCertificadoPrevio
                                      ? 'Certificado .p12 ACTIVO en este dispositivo'
                                      : 'No se ha cargado archivo .p12 todavía',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _tieneCertificadoPrevio ? Colors.green.shade900 : Colors.orange.shade900,
                                  ),
                                ),
                                if (_fechaCargaStr.isNotEmpty)
                                  Text(
                                    'Cargado el: ${_fechaCargaStr.substring(0, 10)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                              ],
                            ),
                          ),
                          if (_tieneCertificadoPrevio)
                            TextButton(
                              onPressed: _eliminarCertificado,
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Quitar'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón para seleccionar .p12
                    const Text('1. Archivo de Firma (.p12 / .pfx)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        _archivoSeleccionado != null
                            ? 'Seleccionado: ${_archivoSeleccionado!.name}'
                            : (_tieneCertificadoPrevio ? 'Cambiar archivo .p12' : 'Seleccionar archivo .p12 (FirmaEC)'),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      onPressed: _seleccionarArchivoP12,
                    ),
                    const SizedBox(height: 16),

                    // Datos del firmante para el Informe
                    const Text('2. Datos del Oficial Firmante del Patio', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo (como consta en FirmaEC)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cedulaCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cédula de Identidad',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _rangoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Rango / Grado',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.shield),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _cargoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cargo (Ej. ENCARGADO DEL CRV CONTROL 120)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _institucionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Institución (Ej. PERTENECIENTE A LA JEFATURA DE TRÁNSITO SZ SDT.)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Previsualización de la Estampa de FirmaEC
                    const Text('3. Previsualización de Estampa Oficial (FirmaEC)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Center(
                      child: FirmaDigitalService.construirEstampaFirmaEC(
                        nombreFirmante: _nombreCtrl.text.isNotEmpty ? _nombreCtrl.text : 'NOMBRE DEL OFICIAL',
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_mensajeError.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _mensajeError,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar Configuración'),
                          onPressed: _guardarCertificado,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
