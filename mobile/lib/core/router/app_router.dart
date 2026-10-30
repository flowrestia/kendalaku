import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../views/auth/login_screen.dart';
import '../../views/categories/manage_categories_screen.dart';
import '../../views/dashboard/dashboard_screen.dart';
import '../../views/error/error_screens.dart';
import '../../views/issues/issue_detail_screen.dart';
import '../../views/issues/issue_wizard_screen.dart';
import '../../views/issues/issues_list_screen.dart';
import '../../views/reports/reports_screen.dart';
import '../../views/settings/settings_screen.dart';
import '../../views/shell/main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final loc = state.matchedLocation;
      final isLoggingIn = loc == '/login';
      final isPublicError = loc == '/403' || loc == '/500';

      if (isPublicError) {
        return null;
      }

      if (!isAuth && !isLoggingIn) {
        return '/login';
      }
      if (isAuth && isLoggingIn) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/403',
        builder: (context, state) => const ForbiddenScreen(),
      ),
      GoRoute(
        path: '/500',
        builder: (context, state) => const ServerErrorScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/issues',
            builder: (context, state) => const IssuesListScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const IssueWizardScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
                  return IssueDetailScreen(issueId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) => const ManageCategoriesScreen(),
          ),
        ],
      ),
    ],
  );
});
