import 'package:flutter/material.dart';
import 'package:google_ml_kit_text_recognition/google_ml_kit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextRecognizer _recognizer = TextRecognizer();
  List<Map<String, dynamic>> _resultados = [];
  bool _cargando = false;

  Future<void> _escanear() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _cargando = true);

    final inputImage = InputImage.fromFilePath(image.path);
    final text = await _recognizer.processImage(inputImage);

    final regex = RegExp(r'\bE\d{3}[a-z]?\b', caseSensitive: false);
    final codigos = <String>{};
    for (var block in text.blocks) {
      for (var line in block.lines) {
        codigos.addAll(regex.allMatches(line.text).map((m) => m.group(0)!.toUpperCase()));
      }
    }

    final resultados = <Map<String, dynamic>>[];
    for (String codigo in codigos) {
      final doc = await FirebaseFirestore.instance.collection('aditivos').doc(codigo).get();
      if (doc.exists) {
        resultados.add({'codigo': codigo, ...doc.data()!});
      }
    }

    setState(() {
      _resultados = resultados;
      _cargando = false;
    });
  }

  String _t(String es, String en) {
    return Localizations.localeOf(context).languageCode == 'es' ? es : en;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('Ingrediente Seguro', 'Safe Ingredient'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _cargando ? null : _escanear,
              icon: const Icon(Icons.camera_alt),
              label: Text(_t('Escanear Ingredientes', 'Scan Ingredients')),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),
            ),
            const SizedBox(height: 20),
            _cargando
                ? const CircularProgressIndicator()
                : Expanded(
                    child: _resultados.isEmpty
                        ? Center(child: Text(_t('Apunta a la lista de ingredientes', 'Point to the ingredient list')))
                        : ListView.builder(
                            itemCount: _resultados.length,
                            itemBuilder: (_, i) {
                              final item = _resultados[i];
                              final nombre = _t(item['nombre_es'] ?? '', item['nombre_en'] ?? '');
                              final desc = _t(item['desc_es'] ?? '', item['desc_en'] ?? '');
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: (item['seguridad'] ?? '').contains('Seguro') ? Colors.green : Colors.orange,
                                    child: Text(item['codigo'], style: const TextStyle(color: Colors.white)),
                                  ),
                                  title: Text(nombre),
                                  subtitle: Text(desc),
                                ),
                              );
                            },
                          ),
                  ),
          ],
        ),
      ),
    );
  }
}
