import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/evora_colors.dart';
import '../models/eco_ledger_model.dart';
import '../services/eco_ledger_service.dart';

class EcoLedgerHistoryScreen extends ConsumerWidget {
  const EcoLedgerHistoryScreen({super.key});

  void _showTransactionDetails(BuildContext context, EcoLedgerEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final rawBottom = [
          media.padding.bottom,
          media.viewPadding.bottom,
          media.viewInsets.bottom,
        ].reduce((a, b) => a > b ? a : b);
        final bottomInset = rawBottom > 0 ? (rawBottom + 16.0) : 56.0;

        return Container(
          padding: EdgeInsets.fromLTRB(22, 16, 22, bottomInset),
          decoration: const BoxDecoration(
            color: EvoraColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EvoraColors.outlineVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: EvoraColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_clock_outlined, color: EvoraColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Cryptographic Transaction Audit',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAuditRow('Transaction ID', entry.id),
              _buildAuditRow('Type', entry.type.label),
              _buildAuditRow('Amount', '${entry.amount >= 0 ? "+" : ""}${entry.amount} EcoCoins'),
              _buildAuditRow('Balance Snapshot', '${entry.balanceAfter} EcoCoins'),
              _buildAuditRow('Reference ID', entry.referenceId),
              _buildAuditRow('Timestamp', DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp)),
              _buildAuditRow('Previous Block Hash', entry.previousHash),
              _buildAuditRow('SHA-256 Chained Hash', entry.hash),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.verifyIntegrity()
                            ? 'Tamper-Evident Hash Verified (Matches Ledger Payload)'
                            : 'Hash Integrity Mismatch Warning',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: entry.verifyIntegrity() ? Colors.green.shade800 : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildAuditRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant)),
          const SizedBox(height: 1),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerState = ref.watch(ecoLedgerProvider);
    final transactions = ledgerState.transactions;
    final isChainValid = ref.read(ecoLedgerProvider.notifier).verifyLedgerIntegrity();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eco Coins Ledger', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Balance Banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    EvoraColors.primary,
                    Colors.teal.shade800,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: EvoraColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Verified Citizen Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isChainValid ? Icons.verified : Icons.warning_amber,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isChainValid ? 'Ledger Verified' : 'Audit Alert',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${ledgerState.currentBalance}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'EcoCoins',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Append-only ledger with cryptographic SHA-256 block hash chaining. Immutable proof of citizen actions.',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                  ),
                ],
              ),
            ),

            // 2. Legal Non-Monetary Compliance Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: EvoraColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: EvoraColors.onSurfaceVariant),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'In-app recognition points only. Zero cash/monetary value under DPDP Act & Indian regulations.',
                      style: TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Transactions List Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                children: [
                  const Text(
                    'Transaction History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${transactions.length} entries',
                    style: const TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            // 4. Transactions List
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 52, color: EvoraColors.outline),
                            const SizedBox(height: 14),
                            const Text(
                              'No ledger transactions yet',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Complete campaign missions or check in on the dashboard to earn verified EcoCoins.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: EvoraColors.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: transactions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = transactions[index];
                        final isCredit = entry.amount >= 0;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: EvoraColors.outlineVariant.withValues(alpha: 0.45)),
                          ),
                          color: EvoraColors.surfaceContainerLowest,
                          child: InkWell(
                            onTap: () => _showTransactionDetails(context, entry),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isCredit
                                          ? EvoraColors.primary.withValues(alpha: 0.12)
                                          : Colors.orange.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isCredit ? Icons.add : Icons.remove,
                                      color: isCredit ? EvoraColors.primary : Colors.orange.shade800,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.title,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('dd MMM yyyy • HH:mm').format(entry.timestamp),
                                          style: const TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${isCredit ? "+" : ""}${entry.amount}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: isCredit ? EvoraColors.primary : Colors.orange.shade800,
                                        ),
                                      ),
                                      Text(
                                        'Bal: ${entry.balanceAfter}',
                                        style: const TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
