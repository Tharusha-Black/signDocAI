import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.7:5000'; // Base URL
  static WebSocketChannel? _channel;
  // Login API call
  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/user_services/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body); // Return parsed JSON response
      } else {
        return {'error': 'Invalid credentials'};
      }
    } catch (e) {
      return {'error': 'Failed to connect to the server'};
    }
  }

  static Future<Map<String, dynamic>?> createUser(
    Map<String, String> userData,
  ) async {
    print("Sending registration request with data: $userData");

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user_services/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body); // Successful registration
      } else {
        return {'error': 'Failed to create user. Please try again.'};
      }
    } catch (e) {
      return {'error': 'An error occurred: $e'};
    }
  }

  static Future<Map<String, dynamic>?> postToPredictFromDocument(
    String base64Image,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai_services/predict-from-document'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image_base64': base64Image}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  static Future<void> submitCorrection(
    String predictedText,
    String correctedName,
  ) async {
    await http.post(
      Uri.parse('$baseUrl/ai_services/submit-correction'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'predicted_text': predictedText,
        'corrected_name': correctedName,
      }),
    );
  }

  static void initializeWebSocket(String wsUrl, Function(String) onMessage) {
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel!.stream.listen((message) {
      onMessage(message); // callback to update UI
    });
  }

  static void sendFrame(String base64Image) {
    if (_channel != null) {
      _channel!.sink.add(base64Image);
    }
  }

  static void closeWebSocket() {
    _channel?.sink.close();
  }
}
