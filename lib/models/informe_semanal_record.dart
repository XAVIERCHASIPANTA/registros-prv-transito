/// Modelo de datos para registrar en el historial cada Informe Semanal generado.
class InformeSemanalRecord {
  final String id;
  final String oficioNro;
  final String fechaOficio;
  final String patio;
  final String jefatura;
  final String subzona;
  final String subzonaAbrev;
  final String semanaLunes;
  final String semanaDomingo;
  final int vehiculosCount;
  final int motocicletasCount;
  final int totalLiberaciones;
  final int fojasCount;
  final String firmanteNombre;
  final String firmanteRango;
  final String firmanteCedula;
  final bool estaFirmadoDigitalmente;
  final DateTime fechaGeneracion;
  final String pdfPath;

  InformeSemanalRecord({
    required this.id,
    required this.oficioNro,
    required this.fechaOficio,
    required this.patio,
    required this.jefatura,
    required this.subzona,
    required this.subzonaAbrev,
    required this.semanaLunes,
    required this.semanaDomingo,
    required this.vehiculosCount,
    required this.motocicletasCount,
    required this.totalLiberaciones,
    required this.fojasCount,
    required this.firmanteNombre,
    required this.firmanteRango,
    this.firmanteCedula = '',
    required this.estaFirmadoDigitalmente,
    required this.fechaGeneracion,
    this.pdfPath = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'oficioNro': oficioNro,
        'fechaOficio': fechaOficio,
        'patio': patio,
        'jefatura': jefatura,
        'subzona': subzona,
        'subzonaAbrev': subzonaAbrev,
        'semanaLunes': semanaLunes,
        'semanaDomingo': semanaDomingo,
        'vehiculosCount': vehiculosCount,
        'motocicletasCount': motocicletasCount,
        'totalLiberaciones': totalLiberaciones,
        'fojasCount': fojasCount,
        'firmanteNombre': firmanteNombre,
        'firmanteRango': firmanteRango,
        'firmanteCedula': firmanteCedula,
        'estaFirmadoDigitalmente': estaFirmadoDigitalmente,
        'fechaGeneracion': fechaGeneracion.toIso8601String(),
        'pdfPath': pdfPath,
      };

  factory InformeSemanalRecord.fromJson(Map<String, dynamic> json) => InformeSemanalRecord(
        id: json['id'] as String? ?? '',
        oficioNro: json['oficioNro'] as String? ?? '',
        fechaOficio: json['fechaOficio'] as String? ?? '',
        patio: json['patio'] as String? ?? '',
        jefatura: json['jefatura'] as String? ?? '',
        subzona: json['subzona'] as String? ?? '',
        subzonaAbrev: json['subzonaAbrev'] as String? ?? '',
        semanaLunes: json['semanaLunes'] as String? ?? '',
        semanaDomingo: json['semanaDomingo'] as String? ?? '',
        vehiculosCount: json['vehiculosCount'] as int? ?? 0,
        motocicletasCount: json['motocicletasCount'] as int? ?? 0,
        totalLiberaciones: json['totalLiberaciones'] as int? ?? 0,
        fojasCount: json['fojasCount'] as int? ?? 0,
        firmanteNombre: json['firmanteNombre'] as String? ?? '',
        firmanteRango: json['firmanteRango'] as String? ?? '',
        firmanteCedula: json['firmanteCedula'] as String? ?? '',
        estaFirmadoDigitalmente: json['estaFirmadoDigitalmente'] as bool? ?? false,
        fechaGeneracion: json['fechaGeneracion'] != null
            ? DateTime.tryParse(json['fechaGeneracion'] as String) ?? DateTime.now()
            : DateTime.now(),
        pdfPath: json['pdfPath'] as String? ?? '',
      );
}
