// RUTA DE ARCHIVO: lib/services/excel_matriz_builder.dart

import 'package:excel/excel.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';

/// Genera la matriz consolidada de Ingresos/Libertades con la MISMA
/// estructura de columnas que la plantilla real de Xavier
/// ("MATRIZ_LIBERTADES_DE_ARCHIVO...xlsx"), pestañas VEHICULOS y
/// MOTOCICLETAS.
///
/// DECISIÓN DE DISEÑO: la plantilla original usa fórmulas de Excel
/// (=(V-D)+1 para días, un IF anidado para la tarifa diaria según el
/// tipo de servicio de garaje, etc.). Aquí esas mismas cuentas se
/// calculan directamente en Dart y se escribe el VALOR ya calculado
/// (no la fórmula). Esto es más robusto: el archivo que se descarga
/// no depende de que Excel vuelva a evaluar nada, funciona igual en
/// Google Sheets/LibreOffice, y no se rompe si alguien borra una
/// fórmula sin querer. La contrapartida es que si Xavier cambia estos
/// datos a mano en el Excel después de descargarlo, el cálculo de
/// días/valor de ESA fila ya no se recalcula solo (tendría que volver
/// a generar el archivo desde la app).
class ExcelMatrizBuilder {
  // Tarifas diarias vigentes según la plantilla (columna AD, IF
  // anidado). Si la ANT actualiza las tarifas, basta con cambiar estos
  // 4 números.
  static const double _tarifaLivianos = 3;
  static const double _tarifaPesados = 9;
  static const double _tarifaMotocicleta = 1;
  static const double _tarifaExtraPesados = 15;

  static const _servicioLivianos =
      'SERVICIO DE GARAJE LIVIANOS (HASTA 3,5 TN A EXCEPCIÓN DE MOTOCICLETAS) (DIARIOS)';
  static const _servicioPesados = 'SERVICIO DE GARAJE PESADOS (DE 3,51 TN HASTA 12 TN) (DIARIOS)';
  static const _servicioMotocicleta = 'SERVICIO DE GARAJE (CENTROS DE RETENCIÓN) MOTOCICLETA';
  static const _servicioExtraPesados = 'SERVICIO DE GARAJE EXTRA PESADOS (MÁS DE 12 TN) (DIARIOS)';

  /// Mapea la etiqueta corta que se elige en el Ingreso (igual que el
  /// desplegable "Tipo cobro parqueo" de SIIPNE 3W: LIVIANO, PESADO,
  /// MOTOCICLETA, EXTRAPESADO) a la etiqueta larga oficial del
  /// tarifario ANT — la misma que usa la columna "TIPO DE TYRAMITE /
  /// PROCESO" de la matriz.
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
        return tipoCobroParqueo; // por si ya viene con la etiqueta larga (dato antiguo)
    }
  }

  static double _tarifaDiaria(String tipoServicioGaraje) {
    switch (tipoServicioGaraje) {
      case _servicioLivianos:
        return _tarifaLivianos;
      case _servicioPesados:
        return _tarifaPesados;
      case _servicioMotocicleta:
        return _tarifaMotocicleta;
      case _servicioExtraPesados:
        return _tarifaExtraPesados;
      default:
        return 0;
    }
  }

  static DateTime? _parseFecha(String texto) {
    // Formato esperado dd/MM/aaaa (el mismo que usa toda la app).
    final partes = texto.trim().split('/');
    if (partes.length != 3) return null;
    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final anio = int.tryParse(partes[2]);
    if (dia == null || mes == null || anio == null) return null;
    return DateTime(anio, mes, dia);
  }

  /// Días de permanencia inclusivos (mismo criterio ya usado en el
  /// resto de la app: entra lunes y sale viernes = 5 días).
  static int? _diasPermanencia(String fechaIngreso, String fechaSalida) {
    final ingreso = _parseFecha(fechaIngreso);
    final salida = _parseFecha(fechaSalida);
    if (ingreso == null || salida == null) return null;
    return salida.difference(ingreso).inDays + 1;
  }

  /// Busca, entre todas las libertades, la que corresponde a un
  /// ingreso (primero por N° de hoja de ingreso —más confiable—, y si
  /// no hay coincidencia, por placa).
  static CasoLibertad? _libertadDe(CasoIngreso ingreso, List<CasoLibertad> libertades) {
    for (final l in libertades) {
      if (l.hojaIngresoNro.isNotEmpty && l.hojaIngresoNro == ingreso.hojaIngresoNro) return l;
    }
    for (final l in libertades) {
      if (l.placa.toUpperCase() == ingreso.placa.toUpperCase()) return l;
    }
    return null;
  }

  static const _headerVehiculos = [
    'ORD.',
    'SUBZONA',
    'CENTRO DE RETENCION VEHICULAR',
    'FECHA DE INGRESO',
    'NÚMERO DE FORMULARIO DE INGRESO VEHICULAR ',
    'PLACA',
    'MARCA',
    'TIPO',
    'MODELO',
    'COLOR',
    'AÑO DE FABRICACIÓN',
    'NÚMERO DE CHASIS',
    'NÚMERO DE MOTOR',
    'NÚMERO DE PARTE ',
    'PARTE ELABORADO POR',
    'NOMBRE PROPIETARIO/RESPONSABLE DEL VEHICULO',
    'SITUACIÓN LEGAL (Infracción tránsito)',
    'AUTORIDAD QUE CONOCE (Juzgado Y/O fiscalia  que avocó conocimiento)',
    'PLACA-GRUA',
    'NOMBRES CONDUCTOR GRUA',
    'NOMBRE SERVIDOR POLICIAL QUE RECIBE LA CUSTODIA DEL VEHÍCULO',
    'FECHA EGRESO',
    'ORDEN DE LIBERTAD EMITIDA AUTORIDAD COMPETENTE',
    'NOMBRE DEL SEÑOR  JEFE QUE  EMITE LIBERTAD',
    'NOMBRES DE PERSONA A QUIEN SE ENTREGA',
    'NÚMERO DE CEDULA ',
    'NÚMERO DE ORDEN DE PAGO (GARAGE)',
    'TIPO DE TYRAMITE / PROCESO',
    'DIAS DE PERMANENCIA',
    'VALOR TARIFARIO DIARIO',
    'VALOR CANCELADO POR PARQUEO ',
    'No DE ORDEN DE PAGO',
    'FECHA DE PAGO EN LA ENTIDA FINANCIERA',
    'No DE COMPROBANTE DE PAGO DE LA ENTIDAD FINANCIERA',
    'INSTITUCION FINANCIERA (BANCO, COOPERATIVA, ETC)',
    'NOMBRE DE LA INSTITUCIÓN FINANCIERA',
    'NÚMERO DE FORMULARIO DE EGRESO VEHICULAR',
    'NOMBRE SERVIDOR POLICIAL QUE ENTREGA EL VEHÍCULO (CUSTODIO)',
    'NÚMERO DE ORDEN DE PAGO POR ALCOHOCHECK',
    'VALOR CANCELADO POR ALCOHOCHEK',
    'PERICIAS REALIZADAS',
    'NOMBRE DEL PERITO',
    'FECHA  DE PAGO EN  LA ENTIDAD FINANCIERA',
    'NRO. DE COMPROBANTE DE PAGO DE LA ENTIDAD FINANCIERA',
    'INSTITUCIÓN FINANCIERA (BANCO-COOPERATIVA)',
  ];

  static const _headerMotocicletas = [
    'ORD.',
    'SUBZONA',
    'CENTRO DE RETENCION VEHICULAR',
    'FECHA DE INGRESO',
    'NÚMERO DE FORMULARIO DE INGRESO VEHICULAR ',
    'PLACA',
    'MARCA',
    'MODELO',
    'COLOR',
    'AÑO DE FABRICACIÓN',
    'NÚMERO DE CHASIS',
    'NÚMERO DE MOTOR',
    'NÚMERO DE PARTE ',
    'PARTE ELABORADO POR (QUIEN TOMA PROCEDIMIENTO)',
    'NOMBRE PROPIETARIO/RESPONSABLE DEL VEHICULO',
    'SITUACIÓN LEGAL (Infracción tránsito)',
    'AUTORIDAD QUE CONOCE (Juzgado Y/O fiscalia  que avocó conocimiento)',
    'PLACA-GRUA',
    'NOMBRES CONDUCTOR GRUA',
    'NOMBRE SERVIDOR POLICIAL QUE RECIBE LA CUSTODIA DEL VEHÍCULO',
    'FECHA EGRESO',
    'ORDEN DE LIBERTAD EMITIDA AUTORIDAD COMPETENTE',
    'NOMBRE DEL SEÑOR  JEFE QUE  EMITE LIBERTAD',
    'NOMBRES DE PERSONA A QUIEN SE ENTREGA',
    'NÚMERO DE CEDULA ',
    'NÚMERO DE ORDEN DE PAGO (GARAGE)',
    'DIAS DE PARQUEO ',
    'VALOR CANCELADO POR PARQUEO ',
    'NÚMERO DE FORMULARIO DE EGRESO VEHICULAR',
    'NOMBRE SERVIDOR POLICIAL QUE ENTREGA EL VEHÍCULO (CUSTODIO)',
    'NÚMERO DE ORDEN DE PAGO POR ALCOHOCHECK',
    'VALOR CANCELADO POR ALCOHOCHEK',
    'PERICIAS REALIZADAS',
    'NOMBRE DEL PERITO',
    'FECHA  DE PAGO EN  LA ENTIDAD FINANCIERA',
    'NRO. DE COMPROBANTE DE PAGO DE LA ENTIDAD FINANCIERA',
    'INSTITUCIÓN FINANCIERA (BANCO-COOPERATIVA)',
  ];

  static List<int> build({
    required List<CasoIngreso> ingresos,
    required List<CasoLibertad> libertades,
    String tituloPatio = 'CENTRO DE RETENCIÓN VEHICULAR',
  }) {
    final excel = Excel.createExcel();
    // La hoja "Sheet1" que trae por defecto el paquete `excel` se
    // elimina al final, una vez creadas las dos hojas reales.
    final hojaDefectoOriginal = excel.getDefaultSheet();

    final vehiculos = excel['VEHICULOS'];
    final motos = excel['MOTOCICLETAS'];

    _escribirEncabezado(vehiculos, tituloPatio, _headerVehiculos);
    _escribirEncabezado(motos, tituloPatio, _headerMotocicletas);

    var ordVehiculos = 1;
    var ordMotos = 1;

    for (final ing in ingresos) {
      final lib = _libertadDe(ing, libertades);
      final esMoto = ing.tipoVehiculo.toUpperCase() == 'MOTOCICLETA';
      final sheet = esMoto ? motos : vehiculos;
      final ord = esMoto ? ordMotos++ : ordVehiculos++;

      final dias = lib != null ? _diasPermanencia(ing.fechaIngreso, lib.fechaSalida) : null;
      final tipoCobro = ing.tipoCobroParqueo.isNotEmpty ? ing.tipoCobroParqueo : lib?.tipoServicioGaraje ?? '';
      final etiquetaLargaTarifa = _etiquetaLargaTarifario(tipoCobro);
      final tarifa = lib != null ? _tarifaDiaria(etiquetaLargaTarifa) : null;
      final valorCalculado = (dias != null && tarifa != null) ? dias * tarifa : null;
      final primerPago = lib != null && lib.pagos.isNotEmpty ? lib.pagos.first : null;
      final bancoGaraje = primerPago != null
          ? (primerPago.entidadFinancieraOficial.isNotEmpty
              ? primerPago.entidadFinancieraOficial
              : primerPago.entidadFinanciera)
          : '';

      final situacionLegal = ing.causaLegal.isNotEmpty
          ? (ing.detalleCausa.isNotEmpty ? '${ing.causaLegal} - ${ing.detalleCausa}' : ing.causaLegal)
          : (ing.causaPrincipal.isNotEmpty ? ing.causaPrincipal : 'ACCIDENTE DE TRANSITO');

      final autoridad = ing.autoridadRequirente.isNotEmpty
          ? ing.autoridadRequirente
          : (lib?.firmadoPor.isNotEmpty == true ? 'FISCALIA' : 'N/A');

      final placaGrua = lib?.placaGrua.isNotEmpty == true
          ? lib!.placaGrua
          : (ing.placaGrua.isNotEmpty ? ing.placaGrua : 'N/A');

      final conductorGrua = ing.conductorGrua.isNotEmpty
          ? ing.conductorGrua
          : (ing.nombreGruaParticular.isNotEmpty ? ing.nombreGruaParticular : 'N/A');

      final ordenPagoGaraje = primerPago?.ordenPagoNro ?? '';
      final comprobanteGaraje = primerPago?.comprobantePagoNro ?? '';
      final fechaPagoGaraje = primerPago?.horaFechaPago ?? '';

      final ordenPagoAlcoho = lib?.ordenPagoAlcohocheckNro.isNotEmpty == true
          ? lib!.ordenPagoAlcohocheckNro
          : (ing.ordenPagoAlcohocheckNro.isNotEmpty ? ing.ordenPagoAlcohocheckNro : 'N/A');

      final valorAlcoho = lib?.valorAlcohocheck.isNotEmpty == true
          ? lib!.valorAlcohocheck
          : (ing.valorAlcohocheck.isNotEmpty ? ing.valorAlcohocheck : 'N/A');

      final pericia = lib?.periciaRealizada.isNotEmpty == true ? lib!.periciaRealizada : 'N/A';
      final perito = lib?.peritoNombre.isNotEmpty == true ? lib!.peritoNombre : 'N/A';

      final fechaPagoPericia = lib?.horaFechaPagoAlcohocheck.isNotEmpty == true
          ? lib!.horaFechaPagoAlcohocheck
          : fechaPagoGaraje;

      final compPagoPericia = lib?.comprobantePagoAlcohocheckNro.isNotEmpty == true
          ? lib!.comprobantePagoAlcohocheckNro
          : comprobanteGaraje;

      final bancoPericia = bancoGaraje;

      List<CellValue?> fila;
      if (!esMoto) {
        fila = [
          IntCellValue(ord), // 1. ORD.
          TextCellValue(ing.subzona.isNotEmpty ? ing.subzona : 'SANTO DOMINGO'), // 2. SUBZONA
          TextCellValue(ing.crv.isNotEmpty ? ing.crv : 'CONTROL 120'), // 3. CENTRO DE RETENCION VEHICULAR
          TextCellValue(ing.fechaIngreso), // 4. FECHA DE INGRESO
          TextCellValue(ing.hojaIngresoNro), // 5. NÚMERO DE FORMULARIO DE INGRESO VEHICULAR
          TextCellValue(ing.placa.toUpperCase()), // 6. PLACA
          TextCellValue(ing.marca), // 7. MARCA
          TextCellValue(ing.tipoVehiculo), // 8. TIPO
          TextCellValue(ing.modelo), // 9. MODELO
          TextCellValue(ing.color), // 10. COLOR
          TextCellValue(ing.anioFabricacion), // 11. AÑO DE FABRICACIÓN
          TextCellValue(ing.chasis), // 12. NÚMERO DE CHASIS
          TextCellValue(ing.motor), // 13. NÚMERO DE MOTOR
          TextCellValue(ing.parteIngresoNro), // 14. NÚMERO DE PARTE
          TextCellValue(ing.policiaNombre), // 15. PARTE ELABORADO POR
          TextCellValue(ing.propietario), // 16. NOMBRE PROPIETARIO/RESPONSABLE DEL VEHICULO
          TextCellValue(situacionLegal), // 17. SITUACIÓN LEGAL (Infracción tránsito)
          TextCellValue(autoridad), // 18. AUTORIDAD QUE CONOCE
          TextCellValue(placaGrua), // 19. PLACA-GRUA
          TextCellValue(conductorGrua), // 20. NOMBRES CONDUCTOR GRUA
          TextCellValue(ing.custodioRecibeNombre), // 21. NOMBRE SERVIDOR POLICIAL QUE RECIBE LA CUSTODIA
          TextCellValue(lib?.fechaSalida ?? ''), // 22. FECHA EGRESO
          TextCellValue(lib?.oficioDevolucionNro ?? ''), // 23. ORDEN DE LIBERTAD EMITIDA AUTORIDAD COMPETENTE
          TextCellValue(lib?.firmadoPor ?? ''), // 24. NOMBRE DEL SEÑOR JEFE QUE EMITE LIBERTAD
          TextCellValue(lib?.retiradoPor ?? ''), // 25. NOMBRES DE PERSONA A QUIEN SE ENTREGA
          TextCellValue(lib?.cedulaRetira ?? ''), // 26. NÚMERO DE CEDULA
          TextCellValue(ordenPagoGaraje), // 27. NÚMERO DE ORDEN DE PAGO (GARAGE)
          TextCellValue(etiquetaLargaTarifa), // 28. TIPO DE TYRAMITE / PROCESO
          if (dias != null) IntCellValue(dias) else TextCellValue(''), // 29. DIAS DE PERMANENCIA
          if (tarifa != null) DoubleCellValue(tarifa) else TextCellValue(''), // 30. VALOR TARIFARIO DIARIO
          if (valorCalculado != null) DoubleCellValue(valorCalculado) else TextCellValue(''), // 31. VALOR CANCELADO POR PARQUEO
          TextCellValue(ordenPagoGaraje), // 32. No DE ORDEN DE PAGO
          TextCellValue(fechaPagoGaraje), // 33. FECHA DE PAGO EN LA ENTIDA FINANCIERA
          TextCellValue(comprobanteGaraje), // 34. No DE COMPROBANTE DE PAGO DE LA ENTIDAD FINANCIERA
          TextCellValue(bancoGaraje), // 35. INSTITUCION FINANCIERA (BANCO, COOPERATIVA, ETC)
          TextCellValue(bancoGaraje), // 36. NOMBRE DE LA INSTITUCIÓN FINANCIERA
          TextCellValue(lib != null ? ing.hojaIngresoNro : ''), // 37. NÚMERO DE FORMULARIO DE EGRESO VEHICULAR
          TextCellValue(lib?.custodioEntregaNombre ?? ''), // 38. NOMBRE SERVIDOR POLICIAL QUE ENTREGA EL VEHÍCULO (CUSTODIO)
          TextCellValue(ordenPagoAlcoho), // 39. NÚMERO DE ORDEN DE PAGO POR ALCOHOCHECK
          TextCellValue(valorAlcoho), // 40. VALOR CANCELADO POR ALCOHOCHEK
          TextCellValue(pericia), // 41. PERICIAS REALIZADAS
          TextCellValue(perito), // 42. NOMBRE DEL PERITO
          TextCellValue(fechaPagoPericia), // 43. FECHA DE PAGO EN LA ENTIDAD FINANCIERA
          TextCellValue(compPagoPericia), // 44. NRO. DE COMPROBANTE DE PAGO DE LA ENTIDAD FINANCIERA
          TextCellValue(bancoPericia), // 45. INSTITUCIÓN FINANCIERA (BANCO-COOPERATIVA)
        ];
      } else {
        fila = [
          IntCellValue(ord), // 1. ORD.
          TextCellValue(ing.subzona.isNotEmpty ? ing.subzona : 'SANTO DOMINGO'), // 2. SUBZONA
          TextCellValue(ing.crv.isNotEmpty ? ing.crv : 'CONTROL 120'), // 3. CENTRO DE RETENCION VEHICULAR
          TextCellValue(ing.fechaIngreso), // 4. FECHA DE INGRESO
          TextCellValue(ing.hojaIngresoNro), // 5. NÚMERO DE FORMULARIO DE INGRESO VEHICULAR
          TextCellValue(ing.placa.toUpperCase()), // 6. PLACA
          TextCellValue(ing.marca), // 7. MARCA
          TextCellValue(ing.modelo), // 8. MODELO
          TextCellValue(ing.color), // 9. COLOR
          TextCellValue(ing.anioFabricacion), // 10. AÑO DE FABRICACIÓN
          TextCellValue(ing.chasis), // 11. NÚMERO DE CHASIS
          TextCellValue(ing.motor), // 12. NÚMERO DE MOTOR
          TextCellValue(ing.parteIngresoNro), // 13. NÚMERO DE PARTE
          TextCellValue(ing.policiaNombre), // 14. PARTE ELABORADO POR
          TextCellValue(ing.propietario), // 15. NOMBRE PROPIETARIO/RESPONSABLE DEL VEHICULO
          TextCellValue(situacionLegal), // 16. SITUACIÓN LEGAL (Infracción tránsito)
          TextCellValue(autoridad), // 17. AUTORIDAD QUE CONOCE
          TextCellValue(placaGrua), // 18. PLACA-GRUA
          TextCellValue(conductorGrua), // 19. NOMBRES CONDUCTOR GRUA
          TextCellValue(ing.custodioRecibeNombre), // 20. NOMBRE SERVIDOR POLICIAL QUE RECIBE LA CUSTODIA
          TextCellValue(lib?.fechaSalida ?? ''), // 21. FECHA EGRESO
          TextCellValue(lib?.oficioDevolucionNro ?? ''), // 22. ORDEN DE LIBERTAD EMITIDA AUTORIDAD COMPETENTE
          TextCellValue(lib?.firmadoPor ?? ''), // 23. NOMBRE DEL SEÑOR JEFE QUE EMITE LIBERTAD
          TextCellValue(lib?.retiradoPor ?? ''), // 24. NOMBRES DE PERSONA A QUIEN SE ENTREGA
          TextCellValue(lib?.cedulaRetira ?? ''), // 25. NÚMERO DE CEDULA
          TextCellValue(ordenPagoGaraje), // 26. NÚMERO DE ORDEN DE PAGO (GARAGE)
          if (dias != null) IntCellValue(dias) else TextCellValue(''), // 27. DIAS DE PARQUEO
          if (valorCalculado != null) DoubleCellValue(valorCalculado) else TextCellValue(''), // 28. VALOR CANCELADO POR PARQUEO
          TextCellValue(lib != null ? ing.hojaIngresoNro : ''), // 29. NÚMERO DE FORMULARIO DE EGRESO VEHICULAR
          TextCellValue(lib?.custodioEntregaNombre ?? ''), // 30. NOMBRE SERVIDOR POLICIAL QUE ENTREGA EL VEHÍCULO (CUSTODIO)
          TextCellValue(ordenPagoAlcoho), // 31. NÚMERO DE ORDEN DE PAGO POR ALCOHOCHECK
          TextCellValue(valorAlcoho), // 32. VALOR CANCELADO POR ALCOHOCHEK
          TextCellValue(pericia), // 33. PERICIAS REALIZADAS
          TextCellValue(perito), // 34. NOMBRE DEL PERITO
          TextCellValue(fechaPagoPericia), // 35. FECHA DE PAGO EN LA ENTIDAD FINANCIERA
          TextCellValue(compPagoPericia), // 36. NRO. DE COMPROBANTE DE PAGO DE LA ENTIDAD FINANCIERA
          TextCellValue(bancoPericia), // 37. INSTITUCIÓN FINANCIERA (BANCO-COOPERATIVA)
        ];
      }

      sheet.appendRow(fila);
    }

    if (hojaDefectoOriginal != null &&
        hojaDefectoOriginal != 'VEHICULOS' &&
        hojaDefectoOriginal != 'MOTOCICLETAS') {
      excel.delete(hojaDefectoOriginal);
    }
    excel.setDefaultSheet('VEHICULOS');

    return excel.encode() ?? [];
  }

  static void _escribirEncabezado(Sheet sheet, String tituloPatio, List<String> columnas) {
    sheet.appendRow([TextCellValue('POLICÍA NACIONAL DE ECUADOR')]);
    sheet.appendRow([TextCellValue('DIRECCIÓN NACIONAL DE CONTROL DE TRÁNSITO Y SEGURIDAD VIAL')]);
    sheet.appendRow([TextCellValue(tituloPatio)]);
    sheet.appendRow([]);
    sheet.appendRow([]);
    sheet.appendRow(columnas.map((e) => TextCellValue(e)).toList());
  }
}
