import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/logging_service.dart';
import '../../auth/services/auth_service.dart';
import '../models/eco_ledger_model.dart';

class EcoLedgerState {
  final int currentBalance;
  final List<EcoLedgerEntry> transactions;
  final bool isLoading;
  final String? errorMessage;

  const EcoLedgerState({
    this.currentBalance = 0,
    this.transactions = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  EcoLedgerState copyWith({
    int? currentBalance,
    List<EcoLedgerEntry>? transactions,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EcoLedgerState(
      currentBalance: currentBalance ?? this.currentBalance,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class EcoLedgerNotifier extends StateNotifier<EcoLedgerState> {
  final Ref _ref;
  final FirebaseFirestore? _firestore;
  static const String _localLedgerPrefix = 'evora_eco_ledger_entries_';
  static const String _genesisHash = 'GENESIS_BLOCK_EVORA_DOON_V1';

  Future<void>? _loadFuture;

  EcoLedgerNotifier(this._ref, {FirebaseFirestore? firestore})
      : _firestore = firestore ?? _resolveFirestore(),
        super(const EcoLedgerState()) {
    _initForCurrentUser();
  }

  static FirebaseFirestore? _resolveFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  void _initForCurrentUser() {
    final user = _ref.read(authProvider).user;
    if (user != null) {
      _loadFuture = loadLedgerForUser(user.uid);
    }
  }

  /// Loads transactions and derives verified balance for a given citizen
  Future<void> loadLedgerForUser(String uid) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final entries = await _fetchEntries(uid);
      final existingIds = state.transactions.map((t) => t.id).toSet();
      final mergedEntries = [
        ...state.transactions,
        ...entries.where((e) => !existingIds.contains(e.id)),
      ];
      final balance = mergedEntries.isNotEmpty ? mergedEntries.first.balanceAfter : 0;

      state = state.copyWith(
        currentBalance: balance,
        transactions: mergedEntries,
        isLoading: false,
      );
    } catch (e) {
      LoggingService.logError('[EcoLedger] Failed loading ledger for $uid: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Appends a new verified transaction to the ledger with cryptographic hash chaining
  Future<EcoLedgerEntry> appendTransaction({
    required String userId,
    required EcoLedgerTransactionType type,
    required int amount,
    required String referenceId,
    required String title,
    required String description,
  }) async {
    if (_loadFuture != null) {
      await _loadFuture;
    }
    final cid = LoggingService.generateCorrelationId();
    final now = DateTime.now();
    final id = 'tx_${const Uuid().v4()}';

    // 1. Get previous transaction hash to ensure hash-chain immutability
    final previousHash = state.transactions.isNotEmpty
        ? state.transactions.first.hash
        : _genesisHash;

    final newBalance = state.currentBalance + amount;

    // 2. Compute tamper-evident SHA-256 hash
    final hash = EcoLedgerEntry.computeHash(
      previousHash: previousHash,
      id: id,
      userId: userId,
      amount: amount,
      balanceAfter: newBalance,
      timestamp: now,
    );

    final entry = EcoLedgerEntry(
      id: id,
      tenantId: AppConstants.defaultTenantId,
      userId: userId,
      type: type,
      amount: amount,
      balanceAfter: newBalance,
      referenceId: referenceId,
      title: title,
      description: description,
      timestamp: now,
      previousHash: previousHash,
      hash: hash,
    );

    // 3. Persist to Firestore if available
    if (_firestore != null) {
      try {
        final docRef = _firestore
            .collection(AppConstants.colTenants)
            .doc(AppConstants.defaultTenantId)
            .collection(AppConstants.subColEcoCoinLedger)
            .doc(id);

        await docRef.set(entry.toJson());

        // Update user snapshot in users/{uid}
        await _firestore
            .collection(AppConstants.colUsers)
            .doc(userId)
            .update({'ecoCoinBalance': newBalance});
      } catch (e) {
        LoggingService.logBreadcrumb(
          '[EcoLedger] Cloud Firestore append warning (falling back to disk): $e',
          correlationId: cid,
        );
      }
    }

    // 4. Update in-memory state and persistent local cache
    final updatedList = [entry, ...state.transactions];
    state = state.copyWith(
      currentBalance: newBalance,
      transactions: updatedList,
    );

    await _saveEntriesToDisk(userId, updatedList);

    LoggingService.logBreadcrumb(
      '[EcoLedger] Appended transaction $id: ${amount >= 0 ? "+$amount" : amount} ($title). Balance: $newBalance',
      correlationId: cid,
    );

    return entry;
  }

  /// Verifies the cryptographic integrity of the ledger chain
  bool verifyLedgerIntegrity() {
    if (state.transactions.isEmpty) return true;

    for (int i = 0; i < state.transactions.length; i++) {
      final current = state.transactions[i];
      if (!current.verifyIntegrity()) {
        return false;
      }

      // Check link to previous block
      if (i < state.transactions.length - 1) {
        final older = state.transactions[i + 1];
        if (current.previousHash != older.hash) {
          return false;
        }
      }
    }
    return true;
  }

  Future<List<EcoLedgerEntry>> _fetchEntries(String uid) async {
    // 1. Try Firestore first
    if (_firestore != null) {
      try {
        final snap = await _firestore
            .collection(AppConstants.colTenants)
            .doc(AppConstants.defaultTenantId)
            .collection(AppConstants.subColEcoCoinLedger)
            .where('userId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .get();

        if (snap.docs.isNotEmpty) {
          final entries = snap.docs.map((d) => EcoLedgerEntry.fromJson(d.data())).toList();
          await _saveEntriesToDisk(uid, entries);
          return entries;
        }
      } catch (e) {
        debugPrint('[EcoLedger] Firestore query error: $e');
      }
    }

    // 2. Fall back to local disk storage
    return await _loadEntriesFromDisk(uid);
  }

  Future<void> _saveEntriesToDisk(String uid, List<EcoLedgerEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = entries.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('$_localLedgerPrefix$uid', rawList);
    } catch (_) {}
  }

  Future<List<EcoLedgerEntry>> _loadEntriesFromDisk(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList('$_localLedgerPrefix$uid');
      if (rawList != null && rawList.isNotEmpty) {
        return rawList
            .map((str) => EcoLedgerEntry.fromJson(jsonDecode(str) as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}

/// Global Riverpod Provider for Eco Coins Ledger
final ecoLedgerProvider =
    StateNotifierProvider<EcoLedgerNotifier, EcoLedgerState>((ref) {
  return EcoLedgerNotifier(ref);
});
