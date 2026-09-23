import 'package:flutter/material.dart';
import 'auth_gate.dart';

/// 23/sep: pantalla de bienvenida animada, pedida por Xavier para
/// reemplazar la transición plana hacia la app. El águila del sello
/// aparece pequeña en el centro y "vuela" hacia la cámara, agrandándose
/// hasta cubrir toda la pantalla; justo cuando la cubre por completo se
/// hace el cambio de pantalla hacia AuthGate (login o Home según sesión).
///
/// Se muestra siempre al abrir la app, ANTES de decidir si hay sesión o
/// no — por eso vive aquí y no dentro de AuthGate.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;
  bool _navego = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    // 0% -> 25%: el águila aparece pequeña (efecto de entrada).
    // 25% -> 100%: el águila "vuela" hacia la cámara y se agranda hasta
    // cubrir toda la pantalla.
    _escala = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.25, end: 0.55)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 9.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 75,
      ),
    ]).animate(_controller);

    // El águila se desvanece justo en el tramo final, cuando ya cubre
    // toda la pantalla, para que la transición hacia AuthGate sea suave.
    _opacidad = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navego) {
        _navego = true;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (_, anim, __) =>
                FadeTransition(opacity: anim, child: const AuthGate()),
          ),
        );
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17356E),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Center(
            child: Opacity(
              opacity: _opacidad.value,
              child: Transform.scale(
                scale: _escala.value,
                child: child,
              ),
            ),
          );
        },
        child: Image.asset('assets/eagle_splash.png', width: 260),
      ),
    );
  }
}
