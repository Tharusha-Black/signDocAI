import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIdx = 0;
  bool _isFlashOn = false;
  FlashMode _currentFlashMode = FlashMode.off;
  IO.Socket? _socket;
  String? _mediapipePrediction;
  String? _cnnPrediction;
  double? _cnnConfidence;
  bool _isLoading = false;
  bool _isConnected = false;
  String _errorMessage = '';
  List<String> _collectedLetters = [];
  String? _selectedLetter;
  bool _showSelectionButtons = false;
  bool _isCapturing = false;
  bool _autoCaptureNext = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    _connectSocket();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_selectedCameraIdx);
    }
  }

  Future<void> _initialize() async {
    await _getAvailableCameras();
    _connectSocket();
  }

  Future<void> _getAvailableCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        throw Exception('No cameras available');
      }
      await _initCamera(_selectedCameraIdx);
    } catch (e) {
      print('Camera initialization failed: $e');
      if (mounted) setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  Future<void> _initCamera(int cameraIdx) async {
    if (_cameras == null || _cameras!.isEmpty) return;

    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      _cameras![cameraIdx],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      await _setFlashMode(_currentFlashMode);

      if (mounted) setState(() {});
    } catch (e) {
      print('Camera initialization failed: $e');
      if (mounted) setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  Future<void> _setFlashMode(FlashMode mode) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.setFlashMode(mode);
      setState(() {
        _currentFlashMode = mode;
        _isFlashOn = mode != FlashMode.off;
      });
    } catch (e) {
      print('Error setting flash mode: $e');
    }
  }

  void _toggleFlash() {
    if (_currentFlashMode == FlashMode.off) {
      _setFlashMode(FlashMode.torch);
    } else {
      _setFlashMode(FlashMode.off);
    }
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() {
      _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras!.length;
      _initCamera(_selectedCameraIdx);
    });
  }

  void _connectSocket() {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io('http://192.168.1.7:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.on('connect', (_) {
      print('Socket connected');
      if (mounted) setState(() => _isConnected = true);
    });

    _socket!.on('disconnect', (_) {
      print('Socket disconnected');
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
      }
    });

    _socket!.on('prediction_response', (data) {
      print('Received prediction: $data');
      if (mounted) {
        try {
          setState(() {
            _mediapipePrediction = data['hand_sign']?.toString();
            _cnnPrediction = data['cnn_prediction']?.toString();
            _cnnConfidence = data['confidence']?.toDouble();
            _isLoading = false;
            _isCapturing = false;

            final bothEmpty =
                (_mediapipePrediction == null ||
                    _mediapipePrediction!.isEmpty) &&
                (_cnnPrediction == null || _cnnPrediction!.isEmpty);

            if (bothEmpty) {
              Future.delayed(Duration(seconds: 1), _captureAndPredict);
            } else {
              _showSelectionButtons = true;
            }
          });
        } catch (e) {
          print('Error decoding message: $e');
          setState(() {
            _errorMessage = 'Error processing prediction: $e';
            _isLoading = false;
            _isCapturing = false;
          });
        }
      }
    });

    _socket!.on('connect_error', (err) {
      print('Socket connection error: $err');
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
          _isCapturing = false;
          _errorMessage = 'Connection error: $err';
        });
      }
    });
  }

  Future<void> _captureAndPredict() async {
    if (_isCapturing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _isLoading = true;
      _mediapipePrediction = null;
      _cnnPrediction = null;
      _selectedLetter = null;
      _showSelectionButtons = false;
      _errorMessage = '';
    });

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      _socket?.emit('predict', {
        'image': base64Image,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error sending frame: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCapturing = false;
          _errorMessage = 'Error capturing/sending image: $e';
        });
      }
    }
  }

  void _saveLetter(String letter) {
    setState(() {
      _collectedLetters.add(letter);
      _selectedLetter = letter;
      _showSelectionButtons = false;
    });

    _autoCaptureNext = true;
    Future.delayed(Duration(seconds: 2), () {
      if (_autoCaptureNext) {
        _captureAndPredict();
      }
    });
  }

  void _stopAutoCapture() {
    _autoCaptureNext = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ASL Recognition'),
        actions: [
          if (_collectedLetters.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _collectedLetters.clear();
                  _stopAutoCapture();
                });
              },
              tooltip: 'Clear all letters',
            ),
        ],
      ),
      body:
          _errorMessage.isNotEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              : Column(
                children: [
                  // Camera preview with controls
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          margin: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child:
                                _cameraController != null &&
                                        _cameraController!.value.isInitialized
                                    ? CameraPreview(_cameraController!)
                                    : Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text('Initializing camera...'),
                                        ],
                                      ),
                                    ),
                          ),
                        ),
                        // Camera controls overlay
                        Positioned(
                          top: 20,
                          right: 20,
                          child: Column(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                onPressed: _toggleFlash,
                              ),
                              SizedBox(height: 16),
                              IconButton(
                                icon: Icon(
                                  Icons.cameraswitch,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                onPressed: _switchCamera,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Prediction section
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Connection status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.circle,
                              color: _isConnected ? Colors.green : Colors.red,
                              size: 12,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _isConnected
                                  ? 'Connected to server'
                                  : 'Disconnected',
                              style: TextStyle(
                                color: _isConnected ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Collected letters
                        if (_collectedLetters.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    _collectedLetters
                                        .map(
                                          (letter) => Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Chip(
                                              label: Text(letter),
                                              backgroundColor:
                                                  _selectedLetter == letter
                                                      ? Colors.green[200]
                                                      : Colors.blue[100],
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ),

                        // Predictions display
                        if (_isLoading)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 8),
                                Text('Processing...'),
                              ],
                            ),
                          ),

                        if ((_mediapipePrediction != null &&
                                _mediapipePrediction!.isNotEmpty) ||
                            (_cnnPrediction != null &&
                                _cnnPrediction!.isNotEmpty))
                          Column(
                            children: [
                              if (_mediapipePrediction != null &&
                                  _mediapipePrediction!.isNotEmpty)
                                _buildPredictionCard(
                                  title: 'MediaPipe Prediction',
                                  prediction: _mediapipePrediction!,
                                  color: Colors.blue[700]!,
                                ),
                              SizedBox(height: 12),
                              if (_cnnPrediction != null &&
                                  _cnnPrediction!.isNotEmpty)
                                _buildPredictionCard(
                                  title: 'CNN Prediction',
                                  prediction: _cnnPrediction!,
                                  confidence: _cnnConfidence,
                                  color: Colors.purple[700]!,
                                ),
                            ],
                          ),

                        SizedBox(height: 16),

                        // Selection buttons
                        if (_showSelectionButtons)
                          Column(
                            children: [
                              Text(
                                'Select correct letter:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (_mediapipePrediction != null &&
                                      _mediapipePrediction!.isNotEmpty)
                                    _buildLetterButton(_mediapipePrediction!),
                                  if (_cnnPrediction != null &&
                                      _cnnPrediction!.isNotEmpty)
                                    _buildLetterButton(_cnnPrediction!),
                                  _buildLetterButton('None (Retry)'),
                                ],
                              ),
                            ],
                          ),

                        SizedBox(height: 16),

                        // Control buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed:
                                  _isLoading || _isCapturing
                                      ? null
                                      : _captureAndPredict,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _collectedLetters.isEmpty
                                    ? "Start"
                                    : "Capture Next",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            if (_autoCaptureNext)
                              ElevatedButton(
                                onPressed: _stopAutoCapture,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[600],
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  "Stop Auto",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildLetterButton(String letter) {
    return ChoiceChip(
      label: Text(letter),
      selected: false,
      onSelected: (_) {
        if (letter == 'None (Retry)') {
          _captureAndPredict();
        } else {
          _saveLetter(letter);
        }
      },
      selectedColor: Colors.green[200],
    );
  }

  Widget _buildPredictionCard({
    required String title,
    required String prediction,
    double? confidence,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Text(
                prediction,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (confidence != null) ...[
                Spacer(),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 16, color: color.withOpacity(0.8)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
