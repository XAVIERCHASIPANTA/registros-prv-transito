// RUTA DE ARCHIVO: lib/services/excel_matriz_builder.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';

/// Genera la matriz consolidada de Ingresos/Libertades utilizando EXACTAMENTE
/// la plantilla oficial de Xavier ("media_1791867783316_11e71031.xlsx"),
/// preservando:
/// 1. Las 7 pestañas oficiales: VEHICULOS, INVENTARIO CAJA 1, CARATULA DE EXPEDIENTE,
///    ETIQUETA DE CAJA, INDICE DE F.A, DATOS y MOTOCICLETAS.
/// 2. Las filas 1 a 6 intactas con sus colores, fuentes, centrado, bordes
///    y encabezados superiores ("INGRESO DEL VEHICULO", "SALIDA DE VEHICULO",
///    "ALCOHOCHECK", "INVESTIGACIÓN").
/// 3. Las fórmulas oficiales de Excel (cálculo dinámico de días, tarifas ANT,
///    liquidaciones de garaje, referencias automáticas de formulario y banco).
/// 4. Los datos reales de la aplicación inyectados a partir de la fila 7.
class ExcelMatrizBuilder {
  static const _servicioLivianos =
      'SERVICIO DE GARAJE LIVIANOS (HASTA 3,5 TN A EXCEPCIÓN DE MOTOCICLETAS) (DIARIOS)';
  static const _servicioPesados =
      'SERVICIO DE GARAJE PESADOS (DE 3,51 TN HASTA 12 TN) (DIARIOS)';
  static const _servicioMotocicleta =
      'SERVICIO DE GARAJE (CENTROS DE RETENCIÓN) MOTOCICLETA';
  static const _servicioExtraPesados =
      'SERVICIO DE GARAJE EXTRA PESADOS (MÁS DE 12 TN) (DIARIOS)';

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

  static CellValue _celdaFecha(String texto) {
    final dt = _parseFecha(texto);
    if (dt != null) {
      return DateCellValue(year: dt.year, month: dt.month, day: dt.day);
    }
    return TextCellValue(texto.trim());
  }

  static CellValue _celdaNumeroOTexto(String val) {
    final limpio = val.trim();
    final n = int.tryParse(limpio);
    if (n != null && !limpio.startsWith('0')) {
      return IntCellValue(n);
    }
    return TextCellValue(limpio);
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
  static Future<List<int>> build({
    required List<CasoIngreso> ingresos,
    required List<CasoLibertad> libertades,
    String tituloPatio = 'CONTROL 120',
  }) async {
    final templateBytes = await _cargarPlantillaBytes();
    if (templateBytes == null || templateBytes.isEmpty) {
      // Fallback de emergencia si no se encuentra el asset
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

    // 1. POBLAR PESTAÑA VEHÍCULOS
    if (vehiculosSheet != null) {
      final listaVehiculos = ingresos.where((i) => i.tipoVehiculo.trim().toUpperCase() != 'MOTOCICLETA').toList();
      int rowVehIndex = 6; // Fila 7 en Excel (0-indexed = 6)

      for (int i = 0; i < listaVehiculos.length; i++) {
        final ing = listaVehiculos[i];
        final lib = _libertadDe(ing, libertades);
        final ord = i + 1;
        final excelRow = rowVehIndex + 1; // 1-based para fórmulas

        final situacionLegal = ing.causaLegal.isNotEmpty
            ? (ing.detalleCausa.isNotEmpty ? '${ing.causaLegal} - ${ing.detalleCausa}' : ing.causaLegal)
            : ing.causaPrincipal;

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

        void setCell(int col, CellValue val) {
          vehiculosSheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowVehIndex),
            val,
          );
        }

        setCell(0, IntCellValue(ord));
        setCell(1, TextCellValue(ing.subzona.isNotEmpty ? ing.subzona : 'SANTO DOMINGO'));
        setCell(2, TextCellValue(ing.crv.isNotEmpty ? ing.crv : tituloPatio));
        setCell(3, _celdaFecha(ing.fechaIngreso));
        setCell(4, _celdaNumeroOTexto(ing.hojaIngresoNro));
        setCell(5, TextCellValue(ing.placa.trim().toUpperCase()));
        setCell(6, TextCellValue(ing.marca.trim()));
        setCell(7, TextCellValue(ing.tipoVehiculo.trim()));
        setCell(8, TextCellValue(ing.modelo.trim()));
        setCell(9, TextCellValue(ing.color.trim()));
        setCell(10, _celdaNumeroOTexto(ing.anioFabricacion));
        setCell(11, TextCellValue(ing.chasis.trim()));
        setCell(12, TextCellValue(ing.motor.trim()));
        setCell(13, TextCellValue(ing.parteIngresoNro.trim()));
        setCell(14, TextCellValue(ing.policiaNombre.trim()));
        setCell(15, TextCellValue(ing.propietario.trim()));
        setCell(16, TextCellValue(situacionLegal));
        setCell(17, TextCellValue(autoridad));
        setCell(18, TextCellValue(placaGrua));
        setCell(19, TextCellValue(conductorGrua));
        setCell(20, TextCellValue(ing.custodioRecibeNombre.trim().isNotEmpty ? ing.custodioRecibeNombre.trim() : 'SGOS. CHASIPANTA XAVIER'));

        if (lib != null && lib.fechaSalida.isNotEmpty) {
          setCell(21, _celdaFecha(lib.fechaSalida));
          setCell(22, TextCellValue(lib.oficioDevolucionNro.trim()));
          setCell(23, TextCellValue(lib.firmadoPor.trim()));
          setCell(24, TextCellValue(lib.retiradoPor.trim()));
          setCell(25, TextCellValue(lib.cedulaRetira.trim()));
          setCell(26, _celdaNumeroOTexto(ordenPagoGaraje));
          setCell(27, TextCellValue(etiquetaLargaTarifa));
          // Fórmula oficial de días:
          setCell(28, FormulaCellValue('=(V$excelRow-D$excelRow)+1'));
          // Fórmula oficial de tarifa diaria ANT:
          setCell(29, FormulaCellValue('IF(AB$excelRow="SERVICIO DE GARAJE LIVIANOS (HASTA 3,5 TN A EXCEPCIÓN DE MOTOCICLETAS) (DIARIOS)",3,IF(AB$excelRow="SERVICIO DE GARAJE PESADOS (DE 3,51 TN HASTA 12 TN) (DIARIOS)",9,IF(AB$excelRow="SERVICIO DE GARAJE (CENTROS DE RETENCIÓN) MOTOCICLETA",1,IF(AB$excelRow="SERVICIO DE GARAJE EXTRA PESADOS (MÁS DE 12 TN) (DIARIOS)",15,0))))'));
          // Fórmula oficial de total parqueo:
          setCell(30, FormulaCellValue('IFERROR(AD$excelRow*AC$excelRow,0)'));
          // Fórmula de réplica de orden de pago:
          setCell(31, FormulaCellValue('AA$excelRow'));
          if (primerPago?.horaFechaPago.isNotEmpty == true) {
            setCell(32, _celdaFecha(primerPago!.horaFechaPago));
          } else {
            setCell(32, TextCellValue(''));
          }
          setCell(33, _celdaNumeroOTexto(comprobanteGaraje));
          setCell(34, TextCellValue(bancoGaraje));
          setCell(35, FormulaCellValue('AI$excelRow'));
          setCell(36, FormulaCellValue('IF(E$excelRow="","",E$excelRow)'));
          setCell(37, TextCellValue(lib.custodioEntregaNombre.trim()));
        } else {
          setCell(21, TextCellValue(''));
          setCell(22, TextCellValue(''));
          setCell(23, TextCellValue(''));
          setCell(24, TextCellValue(''));
          setCell(25, TextCellValue(''));
          setCell(26, TextCellValue(''));
          setCell(27, TextCellValue(''));
          setCell(28, TextCellValue(''));
          setCell(29, TextCellValue(''));
          setCell(30, TextCellValue(''));
          setCell(31, TextCellValue(''));
          setCell(32, TextCellValue(''));
          setCell(33, TextCellValue(''));
          setCell(34, TextCellValue(''));
          setCell(35, TextCellValue(''));
          setCell(36, FormulaCellValue('IF(E$excelRow="","",E$excelRow)'));
          setCell(37, TextCellValue(''));
        }

        setCell(38, TextCellValue(ordenPagoAlcoho));
        setCell(39, TextCellValue(valorAlcoho));
        setCell(40, TextCellValue(pericia));
        setCell(41, TextCellValue(perito));
        setCell(42, FormulaCellValue('AG$excelRow'));
        setCell(43, FormulaCellValue('AH$excelRow'));
        setCell(44, FormulaCellValue('AI$excelRow'));

        rowVehIndex++;
      }

      // Limpiar filas antiguas de plantilla si hubieran quedado remanentes
      while (rowVehIndex < vehiculosSheet.maxRows) {
        final placaVal = vehiculosSheet.rows[rowVehIndex].length > 5 ? vehiculosSheet.rows[rowVehIndex][5]?.value : null;
        if (placaVal == null || placaVal.toString().trim().isEmpty) break;
        for (int c = 0; c < 45; c++) {
          vehiculosSheet.updateCell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowVehIndex), TextCellValue(''));
        }
        rowVehIndex++;
      }
    }

    // 2. POBLAR PESTAÑA MOTOCICLETAS
    if (motosSheet != null) {
      final listaMotos = ingresos.where((i) => i.tipoVehiculo.trim().toUpperCase() == 'MOTOCICLETA').toList();
      int rowMotoIndex = 6; // Fila 7 en Excel (0-indexed = 6)

      for (int i = 0; i < listaMotos.length; i++) {
        final ing = listaMotos[i];
        final lib = _libertadDe(ing, libertades);
        final ord = i + 1;
        final excelRow = rowMotoIndex + 1;

        final situacionLegal = ing.causaLegal.isNotEmpty
            ? (ing.detalleCausa.isNotEmpty ? '${ing.causaLegal} - ${ing.detalleCausa}' : ing.causaLegal)
            : ing.causaPrincipal;

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

        final dias = lib != null ? _diasPermanencia(ing.fechaIngreso, lib.fechaSalida) : null;

        void setCell(int col, CellValue val) {
          motosSheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowMotoIndex),
            val,
          );
        }

        setCell(0, IntCellValue(ord));
        setCell(1, TextCellValue(ing.subzona.isNotEmpty ? ing.subzona : 'SANTO DOMINGO'));
        setCell(2, TextCellValue(ing.crv.isNotEmpty ? ing.crv : tituloPatio));
        setCell(3, _celdaFecha(ing.fechaIngreso));
        setCell(4, _celdaNumeroOTexto(ing.hojaIngresoNro));
        setCell(5, TextCellValue(ing.placa.trim().toUpperCase()));
        setCell(6, TextCellValue(ing.marca.trim()));
        setCell(7, TextCellValue(ing.modelo.trim()));
        setCell(8, TextCellValue(ing.color.trim()));
        setCell(9, _celdaNumeroOTexto(ing.anioFabricacion));
        setCell(10, TextCellValue(ing.chasis.trim()));
        setCell(11, TextCellValue(ing.motor.trim()));
        setCell(12, TextCellValue(ing.parteIngresoNro.trim()));
        setCell(13, TextCellValue(ing.policiaNombre.trim()));
        setCell(14, TextCellValue(ing.propietario.trim()));
        setCell(15, TextCellValue(situacionLegal));
        setCell(16, TextCellValue(autoridad));
        setCell(17, TextCellValue(placaGrua));
        setCell(18, TextCellValue(conductorGrua));
        setCell(19, TextCellValue(ing.custodioRecibeNombre.trim().isNotEmpty ? ing.custodioRecibeNombre.trim() : 'SGOS. CHASIPANTA XAVIER'));

        if (lib != null && lib.fechaSalida.isNotEmpty) {
          setCell(20, _celdaFecha(lib.fechaSalida));
          setCell(21, TextCellValue(lib.oficioDevolucionNro.trim()));
          setCell(22, TextCellValue(lib.firmadoPor.trim()));
          setCell(23, TextCellValue(lib.retiradoPor.trim()));
          setCell(24, TextCellValue(lib.cedulaRetira.trim()));
          setCell(25, _celdaNumeroOTexto(ordenPagoGaraje));
          setCell(26, dias != null ? IntCellValue(dias) : TextCellValue(''));
          setCell(27, dias != null ? IntCellValue(dias) : TextCellValue(''));
          setCell(28, FormulaCellValue('IF(E$excelRow="","",E$excelRow)'));
          setCell(29, TextCellValue(lib.custodioEntregaNombre.trim()));
        } else {
          setCell(20, TextCellValue(''));
          setCell(21, TextCellValue(''));
          setCell(22, TextCellValue(''));
          setCell(23, TextCellValue(''));
          setCell(24, TextCellValue(''));
          setCell(25, TextCellValue(''));
          setCell(26, TextCellValue(''));
          setCell(27, TextCellValue(''));
          setCell(28, FormulaCellValue('IF(E$excelRow="","",E$excelRow)'));
          setCell(29, TextCellValue(''));
        }

        setCell(30, TextCellValue(ordenPagoAlcoho));
        setCell(31, TextCellValue(valorAlcoho));
        setCell(32, TextCellValue(pericia));
        setCell(33, TextCellValue(perito));
        if (lib != null && primerPago?.horaFechaPago.isNotEmpty == true) {
          setCell(34, _celdaFecha(primerPago!.horaFechaPago));
        } else {
          setCell(34, TextCellValue(''));
        }
        setCell(35, _celdaNumeroOTexto(comprobanteGaraje));
        setCell(36, TextCellValue(bancoGaraje));

        rowMotoIndex++;
      }

      // Limpiar filas antiguas si hubieran quedado remanentes
      while (rowMotoIndex < motosSheet.maxRows) {
        final placaVal = motosSheet.rows[rowMotoIndex].length > 5 ? motosSheet.rows[rowMotoIndex][5]?.value : null;
        if (placaVal == null || placaVal.toString().trim().isEmpty) break;
        for (int c = 0; c < 37; c++) {
          motosSheet.updateCell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowMotoIndex), TextCellValue(''));
        }
        rowMotoIndex++;
      }
    }

    return excel.encode() ?? [];
  }

  static int? _diasPermanencia(String fechaIngreso, String fechaSalida) {
    final f1 = _parseFecha(fechaIngreso);
    final f2 = _parseFecha(fechaSalida);
    if (f1 == null || f2 == null) return null;
    return f2.difference(f1).inDays + 1;
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
