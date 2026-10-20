// RUTA DE ARCHIVO: lib/services/terminos_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Términos y condiciones de uso de REGISTROS PRV TRANSITO.
///
/// Si se modifica el texto, SUBIR el número de [version]: a todos los usuarios
/// se les volverá a pedir que acepten la nueva versión al entrar.
class TerminosService {
  static const String version = '2026-10-v1';

  /// Se pone en true cuando la persona marcó la casilla en la pantalla de
  /// inicio de sesión (sirve para guardar la aceptación al crear su perfil).
  static bool aceptadoEnLogin = false;

  static const String titulo = 'Términos y condiciones de uso';

  static const String texto = '''
1. OBJETO
REGISTROS PRV TRANSITO es una herramienta institucional para registrar y consultar el ingreso y la libertad de vehículos en los Centros de Retención Vehicular (CRV). Su uso está limitado a personal autorizado.

2. CUENTA PERSONAL E INTRANSFERIBLE
Su cuenta es personal. Usted es responsable de toda acción realizada con ella y no debe compartirla ni permitir que otra persona la use. El acceso depende de la aprobación de un administrador, quien puede suspenderlo o revocarlo en cualquier momento.

3. USO ADECUADO Y VERACIDAD
Los datos que registre deben ser verdaderos y corresponder a procedimientos reales. Queda prohibido ingresar información falsa, alterar registros sin justificación o usar la información para fines distintos a los institucionales.

4. INFORMACIÓN QUE SE REGISTRA DE SU ACCESO
Al aceptar, usted autoriza expresamente que el sistema registre y conserve, con fines de seguridad, auditoría y control administrativo:
  • Su nombre, correo y patio (CRV) asignado.
  • La dirección IP desde la que accede a la aplicación.
  • El tipo de dispositivo o plataforma, la versión de la aplicación y la fecha y hora de cada inicio de sesión.
  • El historial de registros que crea o modifica (ingresos, libertades e informes).

5. ACCESO A LA INFORMACIÓN
Los datos de ingresos, libertades e informes de todos los centros se almacenan en una base de datos centralizada. Los administradores autorizados pueden consultarlos y extraerlos para fines de gestión, control y estadística institucional. Cada policía solo puede ver los datos de su propio patio.

6. CONFIDENCIALIDAD Y PROTECCIÓN DE DATOS
La información de personas y vehículos es reservada. Usted se compromete a mantener su confidencialidad y a no divulgarla fuera de los canales oficiales, conforme a la normativa vigente sobre protección de datos personales en el Ecuador.

7. FIRMA ELECTRÓNICA
Si carga un certificado de firma electrónica (.p12), éste se almacena únicamente en su dispositivo. La clave del certificado no se guarda en ningún momento.

8. INCUMPLIMIENTO
El uso indebido de la aplicación o de la información puede causar la suspensión del acceso y las acciones administrativas o legales que correspondan.

9. ACEPTACIÓN
Al marcar la casilla y continuar, usted declara haber leído y aceptado estos términos, incluida la autorización de registro de su dirección IP y de su actividad descrita en el numeral 4.
''';

  /// Guarda la aceptación en el perfil del usuario (cuando ya existe).
  static Future<void> registrarAceptacion(String uid) async {
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'terminosAceptados': true,
      'terminosVersion': version,
      'terminosFecha': FieldValue.serverTimestamp(),
    });
  }
}
