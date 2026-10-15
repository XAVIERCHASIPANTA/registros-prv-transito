/// Representa el registro completo de Ingreso de un vehículo al Patio de Retención (PRV).
class CasoIngreso {
  final String id;
  String hojaIngresoNro;
  String parteIngresoNro;
  String fechaIngreso;
  String horaRetencion; // Campo para hora de retención / operativo / hecho

  // --- ubicación del caso dentro de la matriz nacional ---
  String subzona; // Ej: "SANTO DOMINGO" (columna B de la matriz)
  String crv; // Ej: "CONTROL 120" (columna C de la matriz — nombre del patio)

  // Identificación del Vehículo
  String placa;
  String marca;
  String modelo;
  String anioFabricacion;
  String color;
  String tipoVehiculo; // AUTOMÓVIL, MOTOCICLETA, CAMIONETA, etc.
  String cilindraje; // Específico para motocicletas (ej. 150cc, 250cc)
  String chasis; // Número de VIN / Chasis
  String motor; // Número de Motor

  // NUEVO (31/ago): número de operativo, solo aplica cuando
  // tipoOperativo == 'OPERATIVO N°'
  String numeroOperativo;

  // DEPRECADOS (31/ago): Xavier pidió quitar estos 3 casilleros del
  // formulario de Ingreso (Falla/Choque/Colisión, Autoridad Requirente y
  // Causa Principal), porque quedaban repetidos con "Causa legal
  // oficial". Se dejan en el modelo por compatibilidad con datos ya
  // guardados; el formulario ya no los muestra ni los llena.
  String causaPrincipal;
  String submotivoFalta;
  String autoridadRequirente;

  // Módulo de Alcoholemia / Alcohotest
  bool aplicaAlcohotest;
  // NUEVO (31/ago): campos reales que pidió Xavier al activar el módulo
  String numeroPruebaAlcoholemia;
  String nombreSancionado;
  String cedulaSancionado;
  String resultadoAlcoholemia;
  String citacionNro;
  // DEPRECADOS (31/ago): "se negó la prueba"/rango automático y el pago
  // de Alcohocheck salen del formulario de Ingreso. Xavier pidió que el
  // pago (orden/comprobante) se registre en la hoja de Libertad, igual
  // que los comprobantes de pago de garaje — pendiente de implementar
  // ahí (falta formulario_libertad_screen.dart de esta ronda).
  String rangoAlcoholemia;
  bool seNegoPrueba;
  String ordenPagoAlcohocheckNro;
  String valorAlcohocheck;

  // Datos de las personas involucradas
  String propietario;
  String cedulaPropietario;
  String conductor;
  String cedulaConductor;

  // --- Traslado del vehículo hasta el patio ---
  // DEPRECADOS (30/ago): Xavier confirmó que la placa/nombre del
  // conductor de la grúa no son relevantes; se dejan en el modelo por
  // compatibilidad pero ya no se muestran ni se llenan en el
  // formulario. Usar nombreGruaParticular/telefonoGruaParticular en su lugar.
  String placaGrua;
  String conductorGrua;

  String kmGrua; // Km. Grúa Policial — SIEMPRE manual, no se extrae de ningún lado
  String valorGrua; // Valor pagado por el traslado (relevante cuando traslado == 'PARTICULAR')

  // NUEVO (30/ago): datos de la grúa PARTICULAR — solo aplican cuando
  // traslado == 'PARTICULAR' (ver formulario_screen.dart)
  String nombreGruaParticular; // Ej: "Grúa El Gato", "Grúa Tello", "Unitaxis"
  String telefonoGruaParticular;

  // "Traslado" — mismo desplegable de SIIPNE 3W. Valores: 'SUS PROPIOS
  // MEDIOS' o 'PARTICULAR' (antes decía 'GRÚA', renombrado 30/ago)
  String traslado;

  // "Tipo cobro parqueo" — SIIPNE 3W lo pide desde el INGRESO
  // (LIVIANO/PESADO/MOTOCICLETA/EXTRAPESADO); la Libertad hereda este valor.
  // NUEVO (31/ago, ronda 2): tonelaje del vehículo, usado para
  // autocompletar "Tipo cobro parqueo" según el tarifario oficial.
  String tonelaje;
  String tipoCobroParqueo;

  String tipoOperativo; // Ej: "SIN OPERATIVO"

  // Causa legal oficial de SIIPNE 3W (coincide con los desplegables reales
  // "Causa legal"/"Detalle causa")
  String causaLegal;
  String detalleCausa;

  // DEPRECADOS (31/ago): Xavier pidió eliminar estos 3 casilleros del
  // formulario de Ingreso. Se dejan en el modelo por compatibilidad.
  String latitud;
  String longitud;
  String distritoCircuitoSubcircuito;

  // Quién recibe físicamente la custodia al ingreso; distinto de
  // "policiaNombre", que es quien ELABORA el parte
  String custodioRecibeNombre;

  // Persistencia del Agente / Policía que toma el procedimiento
  String policiaNombre;
  String policiaCedula;

  // DEPRECADOS (31/ago): Xavier pidió mover "Investigación / Pericias"
  // a la hoja de Salida (Libertad), no en Ingresos. Se dejan aquí por
  // compatibilidad; pendiente agregarlos al formulario de Libertad
  // cuando se comparta ese archivo.
  String periciaRealizada;
  String peritoNombre;

  // Estado e Inventario
  String estadoVehiculo;
  String observaciones;
  DateTime creado;
  String origen; // 'app' o 'excel'

  bool get esDeExcel => origen == 'excel' || id.startsWith('seed_') || id.startsWith('import_');
  bool get esDeApp => !esDeExcel;

  /// Retorna la situación legal estandarizada para la Matriz Excel y vistas oficiales.
  /// Para accidentes devuelve estrictamente "ACCIDENTE DE TRANSITO" sin guiones ni párrafos.
  /// Para contravenciones extrae el artículo de ley (ej. "ART. 385.1", "ART. 160").
  String get situacionLegalFormateada => formatearSituacionLegal(
        causaLegal: causaLegal,
        detalleCausa: detalleCausa,
        causaPrincipal: causaPrincipal,
      );

  static String formatearSituacionLegal({
    required String causaLegal,
    required String detalleCausa,
    required String causaPrincipal,
  }) {
    final cl = _limpiarTextoBasico(causaLegal);
    final dc = _limpiarTextoBasico(detalleCausa);
    final cp = _limpiarTextoBasico(causaPrincipal);

    final combinada = '$cl $dc $cp'.toUpperCase();

    // 1. Accidente de Tránsito: NUNCA añadir guiones ni textos de partes policiales
    if (combinada.contains('ACCIDENTE') ||
        combinada.contains('CHOQUE') ||
        combinada.contains('SINIESTRO') ||
        combinada.contains('COLISI') ||
        combinada.contains('VOLCAMIENTO') ||
        combinada.contains('ESTRELLAMIENTO') ||
        combinada.contains('ATROPELLO') ||
        combinada.contains('PERDIDA DE CARRIL')) {
      return 'ACCIDENTE DE TRANSITO';
    }

    // 2. Artículos del COIP / LTTTSV
    final regexArt = RegExp(
      r'(?:ART[ÍI]?CULOS?|ART\.?)\s*(\d+(?:\.\d+)?(?:\s*(?:INCISO|NUMERAL|INC|NUM)?\s*#?\s*\d+(?:\.\d+)?)?)',
      caseSensitive: false,
    );
    final match = regexArt.firstMatch('$dc $cl $cp');
    if (match != null) {
      final artNum = match.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
      return 'ART. $artNum'.toUpperCase();
    }

    // 3. Orden Judicial
    if (combinada.contains('ORDEN JUDICIAL') ||
        combinada.contains('DISPOSICION JUDICIAL') ||
        combinada.contains('OFICIO JUDICIAL')) {
      if (dc.isNotEmpty && dc.length <= 30 && !_esRelatoNarrativo(dc)) {
        return 'ORDEN JUDICIAL - ${dc.toUpperCase()}';
      }
      return 'ORDEN JUDICIAL';
    }

    // 4. Acuerdo Ministerial
    if (combinada.contains('ACUERDO MINISTERIAL')) {
      if (dc.isNotEmpty && dc.length <= 30 && !_esRelatoNarrativo(dc)) {
        return 'ACUERDO MINISTERIAL - ${dc.toUpperCase()}';
      }
      return 'ACUERDO MINISTERIAL 00004';
    }

    // 5. Reglamento a la LTTTSV
    if (combinada.contains('REGLAMENTO') || combinada.contains('LTTTSV')) {
      if (dc.isNotEmpty && dc.length <= 30 && !_esRelatoNarrativo(dc)) {
        return dc.toUpperCase();
      }
      return 'REGLAMENTO LTTTSV';
    }

    // 6. Texto base no narrativo
    String base = cl.isNotEmpty ? cl : cp;
    if (base.contains('/')) {
      base = base.split('/').first.trim();
    }
    if (_esRelatoNarrativo(base) || base.length > 50) {
      return 'CONTRAVENCION DE TRANSITO';
    }
    if (base.isNotEmpty) {
      return base.toUpperCase();
    }

    return 'N/A';
  }

  static bool _esRelatoNarrativo(String texto) {
    final t = texto.toUpperCase();
    return t.contains('CIRCUNSTANCIAS DEL HECHO') ||
        t.contains('POR MEDIO DEL PRESENTE') ||
        t.contains('PARTE WEB') ||
        t.contains('SE TRASLADA') ||
        t.contains('AVANZO') ||
        t.contains('ORDEN DE SERVICIO') ||
        t.contains('PERSONAL POLICIAL') ||
        texto.length > 50;
  }

  static String _limpiarTextoBasico(String texto) {
    if (texto.isEmpty) return '';
    return texto
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  CasoIngreso({
    required this.id,
    this.origen = 'app',
    this.hojaIngresoNro = '',
    this.parteIngresoNro = '',
    this.fechaIngreso = '',
    this.horaRetencion = '',
    this.subzona = '',
    this.crv = '',
    this.placa = '',
    this.marca = '',
    this.modelo = '',
    this.anioFabricacion = '',
    this.color = '',
    this.tipoVehiculo = '',
    this.cilindraje = '',
    this.chasis = '',
    this.motor = '',
    this.numeroOperativo = '',
    this.causaPrincipal = '',
    this.submotivoFalta = '',
    this.autoridadRequirente = '',
    this.aplicaAlcohotest = false,
    this.numeroPruebaAlcoholemia = '',
    this.nombreSancionado = '',
    this.cedulaSancionado = '',
    this.resultadoAlcoholemia = '',
    this.citacionNro = '',
    this.rangoAlcoholemia = '',
    this.seNegoPrueba = false,
    this.ordenPagoAlcohocheckNro = '',
    this.valorAlcohocheck = '',
    this.propietario = '',
    this.cedulaPropietario = '',
    this.conductor = '',
    this.cedulaConductor = '',
    this.placaGrua = '',
    this.conductorGrua = '',
    this.kmGrua = '',
    this.valorGrua = '',
    this.nombreGruaParticular = '',
    this.telefonoGruaParticular = '',
    this.traslado = '',
    this.tonelaje = '',
    this.tipoCobroParqueo = '',
    this.tipoOperativo = 'SIN OPERATIVO',
    this.causaLegal = '',
    this.detalleCausa = '',
    this.latitud = '',
    this.longitud = '',
    this.distritoCircuitoSubcircuito = '',
    this.custodioRecibeNombre = '',
    this.policiaNombre = '',
    this.policiaCedula = '',
    this.periciaRealizada = '',
    this.peritoNombre = '',
    this.estadoVehiculo = '',
    this.observaciones = '',
    DateTime? creado,
  }) : creado = creado ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'hojaIngresoNro': hojaIngresoNro,
        'parteIngresoNro': parteIngresoNro,
        'fechaIngreso': fechaIngreso,
        'horaRetencion': horaRetencion,
        'subzona': subzona,
        'crv': crv,
        'placa': placa.toUpperCase(),
        'marca': marca,
        'modelo': modelo,
        'anioFabricacion': anioFabricacion,
        'color': color,
        'tipoVehiculo': tipoVehiculo,
        'cilindraje': cilindraje,
        'chasis': chasis,
        'motor': motor,
        'numeroOperativo': numeroOperativo,
        'causaPrincipal': causaPrincipal,
        'submotivoFalta': submotivoFalta,
        'autoridadRequirente': autoridadRequirente,
        'aplicaAlcohotest': aplicaAlcohotest,
        'numeroPruebaAlcoholemia': numeroPruebaAlcoholemia,
        'nombreSancionado': nombreSancionado,
        'cedulaSancionado': cedulaSancionado,
        'resultadoAlcoholemia': resultadoAlcoholemia,
        'citacionNro': citacionNro,
        'rangoAlcoholemia': rangoAlcoholemia,
        'seNegoPrueba': seNegoPrueba,
        'ordenPagoAlcohocheckNro': ordenPagoAlcohocheckNro,
        'valorAlcohocheck': valorAlcohocheck,
        'propietario': propietario,
        'cedulaPropietario': cedulaPropietario,
        'conductor': conductor,
        'cedulaConductor': cedulaConductor,
        'placaGrua': placaGrua,
        'conductorGrua': conductorGrua,
        'kmGrua': kmGrua,
        'valorGrua': valorGrua,
        'nombreGruaParticular': nombreGruaParticular,
        'telefonoGruaParticular': telefonoGruaParticular,
        'traslado': traslado,
        'tonelaje': tonelaje,
        'tipoCobroParqueo': tipoCobroParqueo,
        'tipoOperativo': tipoOperativo,
        'causaLegal': causaLegal,
        'detalleCausa': detalleCausa,
        'latitud': latitud,
        'longitud': longitud,
        'distritoCircuitoSubcircuito': distritoCircuitoSubcircuito,
        'custodioRecibeNombre': custodioRecibeNombre,
        'policiaNombre': policiaNombre,
        'policiaCedula': policiaCedula,
        'periciaRealizada': periciaRealizada,
        'peritoNombre': peritoNombre,
        'estadoVehiculo': estadoVehiculo,
        'observaciones': observaciones,
        'origen': origen,
        'creado': creado.toIso8601String(),
      };

  factory CasoIngreso.fromJson(Map<String, dynamic> j) => CasoIngreso(
        id: j['id'] ?? '',
        origen: j['origen'] ??
            ((j['id']?.toString().startsWith('seed_') == true ||
                    j['id']?.toString().startsWith('import_') == true)
                ? 'excel'
                : 'app'),
        hojaIngresoNro: j['hojaIngresoNro'] ?? '',
        parteIngresoNro: j['parteIngresoNro'] ?? '',
        fechaIngreso: j['fechaIngreso'] ?? '',
        horaRetencion: j['horaRetencion'] ?? '',
        subzona: j['subzona'] ?? '',
        crv: j['crv'] ?? '',
        placa: j['placa'] ?? '',
        marca: j['marca'] ?? '',
        modelo: j['modelo'] ?? '',
        anioFabricacion: j['anioFabricacion'] ?? '',
        color: j['color'] ?? '',
        tipoVehiculo: j['tipoVehiculo'] ?? '',
        cilindraje: j['cilindraje'] ?? '',
        chasis: j['chasis'] ?? '',
        motor: j['motor'] ?? '',
        numeroOperativo: j['numeroOperativo'] ?? '',
        causaPrincipal: j['causaPrincipal'] ?? '',
        submotivoFalta: j['submotivoFalta'] ?? '',
        autoridadRequirente: j['autoridadRequirente'] ?? '',
        aplicaAlcohotest: j['aplicaAlcohotest'] ?? false,
        numeroPruebaAlcoholemia: j['numeroPruebaAlcoholemia'] ?? '',
        nombreSancionado: j['nombreSancionado'] ?? '',
        cedulaSancionado: j['cedulaSancionado'] ?? '',
        resultadoAlcoholemia: j['resultadoAlcoholemia'] ?? '',
        citacionNro: j['citacionNro'] ?? '',
        rangoAlcoholemia: j['rangoAlcoholemia'] ?? '',
        seNegoPrueba: j['seNegoPrueba'] ?? false,
        ordenPagoAlcohocheckNro: j['ordenPagoAlcohocheckNro'] ?? '',
        valorAlcohocheck: j['valorAlcohocheck'] ?? '',
        propietario: j['propietario'] ?? '',
        cedulaPropietario: j['cedulaPropietario'] ?? '',
        conductor: j['conductor'] ?? '',
        cedulaConductor: j['cedulaConductor'] ?? '',
        placaGrua: j['placaGrua'] ?? '',
        conductorGrua: j['conductorGrua'] ?? '',
        kmGrua: j['kmGrua'] ?? '',
        valorGrua: j['valorGrua'] ?? '',
        nombreGruaParticular: j['nombreGruaParticular'] ?? '',
        telefonoGruaParticular: j['telefonoGruaParticular'] ?? '',
        traslado: j['traslado'] ?? '',
        tonelaje: j['tonelaje'] ?? '',
        tipoCobroParqueo: j['tipoCobroParqueo'] ?? '',
        tipoOperativo: j['tipoOperativo'] ?? 'SIN OPERATIVO',
        causaLegal: j['causaLegal'] ?? '',
        detalleCausa: j['detalleCausa'] ?? '',
        latitud: j['latitud'] ?? '',
        longitud: j['longitud'] ?? '',
        distritoCircuitoSubcircuito: j['distritoCircuitoSubcircuito'] ?? '',
        custodioRecibeNombre: j['custodioRecibeNombre'] ?? '',
        policiaNombre: j['policiaNombre'] ?? '',
        policiaCedula: j['policiaCedula'] ?? '',
        periciaRealizada: j['periciaRealizada'] ?? '',
        peritoNombre: j['peritoNombre'] ?? '',
        estadoVehiculo: j['estadoVehiculo'] ?? '',
        observaciones: j['observaciones'] ?? '',
        creado: DateTime.tryParse(j['creado'] ?? '') ?? DateTime.now(),
      );

  Map<String, String> toPlaceholders() => {
        'HOJA_INGRESO_NRO': hojaIngresoNro,
        'PARTE_INGRESO_NRO': parteIngresoNro,
        'FECHA_INGRESO': fechaIngreso,
        'HORA_RETENCION': horaRetencion,
        'SUBZONA': subzona,
        'CRV': crv,
        'PLACA': placa.toUpperCase(),
        'MARCA': marca,
        'MODELO': modelo,
        'ANIO_FABRICACION': anioFabricacion,
        'COLOR': color,
        'TIPO_VEHICULO': tipoVehiculo,
        'CILINDRAJE': cilindraje,
        'CHASIS': chasis,
        'MOTOR': motor,
        'NUMERO_OPERATIVO': numeroOperativo,
        'CAUSA_PRINCIPAL': causaPrincipal,
        'SUBMOTIVO_FALTA': submotivoFalta,
        'AUTORIDAD_REQUIRENTE': autoridadRequirente,
        'ALCOHOLEMIA_NUMERO_PRUEBA': numeroPruebaAlcoholemia,
        'ALCOHOLEMIA_NOMBRE_SANCIONADO': nombreSancionado,
        'ALCOHOLEMIA_CEDULA_SANCIONADO': cedulaSancionado,
        'ALCOHOLEMIA_RESULTADO': aplicaAlcohotest ? '$resultadoAlcoholemia g/L' : 'N/A',
        'CITACION_NRO': citacionNro,
        'ALCOHOCHECK_ORDEN_PAGO': ordenPagoAlcohocheckNro,
        'ALCOHOCHECK_VALOR': valorAlcohocheck,
        'PROPIETARIO': propietario,
        'CEDULA_PROPIETARIO': cedulaPropietario,
        'CONDUCTOR': conductor,
        'CEDULA_CONDUCTOR': cedulaConductor,
        'KM_GRUA': kmGrua,
        'VALOR_GRUA': valorGrua,
        'NOMBRE_GRUA_PARTICULAR': nombreGruaParticular,
        'TELEFONO_GRUA_PARTICULAR': telefonoGruaParticular,
        'TRASLADO': traslado,
        'TONELAJE': tonelaje,
        'TIPO_COBRO_PARQUEO': tipoCobroParqueo,
        'TIPO_OPERATIVO': tipoOperativo,
        'CAUSA_LEGAL': causaLegal,
        'DETALLE_CAUSA': detalleCausa,
        'LATITUD': latitud,
        'LONGITUD': longitud,
        'DIST_CIRCUITO_SUBCIRCUITO': distritoCircuitoSubcircuito,
        'CUSTODIO_RECIBE': custodioRecibeNombre,
        'POLICIA_NOMBRE': policiaNombre,
        'POLICIA_CEDULA': policiaCedula,
        'PERICIA_REALIZADA': periciaRealizada,
        'PERITO_NOMBRE': peritoNombre,
        'ESTADO_VEHICULO': estadoVehiculo,
        'OBSERVACIONES': observaciones,
      };
}
