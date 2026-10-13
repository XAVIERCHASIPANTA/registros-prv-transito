import 'package:flutter_test/flutter_test.dart';
import 'package:registros_prv_transito/data/matriz_historica_seed.dart';
import 'package:registros_prv_transito/services/excel_matriz_builder.dart';
import 'package:excel/excel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ExcelMatrizBuilder genera matriz con 0 formulas y 100% valores puros', () async {
    final ingresos = MatrizHistoricaSeed.obtenerIngresos();
    final libertades = MatrizHistoricaSeed.obtenerLibertades();

    final bytes = await ExcelMatrizBuilder.build(
      ingresos: ingresos,
      libertades: libertades,
      tituloPatio: 'CONTROL 120',
    );

    expect(bytes.isNotEmpty, isTrue);

    final excel = Excel.decodeBytes(bytes);

    // 1. Verificar las 7 pestañas oficiales
    expect(excel.tables.containsKey('VEHICULOS'), isTrue);
    expect(excel.tables.containsKey('MOTOCICLETAS'), isTrue);
    expect(excel.tables.containsKey('INVENTARIO CAJA 1'), isTrue);
    expect(excel.tables.containsKey('CARATULA DE EXPEDIENTE'), isTrue);
    expect(excel.tables.containsKey('ETIQUETA DE CAJA'), isTrue);
    expect(excel.tables.containsKey('INDICE DE F.A'), isTrue);
    expect(excel.tables.containsKey('DATOS'), isTrue);

    // 2. Verificar que en VEHICULOS NO haya ninguna formula en las filas de datos
    final veh = excel.tables['VEHICULOS']!;
    for (int r = 6; r < 71; r++) {
      for (int c = 0; c < 45; c++) {
        final cell = veh.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        expect(cell.value is FormulaCellValue, isFalse,
            reason: 'Fila ${r + 1}, Col $c tiene una FormulaCellValue inesperada: ${cell.value}');
      }
    }

    // 3. Verificar que en MOTOCICLETAS NO haya ninguna formula en las filas de datos
    final moto = excel.tables['MOTOCICLETAS']!;
    for (int r = 6; r < 50; r++) {
      for (int c = 0; c < 37; c++) {
        final cell = moto.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        expect(cell.value is FormulaCellValue, isFalse,
            reason: 'Fila ${r + 1}, Col $c tiene una FormulaCellValue inesperada: ${cell.value}');
      }
    }

    // 4. Verificar encabezados intactos en filas 1, 2, 3, 5, 6
    expect(veh.rows[0][0]?.value?.toString(), contains('POLICÍA NACIONAL DE ECUADOR'));
    expect(veh.rows[1][0]?.value?.toString(), contains('DIRECCIÓN NACIONAL DE CONTROL DE TRÁNSITO'));
    expect(veh.rows[2][0]?.value?.toString(), contains('CONTROL 120'));
    expect(veh.rows[4][1]?.value?.toString(), equals('INGRESO DEL VEHICULO'));
    expect(veh.rows[4][21]?.value?.toString(), equals('SALIDA DE VEHICULO'));
    expect(veh.rows[5][0]?.value?.toString(), equals('ORD.'));
    expect(veh.rows[5][5]?.value?.toString(), equals('PLACA'));

    // 5. Verificar vehículo en patio (sin salida): celdas limpias, no números negativos
    final celdaDiasPatio = veh.cell(CellIndex.indexByColumnRow(columnIndex: 28, rowIndex: 6));
    expect(celdaDiasPatio.value?.toString().trim().isEmpty ?? true, isTrue);

    // 6. Verificar vehículo con salida: valor de días positivo
    final celdaDiasSalida = veh.cell(CellIndex.indexByColumnRow(columnIndex: 28, rowIndex: 7));
    expect(celdaDiasSalida.value is IntCellValue, isTrue);
    expect((celdaDiasSalida.value as IntCellValue).value, greaterThan(0));

    print('¡Prueba completada con éxito! Cero fórmulas y 100% valores directos limpios.');
  });
}
