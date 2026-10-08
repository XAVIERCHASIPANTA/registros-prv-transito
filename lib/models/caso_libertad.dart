// RUTA DE ARCHIVO: lib/models/caso_libertad.dart

/// Representa un pago realizado por concepto de garaje (uno o varios
/// por caso). "entidadFinanciera" es el texto TAL CUAL aparece en el
/// recibo (ej. "Pichincha Mi Vecino"), y "entidadFinancieraOficial" es
/// a cuál de los 5 bancos oficiales de SIIPNE 3W corresponde ese
/// recibo (ver entidad_financiera_service.dart).
class PagoGaraje {
  String ordenPagoNro;
  String comprobantePagoNro;
  String diasPagados;
  String precioUnitario;
  String valor; // Valor pagado según el comprobante bancario/Datafast
  String horaFechaPago;
  String entidadFinanciera; // texto literal del recibo
  String entidadFinancieraOficial; // uno de EntidadFinancieraService.oficiales

  PagoGaraje({
    this.ordenPagoNro = '',
    this.comprobantePagoNro = '',
    this.diasPagados = '',
    this.precioUnitario = '',
    this.valor = '',
    this.horaFechaPago = '',
    this.entidadFinanciera = '',
    this.entidadFinancieraOficial = '',
  });

  /// cantidad de días x precio unitario = lo que debería costar según
  /// la Orden de Pago (para comparar contra "valor", el comprobante real).
  double get valorCalculado {
    final dias = int.tryParse(diasPagados) ?? 0;
    final precio = double.tryParse(precioUnitario.replaceAll(',', '.')) ?? 0;
    return dias * precio;
  }

  double? get valorComoDouble => double.tryParse(valor.replaceAll(',', '.'));

  Map<String, dynamic> toJson() => {
        'ordenPagoNro': ordenPagoNro,
        'comprobantePagoNro': comprobantePagoNro,
        'diasPagados': diasPagados,
        'precioUnitario': precioUnitario,
        'valor': valor,
        'horaFechaPago': horaFechaPago,
        'entidadFinanciera': entidadFinanciera,
        'entidadFinancieraOficial': entidadFinancieraOficial,
      };

  factory PagoGaraje.fromJson(Map<String, dynamic> j) => PagoGaraje(
        ordenPagoNro: j['ordenPagoNro'] ?? '',
        comprobantePagoNro: j['comprobantePagoNro'] ?? '',
        diasPagados: j['diasPagados'] ?? '',
        precioUnitario: j['precioUnitario'] ?? '',
        valor: j['valor'] ?? '',
        horaFechaPago: j['horaFechaPago'] ?? '',
        entidadFinanciera: j['entidadFinanciera'] ?? '',
        entidadFinancieraOficial: j['entidadFinancieraOficial'] ?? '',
      );
}

/// Representa un registro de "Parte de Libertad" (devolución) de un
/// vehículo. Nace siempre de un CasoIngreso ya existente (hereda
/// placa/marca/color/tipo/hoja/parte/causa) y agrega todo lo propio de
/// la salida: documento de devolución, garaje, Investigación/Pericias
/// y el pago de Alcohocheck (movidos aquí desde el Ingreso).
class CasoLibertad {
  final String id;
  String memorandoNro;
  String memorandoFecha;
  String oficioDevolucionNro;
  String oficioDevolucionFecha;
  String firmadoPor; // nombre + cargo del fiscal/juez
  String gradoDestinatario; // "Mayor" / "Tcrnl." / "Coronel" — Parte elevado al Sr/a
  String marca;
  String color;
  String placa;
  String retiradoPor; // propietario / apoderado / procurador síndico
  String calidadRetira; // 'propietario', 'apoderado', 'procurador síndico'
  String cedulaRetira;
  String hojaIngresoNro;
  String parteIngresoNro;
  String fechaIngreso;
  String fechaSalida;
  String diasPermanencia;
  String tipoVehiculo;
  String observaciones;
  String crv; // heredado del Ingreso
  String causa; // heredado del Ingreso (causaLegal + detalleCausa)

  // Salida y garaje
  String custodioEntregaNombre;
  String placaGrua;
  String numeroParteWebSalida;
  String tipoServicioGaraje;

  // Investigación / Pericias (movido aquí desde Ingreso, ronda 3)
  String periciaRealizada;
  String peritoNombre;

  // Pago Alcohocheck (movido aquí desde Ingreso, ronda 3) — solo aplica
  // si el Ingreso tuvo activado el módulo de alcoholemia.
  String ordenPagoAlcohocheckNro;
  String comprobantePagoAlcohocheckNro;
  String valorAlcohocheck;
  String horaFechaPagoAlcohocheck;

  List<PagoGaraje> pagos;
  DateTime creado;

  CasoLibertad({
    required this.id,
    this.memorandoNro = '',
    this.memorandoFecha = '',
    this.oficioDevolucionNro = '',
    this.oficioDevolucionFecha = '',
    this.firmadoPor = '',
    this.gradoDestinatario = 'Mayor',
    this.marca = '',
    this.color = '',
    this.placa = '',
    this.retiradoPor = '',
    this.calidadRetira = 'propietario',
    this.cedulaRetira = '',
    this.hojaIngresoNro = '',
    this.parteIngresoNro = '',
    this.fechaIngreso = '',
    this.fechaSalida = '',
    this.diasPermanencia = '',
    this.tipoVehiculo = '',
    this.observaciones = '',
    this.crv = '',
    this.causa = '',
    this.custodioEntregaNombre = '',
    this.placaGrua = '',
    this.numeroParteWebSalida = '',
    this.tipoServicioGaraje = '',
    this.periciaRealizada = '',
    this.peritoNombre = '',
    this.ordenPagoAlcohocheckNro = '',
    this.comprobantePagoAlcohocheckNro = '',
    this.valorAlcohocheck = '',
    this.horaFechaPagoAlcohocheck = '',
    List<PagoGaraje>? pagos,
    DateTime? creado,
  })  : pagos = pagos ?? [PagoGaraje()],
        creado = creado ?? DateTime.now();

  /// Suma de todos los pagos de garaje ya registrados (según el
  /// comprobante, no el cálculo teórico de días x precio).
  double get valorTotalGaraje =>
      pagos.fold(0.0, (suma, p) => suma + (p.valorComoDouble ?? 0));

  /// Líneas listas para insertar en el Word de Libertad (docx_builder).
  List<String> pagosParaWord() {
    final lineas = <String>[];
    for (var i = 0; i < pagos.length; i++) {
      final p = pagos[i];
      final banco = p.entidadFinancieraOficial.isNotEmpty ? p.entidadFinancieraOficial : p.entidadFinanciera;
      lineas.add('${i + 1}-Orden de pago Garaje: N.- ${p.ordenPagoNro}');
      lineas.add('Comprobante de pago: N.- ${p.comprobantePagoNro}');
      lineas.add('Hora de pago: ${p.horaFechaPago}');
      lineas.add('Valor: \$${p.valor}');
      lineas.add('Entidad financiera: $banco');
      if (i != pagos.length - 1) lineas.add('');
    }
    return lineas;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'memorandoNro': memorandoNro,
        'memorandoFecha': memorandoFecha,
        'oficioDevolucionNro': oficioDevolucionNro,
        'oficioDevolucionFecha': oficioDevolucionFecha,
        'firmadoPor': firmadoPor,
        'gradoDestinatario': gradoDestinatario,
        'marca': marca,
        'color': color,
        'placa': placa,
        'retiradoPor': retiradoPor,
        'calidadRetira': calidadRetira,
        'cedulaRetira': cedulaRetira,
        'hojaIngresoNro': hojaIngresoNro,
        'parteIngresoNro': parteIngresoNro,
        'fechaIngreso': fechaIngreso,
        'fechaSalida': fechaSalida,
        'diasPermanencia': diasPermanencia,
        'tipoVehiculo': tipoVehiculo,
        'observaciones': observaciones,
        'crv': crv,
        'causa': causa,
        'custodioEntregaNombre': custodioEntregaNombre,
        'placaGrua': placaGrua,
        'numeroParteWebSalida': numeroParteWebSalida,
        'tipoServicioGaraje': tipoServicioGaraje,
        'periciaRealizada': periciaRealizada,
        'peritoNombre': peritoNombre,
        'ordenPagoAlcohocheckNro': ordenPagoAlcohocheckNro,
        'comprobantePagoAlcohocheckNro': comprobantePagoAlcohocheckNro,
        'valorAlcohocheck': valorAlcohocheck,
        'horaFechaPagoAlcohocheck': horaFechaPagoAlcohocheck,
        'pagos': pagos.map((p) => p.toJson()).toList(),
        'creado': creado.toIso8601String(),
      };

  factory CasoLibertad.fromJson(Map<String, dynamic> j) => CasoLibertad(
        id: j['id'],
        memorandoNro: j['memorandoNro'] ?? '',
        memorandoFecha: j['memorandoFecha'] ?? '',
        oficioDevolucionNro: j['oficioDevolucionNro'] ?? '',
        oficioDevolucionFecha: j['oficioDevolucionFecha'] ?? '',
        firmadoPor: j['firmadoPor'] ?? '',
        gradoDestinatario: j['gradoDestinatario'] ?? 'Mayor',
        marca: j['marca'] ?? '',
        color: j['color'] ?? '',
        placa: j['placa'] ?? '',
        retiradoPor: j['retiradoPor'] ?? '',
        calidadRetira: j['calidadRetira'] ?? 'propietario',
        cedulaRetira: j['cedulaRetira'] ?? '',
        hojaIngresoNro: j['hojaIngresoNro'] ?? '',
        parteIngresoNro: j['parteIngresoNro'] ?? '',
        fechaIngreso: j['fechaIngreso'] ?? '',
        fechaSalida: j['fechaSalida'] ?? '',
        diasPermanencia: j['diasPermanencia'] ?? '',
        tipoVehiculo: j['tipoVehiculo'] ?? '',
        observaciones: j['observaciones'] ?? '',
        crv: j['crv'] ?? '',
        causa: j['causa'] ?? '',
        custodioEntregaNombre: j['custodioEntregaNombre'] ?? '',
        placaGrua: j['placaGrua'] ?? '',
        numeroParteWebSalida: j['numeroParteWebSalida'] ?? '',
        tipoServicioGaraje: j['tipoServicioGaraje'] ?? '',
        periciaRealizada: j['periciaRealizada'] ?? '',
        peritoNombre: j['peritoNombre'] ?? '',
        ordenPagoAlcohocheckNro: j['ordenPagoAlcohocheckNro'] ?? '',
        comprobantePagoAlcohocheckNro: j['comprobantePagoAlcohocheckNro'] ?? '',
        valorAlcohocheck: j['valorAlcohocheck'] ?? '',
        horaFechaPagoAlcohocheck: j['horaFechaPagoAlcohocheck'] ?? '',
        pagos: (j['pagos'] as List? ?? []).map((p) => PagoGaraje.fromJson(p)).toList(),
        creado: DateTime.tryParse(j['creado'] ?? '') ?? DateTime.now(),
      );
}
