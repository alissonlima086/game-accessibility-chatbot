// lib/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/admin_service.dart';
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/crawler_management_screen.dart';
import 'screens/user_management_screen.dart';

// Rotas nomeadas — use AppRoutes.chat em vez de strings cruas
abstract class AppRoutes {
  static const login   = '/login';
  static const chat    = '/';
  static const profile = '/perfil';
  static const admin   = '/admin';
  static const adminCrawler = '/admin/crawler';
  static const adminUsers   = '/admin/usuarios';
}

GoRouter buildRouter({
  required AuthService authService,
  required ApiService apiService,
}) {
  final adminService = AdminService(apiService);

  return GoRouter(
    initialLocation: authService.isAuthenticated ? AppRoutes.chat : AppRoutes.login,
    debugLogDiagnostics: false,

    // Redirect: protege rotas autenticadas e evita loop de login
    redirect: (context, state) {
      final loggedIn  = authService.isAuthenticated;
      final onLogin   = state.matchedLocation == AppRoutes.login;

      if (!loggedIn && !onLogin) return AppRoutes.login;
      if (loggedIn  &&  onLogin) return AppRoutes.chat;
      return null;
    },

    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => _fade(
          state,
          LoginScreen(authService: authService, apiService: apiService),
        ),
      ),

      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        pageBuilder: (context, state) => _fade(
          state,
          ChatScreen(authService: authService, apiService: apiService),
        ),
      ),

      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        pageBuilder: (context, state) => _slide(
          state,
          ProfileScreen(
            authService: authService,
            apiService: apiService,
            onLogout: () => context.go(AppRoutes.login),
          ),
        ),
      ),

      GoRoute(
        path: AppRoutes.admin,
        name: 'admin',
        redirect: (context, state) =>
            authService.currentUser?.role == 'ADMIN' ? null : AppRoutes.chat,
        pageBuilder: (context, state) => _slide(
          state,
          AdminPanelScreen(adminService: adminService),
        ),
        routes: [
          GoRoute(
            path: 'crawler',
            name: 'adminCrawler',
            pageBuilder: (context, state) => _slide(
              state,
              CrawlerManagementScreen(adminService: adminService),
            ),
          ),
          GoRoute(
            path: 'usuarios',
            name: 'adminUsers',
            pageBuilder: (context, state) => _slide(
              state,
              UserManagementScreen(adminService: adminService),
            ),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Text(
          'Página não encontrada: ${state.uri}',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    ),
  );
}

// ── Transições ────────────────────────────────────────────────────────────────

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

CustomTransitionPage<void> _slide(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    );
