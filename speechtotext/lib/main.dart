import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart' as permission;


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice to Text Chat with Translation',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, String>> messages = [];
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _rawInput = '';
  String _detectedLanguage = '';

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _speech = stt.SpeechToText();
  }

  Future<void> _requestPermission() async {
    var status = await permission.Permission.microphone.status;
    if (!status.isGranted) {
      await permission.Permission.microphone.request();
    }
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('onStatus: $status');
          if (status == 'done' && _isListening) {
            _stopListening();
            _processInput();
          }

        },
        onError: (val) {
          print('onError: $val');
          setState(() => _isListening = false);
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _rawInput = val.recognizedWords;
          }),
          listenFor: const Duration(seconds: 30),
          localeId: "en-US",
          cancelOnError: true,
        );
      } else {
        setState(() => _isListening = false);
      }
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _processInput() async {
    if (_rawInput.isNotEmpty) {
      await _detectLanguage(_rawInput);
      _printMessage();
    }
  }

  Future<void> _detectLanguage(String text) async {
    final detectResponse = await http.post(
      Uri.parse(
          'https://translation.googleapis.com/language/translate/v2/detect'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'q': text,
        'key':
            'AIzaSyDQMsGVVXorONBCekfpxxYj-RvV12RIHq0', // Replace with your actual Google Translate API key
      }),
    );

    if (detectResponse.statusCode == 200) {
      var detections = json.decode(detectResponse.body)['data']['detections'];
      if (detections.isNotEmpty) {
        setState(() {
          _detectedLanguage = detections[0][0]['language'];
        });
      } else {
        throw Exception('Language detection failed');
      }
    } else {
      throw Exception('Failed to detect language');
    }
  }

  void _printMessage() {
    setState(() {
      messages.add({
        'text': _rawInput,
        'language': _detectedLanguage,
      });
    });
    print('Detected Language: $_detectedLanguage');
    print('Original Text: $_rawInput');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SPEECHtOtEXT'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.teal[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            messages[index]['text'] ?? '',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            messages[index]['language'] ?? '',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _rawInput.isEmpty ? 'Tap mic to start speaking' : _rawInput,
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Detected: $_detectedLanguage',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    FloatingActionButton(
                      onPressed:
                          _isListening ? _stopListening : _startListening,
                      backgroundColor: Colors.teal,
                      child: Icon(_isListening ? Icons.mic : Icons.mic_none),
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
}