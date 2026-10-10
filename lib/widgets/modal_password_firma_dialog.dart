import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/firma_digital_service.dart';
import 'firma_digital_dialog.dart';

class ModalPasswordFirmaDialog extends StatefulWidget {
  final Uint8List pdfUnsignedBytes;
  final String nombreFirmante;

  const ModalPasswordFirmaDialog({
    super.key,
    required this.pdfUnsignedBytes,
    required this.nombreFirmante,
  });

  static Future<Uint8List?> solicitarYFirmar(
    BuildContext context, {
    required Uint8List pdfUnsignedBytes,
    required String nombreFirmante,
  }) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ModalPasswordFirmaDialog(
        pdfUnsignedBytes: pdfUnsignedBytes,
        nombreFirmante: nombreFirmante,
      ),
    );
  }

  @override
  State<ModalPasswordFirmaDialog> createState() => _ModalPasswordFirmaDialogState();
}

class _ModalPasswordFirmaDialogState extends State<ModalPasswordFirmaDialog> {
  final _passwordCtrl = TextEditingController();
  bool _cargando = false;
  bool _obscureText = true;
  String _mensajeError = '';
  Uint8List? _bytesP12;
  String _nombreCertificado = '';

  @override
  void initState() {
    super.initState();
    _cargarCertificado();
  }

  Future<void> _cargarCertificado() async {
    final bytes = await FirmaDigitalService.obtenerBytesCertificadoP12();
    final datos = await FirmaDigitalService.obtenerDatosFirmante();
    if (bytes != null && mounted) {
      setState(() {
        _bytesP12 = bytes;
        _nombreCertificado = datos['nombre']!.isNotEmpty ? datos['nombre']! : widget.nombreFirmante;
      });
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _procesarFirma() async {
    final pass = _passwordCtrl.text;
    if (pass.isEmpty) {
      setState(() => _mensajeError = 'Ingrese la contraseña de su certificado (.p12).');
      return;
    }

    if (_bytesP12 == null) {
      setState(() => _mensajeError = 'No se encontró el archivo .p12 en el dispositivo.');
      return;
    }

    setState(() {
      _cargando = true;
      _mensajeError = '';
    });

    try {
      final esValido = FirmaDigitalService.validarClaveP12(
        bytesP12: _bytesP12!,
        password: pass,
      );

      if (!esValido) {
        setState(() {
          _cargando = false;
          _mensajeError = 'Contraseña incorrecta. Verifique e intente nuevamente.';
        });
        return;
      }

      final signedPdfBytes = await FirmaDigitalService.firmarDocumentoPdf(
        pdfInputBytes: widget.pdfUnsignedBytes,
        bytesP12: _bytesP12!,
        password: pass,
        nombreFirmante: widget.nombreFirmante,
      );

      if (mounted) {
        Navigator.pop(context, signedPdfBytes);
      }
    } catch (e) {
      setState(() {
        _cargando = false;
        _mensajeError = 'Error al procesar la firma digital: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytesP12 == null) {
      return AlertDialog(
        title: const Text('Firma Digital Requerida'),
        content: const Text(
          'No ha cargado su archivo de firma digital (.p12) en este dispositivo. '
          'Desea abrir la configuración para cargarlo ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, widget.pdfUnsignedBytes),
            child: const Text('Generar PDF sin firmar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Cargar Certificado .p12'),
            onPressed: () async {
              Navigator.pop(context, null);
              await FirmaDigitalDialog.mostrar(context);
            },
          ),
        ],
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: Colors.blue, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Firmar Informe Digital (FirmaEC)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),

            Text(
              'Firmante: ${_nombreCertificado.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Ingrese la contraseña de su clave privada (.p12) para aplicar la firma digital oficial.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscureText,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Contraseña del Certificado .p12',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              onFieldSubmitted: (_) => _procesarFirma(),
            ),
            const SizedBox(height: 14),

            if (_mensajeError.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _mensajeError,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _cargando ? null : () => Navigator.pop(context, widget.pdfUnsignedBytes),
                  child: const Text('Omitir Firma'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  icon: _cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.draw),
                  label: Text(_cargando ? 'Firmando...' : 'Firmar PDF'),
                  onPressed: _cargando ? null : _procesarFirma,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
