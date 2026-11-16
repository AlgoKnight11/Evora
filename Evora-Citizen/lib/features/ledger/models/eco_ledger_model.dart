import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Categories of transactions recorded in the append-only ledger
enum EcoLedgerTransactionType {
  creditMission,
  creditDailyHabit,
  creditCivicParticipation,
  debitRewardClaim,
  adjustment;

  String get label {
    switch (this) {
      case EcoLedgerTransactionType.creditMission:
        return 'Mission Completed';
      case EcoLedgerTransactionType.creditDailyHabit:
        return 'Daily Eco Action';
      case EcoLedgerTransactionType.creditCivicParticipation:
        return 'Civic Action';
      case EcoLedgerTransactionType.debitRewardClaim:
        return 'Perk Redemption';
      case EcoLedgerTransactionType.adjustment:
        return 'Ledger Adjustment';
    }
  }

  bool get isCredit => this != EcoLedgerTransactionType.debitRewardClaim;
}

/// Cryptographically chained append-only ledger transaction record
class EcoLedgerEntry {
  final String id;
  final String tenantId;
  final String userId;
  final EcoLedgerTransactionType type;
  final int amount; // positive for credits, negative for debits
  final int balanceAfter;
  final String referenceId; // missionId, caseId, or date
  final String title;
  final String description;
  final DateTime timestamp;
  final String previousHash;
  final String hash;

  const EcoLedgerEntry({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.referenceId,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.previousHash,
    required this.hash,
  });

  /// Computes a deterministic SHA-256 tamper-evident hash for the transaction
  static String computeHash({
    required String previousHash,
    required String id,
    required String userId,
    required int amount,
    required int balanceAfter,
    required DateTime timestamp,
  }) {
    final payload =
        '$previousHash|$id|$userId|$amount|$balanceAfter|${timestamp.toIso8601String()}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Verifies whether the entry's hash matches its contents and previous link
  bool verifyIntegrity() {
    final expected = computeHash(
      previousHash: previousHash,
      id: id,
      userId: userId,
      amount: amount,
      balanceAfter: balanceAfter,
      timestamp: timestamp,
    );
    return expected == hash;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'userId': userId,
        'type': type.name,
        'amount': amount,
        'balanceAfter': balanceAfter,
        'referenceId': referenceId,
        'title': title,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'previousHash': previousHash,
        'hash': hash,
      };

  factory EcoLedgerEntry.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'creditDailyHabit';
    final type = EcoLedgerTransactionType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => EcoLedgerTransactionType.creditDailyHabit,
    );

    return EcoLedgerEntry(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? 'tenant_dehradun_01',
      userId: json['userId'] as String? ?? '',
      type: type,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balanceAfter'] as num?)?.toInt() ?? 0,
      referenceId: json['referenceId'] as String? ?? '',
      title: json['title'] as String? ?? 'Eco Action',
      description: json['description'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      previousHash: json['previousHash'] as String? ?? 'GENESIS_BLOCK_0',
      hash: json['hash'] as String? ?? '',
    );
  }

  /// Mandatory DPDP & Indian Financial Regulations legal disclosure
  static const String legalDisclaimer =
      'EcoCoins are strictly in-app civic recognition points. They hold zero monetary value, '
      'cannot be traded, transferred, or exchanged for fiat currency or cryptocurrency, '
      'and do not constitute accredited carbon credits under the Kyoto Protocol or Paris Agreement.';
}
