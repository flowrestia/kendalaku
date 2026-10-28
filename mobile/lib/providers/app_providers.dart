import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../data/models/models.dart';
import '../../data/repositories/kendala_repository.dart';

// ApiClient & Repository Provider
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final repositoryProvider = Provider<KendalaRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return KendalaRepository(apiClient: client);
});

// Auth State
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final User? user;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Run initial auth check
    checkInitialAuth();
    return AuthState();
  }

  Future<void> checkInitialAuth() async {
    final token = await ApiClient.getToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(isAuthenticated: false);
      return;
    }

    try {
      final repo = ref.read(repositoryProvider);
      final user = await repo.getMe();
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
      );
    } catch (_) {
      await ApiClient.clearAuth();
      state = state.copyWith(isAuthenticated: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(repositoryProvider);
      final res = await repo.login(email, password);
      final user = res['user'] as User;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await ApiClient.clearAuth();
    state = AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// Filter State untuk Issues List
class IssueFilterState {
  final String search;
  final String? status;
  final String? prioritas;
  final int? categoryId;
  final dynamic assignedTo; // int atau String 'me'
  final bool? isOverdue;

  IssueFilterState({
    this.search = '',
    this.status,
    this.prioritas,
    this.categoryId,
    this.assignedTo,
    this.isOverdue,
  });

  IssueFilterState copyWith({
    String? search,
    String? status,
    String? prioritas,
    int? categoryId,
    dynamic assignedTo,
    bool? isOverdue,
    bool clearStatus = false,
    bool clearPrioritas = false,
    bool clearCategory = false,
    bool clearAssigned = false,
    bool clearOverdue = false,
  }) {
    return IssueFilterState(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      prioritas: clearPrioritas ? null : (prioritas ?? this.prioritas),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      assignedTo: clearAssigned ? null : (assignedTo ?? this.assignedTo),
      isOverdue: clearOverdue ? null : (isOverdue ?? this.isOverdue),
    );
  }
}

class IssueFilterNotifier extends Notifier<IssueFilterState> {
  @override
  IssueFilterState build() => IssueFilterState();

  void updateFilter(IssueFilterState Function(IssueFilterState) update) {
    state = update(state);
  }

  void reset() {
    state = IssueFilterState();
  }
}

final issueFilterProvider = NotifierProvider<IssueFilterNotifier, IssueFilterState>(IssueFilterNotifier.new);

// Issues List Provider
final issuesListProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final filter = ref.watch(issueFilterProvider);

  return repo.getIssues(
    search: filter.search,
    status: filter.status,
    prioritas: filter.prioritas,
    categoryId: filter.categoryId,
    assignedTo: filter.assignedTo,
    isOverdue: filter.isOverdue,
    limit: 50,
  );
});

// Master Data Providers
final categoriesProvider = FutureProvider.autoDispose<List<ProblemCategory>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getCategories();
});

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getOrders();
});

final usersListProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getUsers();
});

// Single Issue Detail Provider
final issueDetailProvider = FutureProvider.autoDispose.family<OrderIssue, int>((ref, id) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getIssueDetail(id);
});

// Single Issue Transitions Provider
final issueTransitionsProvider = FutureProvider.autoDispose.family<List<IssueTransaction>, int>((ref, id) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getIssueTransitions(id);
});

// ---------------- PROVIDERS FASE 5: DASHBOARD & REPORT ----------------

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getDashboardSummary();
});

final dashboardCategoryStatsProvider = FutureProvider.autoDispose<List<CategoryStat>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getDashboardByCategory();
});

class DashboardTrendPeriodNotifier extends Notifier<String> {
  @override
  String build() => '7d';

  void setPeriod(String p) => state = p;
}

final dashboardTrendPeriodProvider = NotifierProvider.autoDispose<DashboardTrendPeriodNotifier, String>(
  DashboardTrendPeriodNotifier.new,
);

final dashboardTrendProvider = FutureProvider.autoDispose<List<TrendPoint>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final period = ref.watch(dashboardTrendPeriodProvider);
  return repo.getDashboardTrend(period: period);
});

// Report Date Range State
class ReportDateRangeState {
  final DateTime? from;
  final DateTime? to;

  ReportDateRangeState({this.from, this.to});

  ReportDateRangeState copyWith({DateTime? from, DateTime? to, bool clear = false}) {
    if (clear) return ReportDateRangeState();
    return ReportDateRangeState(
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }
}

class ReportDateRangeNotifier extends Notifier<ReportDateRangeState> {
  @override
  ReportDateRangeState build() => ReportDateRangeState();

  void setRange(DateTime? from, DateTime? to) => state = ReportDateRangeState(from: from, to: to);
  void clear() => state = ReportDateRangeState();
}

final reportDateRangeProvider = NotifierProvider.autoDispose<ReportDateRangeNotifier, ReportDateRangeState>(
  ReportDateRangeNotifier.new,
);

final reportRecapProvider = FutureProvider.autoDispose<ReportRecap>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final range = ref.watch(reportDateRangeProvider);
  final fromStr = range.from != null ? '${range.from!.year}-${range.from!.month.toString().padLeft(2, '0')}-${range.from!.day.toString().padLeft(2, '0')}' : null;
  final toStr = range.to != null ? '${range.to!.year}-${range.to!.month.toString().padLeft(2, '0')}-${range.to!.day.toString().padLeft(2, '0')}' : null;
  return repo.getReportRecap(from: fromStr, to: toStr);
});

final activitiesListProvider = FutureProvider.autoDispose<List<ActivityLogItem>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getActivities();
});

// ---------------- PROVIDERS FASE 6: COMMENTS & DUE SOON ----------------

final issueCommentsProvider = FutureProvider.autoDispose.family<List<IssueComment>, int>((ref, issueId) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getComments(issueId);
});

final dueSoonIssuesProvider = FutureProvider.autoDispose<List<OrderIssue>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getIssuesDueSoon(hours: 24);
});

