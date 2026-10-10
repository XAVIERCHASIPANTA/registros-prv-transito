import '../data/patios_nacional.dart';
// RUTA DE ARCHIVO: lib/services/storage_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import '../models/informe_semanal_record.dart';
import 'auth_service.dart';
import 'docx_builder.dart';
import 'excel_matriz_builder.dart';
import 'firestore_sync_service.dart';

class IngresoDuplicadoException implements Exception {
  final CasoIngreso ingresoExistente;
  IngresoDuplicadoException(this.ingresoExistente);
}

class StorageService {
  static const _claveIngresos = 'ingresos_json_v1';
  static const _claveLibertades = 'libertades_json_v1';
  static const _claveInformesSemanales = 'informes_semanales_json_v1';

  static List<CasoIngreso>? _cacheIngresos;
  static List<CasoLibertad>? _cacheLibertades;

  static String ultimaSubzona = '';
  static String ultimoCrv = '';
  static String ultimoPoliciaNombre = '';
  static String ultimoOficioInformeNro = '';
  static String ultimoAsuntoOficioNro = '';
  static String ultimoAsuntoOficioFecha = '';
  static String ultimoDestinatarioNombre = '';
  static String ultimoDestinatarioRango = '';
  static String ultimoFirmanteNombre = '';
  static String ultimoFirmanteRango = '';

  static Future<Map<String, String>> obtenerPerfilCompletoUsuario() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return {};
    final perfil = await AuthService().obtenerPerfil(usuario.uid);
    if (perfil == null) return {};

    final patioStr = (perfil['patio'] ?? '').toString().trim();
    final jefaturaStr = (perfil['jefaturaTransito'] ?? '').toString().trim();
    final subzonaStr = (perfil['subzona'] ?? '').toString().trim();
    final zonaStr = (perfil['zona'] ?? '').toString().trim();
    final nombreStr = (perfil['nombre'] ?? usuario.displayName ?? '').toString().trim();
    final rangoStr = (perfil['rango'] ?? perfil['grado'] ?? '').toString().trim();

    Patio? patioMatch;
    if (patioStr.isNotEmpty) {
      patioMatch = buscarPatioPorNombre(patioStr);
    }

    final jefaturaFinal = jefaturaStr.isNotEmpty
        ? jefaturaStr
        : (patioMatch?.jefatura.isNotEmpty == true ? patioMatch!.jefatura : '');

    final zonaFinal = zonaStr.isNotEmpty
        ? zonaStr
        : (patioMatch?.zona.isNotEmpty == true ? patioMatch!.zona : '');

    return {
      'patio': patioStr,
      'jefatura': jefaturaFinal,
      'subzona': subzonaStr,
      'zona': zonaFinal,
      'nombre': nombreStr,
      'rango': rangoStr,
    };
  }

  static Future<String> _patioDelUsuario() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return '';
    final perfil = await AuthService().obtenerPerfil(usuario.uid);
    return perfil?['patio'] ?? '';
  }

  static Future<void> _asegurarCargadoLocal() async {
    if (_cacheIngresos != null && _cacheLibertades != null) return;
    final prefs = await SharedPreferences.getInstance();

    final jsonIngresos = prefs.getString(_claveIngresos);
    _cacheIngresos = jsonIngresos == null
        ? <CasoIngreso>[]
        : (jsonDecode(jsonIngresos) as List).map((e) => CasoIngreso.fromJson(e)).toList();

    final jsonLibertades = prefs.getString(_claveLibertades);
    _cacheLibertades = jsonLibertades == null
        ? <CasoLibertad>[]
        : (jsonDecode(jsonLibertades) as List).map((e) => CasoLibertad.fromJson(e)).toList();
  }

  static Future<void> _guardarIngresosEnDisco() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveIngresos, jsonEncode(_cacheIngresos!.map((e) => e.toJson()).toList()));
  }

  static Future<void> _guardarLibertadesEnDisco() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveLibertades, jsonEncode(_cacheLibertades!.map((e) => e.toJson()).toList()));
  }

  static Future<List<CasoIngreso>> obtenerIngresos() async {
    final patio = await _patioDelUsuario();
    if (patio.isNotEmpty) {
      try {
        final desdeNube = await FirestoreSyncService().obtenerIngresos(patio);
        _cacheIngresos = desdeNube;
        await _guardarIngresosEnDisco();
        return List<CasoIngreso>.from(desdeNube);
      } catch (_) {}
    }
    await _asegurarCargadoLocal();
    return List<CasoIngreso>.from(_cacheIngresos!);
  }

  static Future<List<CasoLibertad>> obtenerLibertades() async {
    final patio = await _patioDelUsuario();
    if (patio.isNotEmpty) {
      try {
        final desdeNube = await FirestoreSyncService().obtenerLibertades(patio);
        _cacheLibertades = desdeNube;
        await _guardarLibertadesEnDisco();
        return List<CasoLibertad>.from(desdeNube);
      } catch (_) {}
    }
    await _asegurarCargadoLocal();
    return List<CasoLibertad>.from(_cacheLibertades!);
  }

  static Future<List<CasoIngreso>> buscarIngresosPorPlaca(String placa) async {
    final normalizada = placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    final lista = await obtenerIngresos();
    return lista
        .where((c) => c.placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase().contains(normalizada))
        .toList();
  }

  static Future<List<CasoLibertad>> buscarLibertadesPorPlaca(String placa) async {
    final normalizada = placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    final lista = await obtenerLibertades();
    return lista
        .where((c) => c.placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase().contains(normalizada))
        .toList();
  }

  static Future<bool> yaTieneLibertad(String hojaIngresoNro) async {
    final libertades = await obtenerLibertades();
    return libertades.any((l) => l.hojaIngresoNro == hojaIngresoNro);
  }

  static Future<CasoIngreso?> ingresoAbiertoPorPlaca(String placa, {String? excluirId}) async {
    final normalizada = placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    if (normalizada.isEmpty) return null;
    final ingresos = await obtenerIngresos();
    final libertades = await obtenerLibertades();
    final hojasLiberadas = libertades.map((l) => l.hojaIngresoNro).toSet();
    for (final ing in ingresos) {
      if (excluirId != null && ing.id == excluirId) continue;
      final placaIng = ing.placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
      if (placaIng == normalizada && !hojasLiberadas.contains(ing.hojaIngresoNro)) {
        return ing;
      }
    }
    return null;
  }

  static Future<void> guardarCasoIngreso(CasoIngreso caso) async {
    await _asegurarCargadoLocal();
    final indice = _cacheIngresos!.indexWhere((c) => c.id == caso.id);
    final esEdicion = indice != -1;

    if (!esEdicion) {
      final duplicado = await ingresoAbiertoPorPlaca(caso.placa, excluirId: caso.id);
      if (duplicado != null) {
        throw IngresoDuplicadoException(duplicado);
      }
      _cacheIngresos!.add(caso);
    } else {
      _cacheIngresos![indice] = caso;
    }
    await _guardarIngresosEnDisco();

    if (caso.subzona.trim().isNotEmpty) ultimaSubzona = caso.subzona;
    if (caso.crv.trim().isNotEmpty) ultimoCrv = caso.crv;
    if (caso.policiaNombre.trim().isNotEmpty) ultimoPoliciaNombre = caso.policiaNombre;

    final patio = await _patioDelUsuario();
    await FirestoreSyncService().subirIngreso(caso, patio: patio);
    if (esEdicion) {
      await FirestoreSyncService().registrarEdicion(
        tipo: 'ingreso',
        casoId: caso.id,
        placa: caso.placa,
        patio: patio,
      );
    }
  }

  static Future<void> guardarCasoLibertad(CasoLibertad caso) async {
    await _asegurarCargadoLocal();
    final indice = _cacheLibertades!.indexWhere((c) => c.id == caso.id);
    final esEdicion = indice != -1;
    if (!esEdicion) {
      _cacheLibertades!.add(caso);
    } else {
      _cacheLibertades![indice] = caso;
    }
    await _guardarLibertadesEnDisco();

    final patio = await _patioDelUsuario();
    await FirestoreSyncService().subirLibertad(caso, patio: patio);
    if (esEdicion) {
      await FirestoreSyncService().registrarEdicion(
        tipo: 'libertad',
        casoId: caso.id,
        placa: caso.placa,
        patio: patio,
      );
    }
  }

  static List<int> generarWordIngreso(CasoIngreso c) => DocxBuilder.buildIngreso(c);

  static Future<List<int>> generarWordMasterIngresos() async {
    final ingresos = await obtenerIngresos();
    ingresos.sort((a, b) => b.creado.compareTo(a.creado));
    return DocxBuilder.buildMasterIngresos(ingresos);
  }

  static Future<List<int>> generarWordMasterLibertades() async {
    final libertades = await obtenerLibertades();
    libertades.sort((a, b) => b.creado.compareTo(a.creado));
    return DocxBuilder.buildMasterLibertades(libertades);
  }

  static List<int> generarWordLibertad(CasoLibertad c) => DocxBuilder.buildLibertad(c);

  static String obtenerNombreArchivoWord({required String placa, required bool esIngreso, String hojaIngresoNro = ''}) {
    final placaLimpia = placa.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (esIngreso) {
      return 'Ingreso $placaLimpia hoja N° $hojaIngresoNro.docx';
    } else {
      return 'Libertad_$placaLimpia.docx';
    }
  }

  static Future<List<int>?> generarExcelConsolidado() async {
    final ingresos = await obtenerIngresos();
    if (ingresos.isEmpty) return null;
    final libertades = await obtenerLibertades();
    return ExcelMatrizBuilder.build(ingresos: ingresos, libertades: libertades);
  }

  static DateTime? _parseFechaDdMmAaaa(String texto) {
    final partes = texto.trim().split('/');
    if (partes.length != 3) return null;
    final d = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    final y = int.tryParse(partes[2]);
    if (d == null || m == null || y == null) return null;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  static Future<({int vehiculos, int motocicletas})> contarLibertadesEnRango(
    DateTime lunes,
    DateTime domingo,
  ) async {
    final lista = await obtenerLibertades();
    var vehiculos = 0;
    var motocicletas = 0;

    final desde = DateTime(lunes.year, lunes.month, lunes.day);
    final hasta = DateTime(domingo.year, domingo.month, domingo.day, 23, 59, 59);

    for (final c in lista) {
      final fecha = _parseFechaDdMmAaaa(c.fechaSalida);
      if (fecha == null) continue;
      if (fecha.isBefore(desde) || fecha.isAfter(hasta)) continue;

      if (c.tipoVehiculo.trim().toUpperCase() == 'MOTOCICLETA') {
        motocicletas++;
      } else {
        vehiculos++;
      }
    }

    return (vehiculos: vehiculos, motocicletas: motocicletas);
  }

  // ---------- Historial de Informes Semanales ----------

  static Future<void> guardarInformeSemanalRecord(InformeSemanalRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final historial = await obtenerHistorialInformesSemanales();
    historial.removeWhere((r) => r.id == record.id);
    historial.insert(0, record);
    await prefs.setString(_claveInformesSemanales, jsonEncode(historial.map((e) => e.toJson()).toList()));
    final patio = await _patioDelUsuario();
    await FirestoreSyncService().subirInformeSemanal(record, patio: patio.isNotEmpty ? patio : record.patio);
  }

  static Future<List<InformeSemanalRecord>> obtenerHistorialInformesSemanales() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_claveInformesSemanales);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => InformeSemanalRecord.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
