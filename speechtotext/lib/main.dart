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
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, String>> messages = [];
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Press the button and start speaking';
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
    void _stopListening() {
    if (_speech.isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
        _text = 'Stopped listening';
      });
    }
  }

  Future<void> _startListening() async {
    var status = await permission.Permission.microphone.status;
    if (!status.isGranted) {
      status = await permission.Permission.microphone.request();
      if (!status.isGranted) {
        print('Microphone permission not granted');
        return;
      }
    }

    bool available = await _speech.initialize(
      onStatus: (val) => print('onStatus: $val'),
      onError: (val) => print('onError: $val'),
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) => setState(() {
          _text = val.recognizedWords;
          if (val.hasConfidenceRating && val.confidence > 0) {
            _detectAndTranslate(_text);
          }
        }),
      );
    } else {
      setState(() => _isListening = false);
    }
  }
  Future<void> _detectAndTranslate(String text) async {
    final detectResponse = await http.post(
      Uri.parse('https://translation.googleapis.com/language/translate/v2/detect'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'q': text,
        'key': 'YOUR_GOOGLE_TRANSLATE_API_KEY', // Replace with your Google Translate API key
      }),
    );

    if (detectResponse.statusCode == 200) {
      var detectedLanguage = json.decode(detectResponse.body)['data']['detections'][0][0]['language'];
      setState(() {
        _detectedLanguage = detectedLanguage;
      });

      if (detectedLanguage != 'en') {
        final translateResponse = await http.post(
          Uri.parse('https://translation.googleapis.com/language/translate/v2'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'q': text,
            'target': 'en',
            'key': 'YOUR_GOOGLE_TRANSLATE_API_KEY', // Replace with your Google Translate API key
          }),
        );

        if (translateResponse.statusCode == 200) {
          var translatedText = json.decode(translateResponse.body)['data']['translations'][0]['translatedText'];
          setState(() {
            messages.add({
              'original': text,
              'translated': translatedText,
              'language': detectedLanguage,
            });
          });
        } else {
          throw Exception('Failed to load translation');
        }
      } else {
        setState(() {
          messages.add({
            'original': text,
            'translated': text,
            'language': 'en',
          });
        });
      }
    } else {
      throw Exception('Failed to detect language');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice to Text Chat with Translation'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(messages[index]['original'] ?? ''),
                  subtitle: Text(messages[index]['translated'] ?? ''),
                  trailing: Text(messages[index]['language'] ?? ''),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _text,
                    style: TextStyle(fontSize: 16.0),
                  ),
                ),
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  onPressed: _isListening ? _stopListening : _startListening,
                ),
              ],
            ),
          ),
          Text('Detected Language: $_detectedLanguage'),
        ],
      ),
    );
  }
}
