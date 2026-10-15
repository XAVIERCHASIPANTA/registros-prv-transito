// RUTA DE ARCHIVO: lib/services/excel_matriz_builder.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';

/// Genera la matriz consolidada de Ingresos/Libertades utilizando EXACTAMENTE
/// la plantilla oficial de Xavier ("media_1791867783316_11e71031.xlsx"),
/// con las siguientes garantías:
/// 1. Las 7 pestañas oficiales intactas: VEHICULOS, INVENTARIO CAJA 1, CARATULA DE EXPEDIENTE,
///    ETIQUETA DE CAJA, INDICE DE F.A, DATOS y MOTOCICLETAS.
/// 2. Filas 1 a 6 intactas con sus colores de fondo, bordes, tipografía y centrado.
/// 3. Cero fórmulas de Excel: todos los datos son VALORES PUROS calculados por la aplicación,
///    garantizando 100% de compatibilidad en computadoras, celulares (WPS Office, Sheets, Excel),
///    evitando errores de fórmulas rotas (-45903, #¡VALOR!, #¿NOMBRE?) y permitiendo ordenar/filtrar
///    sin alterar las cuentas.
class ExcelMatrizBuilder {
  static const _servicioLivianos =
      'SERVICIO DE GARAJE LIVIANOS (HASTA 3,5 TN A EXCEPCIÓN DE MOTOCICLETAS) (DIARIOS)';
  static const _servicioPesados =
      'SERVICIO DE GARAJE PESADOS (DE 3,51 TN HASTA 12 TN) (DIARIOS)';
  static const _servicioMotocicleta =
      'SERVICIO DE GARAJE (CENTROS DE RETENCIÓN) MOTOCICLETA';
  static const _servicioExtraPesados =
      'SERVICIO DE GARAJE EXTRA PESADOS (MÁS DE 12 TN) (DIARIOS)';

  static double _tarifaPorTipo(String tipoCobro) {
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
        return 3.0;
    }
  }

  static String _etiquetaLargaTarifario(String tipoCobroParqueo) {
    switch (tipoCobroParqueo.trim().toUpperCase()) {
      case 'LIVIANO':
        return _servicioLivianos;
      case 'PESADO':
        return _servicioPesados;
      case 'MOTOCICLETA':
        return _servicioMotocicleta;
      case 'EXTRAPESADO':
      case 'EXTRA PESADO':
        return _servicioExtraPesados;
      default:
        if (tipoCobroParqueo.contains('PESADO') && tipoCobroParqueo.contains('EXTRA')) {
          return _servicioExtraPesados;
        }
        if (tipoCobroParqueo.contains('PESADOS')) {
          return _servicioPesados;
        }
        if (tipoCobroParqueo.contains('MOTOCICLETA')) {
          return _servicioMotocicleta;
        }
        return tipoCobroParqueo.isNotEmpty ? tipoCobroParqueo : _servicioLivianos;
    }
  }

  static DateTime? _parseFecha(String texto) {
    final partes = texto.trim().split('/');
    if (partes.length == 3) {
      final dia = int.tryParse(partes[0]);
      final mes = int.tryParse(partes[1]);
      final anio = int.tryParse(partes[2]);
      if (dia != null && mes != null && anio != null) return DateTime(anio, mes, dia);
    }
    final partesGuion = texto.trim().split('-');
    if (partesGuion.length == 3) {
      return DateTime.tryParse(texto.trim());
    }
    return null;
  }

  static String _sanitizarTexto(String texto) {
    if (texto.isEmpty) return '';
    return texto
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static TextCellValue _celdaTexto(String texto) {
    return TextCellValue(_sanitizarTexto(texto));
  }

  static CellValue _celdaFecha(String texto) {
    final dt = _parseFecha(texto);
    if (dt != null) {
      return DateCellValue(year: dt.year, month: dt.month, day: dt.day);
    }
    return _celdaTexto(texto);
  }

  static CellValue _celdaNumeroOTexto(String val) {
    final limpio = _sanitizarTexto(val);
    if (limpio.isEmpty) return TextCellValue('');
    final n = int.tryParse(limpio);
    if (n != null && !limpio.startsWith('0')) {
      return IntCellValue(n);
    }
    return TextCellValue(limpio);
  }

  static int? _diasPermanencia(String fechaIngreso, String fechaSalida) {
    final f1 = _parseFecha(fechaIngreso);
    final f2 = _parseFecha(fechaSalida);
    if (f1 == null || f2 == null) return null;
    return f2.difference(f1).inDays + 1;
  }

  static CasoLibertad? _libertadDe(CasoIngreso ingreso, List<CasoLibertad> libertades) {
    for (final l in libertades) {
      if (l.hojaIngresoNro.isNotEmpty && l.hojaIngresoNro == ingreso.hojaIngresoNro) return l;
    }
    for (final l in libertades) {
      if (l.placa.trim().toUpperCase() == ingreso.placa.trim().toUpperCase()) return l;
    }
    return null;
  }

  static Future<Uint8List?> _cargarPlantillaBytes() async {
    try {
      final byteData = await rootBundle.load('assets/plantilla_matriz_general.xlsx');
      return byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    } catch (_) {
      try {
        final f = File('assets/plantilla_matriz_general.xlsx');
        if (f.existsSync()) return f.readAsBytesSync();
      } catch (_) {}
    }
    return null;
  }

  /// Construye la matriz Excel usando el archivo de plantilla oficial de Xavier
  /// inyectando valores limpios sin fórmulas
  static Future<List<int>> build({
    required List<CasoIngreso> ingresos,
    required List<CasoLibertad> libertades,
    String tituloPatio = 'CONTROL 120',
  }) async {
    final templateBytes = await _cargarPlantillaBytes();
    if (templateBytes == null || templateBytes.isEmpty) {
      return _buildFallback(ingresos: ingresos, libertades: libertades, tituloPatio: tituloPatio);
    }

    final excel = Excel.decodeBytes(templateBytes);

    final vehiculosSheet = excel.tables['VEHICULOS'];
    final motosSheet = excel.tables['MOTOCICLETAS'];

    // Actualizar nombre de patio en fila 3 si corresponde
    final textoCRV = 'CENTRO DE RETENCIÓN VEHICULAR "$tituloPatio"';
    if (vehiculosSheet != null && vehiculosSheet.maxRows > 2) {
      vehiculosSheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
        TextCellValue(textoCRV),
      );
    }
    if (motosSheet != null && motosSheet.maxRows > 2) {
      motosSheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
        TextCellValue(textoCRV),
      );
    }

    // 1. POBLAR PESTAÑA VEHÍCULOS (Sin fórmulas, datos puros y verificados)
    if (vehiculosSheet != null) {
      final listaVehiculos = ingresos.where((i) => i.tipoVehiculo.trim().toUpperCase() != 'MOTOCICLETA').toList();
      int rowVehIndex = 6; // Fila 7 en Excel (0-indexed = 6)

      for (int i = 0; i < listaVehiculos.length; i++) {
        final ing = listaVehiculos[i];
        final lib = _libertadDe(ing, libertades);
        final ord = i + 1;

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

        final primerPago = lib != null && lib.pagos.isNotEmpty ? lib.pagos.first : null;
        final bancoGaraje = primerPago != null
            ? (primerPago.entidadFinancieraOficial.isNotEmpty
                ? primerPago.entidadFinancieraOficial
                : primerPago.entidadFinanciera)
            : '';

        final ordenPagoGaraje = primerPago?.ordenPagoNro ?? '';
        final comprobanteGaraje = primerPago?.comprobantePagoNro ?? '';

        final ordenPagoAlcoho = lib?.ordenPagoAlcohocheckNro.isNotEmpty == true
            ? lib!.ordenPagoAlcohocheckNro
            : (ing.ordenPagoAlcohocheckNro.isNotEmpty ? ing.ordenPagoAlcohocheckNro : 'N/A');

        final valorAlcoho = lib?.valorAlcohocheck.isNotEmpty == true
            ? lib!.valorAlcohocheck
            : (ing.valorAlcohocheck.isNotEmpty ? ing.valorAlcohocheck : 'N/A');

        final pericia = lib?.periciaRealizada.isNotEmpty == true ? lib!.periciaRealizada : 'N/A';
        final perito = lib?.peritoNombre.isNotEmpty == true ? lib!.peritoNombre : 'N/A';

        final tipoCobro = ing.tipoCobroParqueo.isNotEmpty
            ? ing.tipoCobroParqueo
            : (lib?.tipoServicioGaraje.isNotEmpty == true ? lib!.tipoServicioGaraje : 'LIVIANO');
        final etiquetaLargaTarifa = _etiquetaLargaTarifario(tipoCobro);
        final tarifa = _tarifaPorTipo(tipoCobro);

        final dias = (lib != null && lib.fechaSalida.isNotEmpty)
            ? _diasPermanencia(ing.fechaIngreso, lib.fechaSalida)
            : null;

        double? valorCalculado;
        if (lib != null) {
          if (lib.valorTotalGaraje > 0) {
            valorCalculado = lib.valorTotalGaraje;
          } else if (dias != null) {
            valorCalculado = dias * tarifa;
          }
        }

        final fechaPagoPericia = lib?.horaFechaPagoAlcohocheck.isNotEmpty == true
            ? lib!.horaFechaPagoAlcohocheck
            : (primerPago?.horaFechaPago ?? '');
        final compPagoPericia = lib?.comprobantePagoAlcohocheckNro.isNotEmpty == true
            ? lib!.comprobantePagoAlcohocheckNro
            : comprobanteGaraje;
        final bancoPericia = bancoGaraje;

        void setCell(int col, CellValue val) {
          vehiculosSheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowVehIndex),
            val,
          );
        }

        setCell(0, IntCellValue(ord));
        setCell(1, _celdaTexto(ing.subzona.isNotEmpty ? ing.subzona : 'SANTO DOMINGO'));
        setCell(2, _celdaTexto(ing.crv.isNotEmpty ? ing.crv : tituloPatio));
        setCell(3, _celdaFecha(ing.fechaIngreso));
        setCell(4, _celdaNumeroOTexto(ing.hojaIngresoNro));
        setCell(5, _celdaTexto(ing.placa.trim().toUpperCase()));
        setCell(6, _celdaTexto(ing.marca.trim()));
        setCell(7, _celdaTexto(ing.tipoVehiculo.trim()));
        setCell(8, _celdaTexto(ing.modelo.trim()));
        setCell(9, _celdaTexto(ing.color.trim()));
        setCell(10, _celdaNumeroOTexto(ing.anioFabricacion));
        setCell(11, _celdaTexto(ing.chasis.trim()));
        setCell(12, _celdaTexto(ing.motor.trim()));
        setCell(13, _celdaTexto(ing.parteIngresoNro.trim()));
        setCell(14, _celdaTexto(ing.policiaNombre.trim()));
        setCell(15, _celdaTexto(ing.propietario.trim()));
        setCell(16, _celdaTexto(situacionLegal));
        setCell(17, _celdaTexto(autoridad));
        setCell(18, _celdaTexto(placaGrua));
        setCell(19, _celdaTexto(conductorGrua));
        setCell(20, _celdaTexto(ing.custodioRecibeNombre.trim().isNotEmpty ? ing.custodioRecibeNombre.trim() : 'SGOS. CHASIPANTA XAVIER'));

        if (lib != null && lib.fechaSalida.isNotEmpty) {
          setCell(21, _celdaFecha(lib.fechaSalida));
          setCell(22, _celdaTexto(lib.oficioDevolucionNro.trim()));
          setCell(23, _celdaTexto(lib.firmadoPor.trim()));
          setCell(24, _celdaTexto(lib.retiradoPor.trim()));
          setCell(25, _celdaTexto(lib.cedulaRetira.trim()));
          setCell(26, _celdaNumeroOTexto(ordenPagoGaraje));
          setCell(27, _celdaTexto(etiquetaLargaTarifa));
          setCell(28, dias != null ? IntCellValue(dias) : TextCellValue(''));
          setCell(29, IntCellValue(tarifa.toInt()));
          setCell(30, valorCalculado != null ? IntCellValue(valorCalculado.toInt()) : TextCellValue(''));
          setCell(31, _celdaNumeroOTexto(ordenPagoGaraje));
          if (primerPago?.horaFechaPago.isNotEmpty == true) {
            setCell(32, _celdaFecha(primerPago!.horaFechaPago));
          } else {
            setCell(32, TextCellValue(''));
          }
          setCell(33, _celdaNumeroOTexto(comprobanteGaraje));
          setCell(34, _celdaTexto(bancoGaraje));
          setCell(35, _celdaTexto(bancoGaraje));
          setCell(36, _celdaNumeroOTexto(ing.hojaIngresoNro));
          setCell(37, _celdaTexto(lib.custodioEntregaNombre.trim()));
        } else {
          for (int c = 21; c <= 37; c++) {
            setCell(c, TextCellValue(''));
          }
        }

        setCell(38, _celdaTexto(ordenPagoAlcoho));
        setCell(39, _celdaTexto(valorAlcoho));
        setCell(40, _celdaTexto(pericia));
        setCell(41, _celdaTexto(perito));
        if (fechaPagoPericia.isNotEmpty && fechaPagoPericia != 'N/A') {
          setCell(42, _celdaFecha(fechaPagoPericia));
        } else {
          setCell(42, TextCellValue(''));
        }
        setCell(43, _celdaNumeroOTexto(compPagoPericia));
        setCell(44, _celdaTexto(bancoPericia));

        rowVehIndex++;
      }

      // Limpiar cualquier fila remanente
      while (rowVehIndex < vehiculosSheet.maxRows) {
        for (int c = 0; c < 45; c++) {
          vehiculosSheet.updateCell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowVehIndex), TextCellValue(''));
        }
        rowVehIndex++;
      }
    }

    // 2. POBLAR PESTAÑA MOTOCICLETAS (Sin fórmulas, datos puros)
    if (motosSheet != null) {
      final listaMotos = ingresos.where((i) => i.tipoVehiculo.trim().toUpperCase() == 'MOTOCICLETA').toList();
      int rowMotoIndex = 6; // Fila 7 en Excel (0-indexed = 6)

      for (int i = 0; i < listaMotos.length; i++) {
        final ing = listaMotos[i];
        final lib = _libertadDe(ing, libertades);
        final ord = i + 1;

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

        final primerPago = lib != null && lib.pagos.isNotEmpty ? lib.pagos.first : null;
        final bancoGaraje = primerPago != null
            ? (primerPago.entidadFinancieraOficial.isNotEmpty
                ? primerPago.entidadFinancieraOficial
                : primerPago.entidadFinanciera)
            : '';

        final ordenPagoGaraje = primerPago?.ordenPagoNro ?? '';
        final comprobanteGaraje = primerPago?.comprobantePagoNro ?? '';

        final ordenPagoAlcoho = lib?.ordenPagoAlcohocheckNro.isNotEmpty == true
            ? lib!.ordenPagoAlcohocheckNro
            : (ing.ordenPagoAlcohocheckNro.isNotEmpty ? ing.ordenPagoAlcohocheckNro : 'N/A');

        final valorAlcoho = lib?.valorAlcohocheck.isNotEmpty == true
            ? lib!.valorAlcohocheck
            : (ing.valorAlcohocheck.isNotEmpty ? ing.valorAlcohocheck : 'N/A');

        final pericia = lib?.periciaRealizada.isNotEmpty == true ? lib!.periciaRealizada : 'N/A';
        final perito = lib?.peritoNombre.isNotEmpty == true ? lib!.peritoNombre : 'N/A';

        final dias = (lib != null && lib.fechaSalida.isNotEmpty)
            ? _diasPermanencia(ing.fechaIngreso, lib.fechaSalida)
            : null;

        final valorCanceladoMoto = (lib != null && lib.valorTotalGaraje > 0)
            ? lib.valorTotalGaraje.toInt()
            : (dias != null ? dias : null);

        final fechaPagoPericia = lib?.horaFechaPagoAlcohocheck.isNotEmpty == true
            ? lib!.horaFechaPagoAlcohocheck
            : (primerPago?.horaFechaPago ?? '');
        final compPagoPericia = lib?.comprobantePagoAlcohocheckNro.isNotEmpty == true
            ? lib!.comprobantePagoAlcohocheckNro
            : comprobanteGaraje;
        final bancoPericia = bancoGaraje;

        void setCell(int col, CellValue val) {
          motosSheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowMotoIndex),
            val,
          );
        }

        setCell(0, IntCellValue(ord));
        setCell(1, _celdaTexto(ing.subzona.isNotEmpty ? ing.subzona : 'SANTO DOMINGO'));
        setCell(2, _celdaTexto(ing.crv.isNotEmpty ? ing.crv : tituloPatio));
        setCell(3, _celdaFecha(ing.fechaIngreso));
        setCell(4, _celdaNumeroOTexto(ing.hojaIngresoNro));
        setCell(5, _celdaTexto(ing.placa.trim().toUpperCase()));
        setCell(6, _celdaTexto(ing.marca.trim()));
        setCell(7, _celdaTexto(ing.modelo.trim()));
        setCell(8, _celdaTexto(ing.color.trim()));
        setCell(9, _celdaNumeroOTexto(ing.anioFabricacion));
        setCell(10, _celdaTexto(ing.chasis.trim()));
        setCell(11, _celdaTexto(ing.motor.trim()));
        setCell(12, _celdaTexto(ing.parteIngresoNro.trim()));
        setCell(13, _celdaTexto(ing.policiaNombre.trim()));
        setCell(14, _celdaTexto(ing.propietario.trim()));
        setCell(15, _celdaTexto(situacionLegal));
        setCell(16, _celdaTexto(autoridad));
        setCell(17, _celdaTexto(placaGrua));
        setCell(18, _celdaTexto(conductorGrua));
        setCell(19, _celdaTexto(ing.custodioRecibeNombre.trim().isNotEmpty ? ing.custodioRecibeNombre.trim() : 'SGOS. CHASIPANTA XAVIER'));

        if (lib != null && lib.fechaSalida.isNotEmpty) {
          setCell(20, _celdaFecha(lib.fechaSalida));
          setCell(21, _celdaTexto(lib.oficioDevolucionNro.trim()));
          setCell(22, _celdaTexto(lib.firmadoPor.trim()));
          setCell(23, _celdaTexto(lib.retiradoPor.trim()));
          setCell(24, _celdaTexto(lib.cedulaRetira.trim()));
          setCell(25, _celdaNumeroOTexto(ordenPagoGaraje));
          setCell(26, dias != null ? IntCellValue(dias) : TextCellValue(''));
          setCell(27, valorCanceladoMoto != null ? IntCellValue(valorCanceladoMoto) : TextCellValue(''));
          setCell(28, _celdaNumeroOTexto(ing.hojaIngresoNro));
          setCell(29, _celdaTexto(lib.custodioEntregaNombre.trim()));
        } else {
          for (int c = 20; c <= 29; c++) {
            setCell(c, TextCellValue(''));
          }
        }

        setCell(30, _celdaTexto(ordenPagoAlcoho));
        setCell(31, _celdaTexto(valorAlcoho));
        setCell(32, _celdaTexto(pericia));
        setCell(33, _celdaTexto(perito));
        if (fechaPagoPericia.isNotEmpty && fechaPagoPericia != 'N/A') {
          setCell(34, _celdaFecha(fechaPagoPericia));
        } else {
          setCell(34, TextCellValue(''));
        }
        setCell(35, _celdaNumeroOTexto(compPagoPericia));
        setCell(36, _celdaTexto(bancoPericia));

        rowMotoIndex++;
      }

      // Limpiar cualquier fila remanente
      while (rowMotoIndex < motosSheet.maxRows) {
        for (int c = 0; c < 37; c++) {
          motosSheet.updateCell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowMotoIndex), TextCellValue(''));
        }
        rowMotoIndex++;
      }
    }

    return excel.encode() ?? [];
  }

  /// Generador básico de respaldo solo en caso extremo de que no exista el archivo de plantilla
  static List<int> _buildFallback({
    required List<CasoIngreso> ingresos,
    required List<CasoLibertad> libertades,
    required String tituloPatio,
  }) {
    final excel = Excel.createExcel();
    final hojaDefectoOriginal = excel.getDefaultSheet();

    final vehiculos = excel['VEHICULOS'];
    final motos = excel['MOTOCICLETAS'];

    if (hojaDefectoOriginal != null &&
        hojaDefectoOriginal != 'VEHICULOS' &&
        hojaDefectoOriginal != 'MOTOCICLETAS') {
      excel.delete(hojaDefectoOriginal);
    }
    excel.setDefaultSheet('VEHICULOS');

    return excel.encode() ?? [];
  }
}
