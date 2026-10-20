// RUTA DE ARCHIVO: lib/services/exportar_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';

/// Utilidades del panel de administrador para exportar tablas a Excel (.xlsx)
/// y CSV, y para entregar el archivo según la plataforma (descarga directa en
/// el navegador / compartir en Android).
class ExportarService {
  /// Convierte cualquier valor de Firestore/JSON a texto legible.
  static String texto(dynamic v) {
    if (v == null) return '';
    if (v is Timestamp) return _fmtFecha(v.toDate());
    if (v is bool) return v ? 'SI' : 'NO';
    if (v is List) {
      return v.map((e) => e is Map ? e.values.map(texto).join(' | ') : texto(e)).join(' || ');
    }
    if (v is Map) return jsonEncode(v);
    return v.toString();
  }

  static String _fmtFecha(DateTime f) {
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(f.day)}/${d2(f.month)}/${f.year} ${d2(f.hour)}:${d2(f.minute)}';
  }

  /// Genera un .xlsx con una hoja por cada entrada de [hojas]
  /// (nombre de hoja -> filas; la primera fila son los encabezados).
  static List<int> generarXlsx(Map<String, List<List<String>>> hojas) {
    final excel = Excel.createExcel();
    final defecto = excel.getDefaultSheet();
    final nombres = <String>[];
    hojas.forEach((nombre, filas) {
      final limpio = nombre.length > 31 ? nombre.substring(0, 31) : nombre;
      nombres.add(limpio);
      final hoja = excel[limpio];
      for (final fila in filas) {
        hoja.appendRow(fila.map<CellValue?>((c) => TextCellValue(c)).toList());
      }
    });
    if (defecto != null && !nombres.contains(defecto)) {
      excel.delete(defecto);
    }
    return excel.encode() ?? <int>[];
  }

  /// CSV con separador ';' y BOM UTF-8 (Excel en español lo abre bien).
  static List<int> generarCsv(List<List<String>> filas) {
    String esc(String s) {
      final necesita = s.contains(';') || s.contains('"') || s.contains('\n') || s.contains('\r');
      final t = s.replaceAll('"', '""');
      return necesita ? '"$t"' : t;
    }

    final sb = StringBuffer('﻿');
    for (final f in filas) {
      sb.writeln(f.map(esc).join(';'));
    }
    return utf8.encode(sb.toString());
  }

  /// Entrega el archivo: descarga directa en la web, compartir en Android.
  static Future<void> entregar(String nombreArchivo, List<int> bytes) async {
    if (kIsWeb) {
      descargarBytesEnNavegador(nombreArchivo, bytes);
      return;
    }
    final mime = nombreArchivo.toLowerCase().endsWith('.csv')
        ? 'text/csv'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    final xFile = XFile.fromData(Uint8List.fromList(bytes), name: nombreArchivo, mimeType: mime);
    await Share.shareXFiles([xFile], text: nombreArchivo);
  }
}
