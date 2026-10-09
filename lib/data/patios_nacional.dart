// Base de datos oficial de Centros de Retención Vehicular (CRV) a nivel nacional
// Fuente: documento oficial de la Dirección Nacional de Control de Tránsito y Seguridad Vial
// Zona 8: sin CRV registrados actualmente (no existe PRV en esa zona)

class Patio {
  final String zona;
  final String jefatura; // Jefatura o Subjefatura. Puede venir vacío (ver Zona 5 - Guayas).
  final String crv; // Nombre del CRV. Puede venir vacío (pendiente de completar).

  const Patio({
    required this.zona,
    required this.jefatura,
    required this.crv,
  });
}

const List<Patio> patiosNacional = [
  // ZONA 1
  Patio(zona: 'ZONA 1', jefatura: 'JEFATURA PROVINCIAL DE ESMERALDAS', crv: 'CRV ESMERALDAS'),
  Patio(zona: 'ZONA 1', jefatura: 'SUBJEFATURA DE QUININDE', crv: 'CRV LA MARUJITA'),
  Patio(zona: 'ZONA 1', jefatura: 'JEFATURA PROVINCIAL DE IMBABURA', crv: 'CRV YUYUCOCHA'),
  Patio(zona: 'ZONA 1', jefatura: 'SUBJEFATURA DE OTAVALO', crv: 'CRV OTAVALO'),
  Patio(zona: 'ZONA 1', jefatura: 'JEFATURA PROVINCIAL DEL CARCHI', crv: 'CRV TULCÁN'),
  Patio(zona: 'ZONA 1', jefatura: 'SUBJEFATURA DE SAN GABRIEL', crv: 'CRV MONTUFAR (SAN GABRIEL)'),
  Patio(zona: 'ZONA 1', jefatura: 'JEFATURA PROVINCIAL DE SUCUMBIOS', crv: 'CRV LAGO AGRIO'),
  Patio(zona: 'ZONA 1', jefatura: 'JEFATURA PROVINCIAL DE SUCUMBIOS', crv: 'CRV SHUSHUFINDI'),
  Patio(zona: 'ZONA 1', jefatura: 'JEFATURA PROVINCIAL DE SUCUMBIOS', crv: 'CRV PTO. EL CARMEN'),
  Patio(zona: 'ZONA 1', jefatura: 'JEFATURA PROVINCIAL DE SUCUMBIOS', crv: 'CRV TARAPOA'),
  Patio(zona: 'ZONA 1', jefatura: 'JEFATURA PROVINCIAL DE SUCUMBIOS', crv: 'CRV SANSAHUARI'),

  // ZONA 2
  Patio(zona: 'ZONA 2', jefatura: 'JEFATURA PROVINCIAL DE PICHINCHA', crv: ''), // pendiente de completar
  Patio(zona: 'ZONA 2', jefatura: 'SUBJEFATURA CAYAMBE', crv: 'CRV CAYAMBE'),
  Patio(zona: 'ZONA 2', jefatura: 'SUBJEFATURA DE PUERTO QUITO', crv: 'CRV NOROCCIDENTE'),
  Patio(zona: 'ZONA 2', jefatura: 'SUBJEFATURA DE RUMIÑAHUI', crv: 'CRV RUMIÑAHUI'),
  Patio(zona: 'ZONA 2', jefatura: 'SUBJEFATURA MEJIA', crv: 'CRV MEJIA'),
  Patio(zona: 'ZONA 2', jefatura: 'JEFATURA DEL NAPO', crv: 'CRV TENA'),
  Patio(zona: 'ZONA 2', jefatura: 'JEFATURA DEL NAPO', crv: 'CRV CHACO'),
  Patio(zona: 'ZONA 2', jefatura: 'JEFATURA DE ORELLANA', crv: 'CRV ORELLANA'),
  Patio(zona: 'ZONA 2', jefatura: 'JEFATURA DE ORELLANA', crv: 'CRV SACHA'),

  // ZONA 3
  Patio(zona: 'ZONA 3', jefatura: 'JEFATURA PROVINCIAL DE COTOPAXI', crv: 'CRV LATACUNGA'),
  Patio(zona: 'ZONA 3', jefatura: 'SUBJEFATURA DE LA MANA', crv: 'CRV LA MANA'),
  Patio(zona: 'ZONA 3', jefatura: 'JEFATURA PROVINCIAL DE TUNGURAHUA', crv: 'CRV SAN VICENTE'),
  Patio(zona: 'ZONA 3', jefatura: 'SUBJEFATURA DE SAN PEDRO DE PELILEO', crv: 'CRV SAN PEDRO DE PELILEO'),
  Patio(zona: 'ZONA 3', jefatura: 'JEFATURA PROVINCIAL DE CHIMBORAZO', crv: 'CRV RIOBAMBA'),
  Patio(zona: 'ZONA 3', jefatura: 'SUBJEFATURA DE ALAUSI', crv: 'CRV ALAUSI'),
  Patio(zona: 'ZONA 3', jefatura: 'JEFATURA PROVINCIAL DE PASTAZA', crv: 'CRV PASTAZA'),

  // ZONA 4
  Patio(zona: 'ZONA 4', jefatura: 'JEFATURA PROVINCIAL DE PORTOVIEJO', crv: 'CRV PORTOVIEJO'),
  Patio(zona: 'ZONA 4', jefatura: 'JEFATURA PROVINCIAL DE PORTOVIEJO', crv: 'CRV JOCAY MANTA'),
  Patio(zona: 'ZONA 4', jefatura: 'SUBJEFATURA DE BAHIA DE CARAQUEZ', crv: 'CRV BAHIA'),
  Patio(zona: 'ZONA 4', jefatura: 'SUBJEFATURA DE CHONE', crv: 'CRV CHONE'),
  Patio(zona: 'ZONA 4', jefatura: 'SUBJEFATURA DE EL CARMEN', crv: 'CRV EL CARMEN'),
  Patio(zona: 'ZONA 4', jefatura: 'SUBJEFATURA DE PICHINCHA', crv: 'CRV PICHINCHA'),
  Patio(zona: 'ZONA 4', jefatura: 'SUBJEFATURA DE PEDERNALES', crv: 'CRV ACHIOTE PEDERNALES'),
  Patio(zona: 'ZONA 4', jefatura: 'SUBJEFATURA DE PEDERNALES', crv: 'CRV JAMA'),
  Patio(zona: 'ZONA 4', jefatura: 'SUBJEFATURA DE JIPIJAPA', crv: 'CRV JIPIJAPA'),
  Patio(zona: 'ZONA 4', jefatura: 'SUBJEFATURA DE JIPIJAPA', crv: 'CRV GUANABANO'),
  Patio(zona: 'ZONA 4', jefatura: 'STO. DOMINGO DE LOS TSACHILAS', crv: 'CRV BURNEO'),
  Patio(zona: 'ZONA 4', jefatura: 'STO. DOMINGO DE LOS TSACHILAS', crv: 'CRV CONTROL 120'),

  // ZONA 5
  Patio(zona: 'ZONA 5', jefatura: 'JEFATURA PROVINCIAL DE GALAPAGOS', crv: 'CRV SAN CRISTOBAL'),
  Patio(zona: 'ZONA 5', jefatura: 'SUBJEFATURA DE SANTA CRUZ', crv: 'CRV SANTA CRUZ'),
  Patio(zona: 'ZONA 5', jefatura: 'JEFATURA PROVINCIAL DE LOS RIOS', crv: 'CRV BABAHOYO'),
  Patio(zona: 'ZONA 5', jefatura: 'JEFATURA PROVINCIAL DE LOS RIOS', crv: 'CRV VENTANAS'),
  Patio(zona: 'ZONA 5', jefatura: 'JEFATURA PROVINCIAL DE LOS RIOS', crv: 'CRV VINCES'),
  Patio(zona: 'ZONA 5', jefatura: 'SUBJEFATURA DE QUEVEDO', crv: 'CRV QUEVEDO'),
  Patio(zona: 'ZONA 5', jefatura: 'JEFATURA PROVINCIAL DE BOLIVAR', crv: 'CRV LAGUACOTO'),
  Patio(zona: 'ZONA 5', jefatura: 'SUBJEFATURA PROVINCIAL DE CHIMBO', crv: 'CRV CHIMBO'),
  // Guayas: sin jefatura propia asignada en la base oficial, se deja directo (zona -> CRV)
  Patio(zona: 'ZONA 5', jefatura: '', crv: 'CRV NARANJAL'),
  Patio(zona: 'ZONA 5', jefatura: '', crv: 'CRV EMPALME-BALZAR'),
  Patio(zona: 'ZONA 5', jefatura: '', crv: 'CRV MILAGRO - YAGUACHI'),
  Patio(zona: 'ZONA 5', jefatura: '', crv: 'CRV SANTA LUCIA-DAULE'),

  // ZONA 6
  Patio(zona: 'ZONA 6', jefatura: 'JEFATURA PROVINCIAL DE CAÑAR', crv: 'CRV AZOGUES'),
  Patio(zona: 'ZONA 6', jefatura: 'SUBJEFATURA DEL CANTÓN CAÑAR', crv: 'CRV CAÑAR'),
  Patio(zona: 'ZONA 6', jefatura: 'SUBJEFATURA DE LA TRÓNCAL', crv: 'CRV TRONCAL'),
  Patio(zona: 'ZONA 6', jefatura: 'SUBJEFATURA DE GIRON', crv: 'CRV GIRÓN'),
  Patio(zona: 'ZONA 6', jefatura: 'SUBJEFATURA DE GUALACEO', crv: 'CRV GUALACEO'),
  Patio(zona: 'ZONA 6', jefatura: 'SUBJEFATURA DE PAUTE', crv: 'CRV PAUTE'),
  Patio(zona: 'ZONA 6', jefatura: 'JEFATURA PROVINCIAL DE MORONA SANTIAGO', crv: 'CRV MORONA SANTIAGO'),

  // ZONA 7
  Patio(zona: 'ZONA 7', jefatura: 'JEFATURA PROVINCIAL DE EL ORO', crv: 'CRV MACHALA'),
  Patio(zona: 'ZONA 7', jefatura: 'JEFATURA PROVINCIAL DE EL ORO', crv: 'CRV PASAJE'),
  Patio(zona: 'ZONA 7', jefatura: 'SUBJEFATURA DE HUAQUILLAS', crv: 'CRV HUAQUILLAS'),
  Patio(zona: 'ZONA 7', jefatura: 'SUBJEFATURA DE HUAQUILLAS', crv: 'CRV EL GUABO'),
  Patio(zona: 'ZONA 7', jefatura: 'SUBJEFATURA DE PIÑAS', crv: 'CRV PIÑAS'),
  Patio(zona: 'ZONA 7', jefatura: 'SUBJEFATURA DE PIÑAS', crv: 'CRV STA. ROSA'),
  Patio(zona: 'ZONA 7', jefatura: 'SUBJEFATURA DE ZARUMA', crv: 'CRV ZARUMA'),
  Patio(zona: 'ZONA 7', jefatura: 'JEFATURA PROVINCIAL DE LOJA', crv: 'CRV SARAGURO'),
  Patio(zona: 'ZONA 7', jefatura: 'JEFATURA PROVINCIAL DE LOJA', crv: 'CRV ESPINDOLA'),
  Patio(zona: 'ZONA 7', jefatura: 'JEFATURA PROVINCIAL DE LOJA', crv: 'CRV CATACOCHA'),
  Patio(zona: 'ZONA 7', jefatura: 'JEFATURA PROVINCIAL DE LOJA', crv: 'CRV ZAPOTILLO'),
  Patio(zona: 'ZONA 7', jefatura: 'JEFATURA PROVINCIAL DE LOJA', crv: 'CRV CARIAMANGA CALVAS'),
  Patio(zona: 'ZONA 7', jefatura: 'JEFATURA PROVINCIAL DE LOJA', crv: 'CRV MACARA'),
  Patio(zona: 'ZONA 7', jefatura: 'JEFATURA PROVINCIAL DE LOJA', crv: 'CRV CATAMAYO'),
  Patio(zona: 'ZONA 7', jefatura: 'SUBJEFATURA DE TRANSITO ALAMOR', crv: 'CRV ALAMOR'),
  Patio(zona: 'ZONA 7', jefatura: 'JEFATURA PROVINCIAL DE ZAMORA', crv: 'CRV ZAMORA'),

  // ZONA 8: sin CRV registrados actualmente

  // ZONA 9
  Patio(zona: 'ZONA 9', jefatura: 'DMQ - UCTSV', crv: 'CRV NORTE-CALDERON'),
  Patio(zona: 'ZONA 9', jefatura: 'DMQ - UCTSV', crv: 'CRV SUR-ELOY ALFARO'),
];

/// Lista de zonas disponibles para el primer desplegable (en orden).
List<String> obtenerZonas() {
  final zonas = patiosNacional.map((p) => p.zona).toSet().toList();
  zonas.sort();
  return zonas;
}

/// Lista de jefaturas/subjefaturas de una zona, para el segundo desplegable.
/// Si una zona tiene entradas sin jefatura (ej. Guayas), esas van directo
/// como CRV en el tercer desplegable sin pasar por este paso.
List<String> obtenerJefaturas(String zona) {
  final jefaturas = patiosNacional
      .where((p) => p.zona == zona && p.jefatura.isNotEmpty)
      .map((p) => p.jefatura)
      .toSet()
      .toList();
  jefaturas.sort();
  return jefaturas;
}

/// CRV disponibles dado zona + jefatura (para el tercer desplegable).
List<String> obtenerCrv(String zona, String jefatura) {
  return patiosNacional
      .where((p) => p.zona == zona && p.jefatura == jefatura)
      .map((p) => p.crv)
      .where((c) => c.isNotEmpty)
      .toList();
}

/// CRV que cuelgan directo de la zona sin jefatura (caso Guayas en Zona 5).
List<String> obtenerCrvDirectosDeZona(String zona) {
  return patiosNacional
      .where((p) => p.zona == zona && p.jefatura.isEmpty)
      .map((p) => p.crv)
      .where((c) => c.isNotEmpty)
      .toList();
}

/// Busca un Patio de la lista nacional dado el nombre o un substring del CRV/Jefatura.
Patio? buscarPatioPorNombre(String nombre) {
  if (nombre.trim().isEmpty) return null;
  final n = nombre.trim().toLowerCase();
  for (final p in patiosNacional) {
    if (p.crv.toLowerCase() == n || (p.crv.isNotEmpty && n.contains(p.crv.toLowerCase()))) {
      return p;
    }
  }
  for (final p in patiosNacional) {
    if (p.jefatura.toLowerCase() == n || (p.jefatura.isNotEmpty && n.contains(p.jefatura.toLowerCase()))) {
      return p;
    }
  }
  return null;
}
