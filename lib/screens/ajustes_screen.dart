import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_key_service.dart';

class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  final _controller = TextEditingController();
  final _service = ApiKeyService();
  bool _guardando = false;
  bool _yaConfigurada = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final key = await _service.obtenerApiKey();
    if (key != null && mounted) {
      setState(() {
        _controller.text = key;
        _yaConfigurada = true;
      });
    }
  }

  Future<void> _abrirAiStudio() async {
    final uri = Uri.parse('https://aistudio.google.com/apikey');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el navegador. Ve manualmente a aistudio.google.com/apikey')),
      );
    }
  }

  Future<void> _guardar() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    try {
      await _service.guardarApiKey(_controller.text);
      if (mounted) {
        setState(() {
          _guardando = false;
          _yaConfigurada = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key guardada. Ya puedes escanear con IA.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la clave: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes — IA de escaneo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            _yaConfigurada ? Icons.check_circle : Icons.key,
            size: 56,
            color: _yaConfigurada ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 12),
          Text(
            _yaConfigurada
                ? 'Ya tienes una API key configurada.'
                : 'Para que la app pueda leer los datos de las fotos, necesitas una API key GRATUITA de Google Gemini.',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Abrir Google AI Studio y crear mi clave'),
            onPressed: _abrirAiStudio,
          ),
          const SizedBox(height: 20),
          const Text('Pasos (2 minutos, gratis, sin tarjeta):', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('1. Toca el botón de arriba (te lleva directo a la página).'),
          const Text('2. Inicia sesión con cualquier cuenta de Google, si te lo pide.'),
          const Text('3. Toca "Create API key" (Crear clave de API).'),
          const Text('4. Copia la clave que te muestra (empieza con "AIza...").'),
          const Text('5. Vuelve a esta pantalla, pégala abajo y toca Guardar.'),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'API key de Gemini',
              border: OutlineInputBorder(),
              hintText: 'AIza...',
            ),
            obscureText: false,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _guardando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_guardando ? 'Guardando...' : 'Guardar'),
            onPressed: _guardando ? null : _guardar,
          ),
        ],
      ),
    );
  }
}
