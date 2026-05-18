// lib/main.dart
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiService(baseUrl: kBaseUrl);
  final auth = AuthService(api);
  await auth.initialize();

  runApp(ChatbotApp(authService: auth, apiService: api));
}

class ChatbotApp extends StatelessWidget {
  final AuthService authService;
  final ApiService apiService;
  const ChatbotApp({super.key, required this.authService, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chatbot',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: authService.isAuthenticated
          ? ChatScreen(authService: authService, apiService: apiService)
          : LoginScreen(authService: authService, apiService: apiService),
    );
  }
}
