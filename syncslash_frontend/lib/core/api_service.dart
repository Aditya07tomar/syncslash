import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Deployed backend on Render
  static const String _host = 'https://syncslash-api.onrender.com';
  static const String baseUrl = '$_host/ingestion';
  static const String analyticsUrl = '$_host/analytics';

  // ═══════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════

  /// Send Google ID token to backend, receive app JWT + user info
  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    final response = await http.post(
      Uri.parse('$_host/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'idToken': idToken}),
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      throw Exception('Backend not responding. Is the server running on port 8000?');
    });
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Auth failed (${response.statusCode}): ${response.body}');
  }

  /// Direct login with email + name (when idToken is unavailable)
  Future<Map<String, dynamic>> directLogin(String email, String name) async {
    final response = await http.post(
      Uri.parse('$_host/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'name': name}),
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      throw Exception('Backend not responding');
    });
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Login failed (${response.statusCode}): ${response.body}');
  }

  // ═══════════════════════════════════════════════════════════
  // B1 — INGESTION
  // ═══════════════════════════════════════════════════════════

  /// GET /ingestion/subscriptions/{userId}
  Future<Map<String, dynamic>> getSubscriptions(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/subscriptions/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load subscriptions');
  }

  /// GET /ingestion/summary/{userId}
  Future<Map<String, dynamic>> getSummary(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/summary/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load summary');
  }

  /// GET /ingestion/transactions/{userId}
  Future<Map<String, dynamic>> getTransactions(int userId, {int limit = 50}) async {
    final response = await http.get(Uri.parse('$baseUrl/transactions/$userId?limit=$limit'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load transactions');
  }

  /// POST /ingestion/connect/{userId}
  Future<void> connectBank(int userId) async {
    final response = await http.post(Uri.parse('$baseUrl/connect/$userId'));
    if (response.statusCode != 200) throw Exception('Failed to connect bank');
  }

  /// POST /ingestion/sync/{userId}
  Future<void> syncBankData(int userId) async {
    final response = await http.post(Uri.parse('$baseUrl/sync/$userId'));
    if (response.statusCode != 200) throw Exception('Failed to sync data');
  }

  // ═══════════════════════════════════════════════════════════
  // B2 — ANALYTICS
  // ═══════════════════════════════════════════════════════════

  /// GET /analytics/fatigue/{userId}
  Future<Map<String, dynamic>> getFatigueScores(int userId) async {
    final response = await http.get(Uri.parse('$analyticsUrl/fatigue/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load fatigue scores');
  }

  /// GET /analytics/ghosts/{userId}
  Future<Map<String, dynamic>> getGhostSubscriptions(int userId) async {
    final response = await http.get(Uri.parse('$analyticsUrl/ghosts/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load ghost subscriptions');
  }

  /// GET /analytics/redundancy/{userId}
  Future<Map<String, dynamic>> getRedundancy(int userId) async {
    final response = await http.get(Uri.parse('$analyticsUrl/redundancy/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load redundancy data');
  }

  /// GET /analytics/report/{userId}
  Future<Map<String, dynamic>> getMonthlyReport(int userId) async {
    final response = await http.get(Uri.parse('$analyticsUrl/report/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load monthly report');
  }

  /// GET /analytics/graph/{userId}  — knowledge graph data
  Future<Map<String, dynamic>> getGraphData(int userId) async {
    final response = await http.get(Uri.parse('$analyticsUrl/graph/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load graph data');
  }

  // ═══════════════════════════════════════════════════════════
  // B3 — VIRTUAL CARDS / PAYMENTS
  // ═══════════════════════════════════════════════════════════

  /// POST /virtualcard/create
  Future<Map<String, dynamic>> createVirtualCard(int userId, int subId) async {
    final response = await http.post(
      Uri.parse('$_host/virtualcard/create'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId, 'sub_id': subId}),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to create virtual card');
  }

  /// GET /virtualcards/{userId}
  Future<Map<String, dynamic>> getUserCards(int userId) async {
    final response = await http.get(Uri.parse('$_host/virtualcards/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load virtual cards');
  }

  /// POST /virtualcard/{cardId}/freeze
  Future<Map<String, dynamic>> freezeCard(int cardId) async {
    final response = await http.post(Uri.parse('$_host/virtualcard/$cardId/freeze'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to freeze card');
  }

  /// POST /virtualcard/{cardId}/unfreeze  (Resume)
  Future<Map<String, dynamic>> unfreezeCard(int cardId) async {
    final response = await http.post(Uri.parse('$_host/virtualcard/$cardId/unfreeze'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to unfreeze card');
  }

  /// DELETE /virtualcard/{cardId}
  Future<Map<String, dynamic>> cancelCard(int cardId) async {
    final response = await http.delete(Uri.parse('$_host/virtualcard/$cardId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to cancel card');
  }

  /// POST /payments/simulate
  Future<Map<String, dynamic>> simulatePayment(String cardToken, double amount) async {
    final response = await http.post(
      Uri.parse('$_host/payments/simulate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'card_token': cardToken, 'amount': amount}),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    if (response.statusCode == 403) throw Exception('Card is frozen — payment blocked');
    throw Exception('Payment failed');
  }

  // ═══════════════════════════════════════════════════════════
  // P2P / SHARED BILLS
  // ═══════════════════════════════════════════════════════════

  /// GET /p2p/balances/{userId}
  Future<Map<String, dynamic>> getP2PBalances(int userId) async {
    final response = await http.get(Uri.parse('$_host/p2p/balances/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load P2P balances');
  }

  /// POST /p2p/create
  Future<Map<String, dynamic>> createSharedBill({
    required int subId,
    required int payerId,
    required int debtorId,
    required double amount,
    String? dueDate,
  }) async {
    final response = await http.post(
      Uri.parse('$_host/p2p/create'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'sub_id': subId,
        'payer_id': payerId,
        'debtor_id': debtorId,
        'amount_owed': amount,
        'due_date': dueDate,
      }),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to create shared bill');
  }

  /// POST /p2p/settle
  Future<Map<String, dynamic>> settleBill(int billId) async {
    final response = await http.post(
      Uri.parse('$_host/p2p/settle'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'bill_id': billId}),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to settle bill');
  }

  /// GET /p2p/history/{userId}
  Future<Map<String, dynamic>> getP2PHistory(int userId) async {
    final response = await http.get(Uri.parse('$_host/p2p/history/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load P2P history');
  }

  // ═══════════════════════════════════════════════════════════
  // GROUPS
  // ═══════════════════════════════════════════════════════════

  /// GET /groups/{userId}
  Future<Map<String, dynamic>> getUserGroups(int userId) async {
    final response = await http.get(Uri.parse('$_host/groups/$userId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load groups');
  }

  /// GET /settlement/optimize/{groupId}
  Future<Map<String, dynamic>> optimizeGroupSettlement(int groupId) async {
    final response = await http.get(Uri.parse('$_host/settlement/optimize/$groupId'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to optimize settlement');
  }

  /// POST /groups/create
  Future<Map<String, dynamic>> createGroup({
    required String name,
    required int creatorId,
    required int subId,
  }) async {
    final response = await http.post(
      Uri.parse('$_host/groups/create'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'creator_id': creatorId, 'sub_id': subId}),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to create group');
  }

  /// POST /groups/join
  Future<Map<String, dynamic>> joinGroup({
    required String inviteCode,
    required int userId,
  }) async {
    final response = await http.post(
      Uri.parse('$_host/groups/join'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'invite_code': inviteCode, 'user_id': userId}),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to join group');
  }

  // ═══════════════════════════════════════════════════════════
  // SUBSCRIPTION STATUS (direct freeze/unfreeze without card)
  // ═══════════════════════════════════════════════════════════

  /// POST /subscription/{subId}/freeze
  Future<Map<String, dynamic>> freezeSubscription(int userId, int subId) async {
    final response = await http.post(
      Uri.parse('$_host/subscription/$subId/freeze'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId}),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to freeze subscription');
  }

  /// POST /subscription/{subId}/unfreeze
  Future<Map<String, dynamic>> unfreezeSubscription(int userId, int subId) async {
    final response = await http.post(
      Uri.parse('$_host/subscription/$subId/unfreeze'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId}),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to unfreeze subscription');
  }
}