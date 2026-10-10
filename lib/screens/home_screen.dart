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
import 'historial_informes_screen.dart';
import 'pdfs_guardados_screen.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../widgets/calculadora_dias_dialog.dart';
import '../widgets/firma_digital_dialog.dart';
import '../version.dart';

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
            icon: const Icon(Icons.verified_outlined),
            tooltip: 'Configuración Firma Digital (.p12)',
            onPressed: () => FirmaDigitalDialog.mostrar(context),
          ),
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF17356E), Color(0xFF1C4488)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Opacity(
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
                      titulo: 'BUSCAR VEHÍCULOS EN EL PATIO',
                      subtitulo: 'Registrar la devolución / libertad de un vehículo',
                      color: Colors.green.shade700,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BuscarPlacaScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                      children: [
                        _TarjetaVidrio(
                          icono: Icons.travel_explore,
                          colorIcono: Colors.tealAccent,
                          titulo: 'Consultar info',
                          onTap: () => _abrirConsultaVehiculos(context),
                          iconoAccion: Icons.calculate,
                          colorIconoAccion: Colors.amberAccent,
                          tooltipAccion: 'Calculador de días de permanencia',
                          onTapAccion: () => CalculadoraDiasDialog.mostrar(context),
                        ),
                        _TarjetaVidrio(
                          icono: Icons.calculate,
                          colorIcono: Colors.amberAccent,
                          titulo: 'Calculador de días',
                          onTap: () => CalculadoraDiasDialog.mostrar(context),
                        ),
                        _TarjetaVidrio(
                          icono: Icons.verified_outlined,
                          colorIcono: Colors.lightGreenAccent,
                          titulo: 'Firma Digital (.p12)',
                          onTap: () => FirmaDigitalDialog.mostrar(context),
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
                          icono: Icons.history_edu_outlined,
                          colorIcono: Colors.amber.shade300,
                          titulo: 'Historial de Informes',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const HistorialInformesScreen()),
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
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Versión $appVersion',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
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

class _TarjetaVidrio extends StatelessWidget {
  final IconData icono;
  final Color colorIcono;
  final String titulo;
  final VoidCallback onTap;
  final IconData? iconoAccion;
  final Color? colorIconoAccion;
  final String? tooltipAccion;
  final VoidCallback? onTapAccion;

  const _TarjetaVidrio({
    required this.icono,
    required this.colorIcono,
    required this.titulo,
    required this.onTap,
    this.iconoAccion,
    this.colorIconoAccion,
    this.tooltipAccion,
    this.onTapAccion,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.10),
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white24,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icono, color: colorIcono, size: 34),
                      if (iconoAccion != null && onTapAccion != null) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: tooltipAccion ?? '',
                          child: InkWell(
                            onTap: onTapAccion,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                iconoAccion,
                                color: colorIconoAccion ?? Colors.amberAccent,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
