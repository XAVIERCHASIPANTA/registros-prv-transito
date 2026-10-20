import 'dart:html' as html;

/// Versión real para WEB (PWA / navegador, incluido Safari en
/// iPhone). En el navegador no existe una carpeta de documentos como
/// en el APK, así que en vez de escribir a un archivo con dart:io,
/// armamos un Blob en memoria con los bytes del .docx/.pdf y
/// disparamos la descarga con un <a download> temporal — es el
/// equivalente, en el navegador, a "guardar el archivo".
///
/// Este archivo y web_download_stub.dart se seleccionan
/// automáticamente entre sí según la plataforma, mediante el import
/// condicional que hay en storage_service.dart. No hace falta
/// tocarlo ni importarlo manualmente en ningún otro lado.
void descargarBytesEnNavegador(String nombreArchivo, List<int> bytes) {
  final n = nombreArchivo.toLowerCase();
  final mimeType = n.endsWith('.docx')
      ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      : n.endsWith('.xlsx')
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : n.endsWith('.csv')
              ? 'text/csv;charset=utf-8'
              : (n.endsWith('.pdf') ? 'application/pdf' : 'application/octet-stream');
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final html.AnchorElement anchor = html.AnchorElement(href: url)
    ..setAttribute('download', nombreArchivo);
  anchor.click();
  html.Url.revokeObjectUrl(url);
}
