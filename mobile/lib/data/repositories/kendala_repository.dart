import '../../core/network/api_client.dart';
import '../models/models.dart';

class KendalaRepository {
  final ApiClient apiClient;

  KendalaRepository({required this.apiClient});

  // Auth: Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await apiClient.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    await ApiClient.saveToken(token);
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    return {'token': token, 'user': user};
  }

  // Auth: Me
  Future<User> getMe() async {
    final response = await apiClient.dio.get('/auth/me');
    final data = response.data['data'] as Map<String, dynamic>;
    return User.fromJson(data);
  }

  // Users: Petugas / Staf
  Future<List<User>> getUsers() async {
    final response = await apiClient.dio.get('/users');
    final list = (response.data['data'] as List?) ?? const [];
    return list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Categories
  Future<List<ProblemCategory>> getCategories() async {
    final response = await apiClient.dio.get('/categories');
    final list = (response.data['data'] as List?) ?? const [];
    return list.map((e) => ProblemCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Orders Simulasi
  Future<List<Order>> getOrders() async {
    final response = await apiClient.dio.get('/orders');
    final list = (response.data['data'] as List?) ?? const [];
    return list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Issues: List
  Future<Map<String, dynamic>> getIssues({
    String? search,
    String? status,
    String? prioritas,
    int? categoryId,
    dynamic assignedTo, // int atau "me"
    bool? isOverdue,
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (prioritas != null && prioritas.isNotEmpty) queryParams['prioritas'] = prioritas;
    if (categoryId != null && categoryId > 0) queryParams['category_id'] = categoryId;
    if (assignedTo != null && assignedTo.toString().isNotEmpty) {
      queryParams['assigned_to'] = assignedTo.toString();
    }
    if (isOverdue != null) queryParams['is_overdue'] = isOverdue;

    final response = await apiClient.dio.get(
      '/issues',
      queryParameters: queryParams,
    );

    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final itemsList = (data['items'] as List?) ?? const [];
    final items = itemsList.map((e) => OrderIssue.fromJson(e as Map<String, dynamic>)).toList();
    final total = data['total'] as int? ?? items.length;

    return {'items': items, 'total': total};
  }

  // Issues: Detail
  Future<OrderIssue> getIssueDetail(int id) async {
    final response = await apiClient.dio.get('/issues/$id');
    final data = response.data['data'] as Map<String, dynamic>;
    return OrderIssue.fromJson(data);
  }

  // Issues: Create
  Future<OrderIssue> createIssue({
    required int orderId,
    required int categoryId,
    required String judul,
    required String deskripsi,
    required String prioritas,
    int? assignedTo,
  }) async {
    final payload = <String, dynamic>{
      'order_id': orderId,
      'category_id': categoryId,
      'judul': judul,
      'deskripsi': deskripsi,
      'prioritas': prioritas,
    };
    if (assignedTo != null && assignedTo > 0) {
      payload['assigned_to'] = assignedTo;
    }

    final response = await apiClient.dio.post('/issues', data: payload);
    final data = response.data['data'] as Map<String, dynamic>;
    return OrderIssue.fromJson(data);
  }

  // Issues: Update
  Future<void> updateIssue({
    required int id,
    required String judul,
    required String deskripsi,
    required String prioritas,
    int? assignedTo,
  }) async {
    final payload = <String, dynamic>{
      'judul': judul,
      'deskripsi': deskripsi,
      'prioritas': prioritas,
    };
    if (assignedTo != null && assignedTo > 0) {
      payload['assigned_to'] = assignedTo;
    }

    await apiClient.dio.put('/issues/$id', data: payload);
  }

  // Issues: Transitions History
  Future<List<IssueTransaction>> getIssueTransitions(int id) async {
    final response = await apiClient.dio.get('/issues/$id/transitions');
    final list = (response.data['data'] as List?) ?? const [];
    return list.map((e) => IssueTransaction.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Issues: Execute Transition
  Future<OrderIssue> transitionStatus({
    required int id,
    required String statusBaru,
    required String catatanTindakan,
    String? catatanPenyelesaian,
  }) async {
    final payload = <String, dynamic>{
      'status_baru': statusBaru,
      'catatan_tindakan': catatanTindakan,
      'catatan_penyelesaian': catatanPenyelesaian ?? '',
    };

    final response = await apiClient.dio.post('/issues/$id/transitions', data: payload);
    final data = response.data['data'] as Map<String, dynamic>;
    return OrderIssue.fromJson(data);
  }

  // Categories CRUD
  Future<ProblemCategory> createCategory({
    required String nama,
    required String warnaHex,
    required String ikon,
    required int tenggatJam,
    bool aktif = true,
  }) async {
    final payload = {
      'nama': nama,
      'warna_hex': warnaHex,
      'ikon': ikon,
      'tenggat_jam': tenggatJam,
      'aktif': aktif,
    };
    final response = await apiClient.dio.post('/categories', data: payload);
    final data = response.data['data'] as Map<String, dynamic>;
    return ProblemCategory.fromJson(data);
  }

  Future<ProblemCategory> updateCategory({
    required int id,
    required String nama,
    required String warnaHex,
    required String ikon,
    required int tenggatJam,
    required bool aktif,
  }) async {
    final payload = {
      'nama': nama,
      'warna_hex': warnaHex,
      'ikon': ikon,
      'tenggat_jam': tenggatJam,
      'aktif': aktif,
    };
    final response = await apiClient.dio.put('/categories/$id', data: payload);
    final data = response.data['data'] as Map<String, dynamic>;
    return ProblemCategory.fromJson(data);
  }

  Future<void> deleteCategory(int id) async {
    await apiClient.dio.delete('/categories/$id');
  }

  // Dashboard API
  Future<DashboardSummary> getDashboardSummary() async {
    final response = await apiClient.dio.get('/dashboard/summary');
    final data = response.data['data'] as Map<String, dynamic>;
    return DashboardSummary.fromJson(data);
  }

  Future<List<CategoryStat>> getDashboardByCategory() async {
    final response = await apiClient.dio.get('/dashboard/by-category');
    final list = (response.data['data'] as List?) ?? const [];
    return list.map((e) => CategoryStat.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TrendPoint>> getDashboardTrend({String period = '7d'}) async {
    final response = await apiClient.dio.get('/dashboard/trend', queryParameters: {'period': period});
    final list = (response.data['data'] as List?) ?? const [];
    return list.map((e) => TrendPoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Reports API
  Future<ReportRecap> getReportRecap({String? from, String? to}) async {
    final q = <String, dynamic>{};
    if (from != null && from.isNotEmpty) q['from'] = from;
    if (to != null && to.isNotEmpty) q['to'] = to;
    final response = await apiClient.dio.get('/reports/recap', queryParameters: q);
    final data = response.data['data'] as Map<String, dynamic>;
    return ReportRecap.fromJson(data);
  }

  Future<String> exportReportCsv({String? from, String? to}) async {
    final q = <String, dynamic>{};
    if (from != null && from.isNotEmpty) q['from'] = from;
    if (to != null && to.isNotEmpty) q['to'] = to;
    final response = await apiClient.dio.get<String>(
      '/reports/export.csv',
      queryParameters: q,
    );
    return response.data ?? '';
  }

  // Activities API
  Future<List<ActivityLogItem>> getActivities({int limit = 50}) async {
    final response = await apiClient.dio.get('/activities', queryParameters: {'limit': limit});
    final list = (response.data['data'] as List?) ?? const [];
    return list.map((e) => ActivityLogItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Share Text WhatsApp (Fase 6B)
  Future<ShareTextResult> getShareText({
    String? search,
    String? status,
    String? prioritas,
    int? categoryId,
    dynamic assignedTo, // int atau "me"
    String? from,
    String? to,
    bool? isOverdue,
    List<int>? ids,
    bool includeCustomer = true,
  }) async {
    final q = <String, dynamic>{
      'include_customer': includeCustomer.toString(),
    };
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (status != null && status.isNotEmpty) q['status'] = status;
    if (prioritas != null && prioritas.isNotEmpty) q['prioritas'] = prioritas;
    if (categoryId != null && categoryId > 0) q['category_id'] = categoryId;
    if (assignedTo != null) q['assigned_to'] = assignedTo.toString();
    if (from != null && from.isNotEmpty) q['from'] = from;
    if (to != null && to.isNotEmpty) q['to'] = to;
    if (isOverdue != null) q['is_overdue'] = isOverdue.toString();
    if (ids != null && ids.isNotEmpty) q['ids'] = ids.join(',');

    final response = await apiClient.dio.get(
      '/share/issues',
      queryParameters: q,
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return ShareTextResult.fromJson(data);
  }

  // ---------------- FASE 6: COMMENTS, REASSIGN, DUE-SOON ----------------

  // Komentar: GET /issues/:id/comments
  Future<List<IssueComment>> getComments(int issueId) async {
    final response = await apiClient.dio.get('/issues/$issueId/comments');
    final list = (response.data['data'] as List?) ?? const [];
    return list.map((e) => IssueComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Komentar: POST /issues/:id/comments
  Future<IssueComment> addComment(int issueId, String isi) async {
    final response = await apiClient.dio.post(
      '/issues/$issueId/comments',
      data: {'isi': isi},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return IssueComment.fromJson(data);
  }

  // Reassign: PATCH /issues/:id/assign
  Future<void> reassignIssue(int issueId, int assignedTo, {String? catatan}) async {
    final payload = <String, dynamic>{
      'assigned_to': assignedTo,
    };
    if (catatan != null && catatan.trim().isNotEmpty) {
      payload['catatan'] = catatan.trim();
    }
    await apiClient.dio.patch('/issues/$issueId/assign', data: payload);
  }

  // Due Soon: GET /dashboard/due-soon?hours=24
  Future<List<OrderIssue>> getIssuesDueSoon({int hours = 24}) async {
    final response = await apiClient.dio.get(
      '/dashboard/due-soon',
      queryParameters: {'hours': hours},
    );
    final list = (response.data['data'] as List?) ?? const [];
    return list.map((e) => OrderIssue.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Auth: PUT /auth/password (Fase 7)
  Future<void> changePassword(String passwordLama, String passwordBaru) async {
    await apiClient.dio.put(
      '/auth/password',
      data: {
        'password_lama': passwordLama,
        'password_baru': passwordBaru,
      },
    );
  }
}
