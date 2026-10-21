# REGISTROS PRV TRANSITO

Aplicación Flutter (Android y web/PWA) para los Centros de Retención Vehicular (CRV/PRV) de la Policía Nacional del Ecuador. Digitaliza los partes de **ingreso** y **libertad** de vehículos, genera los documentos Word/Excel/PDF oficiales y consolida la información de todos los patios.

## Qué hace

- **Ingreso**: lee el parte (foto o PDF de Ecu911) con IA (Gemini) y, como respaldo sin internet, con extracción de texto; llena el formulario en el orden del SIIPNE 3W.
- **Libertad**: hereda los datos del ingreso y agrega oficio, memorando y pago de garaje.
- **Vehículos en el patio**: lista con estado INGRESADO / LIBERADO, búsqueda por placa, edición y exportación.
- **Informe semanal**: PDF con formato oficial, anexos SIIPNE 3W y firma electrónica (.p12).
- **Matriz Excel** de ingresos y salidas; **calculadora de días** y tarifas.
- **Panel Nacional** (`/admin`, solo web): usuarios, patios y base maestra.

## Roles

| Rol | Alcance |
|---|---|
| Administrador nacional (`esAdmin: true`) | Todo el país |
| Administrador de zona (`rol: admin_zona`) | Solo su zona |
| Policía (`aprobado: true`) | Solo su patio |

Los usuarios nuevos quedan **sin aprobar** hasta que un administrador los apruebe. Los permisos se validan en `firestore.rules`, no en la app.

## Configuración

1. Instalar Flutter (canal estable) y el SDK de Android.
2. `flutter pub get`
3. Firebase (proyecto `patios-de-retencion-vehi-a8ab7`): Authentication (Google y Correo/Contraseña) y Firestore.
4. Publicar reglas e índices: `firebase deploy --only firestore:rules,firestore:indexes`
5. **API key de Gemini**: cada usuario crea la suya gratis en <https://aistudio.google.com/apikey> y la pega en *Ajustes de IA*. No se guarda en el repositorio.

## Compilar

- Android: `flutter build apk --release`
- Web/PWA: `flutter build web --release` y `firebase deploy --only hosting`

## Seguridad (resumen)

- Firestore deniega todo por defecto; cada colección tiene reglas por rol y por patio.
- `historial_ediciones` y `registro_accesos` son inmutables.
- No subir al repositorio: datos reales de partes, cédulas, certificados `.p12`, llaves de firma ni API keys personales.

## Versión

La versión vigente está en `lib/version.dart` y `pubspec.yaml` (deben coincidir; se sube en cada cambio).
