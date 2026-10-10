// ============================================================
// pago_validacion.dart  (v2 — con tolerancia por comisión bancaria)
// Lógica de tarifas de garaje y validación de pagos para el
// flujo de "Liberar vehículo" (REGISTROS PRV TRANSITO).
//
// UBICACIÓN EN TU PROYECTO (reemplaza el archivo anterior):
//   registros_prv_transito/lib/utils/pago_validacion.dart
// ============================================================

/// Tipos de servicio de garaje según la tabla de tarifas.
enum TipoServicioGaraje {
  livianos,
  pesados,
  motocicleta,
  extraPesados,
}

class TarifaGaraje {
  final TipoServicioGaraje tipo;
  final String etiqueta;
  final double precioUnitarioReferencia;
  final List<String> keywords;

  const TarifaGaraje({
    required this.tipo,
    required this.etiqueta,
    required this.precioUnitarioReferencia,
    required this.keywords,
  });
}

/// Tabla de tarifas confirmada por Xavier (valores por día, en USD).
const List<TarifaGaraje> tablaTarifasGaraje = [
  TarifaGaraje(
    tipo: TipoServicioGaraje.livianos,
    etiqueta: 'SERVICIO DE GARAJE LIVIANOS (HASTA 3,5 TN A EXCEPCIÓN DE MOTOCICLETAS) (DIARIOS)',
    precioUnitarioReferencia: 3.00,
    keywords: ['LIVIANOS'],
  ),
  TarifaGaraje(
    tipo: TipoServicioGaraje.pesados,
    etiqueta: 'SERVICIO DE GARAJE PESADOS (DE 3,51 TN HASTA 12 TN)',
    precioUnitarioReferencia: 9.00,
    keywords: ['PESADOS', 'DE 3,51 TN HASTA 12 TN'],
  ),
  TarifaGaraje(
    tipo: TipoServicioGaraje.motocicleta,
    etiqueta: 'SERVICIO DE GARAJE (CENTROS DE RETENCIÓN) MOTOCICLETA',
    precioUnitarioReferencia: 1.00,
    keywords: ['MOTOCICLETA'],
  ),
  TarifaGaraje(
    tipo: TipoServicioGaraje.extraPesados,
    etiqueta: 'SERVICIO DE GARAJE EXTRA PESADOS (MÁS DE 12 TN) (DIARIOS)',
    precioUnitarioReferencia: 15.00,
    keywords: ['EXTRA PESADOS', 'MÁS DE 12 TN', 'MAS DE 12 TN'],
  ),
];

/// Deduce el tipo de servicio de garaje leyendo el texto de la
/// propia Orden de Pago (columna Rubro/Servicio).
TarifaGaraje? detectarTarifaDesdeTexto(String textoServicio) {
  final textoNormalizado = textoServicio.toUpperCase();
  for (final tarifa in tablaTarifasGaraje) {
    for (final kw in tarifa.keywords) {
      if (textoNormalizado.contains(kw)) {
        return tarifa;
      }
    }
  }
  return null;
}

/// Datos extraídos de UNA Orden de Pago (puede haber varias por caso).
class OrdenDePago {
  final String numeroOrden;
  final String cedula;
  final String nombres;
  final String textoServicio;
  final int cantidadDias;
  final double precioUnitario;
  final double valorTotal;
  final double? valorComprobanteBancario;

  OrdenDePago({
    required this.numeroOrden,
    required this.cedula,
    required this.nombres,
    required this.textoServicio,
    required this.cantidadDias,
    required this.precioUnitario,
    required this.valorTotal,
    this.valorComprobanteBancario,
  });

  double get valorCalculado => cantidadDias * precioUnitario;
}

/// Nivel de severidad de un resultado de validación.
enum SeveridadValidacion { ok, advertencia, error }

/// Resultado de una validación, para mostrar en pantalla.
class ResultadoValidacion {
  final SeveridadValidacion severidad;
  final String mensaje;

  /// Texto sugerido para el campo "Observaciones" (editable por el
  /// usuario). Vacío cuando no aplica.
  final String observacionSugerida;

  ResultadoValidacion(this.severidad, this.mensaje, {this.observacionSugerida = ''});

  bool get ok => severidad == SeveridadValidacion.ok;
  bool get esError => severidad == SeveridadValidacion.error;

  /// El flujo puede seguir (guardar/editar) tanto en OK como en
  /// advertencia. Solo un error real detiene el guardado.
  bool get permiteContinuar => severidad != SeveridadValidacion.error;
}

/// Tolerancia por comisión bancaria / valor de transacción que a
/// veces se suma en el comprobante (Datafast, transferencias, etc.).
/// Diferencias hasta este monto se registran como observación, no
/// como error. AJUSTA este valor si tu comisión típica es distinta.
const double toleranciaComisionBancaria = 2.00;

/// VALIDACIÓN 1: cantidad × precio unitario (Orden de Pago) vs.
/// valor del/los comprobante(s) bancario/Datafast.
/// - Diferencia = 0            -> OK
/// - Diferencia <= tolerancia  -> ADVERTENCIA (posible comisión), no bloquea
/// - Diferencia > tolerancia   -> ERROR, bloquea
ResultadoValidacion validarValoresDeGaraje(
  List<OrdenDePago> ordenes, {
  double tolerancia = toleranciaComisionBancaria,
}) {
  double totalCalculado = 0;
  double totalComprobantes = 0;
  bool faltaAlgunComprobante = false;

  for (final o in ordenes) {
    totalCalculado += o.valorCalculado;
    if (o.valorComprobanteBancario != null) {
      totalComprobantes += o.valorComprobanteBancario!;
    } else {
      faltaAlgunComprobante = true;
    }
  }

  if (faltaAlgunComprobante) {
    return ResultadoValidacion(
      SeveridadValidacion.advertencia,
      'Falta cargar el comprobante bancario/Datafast de al menos una orden de pago. '
      'Puedes seguir editando y completarlo luego.',
      observacionSugerida: 'Pendiente cargar comprobante de pago.',
    );
  }

  final diferencia = (totalCalculado - totalComprobantes).abs();

  if (diferencia <= 0.01) {
    return ResultadoValidacion(
      SeveridadValidacion.ok,
      'Los valores de garaje coinciden.',
    );
  }

  if (diferencia <= tolerancia) {
    // Diferencia pequeña: probablemente comisión bancaria/valor de
    // transacción del comprobante. No bloquea, solo se anota.
    return ResultadoValidacion(
      SeveridadValidacion.advertencia,
      'Diferencia pequeña de \$${diferencia.toStringAsFixed(2)} entre el valor calculado '
      '(\$${totalCalculado.toStringAsFixed(2)}) y el pagado (\$${totalComprobantes.toStringAsFixed(2)}). '
      'Podría ser el valor de la transacción/comisión bancaria del comprobante. '
      'Puedes continuar y editar la observación si lo deseas.',
      observacionSugerida:
          'Diferencia de \$${diferencia.toStringAsFixed(2)} respecto al valor calculado, '
          'posible comisión/valor de transacción del comprobante.',
    );
  }

  // Diferencia mayor a la tolerancia: sí es un error real.
  return ResultadoValidacion(
    SeveridadValidacion.error,
    'Valores de garaje no coinciden. '
    'Calculado (cantidad x precio unitario): \$${totalCalculado.toStringAsFixed(2)} — '
    'Pagado según comprobante(s): \$${totalComprobantes.toStringAsFixed(2)}.',
  );
}

/// Calcula automáticamente los días de permanencia real (conteo inclusivo desde el día 1).
int calcularDiasPermanencia(DateTime fechaIngreso, DateTime fechaSalida) {
  final inicio = DateTime(fechaIngreso.year, fechaIngreso.month, fechaIngreso.day);
  final fin = DateTime(fechaSalida.year, fechaSalida.month, fechaSalida.day);
  if (fin.isBefore(inicio)) return 0;
  return fin.difference(inicio).inDays + 1;
}

/// VALIDACIÓN 2: suma de días pagados (todas las órdenes) vs. días
/// reales de permanencia. Esta sigue siendo estricta en números
/// enteros de días (no aplica tolerancia monetaria), pero SIEMPRE
/// permite continuar — es informativa, no bloquea el guardado.
ResultadoValidacion validarDiasPagados(
  List<OrdenDePago> ordenes,
  DateTime fechaIngreso,
  DateTime fechaSalida,
) {
  final diasReales = calcularDiasPermanencia(fechaIngreso, fechaSalida);
  final diasPagados = ordenes.fold<int>(0, (suma, o) => suma + o.cantidadDias);

  if (diasPagados == diasReales) {
    return ResultadoValidacion(
      SeveridadValidacion.ok,
      'Días pagados ($diasPagados) coinciden con los días de permanencia ($diasReales).',
    );
  }

  final faltan = diasReales - diasPagados;
  final mensaje = faltan > 0
      ? 'Permanencia real: $diasReales día(s) — Pagado: $diasPagados día(s). Faltan $faltan día(s) por pagar.'
      : 'Permanencia real: $diasReales día(s) — Pagado: $diasPagados día(s). Se pagaron ${-faltan} día(s) de más.';

  return ResultadoValidacion(
    SeveridadValidacion.advertencia,
    mensaje,
    observacionSugerida: mensaje,
  );
}

/// Corre ambas validaciones — llámalo desde el botón "Liberar
/// vehículo" / "Guardar" antes de generar el Word. Ninguna de las
/// dos bloquea salvo un error real de valores (diferencia grande).
class ValidacionCompleta {
  final ResultadoValidacion valores;
  final ResultadoValidacion dias;

  ValidacionCompleta(this.valores, this.dias);

  bool get permiteGuardar => valores.permiteContinuar && dias.permiteContinuar;

  /// Texto combinado listo para precargar en el campo "Observaciones"
  /// del formulario (el usuario lo puede editar libremente).
  String get observacionCombinada {
    final partes = [valores.observacionSugerida, dias.observacionSugerida]
        .where((s) => s.isNotEmpty)
        .toList();
    return partes.join(' | ');
  }
}

ValidacionCompleta validarPagoCompleto(
  List<OrdenDePago> ordenes,
  DateTime fechaIngreso,
  DateTime fechaSalida,
) {
  final valores = validarValoresDeGaraje(ordenes);
  final dias = validarDiasPagados(ordenes, fechaIngreso, fechaSalida);
  return ValidacionCompleta(valores, dias);
}

// ============================================================
// PROMPT SUGERIDO PARA GEMINI (extracción de la Orden de Pago)
// ============================================================
const String promptExtraccionOrdenDePago = '''
Analiza la imagen de un documento llamado "ORDEN DE PAGO" / "SOLICITUD DE PAGO"
emitido por la Agencia Nacional de Tránsito de Ecuador.

Extrae ÚNICAMENTE estos datos y devuélvelos en JSON, sin texto adicional:

{
  "numero_orden": "número que aparece después de 'ORDEN DE PAGO No.'",
  "cedula": "número de cédula que aparece junto a 'CED'",
  "nombres": "nombre completo de la persona (después de la cédula)",
  "texto_servicio": "el texto completo de la fila 'Rubro' o 'Servicio', tal como aparece impreso",
  "cantidad_dias": "el número de la columna 'Cantidad' (entero)",
  "precio_unitario": "el número de la columna 'Precio Unitario' (decimal, sin símbolo de dólar)",
  "valor_total": "el número junto a 'Total a Pagar' (decimal, sin símbolo de dólar)"
}

Reglas:
- El tipo de vehículo/tarifa NO lo debes inferir tú: solo transcribe
  literalmente el texto de la fila de servicio en "texto_servicio".
- Si algún campo no es legible, devuélvelo como null.
- No inventes valores. No agregues explicaciones fuera del JSON.
''';

/// PROMPT para el comprobante bancario/Datafast (documento aparte).
const String promptExtraccionComprobantePago = '''
Analiza la imagen de un comprobante de pago bancario o de Datafast.

Extrae ÚNICAMENTE estos datos y devuélvelos en JSON, sin texto adicional:

{
  "valor_pagado": "el monto total pagado/cobrado, incluyendo cualquier valor de transacción o comisión si aparece sumado (decimal, sin símbolo de dólar)",
  "valor_transaccion_o_comision": "si el comprobante muestra por separado un 'valor de la transacción' o comisión, colócalo aquí (decimal); si no aparece, devuelve null",
  "fecha": "fecha del pago tal como aparece",
  "hora": "hora del pago tal como aparece",
  "entidad_financiera": "nombre del banco o entidad que aparece en el comprobante"
}

Reglas:
- "valor_pagado" debe ser el monto total realmente cobrado (el que se compara contra la Orden de Pago), no solo el valor base del trámite.
- Si algún campo no es legible, devuélvelo como null.
- No inventes valores. No agregues explicaciones fuera del JSON.
''';

// ============================================================
// INTEGRACIÓN DIRECTA CON TU MODELO PagoGaraje / CasoLibertad
// (usa estas funciones desde formulario_screen.dart)
// ============================================================

/// Convierte fechas en formato "dd/mm/aaaa" (como las manejas en el
/// resto de la app) a DateTime. Devuelve null si no se puede parsear.
DateTime? parseFechaDdMmAaaa(String texto) {
  final partes = texto.trim().split('/');
  if (partes.length != 3) return null;
  final dia = int.tryParse(partes[0]);
  final mes = int.tryParse(partes[1]);
  final anio = int.tryParse(partes[2]);
  if (dia == null || mes == null || anio == null) return null;
  try {
    return DateTime(anio, mes, dia);
  } catch (_) {
    return null;
  }
}

/// VALIDACIÓN 1, usando directamente tu lista de PagoGaraje.
/// Compara la suma de (diasPagados x precioUnitario) de cada pago
/// contra la suma de los valores de comprobante ("valor" en cada pago).
ResultadoValidacion validarValoresDeGarajeDesdePagos(
  List<dynamic> pagos, {
  double tolerancia = toleranciaComisionBancaria,
}) {
  double totalCalculado = 0;
  double totalComprobantes = 0;

  for (final p in pagos) {
    totalCalculado += p.valorCalculado as double;
    totalComprobantes += (p.valorComoDouble as double?) ?? 0;
  }

  final diferencia = (totalCalculado - totalComprobantes).abs();

  if (diferencia <= 0.01) {
    return ResultadoValidacion(SeveridadValidacion.ok, 'Los valores de garaje coinciden.');
  }

  if (diferencia <= tolerancia) {
    return ResultadoValidacion(
      SeveridadValidacion.advertencia,
      'Diferencia pequeña de \$${diferencia.toStringAsFixed(2)} entre el valor calculado '
      '(\$${totalCalculado.toStringAsFixed(2)}) y el pagado (\$${totalComprobantes.toStringAsFixed(2)}). '
      'Podría ser el valor de la transacción/comisión bancaria del comprobante. Puedes continuar.',
      observacionSugerida:
          'Diferencia de \$${diferencia.toStringAsFixed(2)} respecto al valor calculado, '
          'posible comisión/valor de transacción del comprobante.',
    );
  }

  return ResultadoValidacion(
    SeveridadValidacion.error,
    'Valores de garaje no coinciden. '
    'Calculado: \$${totalCalculado.toStringAsFixed(2)} — Pagado: \$${totalComprobantes.toStringAsFixed(2)}.',
  );
}

/// VALIDACIÓN 2, usando directamente fechas en texto "dd/mm/aaaa" y
/// tu lista de PagoGaraje. Es informativa: nunca bloquea el guardado.
ResultadoValidacion validarDiasPagadosDesdePagos(
  List<dynamic> pagos,
  String fechaIngresoTexto,
  String fechaSalidaTexto,
) {
  final fechaIngreso = parseFechaDdMmAaaa(fechaIngresoTexto);
  final fechaSalida = parseFechaDdMmAaaa(fechaSalidaTexto);

  if (fechaIngreso == null || fechaSalida == null) {
    return ResultadoValidacion(
      SeveridadValidacion.advertencia,
      'No se pudo calcular los días de permanencia: revisa el formato de las fechas (dd/mm/aaaa).',
    );
  }

  final diasReales = calcularDiasPermanencia(fechaIngreso, fechaSalida);
  final diasPagados = pagos.fold<int>(0, (suma, p) => suma + (int.tryParse(p.diasPagados as String) ?? 0));

  if (diasPagados == diasReales) {
    return ResultadoValidacion(
      SeveridadValidacion.ok,
      'Días pagados ($diasPagados) coinciden con los días de permanencia ($diasReales).',
    );
  }

  final faltan = diasReales - diasPagados;
  final mensaje = faltan > 0
      ? 'Permanencia real: $diasReales día(s) — Pagado: $diasPagados día(s). Faltan $faltan día(s) por pagar.'
      : 'Permanencia real: $diasReales día(s) — Pagado: $diasPagados día(s). Se pagaron ${-faltan} día(s) de más.';

  return ResultadoValidacion(SeveridadValidacion.advertencia, mensaje, observacionSugerida: mensaje);
}

/// Corre ambas validaciones directamente sobre tu CasoLibertad.
class ValidacionCasoLibertad {
  final ResultadoValidacion valores;
  final ResultadoValidacion dias;
  ValidacionCasoLibertad(this.valores, this.dias);
  bool get permiteGuardar => valores.permiteContinuar && dias.permiteContinuar;
  String get observacionCombinada {
    final partes = [valores.observacionSugerida, dias.observacionSugerida]
        .where((s) => s.isNotEmpty)
        .toList();
    return partes.join(' | ');
  }
}

ValidacionCasoLibertad validarCasoLibertad(
  List<dynamic> pagos,
  String fechaIngreso,
  String fechaSalida,
) {
  return ValidacionCasoLibertad(
    validarValoresDeGarajeDesdePagos(pagos),
    validarDiasPagadosDesdePagos(pagos, fechaIngreso, fechaSalida),
  );
}

