import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';

/// Corre OCR sobre una o varias imágenes y arma los modelos de caso
/// buscando los campos conocidos con expresiones regulares.
///
/// IMPORTANTE: el OCR nunca es perfecto (sobre todo en cédulas y números
/// de parte largos). Este servicio deja los campos que SÍ reconoce y
/// deja vacíos los que no encuentra, para que el usuario los complete
/// a mano en el formulario — nunca se debe confiar ciegamente en el
/// resultado.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Une el texto de varias fotos (pueden venir de distintos documentos
  /// del mismo caso) en un solo bloque para buscar los campos.
  Future<String> extraerTextoDeImagenes(List<File> imagenes) async {
    final buffer = StringBuffer();
    for (final img in imagenes) {
      final input = InputImage.fromFile(img);
      final resultado = await _recognizer.processImage(input);
      buffer.writeln(resultado.text);
      buffer.writeln('\n---\n'); // separador entre documentos
    }
    return buffer.toString();
  }

  void dispose() => _recognizer.close();

  // ---------- Helpers de extracción ----------

  String? _buscar(String texto, RegExp regex, {int grupo = 1}) {
    final m = regex.firstMatch(texto);
    if (m == null) return null;
    final valor = m.group(grupo)?.trim();
    return (valor == null || valor.isEmpty) ? null : valor;
  }

  /// Placa ecuatoriana: 3 letras + 3-4 números, con o sin guion.
  String? _buscarPlaca(String texto) {
    final regex = RegExp(r'\b([A-Z]{3}[-\s]?\d{3,4})\b');
    return _buscar(texto, regex);
  }

  String? _buscarCedula(String texto) {
    // Cédula ecuatoriana: 10 dígitos, a veces con guion antes del último.
    final regex = RegExp(r'(?:C\.?I\.?|C\.?C\.?)\s*[:.]?\s*(\d{9,10}-?\d?)');
    return _buscar(texto, regex);
  }

  String? _buscarFecha(String texto, RegExp regex) => _buscar(texto, regex);

  // ---------- Parser: hoja física "Jefatura Provincial" (Ingreso) ----------
  //
  // Campos reales de la hoja (ver README): arriba -> N° en rojo (hoja de
  // ingreso), Control/CRV, Fecha de Ingreso, Vehículo marca, Color,
  // Placas, Nombre del Propietario, Entregado por, Elabora el parte
  // policial, Causa de la detención.

  CasoIngreso parsearIngreso(String texto, {required String id}) {
    final t = texto.replaceAll('\n', ' ');

    final hoja = _buscar(t, RegExp(r'N[°ºo]\s*\.?\s*(0*\d{4,7})')); // el número rojo, ej. 0002099
    final crv = _buscar(t, RegExp(r'TRÁNSITO\s+([A-Za-zÁÉÍÓÚñÑ]+\s*\d+)', caseSensitive: false)) ??
        _buscar(t, RegExp(r'(Control\s*\d+)', caseSensitive: false));
    final fecha = _buscar(
        t,
        RegExp(
            r'Fecha\s+de\s+Ingreso\s*[:.]?\s*([A-Za-zÁÉÍÓÚñÑ]+\s*a\s*\d{1,2}\s*de\s*[A-Za-zÁÉÍÓÚñÑ]+\s*del\s*20\s*\d{2})',
            caseSensitive: false));
    final marca = _buscar(t, RegExp(r'Veh[íi]culo\s+marca\s+([A-Za-zÁÉÍÓÚñÑ]+)', caseSensitive: false));
    final color = _buscar(t, RegExp(r'Color\s+([A-Za-zÁÉÍÓÚñÑ]+)', caseSensitive: false));
    final placa = _buscarPlaca(t.toUpperCase());
    final propietario = _buscar(
        t, RegExp(r'Nombre\s+del\s+Propietario\s+([A-Za-zÁÉÍÓÚñÑ .]+?)(?:\s+Entregado\s+por)', caseSensitive: false));
    final entregadoPor =
        _buscar(t, RegExp(r'Entregado\s+por\s+([A-Za-zÁÉÍÓÚñÑ.,]+(?:\s+[A-Za-zÁÉÍÓÚñÑ.,]+)*?)(?:\s+Elabora)', caseSensitive: false));
    final elaboraParte =
        _buscar(t, RegExp(r'Elabora\s+el\s+parte\s+policial\s+([A-Za-zÁÉÍÓÚñÑ.,]+(?:\s+[A-Za-zÁÉÍÓÚñÑ.,]+)*?)(?:\s+Causa)', caseSensitive: false));
    final causa = _buscar(t, RegExp(r'Causa\s+de\s+la\s+detenci[óo]n\s+([A-Za-zÁÉÍÓÚñÑ .]+)', caseSensitive: false));

    return CasoIngreso(
      id: id,
      crv: crv ?? '',
      marca: marca ?? '',
      color: color ?? '',
      placa: placa ?? '',
      propietario: propietario ?? '',
      causaLegal: causa ?? '',
      hojaIngresoNro: hoja ?? '',
      fechaIngreso: fecha ?? '',
      traslado: entregadoPor ?? '',
      policiaNombre: elaboraParte ?? '',
    );
  }

  // ---------- Parser: hoja física "Jefatura Provincial" (Libertad) ----------
  //
  // Sección inferior de la MISMA hoja, llenada a esfero después:
  // "SALIDA DEL VEHICULO DEL PATIO DE RETENCIÓN DE TRÁNSITO"
  // Fecha de salida / Yo (quien retira, el propietario) / placas / N° de
  // motor / Recibe Conforme -> cédula.

  CasoLibertad parsearLibertad(String texto, {required String id}) {
    final t = texto.replaceAll('\n', ' ');

    final hoja = _buscar(t, RegExp(r'N[°ºo]\s*\.?\s*(0*\d{4,7})'));
    final marca = _buscar(t, RegExp(r'Veh[íi]culo\s+marca\s+([A-Za-zÁÉÍÓÚñÑ]+)', caseSensitive: false));
    final color = _buscar(t, RegExp(r'Color\s+([A-Za-zÁÉÍÓÚñÑ]+)', caseSensitive: false));
    final placa = _buscarPlaca(t.toUpperCase());
    final fechaSalida = _buscar(
        t,
        RegExp(
            r'Fecha\s+de\s+salida\s*[:.]?\s*([A-Za-zÁÉÍÓÚñÑ]*\s*\d{0,2}\s*a?\s*\d{0,2}\s*de\s*[A-Za-zÁÉÍÓÚñÑ]+\s*del\s*20\s*\d{2})',
            caseSensitive: false));
    final retiradoPor = _buscar(t, RegExp(r'\bYo\s+([A-ZÁÉÍÓÚÑ][A-Za-zÁÉÍÓÚñÑ .]+?)\s+mediante\s+el\s+presente', caseSensitive: false));
    final cedula = _buscarCedula(t);
    final fechaIngreso = _buscarFecha(t, RegExp(r'[Ff]echa\s+de\s+[Ii]ngreso\s*[:.]?\s*([A-Za-zÁÉÍÓÚñÑ]+\s*a\s*\d{1,2}\s*de\s*[A-Za-zÁÉÍÓÚñÑ]+\s*del\s*20\s*\d{2})'));

    return CasoLibertad(
      id: id,
      marca: marca ?? '',
      color: color ?? '',
      placa: placa ?? '',
      hojaIngresoNro: hoja ?? '',
      fechaIngreso: fechaIngreso ?? '',
      fechaSalida: fechaSalida ?? '',
      retiradoPor: retiradoPor ?? '',
      cedulaRetira: cedula ?? '',
      pagos: [PagoGaraje()], // esta hoja no trae datos de pago; se llenan a mano si aplica
    );
  }

}
