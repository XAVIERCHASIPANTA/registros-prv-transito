// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Intenta invocar el evento nativo del navegador 'beforeinstallprompt'
/// para instalar la PWA directamente en el teléfono o PC.
bool intentarInstalarPWA() {
  try {
    final res = js.context.callMethod('instalarPWA');
    return res == true;
  } catch (_) {
    return false;
  }
}
