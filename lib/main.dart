import 'dart:io';

import 'package:camera/camera.dart' as c;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

late List<c.CameraDescription> _cameras;

final textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _cameras = (await c.availableCameras())
      .where((element) => element.lensDirection == c.CameraLensDirection.back)
      .toList();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Camera(),
    );
  }
}

class Camera extends StatefulWidget {
  const Camera({
    Key? key,
  }) : super(key: key);

  @override
  State<Camera> createState() => _CameraState();
}

class _CameraState extends State<Camera> with WidgetsBindingObserver {
  c.CameraController? _controller;

  int _currentCamera = 0;

  int get currentCamera => _currentCamera;

  set currentCamera(int value) {
    _currentCamera = value;
    _newCameraController(value);
  }

  @override
  void initState() {
    super.initState();
    _newCameraController(currentCamera);

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;

    if (controller != null && state == AppLifecycleState.inactive) {
      controller.dispose();

      setState(() => _controller = null);
    } else if (state == AppLifecycleState.resumed) {
      _newCameraController(currentCamera);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return Column(
        children: [
          const Expanded(
              child: Center(
            child: Text("Loading camera..."),
          )),
          TextButton(
              onPressed: () => currentCamera = 0,
              child: const Text("Reset Camera"))
        ],
      );
    } else {
      return Column(
        children: [
          c.CameraPreview(controller),
          FloatingActionButton(
            child: Icon(Icons.camera_alt),
            // onPressed 콜백을 제공합니다.
            onPressed: () async {
              // try / catch 블럭에서 사진을 촬영합니다. 만약 뭔가 잘못된다면 에러에
              // 대응할 수 있습니다.
              try {
                // path 패키지를 사용하여 이미지가 저장될 경로를 지정합니다.
                final path = join(
                  // 본 예제에서는 임시 디렉토리에 이미지를 저장합니다. `path_provider`
                  // 플러그인을 사용하여 임시 디렉토리를 찾으세요.
                  (await getTemporaryDirectory()).path,
                  '${DateTime.now()}.png',
                );

                // 사진 촬영을 시도하고 저장되는 경로를 로그로 남깁니다.
                XFile picture = await controller.takePicture();
                picture.saveTo(path);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return DisplayPicture(
                        imagePath: path,
                      );
                    },
                  ),
                );
              } catch (e) {
                // 만약 에러가 발생하면, 콘솔에 에러 로그를 남깁니다.
                print(e);
              }
            },
          )
        ],
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();

    super.dispose();
  }

  void _newCameraController(int camera) {
    if (camera >= _cameras.length) {
      throw IndexError(camera, _cameras.length);
    }

    // Notify the UI we are waiting for a new camera
    setState(() => _controller = null);

    final controller =
        c.CameraController(_cameras[camera], c.ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) return;

      // Notify the UI the new controller is ready
      setState(() => _controller = controller);
    });
  }
}

class DisplayPicture extends StatefulWidget {
  final String imagePath;

  DisplayPicture({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<DisplayPicture> createState() => _DisplayPictureState();
}

class _DisplayPictureState extends State<DisplayPicture> {
  late InputImage inputImage = InputImage.fromFilePath(widget.imagePath);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Display the Picture')),
      // 이미지는 디바이스에 파일로 저장됩니다. 이미지를 보여주기 위해 주어진
      // 경로로 `Image.file`을 생성하세요.
      body: Column(children: [
        Container(
            height: 300, width: 300, child: Image.file(File(widget.imagePath))),
        ElevatedButton(
            onPressed: () async {
// Create a TextRecognizer object
              final textRecognizer =
                  TextRecognizer(script: TextRecognitionScript.korean);

// Use the processImage method to recognize text in the image
              final response = await textRecognizer.processImage(inputImage);

// Print the recognized text to the console
              final text = response.text;
              print(text);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return TextRecognition(text: text);
                  },
                ),
              );
            },
            child: Text("recog")),
      ]),
    );
  }
}

class TextRecognition extends StatefulWidget {
  final String text;

  const TextRecognition({Key? key, required this.text}) : super(key: key);

  @override
  State<TextRecognition> createState() => _TextRecognitionState();
}

class _TextRecognitionState extends State<TextRecognition> {
  late TextEditingController _titleController =
      TextEditingController(text: widget.text);
  late String modifiedText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                height: 500,
                width: 500,
                child: Expanded(
                  child: TextFormField(
                    onChanged: (text) {
                      modifiedText = text;
                    },
                    controller: _titleController,
                    minLines: null,
                    maxLines: 999,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
              ),
              ElevatedButton(
                  onPressed: () {
                    print(modifiedText);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return QRCode(text: modifiedText);
                        },
                      ),
                    );
                  },
                  child: Text("QR"))
            ],
          ),
        ),
      ),
    );
  }
}

class QRCode extends StatelessWidget {
  String text;
  QRCode({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            QrImage(
              data: text,
              version: QrVersions.auto,
              size: 320,
              gapless: false,
            )
          ],
        ),
      ),
    );
  }
}
