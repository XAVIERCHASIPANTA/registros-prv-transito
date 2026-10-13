import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';

class ResultadoImportacion {
  final String patioDetectado;
  final String subzonaDetectada;
  final List<CasoIngreso> ingresos;
  final List<CasoLibertad> libertades;
  final int vehiculosCount;
  final int motosCount;

  ResultadoImportacion({
    required this.patioDetectado,
    required this.subzonaDetectada,
    required this.ingresos,
    required this.libertades,
    required this.vehiculosCount,
    required this.motosCount,
  });
}

class ExcelImporterService {
  static String _clean(dynamic val) {
    if (val == null) return '';
    final s = val.toString().trim();
    if (s == 'null' || s == 'N/A' || s == 'S/N' || s == 's/n') return s == 'N/A' ? 'N/A' : '';
    // Limpieza de fechas ISO (ej. 2025-09-04T00:00:00.000Z -> 04/09/2025)
    if (s.contains('T') && s.contains('-') && s.length >= 10) {
      try {
        final dt = DateTime.parse(s.substring(0, 10));
        final d = dt.day.toString().padLeft(2, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final y = dt.year.toString();
        return '$d/$m/$y';
      } catch (_) {}
    }
    return s;
  }

  static Future<ResultadoImportacion?> seleccionarYProcesarExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return null;

      return parsearExcelBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  static ResultadoImportacion parsearExcelBytes(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<CasoIngreso> listaIngresos = [];
    final List<CasoLibertad> listaLibertades = [];
    int countVeh = 0;
    int countMotos = 0;
    String patioDetectado = '';
    String subzonaDetectada = '';

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 1. PROCESAR VEHICULOS
    String? vehSheetName;
    for (final name in excel.tables.keys) {
      if (name.toUpperCase().contains('VEHIC')) {
        vehSheetName = name;
        break;
      }
    }

    if (vehSheetName != null) {
      final sheet = excel.tables[vehSheetName]!;
      // Intentar detectar nombre de patio en fila 3
      if (sheet.maxRows > 2 && sheet.rows[2].isNotEmpty) {
        final rawTitle = _clean(sheet.rows[2][0]?.value);
        if (rawTitle.isNotEmpty) {
          patioDetectado = rawTitle.replaceAll('CENTRO DE RETENCIÓN VEHICULAR', '').replaceAll('"', '').trim();
        }
      }

      for (int r = 5; r < sheet.maxRows; r++) {
        final row = sheet.rows[r];
        final ordStr = _clean(row.isNotEmpty ? row[0]?.value : '');
        final ord = int.tryParse(ordStr);
        if (ord == null || ord < 1) continue;

        final subzona = _clean(row.length > 1 ? row[1]?.value : '');
        if (subzona.isNotEmpty && subzonaDetectada.isEmpty) subzonaDetectada = subzona;

        final crv = _clean(row.length > 2 ? row[2]?.value : '');
        final fIngreso = _clean(row.length > 3 ? row[3]?.value : '');
        final formIngreso = _clean(row.length > 4 ? row[4]?.value : '');
        final placa = _clean(row.length > 5 ? row[5]?.value : '').toUpperCase();
        if (placa.isEmpty && formIngreso.isEmpty) continue;

        final marca = _clean(row.length > 6 ? row[6]?.value : '');
        final tipo = _clean(row.length > 7 ? row[7]?.value : '');
        final modelo = _clean(row.length > 8 ? row[8]?.value : '');
        final color = _clean(row.length > 9 ? row[9]?.value : '');
        final anio = _clean(row.length > 10 ? row[10]?.value : '');
        final chasis = _clean(row.length > 11 ? row[11]?.value : '');
        final motor = _clean(row.length > 12 ? row[12]?.value : '');
        final parteIngreso = _clean(row.length > 13 ? row[13]?.value : '');
        final policiaParte = _clean(row.length > 14 ? row[14]?.value : '');
        final propietario = _clean(row.length > 15 ? row[15]?.value : '');
        final situacionLegal = _clean(row.length > 16 ? row[16]?.value : '');
        final autoridad = _clean(row.length > 17 ? row[17]?.value : '');
        final placaGrua = _clean(row.length > 18 ? row[18]?.value : '');
        final conductorGrua = _clean(row.length > 19 ? row[19]?.value : '');
        final custodioRecibe = _clean(row.length > 20 ? row[20]?.value : '');

        // Salida
        final fEgreso = _clean(row.length > 21 ? row[21]?.value : '');
        final ordenLibertad = _clean(row.length > 22 ? row[22]?.value : '');
        final jefeLibertad = _clean(row.length > 23 ? row[23]?.value : '');
        final personaEntrega = _clean(row.length > 24 ? row[24]?.value : '');
        final cedulaRetira = _clean(row.length > 25 ? row[25]?.value : '');
        final ordenPagoGaraje = _clean(row.length > 26 ? row[26]?.value : '');
        final tipoCobro = _clean(row.length > 27 ? row[27]?.value : '');
        final diasPerm = _clean(row.length > 28 ? row[28]?.value : '');
        final tarifa = _clean(row.length > 29 ? row[29]?.value : '');
        final valorParqueo = _clean(row.length > 30 ? row[30]?.value : '');
        final fPagoBanco = _clean(row.length > 32 ? row[32]?.value : '');
        final comprobantePago = _clean(row.length > 33 ? row[33]?.value : '');
        final banco = _clean(row.length > 34 ? row[34]?.value : '');
        final custodioEntrega = _clean(row.length > 37 ? row[37]?.value : '');
        final ordenAlco = _clean(row.length > 38 ? row[38]?.value : '');
        final valorAlco = _clean(row.length > 39 ? row[39]?.value : '');
        final pericias = _clean(row.length > 40 ? row[40]?.value : '');
        final perito = _clean(row.length > 41 ? row[41]?.value : '');
        final fPagoPerito = _clean(row.length > 42 ? row[42]?.value : '');
        final compPerito = _clean(row.length > 43 ? row[43]?.value : '');

        final id = 'import_veh_${timestamp}_$ord';
        final ing = CasoIngreso(
          id: id,
          origen: 'excel',
          hojaIngresoNro: formIngreso.isNotEmpty ? formIngreso : 'FORM-$ord',
          parteIngresoNro: parteIngreso,
          fechaIngreso: fIngreso,
          subzona: subzona.isNotEmpty ? subzona : 'SANTO DOMINGO',
          crv: crv.isNotEmpty ? crv : (patioDetectado.isNotEmpty ? patioDetectado : 'CRV'),
          placa: placa.isNotEmpty ? placa : 'S/P-$ord',
          marca: marca,
          modelo: modelo,
          anioFabricacion: anio,
          color: color,
          tipoVehiculo: tipo.isNotEmpty ? tipo : 'LIVIANO',
          chasis: chasis,
          motor: motor,
          causaPrincipal: situacionLegal,
          causaLegal: situacionLegal,
          autoridadRequirente: autoridad,
          propietario: propietario,
          policiaNombre: policiaParte,
          custodioRecibeNombre: custodioRecibe,
          placaGrua: placaGrua,
          conductorGrua: conductorGrua,
          tipoCobroParqueo: tipoCobro,
        );
        listaIngresos.add(ing);
        countVeh++;

        if (fEgreso.isNotEmpty && fEgreso != 'N/A') {
          final List<PagoGaraje> pagos = [];
          if (comprobantePago.isNotEmpty || ordenPagoGaraje.isNotEmpty) {
            pagos.add(PagoGaraje(
              ordenPagoNro: ordenPagoGaraje,
              comprobantePagoNro: comprobantePago,
              diasPagados: diasPerm,
              precioUnitario: tarifa,
              valor: valorParqueo,
              horaFechaPago: fPagoBanco,
              entidadFinanciera: banco,
              entidadFinancieraOficial: banco,
            ));
          }
          final lib = CasoLibertad(
            id: 'import_lib_veh_${timestamp}_$ord',
            origen: 'excel',
            placa: placa.isNotEmpty ? placa : 'S/P-$ord',
            marca: marca,
            color: color,
            tipoVehiculo: tipo.isNotEmpty ? tipo : 'LIVIANO',
            hojaIngresoNro: formIngreso.isNotEmpty ? formIngreso : 'FORM-$ord',
            parteIngresoNro: parteIngreso,
            fechaIngreso: fIngreso,
            fechaSalida: fEgreso,
            oficioDevolucionNro: ordenLibertad,
            firmadoPor: jefeLibertad,
            retiradoPor: personaEntrega,
            cedulaRetira: cedulaRetira,
            diasPermanencia: diasPerm,
            custodioEntregaNombre: custodioEntrega,
            crv: crv.isNotEmpty ? crv : (patioDetectado.isNotEmpty ? patioDetectado : 'CRV'),
            periciaRealizada: pericias,
            peritoNombre: perito,
            ordenPagoAlcohocheckNro: ordenAlco,
            valorAlcohocheck: valorAlco,
            horaFechaPagoAlcohocheck: fPagoPerito,
            comprobantePagoAlcohocheckNro: compPerito,
            pagos: pagos,
          );
          listaLibertades.add(lib);
        }
      }
    }

    // 2. PROCESAR MOTOCICLETAS
    String? motoSheetName;
    for (final name in excel.tables.keys) {
      if (name.toUpperCase().contains('MOTO')) {
        motoSheetName = name;
        break;
      }
    }

    if (motoSheetName != null) {
      final sheet = excel.tables[motoSheetName]!;
      for (int r = 5; r < sheet.maxRows; r++) {
        final row = sheet.rows[r];
        final ordStr = _clean(row.isNotEmpty ? row[0]?.value : '');
        final ord = int.tryParse(ordStr);
        if (ord == null || ord < 1) continue;

        final subzona = _clean(row.length > 1 ? row[1]?.value : '');
        final crv = _clean(row.length > 2 ? row[2]?.value : '');
        final fIngreso = _clean(row.length > 3 ? row[3]?.value : '');
        final formIngreso = _clean(row.length > 4 ? row[4]?.value : '');
        final placa = _clean(row.length > 5 ? row[5]?.value : '').toUpperCase();
        if (placa.isEmpty && formIngreso.isEmpty) continue;

        final marca = _clean(row.length > 6 ? row[6]?.value : '');
        final modelo = _clean(row.length > 7 ? row[7]?.value : '');
        final color = _clean(row.length > 8 ? row[8]?.value : '');
        final anio = _clean(row.length > 9 ? row[9]?.value : '');
        final chasis = _clean(row.length > 10 ? row[10]?.value : '');
        final motor = _clean(row.length > 11 ? row[11]?.value : '');
        final parteIngreso = _clean(row.length > 12 ? row[12]?.value : '');
        final policiaParte = _clean(row.length > 13 ? row[13]?.value : '');
        final propietario = _clean(row.length > 14 ? row[14]?.value : '');
        final situacionLegal = _clean(row.length > 15 ? row[15]?.value : '');
        final autoridad = _clean(row.length > 16 ? row[16]?.value : '');
        final placaGrua = _clean(row.length > 17 ? row[17]?.value : '');
        final conductorGrua = _clean(row.length > 18 ? row[18]?.value : '');
        final custodioRecibe = _clean(row.length > 19 ? row[19]?.value : '');

        // Salida moto
        final fEgreso = _clean(row.length > 20 ? row[20]?.value : '');
        final ordenLibertad = _clean(row.length > 21 ? row[21]?.value : '');
        final jefeLibertad = _clean(row.length > 22 ? row[22]?.value : '');
        final personaEntrega = _clean(row.length > 23 ? row[23]?.value : '');
        final cedulaRetira = _clean(row.length > 24 ? row[24]?.value : '');
        final ordenPagoGaraje = _clean(row.length > 25 ? row[25]?.value : '');
        final diasPerm = _clean(row.length > 26 ? row[26]?.value : '');
        final valorParqueo = _clean(row.length > 27 ? row[27]?.value : '');
        final custodioEntrega = _clean(row.length > 29 ? row[29]?.value : '');
        final fPagoBanco = _clean(row.length > 34 ? row[34]?.value : '');
        final comprobantePago = _clean(row.length > 35 ? row[35]?.value : '');
        final banco = _clean(row.length > 36 ? row[36]?.value : '');

        final id = 'import_moto_${timestamp}_$ord';
        final ing = CasoIngreso(
          id: id,
          origen: 'excel',
          hojaIngresoNro: formIngreso.isNotEmpty ? formIngreso : 'MOTO-$ord',
          parteIngresoNro: parteIngreso,
          fechaIngreso: fIngreso,
          subzona: subzona.isNotEmpty ? subzona : 'SANTO DOMINGO',
          crv: crv.isNotEmpty ? crv : (patioDetectado.isNotEmpty ? patioDetectado : 'CRV'),
          placa: placa.isNotEmpty ? placa : 'S/P-$ord',
          marca: marca,
          modelo: modelo,
          anioFabricacion: anio,
          color: color,
          tipoVehiculo: 'MOTOCICLETA',
          chasis: chasis,
          motor: motor,
          causaPrincipal: situacionLegal,
          causaLegal: situacionLegal,
          autoridadRequirente: autoridad,
          propietario: propietario,
          policiaNombre: policiaParte,
          custodioRecibeNombre: custodioRecibe,
          placaGrua: placaGrua,
          conductorGrua: conductorGrua,
          tipoCobroParqueo: 'MOTOCICLETA',
        );
        listaIngresos.add(ing);
        countMotos++;

        if (fEgreso.isNotEmpty && fEgreso != 'N/A') {
          final List<PagoGaraje> pagos = [];
          if (comprobantePago.isNotEmpty || ordenPagoGaraje.isNotEmpty) {
            pagos.add(PagoGaraje(
              ordenPagoNro: ordenPagoGaraje,
              comprobantePagoNro: comprobantePago,
              diasPagados: diasPerm,
              precioUnitario: '1.0',
              valor: valorParqueo,
              horaFechaPago: fPagoBanco,
              entidadFinanciera: banco,
              entidadFinancieraOficial: banco,
            ));
          }
          final lib = CasoLibertad(
            id: 'import_lib_moto_${timestamp}_$ord',
            origen: 'excel',
            placa: placa.isNotEmpty ? placa : 'S/P-$ord',
            marca: marca,
            color: color,
            tipoVehiculo: 'MOTOCICLETA',
            hojaIngresoNro: formIngreso.isNotEmpty ? formIngreso : 'MOTO-$ord',
            parteIngresoNro: parteIngreso,
            fechaIngreso: fIngreso,
            fechaSalida: fEgreso,
            oficioDevolucionNro: ordenLibertad,
            firmadoPor: jefeLibertad,
            retiradoPor: personaEntrega,
            cedulaRetira: cedulaRetira,
            diasPermanencia: diasPerm,
            custodioEntregaNombre: custodioEntrega,
            crv: crv.isNotEmpty ? crv : (patioDetectado.isNotEmpty ? patioDetectado : 'CRV'),
            pagos: pagos,
          );
          listaLibertades.add(lib);
        }
      }
    }

    return ResultadoImportacion(
      patioDetectado: patioDetectado,
      subzonaDetectada: subzonaDetectada,
      ingresos: listaIngresos,
      libertades: listaLibertades,
      vehiculosCount: countVeh,
      motosCount: countMotos,
    );
  }
}
