import 'dart:io';
import '../lib/services/docx_builder.dart';

void main() {
  final bytes = DocxBuilder.buildInformeSemanal(
    jefaturaNombre: 'SANTO DOMINGO',
    patio: 'CONTROL 120',
    subzona: 'Santo Domingo de los Tsáchilas',
    subzonaAbrev: 'SDT',
    oficioNro: 'PN-SZ-SDT-JPCTSV-CRV-2026-001-O',
    fechaOficio: '10 de octubre de 2026',
    asuntoOficioNro: 'PN-DNT-SCRV-QX-2025-045-O',
    asuntoOficioFecha: '30 de abril del 2025',
    destinatarioNombre: 'Cristian German Barreiros Tumipamba',
    destinatarioRango: 'Coronel de E.M',
    fechaLunes: '28 de septiembre de 2026',
    fechaDomingo: '04 de octubre de 2026',
    vehiculos: 1,
    motocicletas: 0,
    fojasStr: '02',
    observacionAdicional: '',
    firmanteNombre: '',
    firmanteRango: 'Sargento Segundo De Policía',
  );

  File('scratch/test_generated_informe.docx').writeAsBytesSync(bytes);
  print('Docx generado exitosamente: ${bytes.length} bytes');
}
