import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(BackgroundEditorApp());

class BackgroundEditorApp extends StatelessWidget {
  const BackgroundEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Editor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const ui.Color.fromARGB(255, 7, 0, 41),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Roboto', fontSize: 16.0),
        ),
      ),
      home: const BackgroundEditorScreen(),
    );
  }
}

class BackgroundEditorScreen extends StatefulWidget {
  const BackgroundEditorScreen({super.key});

  @override
  _BackgroundEditorScreenState createState() => _BackgroundEditorScreenState();
}

class _BackgroundEditorScreenState extends State<BackgroundEditorScreen> {
  File? _imageFile;
  Uint8List? _processedImageBytes;
  File? _backgroundImage;
  final ImagePicker _picker = ImagePicker();
  Color _solidColor = Colors.white;
  bool _isProcessing = false;

  // Pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _processedImageBytes = null;
        _backgroundImage = null;
      });
    }
  }

  // Pick a background image from the gallery
  Future<void> _pickBackgroundImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _backgroundImage = File(pickedFile.path);
      });
    }
  }

  // Remove the background using Remove.bg API
  Future<void> _removeBackground() async {
    if (_imageFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.remove.bg/v1.0/removebg'),
      )
        ..headers['X-Api-Key'] = '29Jid4qXVBDGEQah5qfbfJGU' // Remove BG API key
        ..files.add(
            await http.MultipartFile.fromPath('image_file', _imageFile!.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        setState(() {
          _processedImageBytes = bytes;
        });
      } else {
        _showError('Failed to remove background. Try again.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Combine the processed image with the background
  Future<Uint8List> _combineImageWithBackground() async {
    if (_processedImageBytes == null) {
      throw Exception("No processed image to combine.");
    }

    final processedImage = await decodeImageFromList(_processedImageBytes!);

    // Create a canvas with the size of the processed image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, processedImage.width.toDouble(),
            processedImage.height.toDouble()));

    // Draw the background (solid color or image)
    if (_backgroundImage != null) {
      final bgImage =
          await decodeImageFromList(await _backgroundImage!.readAsBytes());
      canvas.drawImageRect(
        bgImage,
        Rect.fromLTWH(
            0, 0, bgImage.width.toDouble(), bgImage.height.toDouble()),
        Rect.fromLTWH(0, 0, processedImage.width.toDouble(),
            processedImage.height.toDouble()),
        Paint(),
      );
    } else {
      final paint = Paint()..color = _solidColor;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, processedImage.width.toDouble(),
            processedImage.height.toDouble()),
        paint,
      );
    }

    // Draw the processed image on top of the background
    canvas.drawImage(processedImage, Offset.zero, Paint());

    // Convert the canvas to an image
    final combinedImage = await recorder
        .endRecording()
        .toImage(processedImage.width, processedImage.height);

    // Convert the image to bytes
    final byteData =
        await combinedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // Show an error message in a snackbar
  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Save the processed image to the device
  Future<void> _saveImage() async {
    try {
      final combinedImageBytes = await _combineImageWithBackground();

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/processed_image_with_bg.png';
      final file = File(filePath);
      await file.writeAsBytes(combinedImageBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image saved to $filePath')),
      );
    } catch (e) {
      _showError('Failed to save image: $e');
    }
  }

  // Share the processed image
  Future<void> _shareImage() async {
    try {
      final combinedImageBytes = await _combineImageWithBackground();

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/shared_image_with_bg.png';
      final file = File(filePath);
      await file.writeAsBytes(combinedImageBytes);

      await Share.shareXFiles([XFile(filePath)],
          text: 'Check out my edited image!');
    } catch (e) {
      _showError('Failed to share image: $e');
    }
  }

  // Change the background color
  Future<void> _changeBackgroundColor() async {
    if (_processedImageBytes == null) {
      _showError("No processed image to apply background color.");
      return;
    }

    setState(() {
      _solidColor = Colors.primaries[
          DateTime.now().millisecondsSinceEpoch % Colors.primaries.length];
      _backgroundImage = null; // Clear any existing background image
    });
  }

  // Reset to add image state
  void _resetToAddImageState() {
    setState(() {
      _imageFile = null;
      _processedImageBytes = null;
      _backgroundImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Background Editor',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const ui.Color.fromARGB(255, 7, 0, 41),
        actions: [
          if (_processedImageBytes != null)
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white),
              onPressed: _resetToAddImageState,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_backgroundImage != null)
            Center(
              child: Image.file(
                _backgroundImage!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          if (_imageFile != null && _processedImageBytes == null)
            Center(
              child: Image.file(
                _imageFile!,
                fit: BoxFit.contain,
              ),
            ),
          if (_processedImageBytes != null)
            Container(
              color: _backgroundImage == null ? _solidColor : null,
              child: Center(
                child: Image.memory(
                  _processedImageBytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          if (_imageFile == null && _processedImageBytes == null)
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blueAccent,
                      style: BorderStyle.solid,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                    color: const ui.Color.fromARGB(255, 7, 0, 41),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 3,
                        blurRadius: 7,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.add_a_photo,
                        size: 60,
                        color: Colors.blueAccent,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Tap to add an image",
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (_imageFile != null && _processedImageBytes == null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 20.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: _removeBackground,
                child: const Text('Remove Background',
                    style: TextStyle(color: Colors.white)),
              ),
            if (_processedImageBytes != null)
              IconButton(
                icon: const Icon(Icons.save, color: Colors.white),
                onPressed: _saveImage,
              ),
            if (_processedImageBytes != null)
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: _shareImage,
              ),
            if (_processedImageBytes != null)
              IconButton(
                icon: const Icon(Icons.image, color: Colors.white),
                onPressed: _pickBackgroundImage,
              ),
            if (_processedImageBytes != null)
              IconButton(
                icon: const Icon(Icons.format_paint, color: Colors.white),
                onPressed: _changeBackgroundColor,
              ),
          ],
        ),
      ),
    );
  }
}
