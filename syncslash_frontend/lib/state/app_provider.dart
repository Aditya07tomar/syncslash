import 'package:flutter/material.dart';
import '../core/api_service.dart';

class AppProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  int currentUserId = 1;
  String userName = 'User';
  String? jwtToken;

  // ── Loading / Error states ──
  bool isLoading = true;
  bool isAnalyticsLoading = false;
  bool isCardsLoading = false;
  bool isP2PLoading = false;
  String? errorMessage;

  // ── B1 Data ──
  List<dynamic> subscriptions = [];
  Map<String, dynamic>? summaryData;

  // ── B2 Analytics Data ──
  Map<String, dynamic>? fatigueData;
  Map<String, dynamic>? ghostData;
  Map<String, dynamic>? redundancyData;
  Map<String, dynamic>? reportData;
  Map<String, dynamic>? graphData;

  // ── B3 Virtual Cards ──
  List<dynamic> virtualCards = [];

  // ── P2P / Split ──
  Map<String, dynamic>? p2pBalanceData;
  List<dynamic> p2pHistory = [];
  List<dynamic> groups = [];

  // ═══════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════

  void setAuthData(int userId, String name, String token) {
    currentUserId = userId;
    userName = name;
    jwtToken = token;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // B1 — DASHBOARD DATA
  // ═══════════════════════════════════════════════════════════

  Future<void> loadInitialData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getSubscriptions(currentUserId),
        _api.getSummary(currentUserId),
        _api.getUserGroups(currentUserId),
      ]);

      final subData = results[0] as Map<String, dynamic>;
      summaryData = results[1] as Map<String, dynamic>;
      subscriptions = subData['subscriptions'] ?? [];
      final groupData = results[2] as Map<String, dynamic>;
      groups = groupData['groups'] ?? [];
    } catch (e) {
      errorMessage = 'Failed to load dashboard data. Is the backend running?';
      print("Fetch Error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> triggerBankSync() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _api.connectBank(currentUserId);
      await _api.syncBankData(currentUserId);
      await loadInitialData();
    } catch (e) {
      errorMessage = 'Bank sync failed: $e';
      print("Sync Error: $e");
      isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // B2 — ANALYTICS
  // ═══════════════════════════════════════════════════════════

  Future<void> loadAnalytics() async {
    isAnalyticsLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getFatigueScores(currentUserId),
        _api.getGhostSubscriptions(currentUserId),
        _api.getMonthlyReport(currentUserId),
      ]);

      fatigueData = results[0] as Map<String, dynamic>;
      ghostData = results[1] as Map<String, dynamic>;
      reportData = results[2] as Map<String, dynamic>;
    } catch (e) {
      print("Analytics Error: $e");
    } finally {
      isAnalyticsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRedundancy() async {
    try {
      redundancyData = await _api.getRedundancy(currentUserId);
      notifyListeners();
    } catch (e) {
      print("Redundancy Error: $e");
    }
  }

  Future<void> loadGraphData() async {
    try {
      graphData = await _api.getGraphData(currentUserId);
      notifyListeners();
    } catch (e) {
      print("Graph Error: $e");
    }
  }

  // ═══════════════════════════════════════════════════════════
  // B3 — VIRTUAL CARDS
  // ═══════════════════════════════════════════════════════════

  Future<void> loadVirtualCards() async {
    isCardsLoading = true;
    notifyListeners();
    try {
      final data = await _api.getUserCards(currentUserId);
      virtualCards = data['cards'] ?? [];
    } catch (e) {
      print("Cards Error: $e");
    } finally {
      isCardsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createVirtualCard(int subId) async {
    try {
      await _api.createVirtualCard(currentUserId, subId);
      await loadVirtualCards();
      return true;
    } catch (e) {
      print("Create Card Error: $e");
      return false;
    }
  }

  Future<bool> freezeCard(int cardId) async {
    try {
      await _api.freezeCard(cardId);
      await loadVirtualCards();
      await loadInitialData(); // refresh subscription statuses
      return true;
    } catch (e) {
      print("Freeze Error: $e");
      return false;
    }
  }

  Future<bool> unfreezeCard(int cardId) async {
    try {
      await _api.unfreezeCard(cardId);
      await loadVirtualCards();
      await loadInitialData();
      return true;
    } catch (e) {
      print("Unfreeze Error: $e");
      return false;
    }
  }

  Future<bool> cancelCard(int cardId) async {
    try {
      await _api.cancelCard(cardId);
      await loadVirtualCards();
      await loadInitialData();
      return true;
    } catch (e) {
      print("Cancel Card Error: $e");
      return false;
    }
  }

  // Kill switch (local + backend)
  void triggerKillSwitch(int subId) {
    final index = subscriptions.indexWhere((s) => s['sub_id'] == subId);
    if (index != -1) {
      subscriptions[index]['status'] = 'frozen';
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // P2P / SPLIT
  // ═══════════════════════════════════════════════════════════

  Future<void> loadP2PData() async {
    isP2PLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getP2PBalances(currentUserId),
        _api.getP2PHistory(currentUserId),
        _api.getUserGroups(currentUserId),
      ]);
      p2pBalanceData = results[0] as Map<String, dynamic>;
      final historyData = results[1] as Map<String, dynamic>;
      p2pHistory = historyData['history'] ?? [];
      final groupData = results[2] as Map<String, dynamic>;
      groups = groupData['groups'] ?? [];
    } catch (e) {
      print("P2P Error: $e");
    } finally {
      isP2PLoading = false;
      notifyListeners();
    }
  }

  Future<bool> settleBill(int billId) async {
    try {
      await _api.settleBill(billId);
      await loadP2PData();
      return true;
    } catch (e) {
      print("Settle Error: $e");
      return false;
    }
  }

  Future<bool> createSharedBill({
    required int subId,
    required int debtorId,
    required double amount,
    String? dueDate,
  }) async {
    try {
      await _api.createSharedBill(
        subId: subId,
        payerId: currentUserId,
        debtorId: debtorId,
        amount: amount,
        dueDate: dueDate,
      );
      await loadP2PData();
      return true;
    } catch (e) {
      print("Create Bill Error: $e");
      return false;
    }
  }

  Future<bool> createGroup({required String name, required int subId}) async {
    try {
      await _api.createGroup(name: name, creatorId: currentUserId, subId: subId);
      await loadP2PData();
      return true;
    } catch (e) {
      print("Create Group Error: $e");
      return false;
    }
  }

  Future<bool> joinGroup({required String inviteCode}) async {
    try {
      await _api.joinGroup(inviteCode: inviteCode, userId: currentUserId);
      await loadP2PData();
      return true;
    } catch (e) {
      print("Join Group Error: $e");
      return false;
    }
  }

  // --- C++ Engine Settlement Optimization ---
  Map<int, Map<String, dynamic>> optimizedSettlementData = {};
  bool isOptimizing = false;

  Future<void> optimizeGroupSettlement(int groupId) async {
    isOptimizing = true;
    notifyListeners();
    try {
      final data = await _api.optimizeGroupSettlement(groupId);
      optimizedSettlementData[groupId] = data;
    } catch (e) {
      print("Optimization Error: $e");
    } finally {
      isOptimizing = false;
      notifyListeners();
    }
  }
}