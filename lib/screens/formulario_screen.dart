// RUTA DE ARCHIVO: lib/screens/formulario_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/causa_legal_catalogo.dart';
import '../models/caso_ingreso.dart';
import '../services/docx_builder.dart';
import '../services/storage_service.dart';
import '../widgets/campo_autocompletable.dart';
import 'documento_screen.dart';
import 'home_screen.dart';

void _verTextoOcr(BuildContext context, String? texto) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Texto que reconoció la cámara'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Text(
            (texto == null || texto.trim().isEmpty) ? '(no se reconoció ningún texto)' : texto,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (texto != null && texto.isNotEmpty) {
              await Clipboard.setData(ClipboardData(text: texto));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Texto copiado al portapapeles')),
                );
              }
            }
          },
          child: const Text('Copiar'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    ),
  );
}

// ============================================================
// FORMULARIO: INGRESO
// ============================================================
//
// ORDEN DE SECCIONES (09/sep): replica el orden en que SIIPNE 3W pide
// los datos, tal como indicó Xavier, para evitar tener que saltar de
// un lado a otro y reescribir datos repetidos:
//   1. Tipo operativo
//   2. Fecha de retención
//   3. Hora de retención
//   4. Personal que toma procedimiento (nombre + cédula)
//   5. Propietario (nombre + cédula)
//   6. Conductor (nombre + cédula)
//   7. Causa legal -> Detalle de la causa
//   8. Datos del vehículo (placa, tipo, color, motor, chasis, marca,
//      modelo, año, cilindraje/estado)
//   9. Formulario N° (antes "Hoja de ingreso Nro.")
//  10. N° de Parte Web (Ingreso) (antes "Parte de ingreso Nro.")
//  11. Trasladado por... (sus propios medios / particular / policial)
//  12. Tipo de cobro (tonelaje -> autocompleta liviano/pesado/extrapesado)
//  13. Alcoholemia: Nombres del conductor (auto) / Cédula (auto) /
//      Prueba N° / Resultado / Citación N°
//  14. Personal Policial que Recibe la Custodia (al final)

class FormularioIngresoScreen extends StatefulWidget {
  final CasoIngreso caso;
  final String? textoOcr;
  final bool esEdicion;
  const FormularioIngresoScreen({super.key, required this.caso, this.textoOcr, this.esEdicion = false});

  @override
  State<FormularioIngresoScreen> createState() => _FormularioIngresoScreenState();
}

/// Catálogo de tipos de vehículo del dropdown. Se amplió en la ronda
/// 19: el catálogo viejo (solo 7 palabras) hacía que cualquier tipo
/// que la IA detectara y no calzara EXACTO con una de esas 7 (ej.
/// "Furgón", "Jeep", o hasta "Camion" sin tilde) cayera en silencio
/// al valor por defecto "AUTOMÓVIL" — un dato falso sin que nadie lo
/// notara.
const tiposVehiculoConocidos = [
  'AUTOMÓVIL', 'CAMIONETA', 'CAMIÓN', 'FURGÓN', 'JEEP', 'BUS', 'BUSETA',
  'VAN', 'TRÁILER', 'CABEZAL', 'VOLQUETA', 'TANQUERO', 'MOTOCICLETA',
  'CUATRIMOTO', 'PLATAFORMA', 'GRÚA', 'MIXTO', 'OTRO',
];

/// Convierte lo que devolvió la IA (o lo que diga un parte, tal cual
/// venga escrito: con/sin tilde, mayúsculas/minúsculas, sinónimos) al
/// valor exacto del catálogo de arriba, para que el dropdown lo
/// muestre ya seleccionado en vez de caer a un valor por defecto
/// equivocado. Si de verdad no reconoce ningún tipo, devuelve 'OTRO'
/// — nunca 'AUTOMÓVIL': mejor que quede evidente que hay que
/// revisarlo a mano que dejar un dato falso.
String normalizarTipoVehiculo(String? deteccion) {
  if (deteccion == null || deteccion.trim().isEmpty) return 'OTRO';
  String quitarTildes(String s) => s
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U');
  final limpio = quitarTildes(deteccion.toUpperCase().trim());

  // Sinónimos/variantes comunes en partes policiales que no
  // coinciden letra por letra con el nombre del catálogo.
  const sinonimos = {
    'FURGONETA': 'FURGÓN',
    'FURGON': 'FURGÓN',
    'CAMION': 'CAMIÓN',
    'TRAILER': 'TRÁILER',
    'TRACTOCAMION': 'CABEZAL',
    'PICK UP': 'CAMIONETA',
    'PICKUP': 'CAMIONETA',
    'GRUA': 'GRÚA',
    'MOTO': 'MOTOCICLETA',
  };
  if (sinonimos.containsKey(limpio)) return sinonimos[limpio]!;

  for (final t in tiposVehiculoConocidos) {
    if (quitarTildes(t) == limpio) return t;
  }
  return 'OTRO';
}

const _tiposCobroParqueo = ['LIVIANO', 'PESADO', 'MOTOCICLETA', 'EXTRAPESADO'];

const _tiposTraslado = ['SUS PROPIOS MEDIOS', 'PARTICULAR', 'GRÚA POLICIAL'];

class _FormularioIngresoScreenState extends State<FormularioIngresoScreen> {
  final _formKey = GlobalKey<FormState>();
  late CasoIngreso _caso;

  final _tipoOperativoNroCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();
  final _policiaNombreCtrl = TextEditingController();
  final _policiaCedulaCtrl = TextEditingController();
  final _propietarioCtrl = TextEditingController();
  final _cedulaPropietarioCtrl = TextEditingController();
  final _conductorCtrl = TextEditingController();
  final _cedulaConductorCtrl = TextEditingController();
  final _detalleCausaCtrl = TextEditingController(); // solo se usa para "N° de Orden" (Orden Judicial)
  final _placaCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _motorCtrl = TextEditingController();
  final _chasisCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _cilindrajeCtrl = TextEditingController();
  final _estadoVehiculoCtrl = TextEditingController();
  final _hojaCtrl = TextEditingController(); // "Formulario N°"
  final _parteCtrl = TextEditingController(); // "N° de Parte Web (Ingreso)"
  final _kmGruaCtrl = TextEditingController();
  final _conductorGruaCtrl = TextEditingController();
  final _valorGruaCtrl = TextEditingController();
  final _nombreGruaParticularCtrl = TextEditingController();
  final _telefonoGruaParticularCtrl = TextEditingController();
  final _tonelajeCtrl = TextEditingController();
  final _nombreSancionadoCtrl = TextEditingController();
  final _cedulaSancionadoCtrl = TextEditingController();
  final _numeroPruebaCtrl = TextEditingController();
  final _resultadoAlcoholemiaCtrl = TextEditingController();
  final _citacionCtrl = TextEditingController();
  final _custodioRecibeCtrl = TextEditingController();
  final _subzonaCtrl = TextEditingController();
  final _crvCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  // Autoridad que conoce el caso: se autollena según la causa legal
  // (Accidente de Tránsito -> FISCALÍA, cualquier otra causa -> NO
  // APLICA), pero siempre queda editable a mano.
  final _autoridadRequirenteCtrl = TextEditingController();

  String _tipoVehiculo = 'AUTOMÓVIL';
  // Ronda 20: catálogo de tipos de vehículo QUE SE PUEDE AMPLIAR en
  // tiempo real — arranca con el catálogo fijo (tiposVehiculoConocidos)
  // y le suma cualquier tipo "aprendido" antes (SharedPreferences,
  // mismo espíritu que CampoAutocompletable) más el de este caso en
  // particular si vino con un tipo que la IA detectó y no estaba en
  // ningún lado (ej. "Triciclo") — así el dropdown lo puede mostrar ya
  // seleccionado sin caerse (Dropdown exige que el valor actual esté
  // en la lista de items) y sin perder el dato real.
  List<String> _tiposVehiculoDisponibles = List<String>.from(tiposVehiculoConocidos);
  static const _prefKeyTiposVehiculoAprendidos = 'tipos_vehiculo_aprendidos';
  String _tipoOperativo = 'SIN OPERATIVO';
  String _causaLegal = '';
  String? _detalleCausaSeleccionado;
  String? _tipoCobroParqueo;
  String _traslado = 'SUS PROPIOS MEDIOS';
  bool _aplicaAlcohotest = false;

  bool _guardando = false;

  @override
  
  Future<void> _cargarPerfilAutocompletar() async {
    if (_caso.crv.isEmpty || _caso.subzona.isEmpty) {
      final perfil = await StorageService.obtenerPerfilCompletoUsuario();
      if (mounted) {
        setState(() {
          if (_caso.crv.isEmpty && perfil['patio']?.isNotEmpty == true) {
            _crvCtrl.text = perfil['patio']!;
          }
          if (_caso.subzona.isEmpty && perfil['subzona']?.isNotEmpty == true) {
            _subzonaCtrl.text = perfil['subzona']!;
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarPerfilAutocompletar();
    _caso = widget.caso;

    _tipoOperativoNroCtrl.text = _caso.numeroOperativo;
    // Si es un caso nuevo (no edición) y no vino una fecha ya extraída
    // de fotos/PDF, se autocompleta con la fecha de hoy — el mismo
    // criterio que ya usa Libertad para "Fecha de Salida".
    _fechaCtrl.text = _caso.fechaIngreso.isEmpty && !widget.esEdicion
        ? DateFormat('dd/MM/yyyy').format(DateTime.now())
        : _caso.fechaIngreso;
    _horaCtrl.text = _caso.horaRetencion;
    _policiaNombreCtrl.text = _caso.policiaNombre;
    _policiaCedulaCtrl.text = _caso.policiaCedula;
    _propietarioCtrl.text = _caso.propietario;
    _cedulaPropietarioCtrl.text = _caso.cedulaPropietario;
    _conductorCtrl.text = _caso.conductor;
    _cedulaConductorCtrl.text = _caso.cedulaConductor;
    // "Detalle causa" se reconstruye según la causa legal elegida:
    // si la causa ya trae desplegable, el valor guardado debería ser
    // una de esas opciones; si no, es el N° de Orden que se escribió
    // a mano.
    if (CausaLegalCatalogo.tieneDesplegable(_caso.causaLegal) &&
        (CausaLegalCatalogo.detalles[_caso.causaLegal] ?? []).contains(_caso.detalleCausa)) {
      _detalleCausaSeleccionado = _caso.detalleCausa;
    } else if (_caso.causaLegal != CausaLegalCatalogo.causaAccidenteTransito) {
      _detalleCausaCtrl.text = _caso.detalleCausa;
    }
    _placaCtrl.text = _caso.placa;
    _colorCtrl.text = _caso.color;
    _motorCtrl.text = _caso.motor;
    _chasisCtrl.text = _caso.chasis;
    _marcaCtrl.text = _caso.marca;
    _modeloCtrl.text = _caso.modelo;
    _anioCtrl.text = _caso.anioFabricacion;
    _cilindrajeCtrl.text = _caso.cilindraje;
    _estadoVehiculoCtrl.text = _caso.estadoVehiculo;
    _hojaCtrl.text = _caso.hojaIngresoNro;
    _parteCtrl.text = _caso.parteIngresoNro;
    _kmGruaCtrl.text = _caso.kmGrua;
    _conductorGruaCtrl.text = _caso.conductorGrua;
    _valorGruaCtrl.text = _caso.valorGrua;
    _nombreGruaParticularCtrl.text = _caso.nombreGruaParticular;
    _telefonoGruaParticularCtrl.text = _caso.telefonoGruaParticular;
    _tonelajeCtrl.text = _caso.tonelaje;
    // "Nombres del Conductor"/"Cédula" de Alcoholemia parten
    // precargados con los datos del conductor de arriba (editable, ver
    // _alTocarSwitchAlcoholemia), salvo que ya se hubiera guardado algo
    // distinto para el sancionado en una edición previa.
    _nombreSancionadoCtrl.text = _caso.nombreSancionado.isNotEmpty ? _caso.nombreSancionado : _caso.conductor;
    _cedulaSancionadoCtrl.text = _caso.cedulaSancionado.isNotEmpty ? _caso.cedulaSancionado : _caso.cedulaConductor;
    _numeroPruebaCtrl.text = _caso.numeroPruebaAlcoholemia;
    _resultadoAlcoholemiaCtrl.text = _caso.resultadoAlcoholemia;
    _citacionCtrl.text = _caso.citacionNro;
    _custodioRecibeCtrl.text = _caso.custodioRecibeNombre;
    _subzonaCtrl.text = _caso.subzona;
    _crvCtrl.text = _caso.crv.isEmpty ? (_crvCtrl.text.isNotEmpty ? _crvCtrl.text : 'Control 120') : _caso.crv;
    _observacionesCtrl.text = _caso.observaciones;
    // Si ya hay un valor guardado (caso existente/edición) se respeta
    // tal cual, aunque no coincida con la regla — es editable a mano.
    // Si es un caso nuevo (nunca se guardó nada), se autollena según
    // la causa legal ya cargada arriba.
    _autoridadRequirenteCtrl.text = _caso.autoridadRequirente.isNotEmpty
        ? _caso.autoridadRequirente
        : (_caso.causaLegal == CausaLegalCatalogo.causaAccidenteTransito ? 'FISCALÍA' : 'NO APLICA');

    _tipoVehiculo = _tiposVehiculoDisponibles.contains(_caso.tipoVehiculo)
        ? _caso.tipoVehiculo
        : normalizarTipoVehiculo(_caso.tipoVehiculo);
    // Si el resultado (normalizado o tal cual venía) todavía no está
    // en la lista de opciones (es un tipo nunca visto, ej. "TRICICLO"
    // detectado por la IA), se agrega ya mismo para que el dropdown lo
    // pueda mostrar seleccionado, y se recuerda para los próximos
    // ingresos.
    if (!_tiposVehiculoDisponibles.contains(_tipoVehiculo)) {
      _tiposVehiculoDisponibles.add(_tipoVehiculo);
      _recordarTipoVehiculoSiEsNuevo(_tipoVehiculo);
    }
    _cargarTiposVehiculoAprendidos();
    _tipoOperativo = _caso.tipoOperativo.isEmpty ? 'SIN OPERATIVO' : _caso.tipoOperativo;
    _causaLegal = CausaLegalCatalogo.causas.contains(_caso.causaLegal) ? _caso.causaLegal : '';
    _tipoCobroParqueo = _tiposCobroParqueo.contains(_caso.tipoCobroParqueo) ? _caso.tipoCobroParqueo : null;
    _traslado = _tiposTraslado.contains(_caso.traslado) ? _caso.traslado : 'SUS PROPIOS MEDIOS';
    _aplicaAlcohotest = _caso.aplicaAlcohotest;

    _tonelajeCtrl.addListener(_autocompletarTipoCobro);
  }

  /// Trae los tipos de vehículo "aprendidos" en ingresos anteriores
  /// (ej. "TRICICLO") y los suma a las opciones del dropdown, sin
  /// duplicar los que ya están del catálogo fijo.
  Future<void> _cargarTiposVehiculoAprendidos() async {
    final prefs = await SharedPreferences.getInstance();
    final guardados = prefs.getStringList(_prefKeyTiposVehiculoAprendidos) ?? [];
    if (!mounted) return;
    setState(() {
      for (final t in guardados) {
        if (!_tiposVehiculoDisponibles.contains(t)) _tiposVehiculoDisponibles.add(t);
      }
    });
  }

  /// Guarda un tipo de vehículo nuevo (que no está en el catálogo
  /// fijo) para que la próxima vez ya aparezca como opción — mismo
  /// principio que CampoAutocompletable, pero para el dropdown.
  Future<void> _recordarTipoVehiculoSiEsNuevo(String tipo) async {
    if (tipo.trim().isEmpty || tiposVehiculoConocidos.contains(tipo)) return;
    final prefs = await SharedPreferences.getInstance();
    final guardados = prefs.getStringList(_prefKeyTiposVehiculoAprendidos) ?? [];
    if (!guardados.contains(tipo)) {
      guardados.add(tipo);
      await prefs.setStringList(_prefKeyTiposVehiculoAprendidos, guardados);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _tipoOperativoNroCtrl, _fechaCtrl, _horaCtrl, _policiaNombreCtrl, _policiaCedulaCtrl,
      _propietarioCtrl, _cedulaPropietarioCtrl, _conductorCtrl, _cedulaConductorCtrl, _detalleCausaCtrl,
      _placaCtrl, _colorCtrl, _motorCtrl, _chasisCtrl, _marcaCtrl, _modeloCtrl, _anioCtrl,
      _cilindrajeCtrl, _estadoVehiculoCtrl, _hojaCtrl, _parteCtrl, _kmGruaCtrl, _conductorGruaCtrl, _valorGruaCtrl,
      _nombreGruaParticularCtrl, _telefonoGruaParticularCtrl, _tonelajeCtrl, _nombreSancionadoCtrl,
      _cedulaSancionadoCtrl, _numeroPruebaCtrl, _resultadoAlcoholemiaCtrl, _citacionCtrl,
      _custodioRecibeCtrl, _subzonaCtrl, _crvCtrl, _observacionesCtrl, _autoridadRequirenteCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Tarifario oficial (vigente 2021-2025): Livianos ≤3,5TN, Pesados
  /// 3,51-12TN, Extrapesados >12TN. Motocicletas siempre van aparte,
  /// sin importar el tonelaje.
  void _autocompletarTipoCobro() {
    if (_tipoVehiculo == 'MOTOCICLETA') {
      setState(() => _tipoCobroParqueo = 'MOTOCICLETA');
      return;
    }
    final tonelaje = double.tryParse(_tonelajeCtrl.text.replaceAll(',', '.'));
    if (tonelaje == null) return;
    String nuevo;
    if (tonelaje <= 3.5) {
      nuevo = 'LIVIANO';
    } else if (tonelaje <= 12) {
      nuevo = 'PESADO';
    } else {
      nuevo = 'EXTRAPESADO';
    }
    if (nuevo != _tipoCobroParqueo) setState(() => _tipoCobroParqueo = nuevo);
  }

  /// Al activar el switch de Alcoholemia, se precargan "Nombres del
  /// Conductor"/"Cédula" con lo ya escrito arriba en Conductor — sigue
  /// siendo editable por si la prueba se le hizo a otra persona.
  void _alActivarAlcoholemia(bool activo) {
    setState(() {
      _aplicaAlcohotest = activo;
      if (activo) {
        if (_nombreSancionadoCtrl.text.trim().isEmpty) _nombreSancionadoCtrl.text = _conductorCtrl.text;
        if (_cedulaSancionadoCtrl.text.trim().isEmpty) _cedulaSancionadoCtrl.text = _cedulaConductorCtrl.text;
      }
    });
  }

  void _aplicarCambiosACaso() {
    _caso
      ..hojaIngresoNro = _hojaCtrl.text.trim()
      ..parteIngresoNro = _parteCtrl.text.trim()
      ..fechaIngreso = _fechaCtrl.text.trim()
      ..horaRetencion = _horaCtrl.text.trim()
      ..subzona = _subzonaCtrl.text.trim()
      ..crv = _crvCtrl.text.trim()
      ..placa = _placaCtrl.text.trim()
      ..marca = _marcaCtrl.text.trim()
      ..modelo = _modeloCtrl.text.trim()
      ..anioFabricacion = _anioCtrl.text.trim()
      ..color = _colorCtrl.text.trim()
      ..tipoVehiculo = _tipoVehiculo
      ..cilindraje = _tipoVehiculo == 'MOTOCICLETA' ? _cilindrajeCtrl.text.trim() : ''
      ..chasis = _tipoVehiculo == 'MOTOCICLETA' ? '' : _chasisCtrl.text.trim()
      ..motor = _tipoVehiculo == 'MOTOCICLETA' ? '' : _motorCtrl.text.trim()
      ..numeroOperativo = _tipoOperativo == 'OPERATIVO N°' ? _tipoOperativoNroCtrl.text.trim() : ''
      ..tipoOperativo = _tipoOperativo
      ..aplicaAlcohotest = _aplicaAlcohotest
      ..numeroPruebaAlcoholemia = _aplicaAlcohotest ? _numeroPruebaCtrl.text.trim() : ''
      ..nombreSancionado = _aplicaAlcohotest ? _nombreSancionadoCtrl.text.trim() : ''
      ..cedulaSancionado = _aplicaAlcohotest ? _cedulaSancionadoCtrl.text.trim() : ''
      ..resultadoAlcoholemia = _aplicaAlcohotest ? _resultadoAlcoholemiaCtrl.text.trim() : ''
      ..citacionNro = _aplicaAlcohotest ? _citacionCtrl.text.trim() : ''
      ..propietario = _propietarioCtrl.text.trim()
      ..cedulaPropietario = _cedulaPropietarioCtrl.text.trim()
      ..conductor = _conductorCtrl.text.trim()
      ..cedulaConductor = _cedulaConductorCtrl.text.trim()
      ..traslado = _traslado
      ..kmGrua = _traslado == 'GRÚA POLICIAL' ? _kmGruaCtrl.text.trim() : ''
      ..conductorGrua = _traslado == 'GRÚA POLICIAL' ? _conductorGruaCtrl.text.trim() : ''
      ..autoridadRequirente = _autoridadRequirenteCtrl.text.trim()
      ..valorGrua = _traslado == 'PARTICULAR' ? _valorGruaCtrl.text.trim() : ''
      ..nombreGruaParticular = _traslado == 'PARTICULAR' ? _nombreGruaParticularCtrl.text.trim() : ''
      ..telefonoGruaParticular = _traslado == 'PARTICULAR' ? _telefonoGruaParticularCtrl.text.trim() : ''
      ..tonelaje = _tipoVehiculo == 'MOTOCICLETA' ? '' : _tonelajeCtrl.text.trim()
      ..tipoCobroParqueo = _tipoCobroParqueo ?? ''
      ..causaLegal = _causaLegal
      ..detalleCausa = _causaLegal == CausaLegalCatalogo.causaAccidenteTransito
          ? _causaLegal
          : (CausaLegalCatalogo.tieneDesplegable(_causaLegal)
              ? (_detalleCausaSeleccionado ?? '')
              : _detalleCausaCtrl.text.trim())
      ..custodioRecibeNombre = _custodioRecibeCtrl.text.trim()
      ..policiaNombre = _policiaNombreCtrl.text.trim()
      ..policiaCedula = _policiaCedulaCtrl.text.trim()
      ..estadoVehiculo = _estadoVehiculoCtrl.text.trim()
      ..observaciones = _observacionesCtrl.text.trim();
  }

  /// Antes esto bloqueaba todo el guardado en silencio si faltaba un
  /// campo obligatorio (con el mensaje en rojo fuera de la vista, sin
  /// que se notara). Ahora solo avisa y deja decidir: completar ahora
  /// o guardar igual y completarlo después (útil cuando el vehículo
  /// llega sin todos los datos a mano).
  /// Ronda 23: alerta bloqueante cuando ya existe un Ingreso abierto
  /// (sin Libertad) para esa misma placa — impide guardar un ingreso
  /// duplicado del mismo vehículo mientras sigue en el patio.
  Future<void> _mostrarAlertaIngresoDuplicado(CasoIngreso existente) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vehículo ya ingresado'),
        content: Text(
          'La placa ${existente.placa} ya tiene un Ingreso registrado '
          '(Hoja ${existente.hojaIngresoNro.isEmpty ? "s/n" : existente.hojaIngresoNro}) '
          'que todavía no tiene Libertad. No se puede volver a ingresar '
          'mientras el vehículo siga retenido.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
        ],
      ),
    );
  }

  Future<bool> _puedeContinuar() async {
    final valido = _formKey.currentState!.validate();
    if (valido) return true;
    if (!mounted) return false;
    final continuar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Faltan campos obligatorios'),
        content: const Text(
          'Hay campos obligatorios vacíos (marcados en rojo en el formulario). '
          'Puedes bajar a completarlos ahora, o guardar el avance y llenarlos más tarde.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Completar campos')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar de todas formas')),
        ],
      ),
    );
    return continuar ?? false;
  }

  Future<void> _guardar({bool compartirDespues = false}) async {
    // Ronda 23: el guard de "_guardando" se pone ANTES de cualquier
    // await (antes se ponía después de _puedeContinuar(), que es
    // asíncrono) — un doble-toque rápido alcanzaba a disparar esta
    // función dos veces antes de que el botón se desactivara, y como
    // el vehículo todavía no estaba guardado, ambas llamadas lo
    // agregaban por separado (causa real del ingreso duplicado).
    if (_guardando) return;
    setState(() => _guardando = true);

    if (!await _puedeContinuar()) {
      setState(() => _guardando = false);
      return;
    }

    _aplicarCambiosACaso();
    try {
      await StorageService.guardarCasoIngreso(_caso);
    } on IngresoDuplicadoException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      await _mostrarAlertaIngresoDuplicado(e.ingresoExistente);
      return;
    }

    if (!mounted) return;
    setState(() => _guardando = false);

    if (compartirDespues) {
      await _compartir();
      return;
    }

    if (widget.esEdicion) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caso actualizado')));
      Navigator.pop(context);
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DocumentoScreen(tipo: TipoParte.ingreso)),
      (route) => route.isFirst,
    );
  }

  Future<void> _verVistaPrevia() async {
    // Ronda 23: mismo guard sincrónico que en _guardar() (ver comentario ahí).
    if (_guardando) return;
    setState(() => _guardando = true);

    if (!await _puedeContinuar()) {
      if (mounted) setState(() => _guardando = false);
      return;
    }
    if (!mounted) return;
    _aplicarCambiosACaso();

    final accion = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => _VistaPreviaIngresoScreen(caso: _caso)),
    );
    if (accion == null || !mounted) {
      setState(() => _guardando = false);
      return;
    }

    try {
      await StorageService.guardarCasoIngreso(_caso);
    } on IngresoDuplicadoException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      await _mostrarAlertaIngresoDuplicado(e.ingresoExistente);
      return;
    }
    if (!mounted) return;
    setState(() => _guardando = false);
    
    if (accion == 'descargar_enviar') {
      await _compartir(mensajeWhatsapp: true);
    } else if (accion == 'grabar') {
      if (mounted) {
        if (widget.esEdicion) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DocumentoScreen(tipo: TipoParte.ingreso)),
            (route) => route.isFirst,
          );
        }
      }
    }
  }

  Future<void> _compartir({bool mensajeWhatsapp = false}) async {
    final bytes = StorageService.generarWordIngreso(_caso);
    final nombre = StorageService.obtenerNombreArchivoWord(placa: _caso.placa, esIngreso: true, hojaIngresoNro: _caso.hojaIngresoNro);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: nombre,
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    await Share.shareXFiles(
      [xFile],
      text: mensajeWhatsapp
          ? 'Ingreso ${_caso.placa} - REGISTROS PRV TRANSITO (elige WhatsApp en la bandeja para enviarlo)'
          : 'Ingreso ${_caso.placa} - REGISTROS PRV TRANSITO',
    );
    if (mounted) {
      if (widget.esEdicion) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DocumentoScreen(tipo: TipoParte.ingreso)),
          (route) => route.isFirst,
        );
      }
    }
  }

  Widget _seccion(String titulo, IconData icono, List<Widget> hijos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ...hijos.map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w)),
          ],
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, {int lineas = 1, TextInputType? tipo, bool requerido = false}) {
    return TextFormField(
      controller: ctrl,
      maxLines: lineas,
      keyboardType: tipo,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      validator: requerido ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null : null,
    );
  }

  // Misma página de consulta vehicular (AXIS CRV) que ya se abre desde
  // el botón de la pantalla principal — aquí sirve para que el
  // oficial revise el tonelaje del vehículo antes de llenar el
  // casillero de al lado, sin tener que salir a buscar el link.
  static const _urlConsultaVehiculos = 'https://servicios.axiscloud.ec/CRV/?ps_empresa=02';

  Future<void> _abrirConsultaVehiculos() async {
    final uri = Uri.parse(_urlConsultaVehiculos);
    final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el navegador.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esEdicion ? 'Editar Ingreso' : 'Confirmar datos de Ingreso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copiar texto para Parte Web',
            onPressed: () {
              _aplicarCambiosACaso();
              final texto = DocxBuilder.generarTextoNarrativoIngreso(_caso);
              Clipboard.setData(ClipboardData(text: texto));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Texto para Parte Web copiado al portapapeles'),
                  backgroundColor: Color(0xFF17356E),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.text_snippet_outlined),
            tooltip: 'Ver texto reconocido',
            onPressed: () => _verTextoOcr(context, widget.textoOcr),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          // Bottom extra: evita que el último botón (Guardar) quede
          // tapado por la barra de navegación del sistema (gestos o
          // los 3 botones de Android) — antes el padding era fijo
          // (16) y no consideraba esa barra.
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          children: [
            // 1-3: Tipo operativo / Fecha / Hora de retención. Subzona
            // y CRV se quitaron de la pantalla (Xavier pidió
            // ocultarlos, no borrarlos) — se siguen guardando con lo
            // que ya traían (perfil del usuario / lo último usado) y
            // se usan igual al generar el Word.
            _seccion('Datos del ingreso', Icons.assignment_outlined, [
              DropdownButtonFormField<String>(
                initialValue: _tipoOperativo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo operativo', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'SIN OPERATIVO', child: Text('Sin operativo')),
                  DropdownMenuItem(value: 'OPERATIVO N°', child: Text('Operativo N°')),
                ],
                onChanged: (v) => setState(() => _tipoOperativo = v ?? 'SIN OPERATIVO'),
              ),
              if (_tipoOperativo == 'OPERATIVO N°') _campo(_tipoOperativoNroCtrl, 'Número de operativo'),
              _campo(_fechaCtrl, 'Fecha de retención (dd/mm/aaaa)', requerido: true),
              _campo(_horaCtrl, 'Hora de retención'),
            ]),
            // 4: Personal que toma procedimiento
            _seccion('Personal que toma procedimiento', Icons.local_police_outlined, [
              CampoAutocompletable(
                etiqueta: 'Nombre del policía',
                claveAlmacenamiento: 'ingreso_policia_nombre',
                controller: _policiaNombreCtrl,
              ),
              CampoAutocompletable(
                etiqueta: 'Cédula del policía',
                claveAlmacenamiento: 'ingreso_policia_cedula',
                controller: _policiaCedulaCtrl,
              ),
            ]),
            // 5: Propietario
            _seccion('Propietario', Icons.person_outline, [
              CampoAutocompletable(
                etiqueta: 'Nombre del propietario',
                claveAlmacenamiento: 'ingreso_propietario',
                controller: _propietarioCtrl,
              ),
              CampoAutocompletable(
                etiqueta: 'Cédula del propietario',
                claveAlmacenamiento: 'ingreso_cedula_propietario',
                controller: _cedulaPropietarioCtrl,
              ),
            ]),
            // 6: Conductor
            _seccion('Conductor', Icons.badge_outlined, [
              CampoAutocompletable(
                etiqueta: 'Nombre del conductor',
                claveAlmacenamiento: 'ingreso_conductor',
                controller: _conductorCtrl,
              ),
              CampoAutocompletable(
                etiqueta: 'Cédula del conductor',
                claveAlmacenamiento: 'ingreso_cedula_conductor',
                controller: _cedulaConductorCtrl,
              ),
            ]),
            // 7: Causa legal -> Detalle de la causa (catálogo real de
            // SIIPNE 3W). Según la causa elegida, "Detalle causa"
            // cambia de comportamiento: Accidente de Tránsito no
            // necesita nada más (se autocompleta con la misma causa),
            // Orden Judicial pide el N° de Orden a mano, y el resto
            // muestra su propio desplegable de artículos.
            _seccion('Causa legal', Icons.gavel_outlined, [
              DropdownButtonFormField<String>(
                initialValue: _causaLegal.isEmpty ? null : _causaLegal,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Causa legal', border: OutlineInputBorder(), isDense: true),
                hint: const Text('Seleccione causa'),
                items: CausaLegalCatalogo.causas
                    .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _causaLegal = v ?? '';
                  _detalleCausaSeleccionado = null;
                  _detalleCausaCtrl.clear();
                  _autoridadRequirenteCtrl.text =
                      _causaLegal == CausaLegalCatalogo.causaAccidenteTransito ? 'FISCALÍA' : 'NO APLICA';
                }),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              if (_causaLegal == CausaLegalCatalogo.causaOrdenJudicial)
                _campo(_detalleCausaCtrl, 'N° de Orden', requerido: true)
              else if (CausaLegalCatalogo.tieneDesplegable(_causaLegal))
                DropdownButtonFormField<String>(
                  initialValue: _detalleCausaSeleccionado,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Detalle causa', border: OutlineInputBorder(), isDense: true),
                  hint: const Text('Seleccione opción'),
                  items: (CausaLegalCatalogo.detalles[_causaLegal] ?? [])
                      .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => _detalleCausaSeleccionado = v),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
              // Accidente de Tránsito no muestra nada más: su detalle
              // es la misma causa elegida arriba.
              _campo(_autoridadRequirenteCtrl, 'Autoridad que conoce'),
            ]),
            // 8: Datos del vehículo
            _seccion('Datos del vehículo', Icons.directions_car_outlined, [
              _campo(_placaCtrl, 'Placa', requerido: true),
              DropdownButtonFormField<String>(
                initialValue: _tipoVehiculo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo de vehículo', border: OutlineInputBorder(), isDense: true),
                items: _tiposVehiculoDisponibles
                    .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _tipoVehiculo = v ?? 'AUTOMÓVIL';
                  _autocompletarTipoCobro();
                }),
              ),
              CampoAutocompletable(etiqueta: 'Color', claveAlmacenamiento: 'ingreso_color', controller: _colorCtrl),
              if (_tipoVehiculo == 'MOTOCICLETA')
                CampoAutocompletable(
                  etiqueta: 'Cilindraje (ej. 150cc)',
                  claveAlmacenamiento: 'ingreso_cilindraje',
                  controller: _cilindrajeCtrl,
                )
              else ...[
                _campo(_motorCtrl, 'Motor'),
                _campo(_chasisCtrl, 'Chasis / VIN'),
              ],
              CampoAutocompletable(etiqueta: 'Marca', claveAlmacenamiento: 'ingreso_marca', controller: _marcaCtrl),
              CampoAutocompletable(etiqueta: 'Modelo', claveAlmacenamiento: 'ingreso_modelo', controller: _modeloCtrl),
              _campo(_anioCtrl, 'Año de fabricación'),
              _campo(_estadoVehiculoCtrl, 'Estado físico del vehículo', lineas: 2),
            ]),
            // 9-10: Formulario N° / N° de Parte Web (Ingreso)
            _seccion('Identificación del trámite', Icons.numbers_outlined, [
              _campo(_hojaCtrl, 'Formulario N°', requerido: true),
              _campo(_parteCtrl, 'N° de Parte Web (Ingreso)'),
            ]),
            // 11: Trasladado por...
            _seccion('Trasladado por', Icons.local_shipping_outlined, [
              DropdownButtonFormField<String>(
                initialValue: _traslado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Trasladado por', border: OutlineInputBorder(), isDense: true),
                items: _tiposTraslado.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _traslado = v ?? 'SUS PROPIOS MEDIOS'),
              ),
              if (_traslado == 'GRÚA POLICIAL') ...[
                _campo(_kmGruaCtrl, 'Km. grúa policial'),
                _campo(_conductorGruaCtrl, 'Nombre del conductor de la grúa'),
              ],
              if (_traslado == 'PARTICULAR') ...[
                CampoAutocompletable(
                  etiqueta: 'Nombre de la grúa particular',
                  claveAlmacenamiento: 'ingreso_grua_particular',
                  controller: _nombreGruaParticularCtrl,
                ),
                CampoAutocompletable(
                  etiqueta: 'Teléfono de la grúa',
                  claveAlmacenamiento: 'ingreso_grua_telefono',
                  controller: _telefonoGruaParticularCtrl,
                ),
                _campo(_valorGruaCtrl, 'Valor pagado', tipo: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ]),
            // 12: Tipo de cobro (tonelaje -> autocompleta)
            _seccion('Tipo de cobro', Icons.paid_outlined, [
              if (_tipoVehiculo != 'MOTOCICLETA')
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 90, child: _campo(_tonelajeCtrl, 'TN', tipo: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _abrirConsultaVehiculos,
                      icon: const Icon(Icons.travel_explore),
                      tooltip: 'Consultar tonelaje del vehículo (AXIS CRV)',
                    ),
                  ],
                ),
              DropdownButtonFormField<String>(
                initialValue: _tipoCobroParqueo,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo cobro parqueo',
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText: 'Se sugiere solo según el tonelaje; puedes cambiarlo a mano',
                ),
                items: _tiposCobroParqueo.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _tipoCobroParqueo = v),
              ),
            ]),
            // 13: Alcoholemia (rediseñada)
            _seccion('Alcoholemia', Icons.local_bar_outlined, [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('¿Se realizó prueba de alcoholemia?'),
                value: _aplicaAlcohotest,
                onChanged: _alActivarAlcoholemia,
              ),
              if (_aplicaAlcohotest) ...[
                _campo(_nombreSancionadoCtrl, 'Nombres del conductor'),
                _campo(_cedulaSancionadoCtrl, 'Cédula de ciudadanía'),
                _campo(_numeroPruebaCtrl, 'Prueba N°'),
                _campo(_resultadoAlcoholemiaCtrl, 'Resultado (g/L)', tipo: const TextInputType.numberWithOptions(decimal: true)),
                _campo(_citacionCtrl, 'Citación N°'),
              ],
            ]),
            // 14: Personal Policial que Recibe la Custodia
            _seccion('Personal Policial que Recibe la Custodia', Icons.shield_outlined, [
              CampoAutocompletable(
                etiqueta: 'Recibe la custodia',
                claveAlmacenamiento: 'ingreso_custodio_recibe',
                controller: _custodioRecibeCtrl,
              ),
            ]),
            _seccion('Observaciones', Icons.notes_outlined, [
              _campo(_observacionesCtrl, 'Observaciones', lineas: 3),
            ]),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: _guardando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.visibility_outlined),
              label: Text(_guardando ? 'Procesando...' : 'Vista previa'),
              onPressed: _guardando ? null : _verVistaPrevia,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: Text(widget.esEdicion ? 'Guardar cambios' : 'Guardar avance'),
              onPressed: _guardando ? null : () => _guardar(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista Previa de solo lectura antes de guardar/compartir — mismo
/// patrón que _VistaPreviaLibertadScreen en formulario_libertad_screen.dart.
class _VistaPreviaIngresoScreen extends StatelessWidget {
  final CasoIngreso caso;
  const _VistaPreviaIngresoScreen({required this.caso});

  Widget _fila(String etiqueta, String valor) {
    if (valor.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(text: '$etiqueta: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(String titulo, List<Widget> filas) {
    final visibles = filas.where((w) => w is! SizedBox).toList();
    if (visibles.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            ...filas,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textoParteWeb = DocxBuilder.generarTextoNarrativoIngreso(caso);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista Previa — Ingreso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copiar texto para Parte Web',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: textoParteWeb));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Texto para Parte Web copiado al portapapeles'),
                  backgroundColor: Color(0xFF17356E),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${caso.placa.toUpperCase()} — ${caso.marca} ${caso.color}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 14),
          Card(
            color: const Color(0xFFF0F5FD),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF17356E), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.assignment_outlined, color: Color(0xFF17356E)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Texto Oficial para Parte Web (Circunstancias)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF17356E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFC7D7EE)),
                  const SizedBox(height: 6),
                  SelectableText(
                    textoParteWeb,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF1C2D42),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF17356E),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar texto para Parte Web'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: textoParteWeb));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Texto narrativo copiado! Listo para pegar en Parte Web.'),
                          backgroundColor: Color(0xFF17356E),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _tarjeta('Datos del ingreso', [
            _fila('Tipo operativo', caso.tipoOperativo),
            _fila('Fecha de retención', caso.fechaIngreso),
            _fila('Hora de retención', caso.horaRetencion),
            _fila('CRV', caso.crv),
          ]),
          _tarjeta('Personal que toma procedimiento', [
            _fila('Nombre', caso.policiaNombre),
            _fila('Cédula', caso.policiaCedula),
          ]),
          _tarjeta('Propietario', [
            _fila('Nombre', caso.propietario),
            _fila('Cédula', caso.cedulaPropietario),
          ]),
          _tarjeta('Conductor', [
            _fila('Nombre', caso.conductor),
            _fila('Cédula', caso.cedulaConductor),
          ]),
          _tarjeta('Causa legal', [
            _fila('Causa', caso.causaLegal),
            _fila('Detalle', caso.detalleCausa),
            _fila('Autoridad que conoce', caso.autoridadRequirente),
          ]),
          _tarjeta('Vehículo', [
            _fila('Tipo', caso.tipoVehiculo),
            _fila('Modelo', caso.modelo),
            _fila('Año', caso.anioFabricacion),
            _fila('Chasis', caso.chasis),
            _fila('Motor', caso.motor),
          ]),
          _tarjeta('Identificación del trámite', [
            _fila('Formulario N°', caso.hojaIngresoNro),
            _fila('N° de Parte Web (Ingreso)', caso.parteIngresoNro),
          ]),
          _tarjeta('Trasladado por', [
            _fila('Traslado', caso.traslado),
            _fila('Conductor de la grúa', caso.conductorGrua),
            _fila('Grúa particular', caso.nombreGruaParticular),
          ]),
          _tarjeta('Tipo de cobro', [
            _fila('Tonelaje', caso.tonelaje),
            _fila('Tipo cobro parqueo', caso.tipoCobroParqueo),
          ]),
          if (caso.aplicaAlcohotest)
            _tarjeta('Alcoholemia', [
              _fila('Nombres del conductor', caso.nombreSancionado),
              _fila('Cédula', caso.cedulaSancionado),
              _fila('Prueba N°', caso.numeroPruebaAlcoholemia),
              _fila('Resultado', '${caso.resultadoAlcoholemia} g/L'),
              _fila('Citación N°', caso.citacionNro),
            ]),
          _tarjeta('Personal Policial que Recibe la Custodia', [
            _fila('Recibe la custodia', caso.custodioRecibeNombre),
          ]),
          _tarjeta('Observaciones', [
            _fila('Observaciones', caso.observaciones),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('GRABAR INGRESO'),
            onPressed: () => Navigator.pop(context, 'grabar'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.share_outlined),
            label: const Text('Descargar y enviar'),
            onPressed: () => Navigator.pop(context, 'descargar_enviar'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Volver a editar'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
