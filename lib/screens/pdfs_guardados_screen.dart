// RUTA DE ARCHIVO: lib/screens/pdfs_guardados_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/pdf_respaldo_service.dart';
import 'captura_screen.dart';
import 'home_screen.dart';

/// Ronda 21: pantalla pedida por Xavier para ver, dentro de la misma
/// app, los PDF de partes policiales que se han ido guardando de forma
/// local en el celular (respaldo sin nube — ver pdf_respaldo_service.dart
/// para el porqué). Solo existen mientras sea el mismo celular/cuenta.
class PdfsGuardadosScreen extends StatefulWidget {
  const PdfsGuardadosScreen({super.key});

  @override
  State<PdfsGuardadosScreen> createState() => _PdfsGuardadosScreenState();
}

class _PdfsGuardadosScreenState extends State<PdfsGuardadosScreen> {
  List<File> _archivos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final archivos = await PdfRespaldoService.listar();
    if (mounted) setState(() {
      _archivos = archivos;
      _cargando = false;
    });
  }

  String _nombreCorto(File f) {
    final nombre = f.uri.pathSegments.last;
    return nombre.length > 60 ? '${nombre.substring(0, 57)}...' : nombre;
  }

  String _fechaHora(File f) {
    final m = f.statSync().modified;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(m.day)}/${dos(m.month)}/${m.year} ${dos(m.hour)}:${dos(m.minute)}';
  }

  String _tamano(File f) {
    final kb = f.lengthSync() / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _eliminar(File archivo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar respaldo'),
        content: Text('¿Eliminar "${_nombreCorto(archivo)}" del celular? Esto no afecta el caso ya guardado, solo borra la copia del PDF.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar == true) {
      await PdfRespaldoService.eliminar(archivo);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDFs guardados')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _archivos.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay PDFs respaldados en este celular.\n'
                      'Cada vez que subas un parte en PDF, se guarda aquí automáticamente.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _archivos.length,
                  itemBuilder: (_, i) {
                    final archivo = _archivos[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                        title: Text(_nombreCorto(archivo)),
                        subtitle: Text('${_fechaHora(archivo)} — ${_tamano(archivo)}'),
                        onTap: () => OpenFilex.open(archivo.path),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.upload_file, color: Colors.blue),
                              tooltip: 'Leer de nuevo para Ingreso',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CapturaScreen(tipo: TipoParte.ingreso, pdfInicial: archivo),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.share_outlined),
                              tooltip: 'Compartir',
                              onPressed: () => Share.shareXFiles([XFile(archivo.path)]),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Eliminar',
                              onPressed: () => _eliminar(archivo),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
