import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_usuarios_screen.dart';
import 'captura_screen.dart';
import 'documento_screen.dart';
import 'ajustes_screen.dart';
import 'buscar_placa_screen.dart';
import 'informe_semanal_screen.dart';
import 'pdfs_guardados_screen.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';

enum TipoParte { ingreso, libertad }

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _exportarExcelMasivo(BuildContext context) async {
    try {
      final bytes = await StorageService.generarExcelConsolidado();
      if (bytes == null || bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay información suficiente para generar la matriz Excel.')),
          );
        }
        return;
      }

      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: 'REPORTE_MATRIZ_PATIO_2026.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      await Share.shareXFiles([xFile], text: 'Matriz Consolidada de Registros de Patio 2026 (.xlsx)');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar la matriz Excel: $e')),
        );
      }
    }
  }

  // Abre la página externa de consulta de vehículos (AXIS CRV). Es un
  // formulario de búsqueda por placa/VIN/motor; no tiene una URL de
  // consulta directa por parámetros, así que solo se abre en el
  // navegador — el oficial busca la placa manualmente ahí.
  static const _urlConsultaVehiculos = 'https://servicios.axiscloud.ec/CRV/?ps_empresa=02';

  Future<void> _abrirConsultaVehiculos(BuildContext context) async {
    final uri = Uri.parse(_urlConsultaVehiculos);
    final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el navegador.')),
      );
    }
  }

  Widget _botonAdminSiCorresponde() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final esAdmin = snapshot.data?.data()?['esAdmin'] == true;
        if (!esAdmin) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.admin_panel_settings),
          tooltip: 'Panel Nacional',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminUsuariosScreen()),
            );
          },
        );
      },
    );
  }

  // NUEVO (30/ago): muestra "PRV [nombre del patio]" debajo del sello,
  // leyendo en vivo el campo 'patio' que guarda identificacion_screen.dart
  // en Firestore (colección "usuarios"). Es el nombre bautizado que esa
  // cuenta le puso a su matriz (ej. "Control 120" → "PRV CONTROL 120").
  Widget _nombrePatio() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final patio = (snapshot.data?.data()?['patio'] as String?)?.trim();
        if (patio == null || patio.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'PRV ${patio.toUpperCase()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('REGISTROS PRV TRANSITO'),
        backgroundColor: const Color(0xFF17356E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          _botonAdminSiCorresponde(),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes de IA',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AjustesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => AuthService().cerrarSesion(),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
        decoration: const BoxDecoration(
          // 01/sep: degradado azul institucional aprobado por Xavier
          // (inspirado en la app oficial SIIPNE Móvil) — NO CAMBIAR sin
          // que lo pida explícitamente, ya pasó por varias iteraciones.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF17356E), Color(0xFF1C4488)],
          ),
        ),
        child: Stack(
          children: [
            // Marca de agua sutil del sello institucional en la esquina
            // inferior derecha, inspirada en la app oficial SIIPNE Móvil.
            Positioned(
              right: -30,
              bottom: -30,
              child: Opacity(
                // 02/sep: reemplazado assets/logo.png por assets/sello_prv.png
                // — el sello oficial real que Xavier subió, ya recortado y
                // sin fondo (antes assets/logo.png era un genérico). Opacidad
                // en 0.14 para que se note sutil sobre el degradado azul.
                opacity: 0.14,
                child: Image.asset('assets/sello_prv.png', width: 220, height: 220),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // 23/sep: se quitó el bloque de texto "CONTROL Y GESTIÓN
                    // DE / PATIOS DE RETENCIÓN VEHICULAR ECUADOR / En un
                    // solo lugar" — Xavier lo pidió eliminar por quedar
                    // repetido con el texto que ya trae el propio logo.
                    Image.asset('assets/logo.png', height: 190),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 26, height: 3, color: const Color(0xFFE8B62C)),
                        const SizedBox(width: 5),
                        Container(width: 26, height: 3, color: const Color(0xFF5BA3F5)),
                        const SizedBox(width: 5),
                        Container(width: 26, height: 3, color: const Color(0xFFC0392B)),
                      ],
                    ),
                    _nombrePatio(),
                    const SizedBox(height: 28),
                    _BotonPrincipal(
                      icono: Icons.login,
                      titulo: 'INGRESO',
                      subtitulo: 'Registrar el ingreso de un vehículo al CRV',
                      // 01/sep: Ingreso = ROJO (antes verde) — confirmado por Xavier
                      color: Colors.red.shade700,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CapturaScreen(tipo: TipoParte.ingreso),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _BotonPrincipal(
                      icono: Icons.logout,
                      // Ronda 23: "LIBERTAD" no tenía mucho sentido como
                      // rótulo porque abajo ya existía la tarjeta "Ver
                      // libertades" — Xavier pidió renombrarlo a "BUSCAR
                      // VEHÍCULOS EN EL PATIO" (mismo botón, mismo color,
                      // misma función y mismo destino de siempre:
                      // BuscarPlacaScreen, donde está "Liberar vehículo").
                      titulo: 'BUSCAR VEHÍCULOS EN EL PATIO',
                      subtitulo: 'Registrar la devolución / libertad de un vehículo',
                      // 01/sep: Libertad = VERDE (antes naranja) — confirmado por Xavier. Se mantiene el verde.
                      color: Colors.green.shade700,
                      // 02/sep: BUG CORREGIDO — este botón mandaba a CapturaScreen()
                      // (la MISMA pantalla de escanear un Ingreso nuevo), así que
                      // tocar "LIBERTAD" en realidad iniciaba un Ingreso, no una
                      // Libertad. El flujo real de Libertad en esta app siempre
                      // parte de buscar el Ingreso ya existente (para heredar sus
                      // datos), así que este botón ahora manda directo a
                      // "Buscar por placa", donde ya existe el botón funcional
                      // "Liberar vehículo" junto a cada caso sin libertad.
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BuscarPlacaScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 02/sep: reemplazo de los 6 botones "planos" por tarjetas
                    // de vidrio translúcido en grilla 2 columnas — es el pedido
                    // original de Xavier (Imagen 1 del mockup) que se había
                    // quedado pendiente. El fondo degradado azul del Scaffold
                    // NO se toca; estas tarjetas solo van encima con
                    // BackdropFilter + opacidad baja para el efecto vidrio.
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                      children: [
                        // Ronda 23: se quitó la tarjeta "Buscar placa" de
                        // aquí — quedaba redundante porque el botón verde
                        // grande de arriba ("BUSCAR VEHÍCULOS EN EL
                        // PATIO") ya manda exactamente a la misma pantalla
                        // (BuscarPlacaScreen).
                        _TarjetaVidrio(
                          icono: Icons.travel_explore,
                          colorIcono: Colors.tealAccent,
                          titulo: 'Consultar info',
                          onTap: () => _abrirConsultaVehiculos(context),
                        ),
                        _TarjetaVidrio(
                          icono: Icons.table_chart_outlined,
                          colorIcono: Colors.purpleAccent,
                          titulo: 'Generar Excel',
                          onTap: () => _exportarExcelMasivo(context),
                        ),
                        _TarjetaVidrio(
                          icono: Icons.summarize_outlined,
                          colorIcono: Colors.orangeAccent,
                          titulo: 'Generar Informe Semanal',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const InformeSemanalScreen()),
                          ),
                        ),
                        _TarjetaVidrio(
                          icono: Icons.description_outlined,
                          colorIcono: Colors.grey.shade300,
                          titulo: 'Ver ingresos',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DocumentoScreen(tipo: TipoParte.ingreso),
                            ),
                          ),
                        ),
                        _TarjetaVidrio(
                          icono: Icons.copy_all_outlined,
                          colorIcono: Colors.grey.shade300,
                          titulo: 'Ver libertades',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DocumentoScreen(tipo: TipoParte.libertad),
                            ),
                          ),
                        ),
                        _TarjetaVidrio(
                          icono: Icons.picture_as_pdf_outlined,
                          colorIcono: Colors.redAccent.shade100,
                          titulo: 'PDFs guardados',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PdfsGuardadosScreen()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 02/sep: tarjeta de vidrio translúcido (glassmorphism) — icono en color +
// título, usada en la grilla 2x2+2 del home (Buscar placa, Consultar info,
// Generar Excel, Generar Informe Semanal, Ver ingresos, Ver libertades).
// El texto usa maxLines+overflow para que títulos largos ("Generar Informe
// Semanal") hagan salto de línea en vez de desbordarse.
class _TarjetaVidrio extends StatelessWidget {
  final IconData icono;
  final Color colorIcono;
  final String titulo;
  final VoidCallback onTap;

  const _TarjetaVidrio({
    required this.icono,
    required this.colorIcono,
    required this.titulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(0.10),
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white24,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icono, color: colorIcono, size: 34),
                  const SizedBox(height: 10),
                  Text(
                    titulo,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonPrincipal extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color color;
  final VoidCallback onTap;

  const _BotonPrincipal({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Icon(icono, color: Colors.white, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
