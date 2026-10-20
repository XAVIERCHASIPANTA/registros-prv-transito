import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_home_screen.dart';
import 'captura_screen.dart';
import 'documento_screen.dart';
import 'ajustes_screen.dart';
import 'buscar_placa_screen.dart';
import 'informe_semanal_screen.dart';
import 'historial_informes_screen.dart';
import 'matriz_excel_screen.dart';
import 'pdfs_guardados_screen.dart';
import '../services/auth_service.dart';
import '../services/pwa_install_stub.dart'
    if (dart.library.html) '../services/pwa_install_web.dart';
import '../widgets/calculadora_dias_dialog.dart';
import '../widgets/firma_digital_dialog.dart';
import '../version.dart';

enum TipoParte { ingreso, libertad }

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _urlConsultaVehiculos = 'https://servicios.axiscloud.ec/CRV/?ps_empresa=02';

  Future<void> _abrirEnlaceWeb(BuildContext context, String urlStr, {String? nombre}) async {
    try {
      final uri = Uri.parse(urlStr);
      final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abierto && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir ${nombre ?? 'el enlace'}.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir enlace: $e')),
        );
      }
    }
  }

  Future<void> _abrirConsultaVehiculos(BuildContext context) async {
    await _abrirEnlaceWeb(context, _urlConsultaVehiculos, nombre: 'Consulta de Vehículos');
  }

  void _mostrarSubmenuInformeSemanal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _SubmenuModal(
          titulo: 'Informe Semanal',
          subtitulo: 'Gestión de informes semanales y firma electrónica',
          icono: Icons.summarize_outlined,
          colorIcono: Colors.orangeAccent,
          opciones: [
            _OpcionSubmenu(
              titulo: 'Generar informe semanal',
              descripcion: 'Crear nuevo informe consolidado de novedades',
              icono: Icons.post_add_rounded,
              colorIcono: Colors.orangeAccent,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InformeSemanalScreen()),
                );
              },
            ),
            _OpcionSubmenu(
              titulo: 'Historial de informes',
              descripcion: 'Consultar y reimprimir informes generados',
              icono: Icons.history_edu_outlined,
              colorIcono: Colors.amber.shade300,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistorialInformesScreen()),
                );
              },
            ),
            _OpcionSubmenu(
              titulo: 'Firma digital (.p12)',
              descripcion: 'Configurar certificado de firma y credenciales',
              icono: Icons.verified_outlined,
              colorIcono: Colors.lightGreenAccent,
              onTap: () {
                Navigator.pop(ctx);
                FirmaDigitalDialog.mostrar(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _mostrarSubmenuApartadosWeb(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        // Primero se reproduce el efecto (inflar + desaparecer) dentro del
        // propio círculo; recién después se cierra el panel y se abre el enlace.
        void abrir(String url, String nombre) {
          Navigator.pop(ctx);
          _abrirEnlaceWeb(context, url, nombre: nombre);
        }

        return _ApartadosRadialModal(
          centro: _EnlaceRadial(
            titulo: 'Tonelaje de vehículo',
            icono: Icons.travel_explore,
            color: Colors.tealAccent,
            onTap: () => abrir(_urlConsultaVehiculos, 'Consulta de Vehículos'),
          ),
          alrededor: [
            _EnlaceRadial(
              titulo: 'PARTE WEB',
              icono: Icons.shield_outlined,
              color: const Color(0xFF5BA3F5),
              onTap: () => abrir(
                'https://partepolicial.ministeriodelinterior.gob.ec/',
                'PARTE WEB',
              ),
            ),
            _EnlaceRadial(
              titulo: 'SIIPNE 3W',
              icono: Icons.local_police_outlined,
              color: Colors.tealAccent,
              onTap: () => abrir(
                'https://siipne.policia.gob.ec/indexSiipne.php',
                'SIIPNE 3W',
              ),
            ),
            _EnlaceRadial(
              titulo: 'DOCPOL',
              icono: Icons.folder_shared_outlined,
              color: Colors.amberAccent,
              onTap: () => abrir(
                'https://docpol.policia.gob.ec/login.php',
                'DOCPOL',
              ),
            ),
            _EnlaceRadial(
              titulo: 'MULTAS AMT',
              icono: Icons.receipt_long_outlined,
              color: const Color(0xFFFF6B6B),
              onTap: () => abrir(
                'https://servicios.axiscloud.ec/AutoServicio/inicio.jsp?ps_empresa=03&ps_accion=P55',
                'MULTAS AMT',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _botonAdminSiCorresponde() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final d = snapshot.data?.data();
        final esAdmin = d?['esAdmin'] == true ||
            (d?['rol'] == 'admin_zona' && d?['aprobado'] == true);
        if (!esAdmin) return const SizedBox.shrink();
        return IconButton(
          icon: const Icon(Icons.admin_panel_settings),
          tooltip: 'Panel Nacional',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
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

  void _manejarDescargaOInstalacion(BuildContext context) {
    final instalado = intentarInstalarPWA();
    if (instalado) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF132B59),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.download_rounded, color: Colors.cyanAccent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instalar Aplicación en Celular',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Acceso directo en pantalla de inicio (PWA)',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 26),
              _itemGuiaInstalacion(
                icono: Icons.android_rounded,
                colorIcono: Colors.greenAccent,
                titulo: 'En celulares Android (Chrome / Brave)',
                pasos: '1. Toca el menú de tres puntos (⋮) en la esquina superior derecha del navegador.\n'
                    '2. Pulsa en "Instalar aplicación" o "Agregar a la pantalla principal".\n'
                    '3. ¡Listo! La app se abrirá a pantalla completa como una aplicación instalada.',
              ),
              const SizedBox(height: 12),
              _itemGuiaInstalacion(
                icono: Icons.apple_rounded,
                colorIcono: Colors.white,
                titulo: 'En iPhone / iPad (Safari)',
                pasos: '1. Toca el botón Compartir (icono de cuadrado con flecha hacia arriba).\n'
                    '2. Desliza hacia abajo y selecciona "Agregar al inicio" (Add to Home Screen).\n'
                    '3. Toca "Agregar" en la esquina superior.',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5BB0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _itemGuiaInstalacion({
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String pasos,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: colorIcono, size: 20),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pasos,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _botonDescargarConTexto(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _manejarDescargaOInstalacion(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF153366).withValues(alpha: 0.9),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.download_rounded,
                  color: Colors.cyanAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Descargar aplicación',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
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
              right: -60,
              bottom: -60,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.13,
                  child: Image.asset(
                    'assets/sello_prv.png',
                    width: 480,
                    height: 480,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        Image.asset('assets/logo.png', height: 165),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _botonDescargarConTexto(context),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 14),
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
                        GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 118,
                          ),
                          children: [
                            _TarjetaVidrio(
                              icono: Icons.travel_explore,
                              colorIcono: Colors.tealAccent,
                              titulo: 'Consultar tonelaje de vehículo',
                              onTap: () => _abrirConsultaVehiculos(context),
                            ),
                            _TarjetaVidrio(
                              icono: Icons.calculate,
                              colorIcono: Colors.amberAccent,
                              titulo: 'Calculador de días',
                              onTap: () => CalculadoraDiasDialog.mostrar(context),
                            ),
                            _TarjetaVidrio(
                              icono: Icons.table_chart_outlined,
                              colorIcono: Colors.purpleAccent,
                              titulo: 'Matriz general de ingresos y salidas Excel',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MatrizExcelScreen()),
                              ),
                            ),
                            _TarjetaVidrio(
                              icono: Icons.summarize_outlined,
                              colorIcono: Colors.orangeAccent,
                              titulo: 'Informe semanal',
                              onTap: () => _mostrarSubmenuInformeSemanal(context),
                            ),
                            _TarjetaVidrio(
                              icono: Icons.language_outlined,
                              colorIcono: Colors.cyanAccent,
                              titulo: 'Apartados web',
                              onTap: () => _mostrarSubmenuApartadosWeb(context),
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
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            creditoAutor,
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
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
          color: Colors.white.withValues(alpha: 0.10),
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white24,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icono, color: colorIcono, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    titulo,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.15,
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

class _OpcionSubmenu {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Color colorIcono;
  final VoidCallback onTap;

  const _OpcionSubmenu({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.colorIcono,
    required this.onTap,
  });
}

class _SubmenuModal extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color colorIcono;
  final List<_OpcionSubmenu> opciones;

  const _SubmenuModal({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.colorIcono,
    required this.opciones,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF132B59),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: colorIcono.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: colorIcono.withValues(alpha: 0.3)),
                    ),
                    child: Icon(icono, color: colorIcono, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...opciones.map((opc) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: opc.onTap,
                      splashColor: opc.colorIcono.withValues(alpha: 0.2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: opc.colorIcono.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(opc.icono, color: opc.colorIcono, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opc.titulo,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    opc.descripcion,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// APARTADOS WEB — menú radial: 1 enlace al centro + 4 alrededor.
// Al tocar un círculo: se infla, se desvanece y recién entonces se abre el enlace.
// ─────────────────────────────────────────────────────────────────────────────

class _EnlaceRadial {
  final String titulo;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;

  const _EnlaceRadial({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.onTap,
  });
}

class _ApartadosRadialModal extends StatelessWidget {
  final _EnlaceRadial centro;
  final List<_EnlaceRadial> alrededor; // se espera 4

  const _ApartadosRadialModal({
    required this.centro,
    required this.alrededor,
  });

  static const double _ancho = 300;
  static const double _alto = 300;
  static const double _tamCentro = 108;
  static const double _tamSatelite = 66;
  static const double _anchoNodo = 92;
  static const double _desplazamiento = 78; // en X e Y desde el centro (diagonales)

  @override
  Widget build(BuildContext context) {
    const cx = _ancho / 2;
    const cy = _alto / 2;

    // Esquinas: arriba-izq, arriba-der, abajo-izq, abajo-der
    const posiciones = <Offset>[
      Offset(-_desplazamiento, -_desplazamiento),
      Offset(_desplazamiento, -_desplazamiento),
      Offset(-_desplazamiento, _desplazamiento),
      Offset(_desplazamiento, _desplazamiento),
    ];

    final satelites = <Widget>[];
    for (var i = 0; i < alrededor.length && i < posiciones.length; i++) {
      final p = posiciones[i];
      satelites.add(
        Positioned(
          left: cx + p.dx - _anchoNodo / 2,
          top: cy + p.dy - _tamSatelite / 2,
          width: _anchoNodo,
          child: _NodoInflable(
            enlace: alrededor[i],
            tam: _tamSatelite,
            etiquetaDentro: false,
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF132B59),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.language_outlined, color: Colors.cyanAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apartados Web',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Toca un círculo para abrir la plataforma',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: _ancho,
                height: _alto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _LineasRadialPainter(
                            centro: const Offset(cx, cy),
                            destinos: [
                              for (final p in posiciones) Offset(cx + p.dx, cy + p.dy),
                            ],
                            colorCentro: centro.color,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: cx - _tamCentro / 2,
                      top: cy - _tamCentro / 2,
                      width: _tamCentro,
                      child: _NodoInflable(
                        enlace: centro,
                        tam: _tamCentro,
                        etiquetaDentro: true,
                      ),
                    ),
                    ...satelites,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineasRadialPainter extends CustomPainter {
  final Offset centro;
  final List<Offset> destinos;
  final Color colorCentro;

  _LineasRadialPainter({
    required this.centro,
    required this.destinos,
    required this.colorCentro,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linea = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final d in destinos) {
      canvas.drawLine(centro, d, linea);
    }
    final anillo = Paint()
      ..color = colorCentro.withValues(alpha: 0.12)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(centro, 68, anillo);
  }

  @override
  bool shouldRepaint(covariant _LineasRadialPainter old) =>
      old.centro != centro || old.colorCentro != colorCentro || old.destinos != destinos;
}

class _NodoInflable extends StatefulWidget {
  final _EnlaceRadial enlace;
  final double tam;
  final bool etiquetaDentro;

  const _NodoInflable({
    required this.enlace,
    required this.tam,
    required this.etiquetaDentro,
  });

  @override
  State<_NodoInflable> createState() => _NodoInflableState();
}

class _NodoInflableState extends State<_NodoInflable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  bool _activo = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _tocar() async {
    if (_activo) return;
    _activo = true;
    await _c.forward();
    if (!mounted) return;
    widget.enlace.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.enlace;
    final dentro = widget.etiquetaDentro;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final escala = 1 + 0.9 * Curves.easeOut.transform(_c.value);
        final opacidad = 1 - Curves.easeIn.transform(_c.value);

        final circulo = Transform.scale(
          scale: escala,
          child: Opacity(
            opacity: opacidad,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                splashColor: e.color.withValues(alpha: 0.3),
                onTap: _tocar,
                child: Container(
                  width: widget.tam,
                  height: widget.tam,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: e.color.withValues(alpha: dentro ? 0.22 : 0.16),
                    border: Border.all(
                      color: e.color.withValues(alpha: dentro ? 0.9 : 0.6),
                      width: dentro ? 2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: e.color.withValues(alpha: dentro ? 0.35 : 0.18),
                        blurRadius: dentro ? 18 : 10,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(6),
                  child: dentro
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(e.icono, color: e.color, size: 34),
                            const SizedBox(height: 4),
                            Text(
                              e.titulo,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                                height: 1.1,
                              ),
                            ),
                          ],
                        )
                      : Icon(e.icono, color: e.color, size: 30),
                ),
              ),
            ),
          ),
        );

        if (dentro) return Center(child: circulo);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            circulo,
            const SizedBox(height: 4),
            Opacity(
              opacity: opacidad,
              child: Text(
                e.titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 1.1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
