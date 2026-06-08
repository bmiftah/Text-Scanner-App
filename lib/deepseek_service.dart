import 'dart:convert';
import 'package:http/http.dart' as http;

class ExtractedContact {
  String name;
  String email;
  String phone;
  String website;
  String notes;

  ExtractedContact({
    required this.name,
    required this.email,
    required this.phone,
    required this.website,
    required this.notes,
  });
}

class DeepSeekService {
  static const String apiKey = 'sk-3e6e773477764f9e9920a1bf576ccebf';
  static const String apiUrl = 'https://api.deepseek.com/v1/chat/completions';

  Future<ExtractedContact> extractContactInfo(String scannedText) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-v4-flash',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a business card analyzer. Extract contact information. Return ONLY in JSON: {"name":"","email":"","phone":"","website":"","notes":""} Use empty string if not found.'
            },
            {'role': 'user', 'content': scannedText}
          ],
          'temperature': 0.2,
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'];
        
        try {
          final jsonData = jsonDecode(aiResponse);
          return ExtractedContact(
            name: jsonData['name'] ?? '',
            email: jsonData['email'] ?? '',
            phone: jsonData['phone'] ?? '',
            website: jsonData['website'] ?? '',
            notes: jsonData['notes'] ?? '',
          );
        } catch (e) {
          return ExtractedContact(
            name: '',
            email: '',
            phone: '',
            website: '',
            notes: aiResponse.length > 200 ? aiResponse.substring(0, 200) : aiResponse,
          );
        }
      } else {
        return ExtractedContact(
          name: '',
          email: '',
          phone: '',
          website: '',
          notes: 'API Error: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ExtractedContact(
        name: '',
        email: '',
        phone: '',
        website: '',
        notes: 'Error: $e',
      );
    }
  }
}