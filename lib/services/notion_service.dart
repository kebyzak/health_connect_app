import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotionService {
  static const String _baseUrl = 'https://api.notion.com/v1';
  late final String _apiKey;
  late final String _databaseId;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('notion_api_key') ?? '';
    _databaseId = prefs.getString('notion_database_id') ?? '';
  }

  Future<void> saveCredentials(String apiKey, String databaseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notion_api_key', apiKey);
    await prefs.setString('notion_database_id', databaseId);
    _apiKey = apiKey;
    _databaseId = databaseId;
  }

  Future<bool> addSleepData(Map<String, dynamic> sleepData) async {
    if (_apiKey.isEmpty || _databaseId.isEmpty) {
      print('Notion credentials not set');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/pages'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'parent': {'database_id': _databaseId},
          'properties': {
            'Date': {
              'date': {
                'start': sleepData['date'],
              }
            },
            'Sleep Duration': {
              'number': sleepData['duration'],
            },
            'Sleep Quality': {
              'select': {
                'name': sleepData['quality'],
              }
            },
            'Notes': {
              'rich_text': [
                {
                  'text': {
                    'content': sleepData['notes'] ?? '',
                  }
                }
              ]
            }
          }
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending data to Notion: $e');
      return false;
    }
  }
}
