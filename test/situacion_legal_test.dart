import 'package:flutter_test/flutter_test.dart';
import 'package:registros_prv_transito/models/caso_ingreso.dart';
import 'package:registros_prv_transito/models/caso_libertad.dart';
import 'package:registros_prv_transito/services/excel_matriz_builder.dart';
import 'package:excel/excel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Situación Legal y Sanitización Excel para TDL0101', () {
    test('TDL0101 con relato extenso de accidente formatea estrictamente a ACCIDENTE DE TRANSITO', () {
      final relatoLargo =
          'Circunstancias del hecho: Con fecha 12/03/2026, encontrándome en cumplimiento a la Orden de Servicio “OPERATIVOS DE CONTROL”, el personal policial avanza al lugar donde se verifica un presunto accidente de tránsito tipo choque lateral angular entre el vehículo placa TDL0101 y otro automotor. Se procede a la retención según los protocolos legales vigentes.';

      final caso = CasoIngreso(
        id: 'test_tdl0101',
        placa: 'TDL0101',
        tipoVehiculo: 'LIVIANO',
        fechaIngreso: '12/03/2026',
        causaLegal: 'Accidente de Tránsito /Por accidente de Tránsito',
        detalleCausa: relatoLargo,
        causaPrincipal: 'Accidente de Tránsito',
      );

      // Debe retornar únicamente 'ACCIDENTE DE TRANSITO' sin guiones ni párrafos
      expect(caso.situacionLegalFormateada, equals('ACCIDENTE DE TRANSITO'));
    });

    test('Artículos de contravención formatean concisos y limpios', () {
      final c1 = CasoIngreso(
        id: 'c1',
        placa: 'ABC1234',
        causaLegal: 'Contravenciones de Tránsito /Artículos que permiten en el COIP la retención de los vehículos',
        detalleCausa: 'Artículo 385.1 /Nivel de alcohol de 0,3 a 0,8 gramos por litro de sangre.',
      );
      expect(c1.situacionLegalFormateada, equals('ART. 385.1'));

      final c2 = CasoIngreso(
        id: 'c2',
        placa: 'XYZ9876',
        causaLegal: 'Reglamento a la LTTTSV /Artículos del Reglamento de Tránsito que estipulan la retención del vehículo.',
        detalleCausa: 'Artículo 160 /Circular sin poseer la matrícula vigente.',
      );
      expect(c2.situacionLegalFormateada, equals('ART. 160'));
    });

    test('ExcelMatrizBuilder exporta TDL0101 con celda limpia y sin caracteres corruptores', () async {
      final tdl0101 = CasoIngreso(
        id: 'tdl0101_ingreso',
        placa: 'TDL0101',
        hojaIngresoNro: '3001',
        parteIngresoNro: '202603120101',
        fechaIngreso: '12/03/2026',
        subzona: 'SANTO DOMINGO',
        crv: 'CONTROL 120',
        marca: 'CHEVROLET',
        modelo: 'AVEO FAMILY',
        color: 'PLOMO',
        tipoVehiculo: 'LIVIANO',
        causaLegal: 'Accidente de Tránsito /Por accidente de Tránsito',
        detalleCausa: 'Circunstancias del hecho: \x93OPERATIVO\x94 relato con controles \x00\x08 y comillas “tipográficas”.',
        causaPrincipal: 'Accidente de Tránsito',
      );

      final bytes = await ExcelMatrizBuilder.build(
        ingresos: [tdl0101],
        libertades: [],
        tituloPatio: 'CONTROL 120',
      );

      expect(bytes.isNotEmpty, isTrue);

      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables['VEHICULOS']!;

      // Fila 7 (índice 6), Columna 17 (índice 16 = Q = SITUACIÓN LEGAL)
      final celdaSituacion = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: 6));
      expect(celdaSituacion.value?.toString(), equals('ACCIDENTE DE TRANSITO'));

      // Verificar que ninguna celda contenga caracteres de control ASCII corruptos
      for (int c = 0; c < 45; c++) {
        final val = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 6)).value?.toString() ?? '';
        expect(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]').hasMatch(val), isFalse,
            reason: 'Columna $c contiene caracteres de control corruptos: $val');
      }

      print('¡Test de TDL0101 y sanitización Excel completado con éxito!');
    });
  });
}
