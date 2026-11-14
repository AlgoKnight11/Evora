import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/evora_colors.dart';
import '../../auth/services/auth_service.dart';
import '../models/impact_profile_model.dart';
import '../services/impact_profile_service.dart';

class ImpactProfileScreen extends ConsumerWidget {
  const ImpactProfileScreen({super.key});

  void _showSdgMethodology(BuildContext context, SdgInfo sdg, double currentMetric) {
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sdg.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(sdg.icon, color: sdg.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SDG ${sdg.number}: ${sdg.title}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: sdg.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'UN 2030 Sustainable Development Agenda',
                          style: TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                sdg.officialName,
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, height: 1.35),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Text(
                'Local Dehradun Context & Verification:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                sdg.localContext,
                style: const TextStyle(fontSize: 12.5, color: EvoraColors.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: EvoraColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Verified Contribution',
                          style: TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${currentMetric.toStringAsFixed(1)} ${sdg.primaryMetricUnit}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: sdg.color,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.verified, color: Colors.green, size: 22),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShareCardModal(BuildContext context, CitizenImpactSummary impact, String userName, String locality) {
    final cardKey = GlobalKey();
    bool isSharing = false;

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
        final bottomInset = math.max(rawBottom, 16.0) + 16.0;

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(22, 16, 22, bottomInset),
              decoration: const BoxDecoration(
                color: EvoraColors.surfaceContainerLowest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: EvoraColors.outlineVariant,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Visual Share Card (Wrapped in RepaintBoundary for high-res PNG export)
                  RepaintBoundary(
                    key: cardKey,
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF004D34),
                            EvoraColors.primary,
                            Colors.teal.shade900,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.eco, color: EvoraColors.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'EVORA UTTARAKHAND',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  impact.tier.title,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            userName,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '$locality • Citizen Impact Record',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildShareMetric('${impact.co2AvoidedKg.toStringAsFixed(0)} kg', 'CO₂e Avoided'),
                              _buildShareMetric('${impact.wasteDivertedKg.toStringAsFixed(0)} kg', 'Waste Diverted'),
                              _buildShareMetric('${impact.waterSavedLiters.toStringAsFixed(0)} L', 'Water Protected'),
                              _buildShareMetric('${impact.treesSupported}', 'Trees Planted'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.verified, color: Colors.lightGreenAccent, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${impact.totalEcoCoins} Verified EcoCoins Earned',
                                style: const TextStyle(
                                  color: Colors.lightGreenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EvoraColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isSharing
                          ? null
                          : () async {
                              setSheetState(() => isSharing = true);
                              try {
                                final shareCaption =
                                    '🌿 My Verified EVORA Sustainability Record\n\n'
                                    '👤 Citizen: $userName\n'
                                    '🏅 Tier: ${impact.tier.title}\n'
                                    '📍 Locality: $locality, Uttarakhand\n\n'
                                    '🌍 Cumulative Environmental Action:\n'
                                    '• ${impact.co2AvoidedKg.toStringAsFixed(1)} kg CO₂e Emissions Avoided\n'
                                    '• ${impact.wasteDivertedKg.toStringAsFixed(1)} kg Waste Diverted from Dumpsites\n'
                                    '• ${impact.waterSavedLiters.toStringAsFixed(0)} L Clean Water Protected\n'
                                    '• ${impact.treesSupported} Native Trees Planted\n'
                                    '• ${impact.totalEcoCoins} Verified EcoCoins Earned\n\n'
                                    'Verified under UN Sustainable Development Goals (SDGs 6, 11, 12, 13, 15) on EVORA — Himalayan Modernism in Civic Action!';

                                // Capture visual card widget as high-resolution PNG image
                                final boundary = cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                                if (boundary != null) {
                                  final image = await boundary.toImage(pixelRatio: 3.0);
                                  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                                  if (byteData != null) {
                                    final buffer = byteData.buffer.asUint8List();
                                    final tempDir = await getTemporaryDirectory();
                                    final filePath = '${tempDir.path}/evora_impact_${DateTime.now().millisecondsSinceEpoch}.png';
                                    final file = File(filePath);
                                    await file.writeAsBytes(buffer);

                                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);

                                    await SharePlus.instance.share(
                                      ShareParams(
                                        files: [XFile(file.path, mimeType: 'image/png')],
                                        text: shareCaption,
                                        subject: 'My EVORA Uttarakhand Citizen Impact Milestone',
                                        title: 'Share EVORA Impact Record',
                                      ),
                                    );
                                    return;
                                  }
                                }

                                // Fallback to formatted text share if image rasterization fails
                                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                await SharePlus.instance.share(
                                  ShareParams(
                                    text: shareCaption,
                                    subject: 'My EVORA Uttarakhand Citizen Impact Milestone',
                                    title: 'Share EVORA Impact Record',
                                  ),
                                );
                              } catch (e) {
                                debugPrint('[Share] Error sharing impact card: $e');
                                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                await SharePlus.instance.share(
                                  ShareParams(
                                    text: '🌿 I am driving climate action with EVORA! Avoided ${impact.co2AvoidedKg.toStringAsFixed(1)} kg CO₂e and earned ${impact.totalEcoCoins} EcoCoins in Dehradun.',
                                    subject: 'My EVORA Impact Milestone',
                                    title: 'Share EVORA Impact Record',
                                  ),
                                );
                              }
                            },
                      child: isSharing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                                SizedBox(width: 10),
                                Text('Generating Card...', style: TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.share, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Share to WhatsApp / Social Media',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildShareMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final impact = ref.watch(citizenImpactProvider);
    final displayName = user?.displayName.isNotEmpty == true ? user!.displayName : 'Resident Citizen';
    final locality = user?.selectedLocality ?? 'Dehradun Valley';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impact Profile', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Eco Coins Ledger',
            onPressed: () => context.push('/ledger'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            math.max(
              MediaQuery.of(context).padding.bottom,
              MediaQuery.of(context).viewPadding.bottom,
            ) + 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Citizen Profile Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: EvoraColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: impact.tier.color,
                      child: Text(
                        displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 13, color: EvoraColors.onSurfaceVariant),
                              const SizedBox(width: 3),
                              Text(
                                locality,
                                style: const TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: impact.tier.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              impact.tier.title,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: impact.tier.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Verified Balance & Ledger Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      EvoraColors.primary.withValues(alpha: 0.12),
                      Colors.teal.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: EvoraColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: EvoraColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.eco, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${impact.totalEcoCoins} EcoCoins',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: EvoraColors.primary,
                            ),
                          ),
                          const Text(
                            'Verified in append-only cryptographic ledger',
                            style: TextStyle(fontSize: 11.5, color: EvoraColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.push('/ledger'),
                      child: const Text('Ledger'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Cumulative Environmental Metrics Grid (2x2)
              const Text(
                'Cumulative Real-World Impact',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Aggregated verified contributions across all completed missions and civic actions.',
                style: TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.cloud_outlined,
                      value: '${impact.co2AvoidedKg.toStringAsFixed(1)} kg',
                      label: 'Avoided CO₂e',
                      color: const Color(0xFF15803D),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.delete_sweep_outlined,
                      value: '${impact.wasteDivertedKg.toStringAsFixed(1)} kg',
                      label: 'Waste Diverted',
                      color: const Color(0xFFCA8A04),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.water_drop_outlined,
                      value: '${impact.waterSavedLiters.toStringAsFixed(0)} L',
                      label: 'Water Protected',
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.park_outlined,
                      value: '${impact.treesSupported}',
                      label: 'Trees Supported',
                      color: const Color(0xFF008955),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 4. UN Sustainable Development Goals Alignment
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'UN SDG 2030 Alignment',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.info_outline, size: 14),
                    label: const Text('Methodology', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _showSdgMethodology(
                        context,
                        SdgInfo.registry[13]!,
                        impact.sdgMetrics[13] ?? 0.0,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap any goal to inspect the exact conversion formula and local Dehradun context.',
                style: TextStyle(fontSize: 12, color: EvoraColors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              ...[6, 11, 12, 13, 15].map((sdgNum) {
                final sdg = SdgInfo.registry[sdgNum]!;
                final currentMetric = impact.sdgMetrics[sdgNum] ?? 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: EvoraColors.outlineVariant.withValues(alpha: 0.45)),
                    ),
                    color: EvoraColors.surfaceContainerLowest,
                    child: InkWell(
                      onTap: () => _showSdgMethodology(context, sdg, currentMetric),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: sdg.color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(sdg.icon, color: sdg.color, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SDG $sdgNum • ${sdg.title}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${currentMetric.toStringAsFixed(1)} ${sdg.primaryMetricUnit}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: sdg.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: EvoraColors.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),

              // 5. Earned Badges Strip
              const Text(
                'Citizen Honors & Badges',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: impact.earnedBadgeNames.map((badge) {
                  return Chip(
                    avatar: const Icon(Icons.shield, color: EvoraColors.primary, size: 16),
                    label: Text(badge, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    backgroundColor: EvoraColors.surfaceContainerHigh,
                    side: BorderSide(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 6. Share My Impact CTA
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Generate Shareable Impact Card', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EvoraColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _showShareCardModal(context, impact, displayName, locality),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: EvoraColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
