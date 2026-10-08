import 'package:flutter_test/flutter_test.dart';
import 'package:registros_prv_transito/models/caso_ingreso.dart';
import 'package:registros_prv_transito/services/docx_builder.dart';

void main() {
  test('DocxBuilder smoke test', () {
    final caso = CasoIngreso(
      id: 'smoke-1',
      placa: 'ABC1234',
      marca: 'Hino',
      color: 'blanco',
      hojaIngresoNro: '0001',
    );
    final texto = DocxBuilder.generarTextoNarrativoIngreso(caso);
    expect(texto, contains('ABC1234'));
    expect(texto, contains('Hino'));
  });
}

