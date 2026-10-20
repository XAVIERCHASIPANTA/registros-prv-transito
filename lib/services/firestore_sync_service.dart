import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import '../models/informe_semanal_record.dart';

/// Sube y gestiona la sincronización con Firestore de casos nacionales e informes semanales.
class FirestoreSyncService {
  final _firestore = FirebaseFirestore.instance;

  /// Zona del usuario actual (se agrega a cada caso para que el administrador
  /// de zona pueda filtrar). Si falla, devuelve ''.
  Future<String> _zonaDelUsuario() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return '';
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      return (doc.data()?['zona'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> subirIngreso(CasoIngreso c, {required String patio}) async {
    try {
      final zona = await _zonaDelUsuario();
      await _firestore.collection('casos_nacionales').doc('ingreso_${c.id}').set({
        'tipo': 'ingreso',
        'patio': patio,
        'zona': zona,
        ...c.toJson(),
        'actualizado': FieldValue.serverTimestamp(),
      });

      if (c.placa.isNotEmpty) {
        await _firestore.collection('consulta_publica').doc(c.placa.toUpperCase()).set({
          'placa': c.placa.toUpperCase(),
          'marca': c.marca,
          'color': c.color,
          'estado': 'RETENIDO',
          'patio': patio,
          'actualizado': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> subirLibertad(CasoLibertad c, {required String patio}) async {
    try {
      final zona = await _zonaDelUsuario();
      await _firestore.collection('casos_nacionales').doc('libertad_${c.id}').set({
        'tipo': 'libertad',
        'patio': patio,
        'zona': zona,
        ...c.toJson(),
        'actualizado': FieldValue.serverTimestamp(),
      });

      if (c.placa.isNotEmpty) {
        await _firestore.collection('consulta_publica').doc(c.placa.toUpperCase()).set({
          'placa': c.placa.toUpperCase(),
          'marca': c.marca,
          'color': c.color,
          'estado': 'LIBERADO',
          'patio': patio,
          'actualizado': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  Future<void> subirInformeSemanal(InformeSemanalRecord record, {required String patio}) async {
    try {
      final zona = await _zonaDelUsuario();
      await _firestore.collection('informes_semanales_nacionales').doc(record.id).set({
        'patio': patio,
        'zona': zona,
        ...record.toJson(),
        'actualizado': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<List<CasoIngreso>> obtenerIngresos(String patio) async {
    final query = await _firestore
        .collection('casos_nacionales')
        .where('tipo', isEqualTo: 'ingreso')
        .where('patio', isEqualTo: patio)
        .orderBy('creado')
        .get(const GetOptions(source: Source.server));

    return query.docs.map((d) => CasoIngreso.fromJson(d.data())).toList();
  }

  Future<List<CasoLibertad>> obtenerLibertades(String patio) async {
    final query = await _firestore
        .collection('casos_nacionales')
        .where('tipo', isEqualTo: 'libertad')
        .where('patio', isEqualTo: patio)
        .orderBy('creado')
        .get(const GetOptions(source: Source.server));

    return query.docs.map((d) => CasoLibertad.fromJson(d.data())).toList();
  }

  Future<void> registrarEdicion({
    required String tipo,
    required String casoId,
    required String placa,
    required String patio,
  }) async {
    try {
      final zona = await _zonaDelUsuario();
      await _firestore.collection('historial_ediciones').add({
        'zona': zona,
        'tipo': tipo,
        'casoId': casoId,
        'placa': placa,
        'patio': patio,
        'editadoEn': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
