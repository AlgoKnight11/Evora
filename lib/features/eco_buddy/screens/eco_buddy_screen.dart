import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/evora_colors.dart';
import '../../../core/utils/external_launcher.dart';
import '../models/eco_buddy_models.dart';
import '../services/eco_buddy_service.dart';

/// Interactive conversational AI screen for Eco Buddy (Bilingual RAG Assistant).
class EcoBuddyScreen extends ConsumerStatefulWidget {
  const EcoBuddyScreen({super.key});

  @override
  ConsumerState<EcoBuddyScreen> createState() => _EcoBuddyScreenState();
}

class _EcoBuddyScreenState extends ConsumerState<EcoBuddyScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(ecoBuddyProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isHindi = ref.read(ecoBuddyProvider).isHindi;
        return AlertDialog(
          title: Text(
            isHindi ? 'बातचीत रीसेट करें?' : 'Clear Chat History?',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            isHindi
                ? 'क्या आप संदेश इतिहास हटाकर बातचीत नए सिरे से शुरू करना चाहते हैं?'
                : 'Are you sure you want to clear the conversation and restart with Eco Buddy?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: EvoraColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(ecoBuddyProvider.notifier).clearChat();
              },
              child: Text(isHindi ? 'हटाएं' : 'Clear'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final buddyState = ref.watch(ecoBuddyProvider);
    final isHindi = buddyState.isHindi;

    ref.listen(ecoBuddyProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length || next.isLoading) {
        _scrollToBottom();
      }
    });

    final bottomPadding = math.max(
      math.max(
        MediaQuery.of(context).padding.bottom,
        MediaQuery.of(context).viewPadding.bottom,
      ),
      12.0,
    );

    return Scaffold(
      backgroundColor: EvoraColors.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: EvoraColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco,
                color: EvoraColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isHindi ? 'इको बडी (Eco Buddy)' : 'Eco Buddy',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: EvoraColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AI Grounded',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: EvoraColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isHindi
                        ? 'देहरादून नगर निगम सत्यापित ज्ञान'
                        : 'Verified Dehradun Municipal Knowledge',
                    style: const TextStyle(
                      fontSize: 11,
                      color: EvoraColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Language toggle button (EN / HI)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: EvoraColors.primary,
            ),
            icon: const Icon(Icons.translate, size: 16),
            label: Text(
              isHindi ? 'हिन्दी' : 'EN',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            onPressed: () {
              ref.read(ecoBuddyProvider.notifier).toggleLanguage();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            tooltip: isHindi ? 'रीसेट करें' : 'Clear Chat',
            onPressed: _showClearChatDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Rate Limit Warning Banner (when cooldown active)
          if (buddyState.isRateLimited)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade100,
              child: Row(
                children: [
                  Icon(Icons.hourglass_top, size: 18, color: Colors.amber.shade900),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isHindi
                          ? 'संदेश दर सीमा सक्रिय। शेष समय: ${buddyState.rateLimitResetSeconds} सेकंड'
                          : 'Rate limit active. Cooldown: ${buddyState.rateLimitResetSeconds}s remaining',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Suggested quick prompt chips (scrollable horizontal bar)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: EcoBuddyQuickPrompt.defaultPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final chip = EcoBuddyQuickPrompt.defaultPrompts[index];
                return ActionChip(
                  avatar: Icon(chip.icon, size: 15, color: EvoraColors.primary),
                  label: Text(
                    isHindi ? chip.labelHi : chip.labelEn,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: EvoraColors.primary,
                    ),
                  ),
                  backgroundColor: EvoraColors.primary.withValues(alpha: 0.08),
                  side: BorderSide(color: EvoraColors.primary.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  onPressed: buddyState.isLoading || buddyState.isRateLimited
                      ? null
                      : () {
                          ref.read(ecoBuddyProvider.notifier).sendQuickPrompt(chip);
                          _scrollToBottom();
                        },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Main Conversation Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: buddyState.messages.length + (buddyState.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == buddyState.messages.length && buddyState.isLoading) {
                  return _buildTypingIndicator(isHindi);
                }
                final message = buddyState.messages[index];
                return _buildMessageItem(message, isHindi);
              },
            ),
          ),

          // Message Input Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding),
            decoration: BoxDecoration(
              color: EvoraColors.surfaceContainerLowest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
              border: Border(
                top: BorderSide(
                  color: EvoraColors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: EvoraColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: EvoraColors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      enabled: !buddyState.isRateLimited,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: buddyState.isRateLimited
                            ? (isHindi
                                ? 'प्रतीक्षा करें... (${buddyState.rateLimitResetSeconds}s)'
                                : 'Cooldown active... (${buddyState.rateLimitResetSeconds}s)')
                            : (isHindi
                                ? 'देहरादून कचरा नियम, पुनर्चक्रण पूछें...'
                                : 'Ask about Dehradun recycling, waste rules...'),
                        hintStyle: const TextStyle(fontSize: 13, color: EvoraColors.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: (buddyState.isLoading || buddyState.isRateLimited) ? null : _handleSend,
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: (buddyState.isLoading || buddyState.isRateLimited)
                          ? EvoraColors.onSurfaceVariant.withValues(alpha: 0.3)
                          : EvoraColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isHindi) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: EvoraColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco, size: 18, color: EvoraColors.primary),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: EvoraColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(EvoraColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isHindi ? 'सत्यापित रिकॉर्ड खोज रहा है...' : 'Checking verified municipal records...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: EvoraColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(EcoBuddyMessage message, bool isHindi) {
    final isUser = message.sender == EcoBuddySender.user;
    final timeStr = DateFormat('hh:mm a').format(message.timestamp);

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timeStr,
              style: const TextStyle(fontSize: 10, color: EvoraColors.onSurfaceVariant),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: EvoraColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Assistant Message
    final isEmergency = message.messageType == EcoBuddyMessageType.emergencyAlert;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isEmergency
                  ? Colors.red.withValues(alpha: 0.15)
                  : EvoraColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEmergency ? Icons.warning_amber_rounded : Icons.eco,
              size: 18,
              color: isEmergency ? Colors.red.shade700 : EvoraColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isEmergency
                        ? const Color(0xFFFEF2F2) // Red tint
                        : EvoraColors.surfaceContainerLowest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: isEmergency
                          ? Colors.red.shade300
                          : EvoraColors.outlineVariant.withValues(alpha: 0.5),
                      width: isEmergency ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text content rendered with basic markdown styling
                      _renderFormattedMarkdown(message.text, isEmergency),

                      // If acute emergency, display Emergency Helplines with quick dialers
                      if (message.helplines.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Text(
                          isHindi ? 'आधिकारिक आपातकालीन हेल्पलाइन:' : 'OFFICIAL EMERGENCY HELPLINES:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: Colors.red.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...message.helplines.map((helpline) => _buildHelplineCard(helpline)),
                      ],

                      // If grounded sources exist, display verified facility cards
                      if (message.sources.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Text(
                          isHindi ? 'सत्यापित स्रोत एवं केंद्र:' : 'VERIFIED LOCAL SOURCES:',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: EvoraColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...message.sources.map((src) => _buildSourceCard(src, isHindi)),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 6),
                  child: Text(
                    timeStr,
                    style: const TextStyle(fontSize: 10, color: EvoraColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelplineCard(EmergencyHelpline helpline) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: helpline.themeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: helpline.themeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(helpline.icon, size: 18, color: helpline.themeColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  helpline.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: helpline.themeColor,
                  ),
                ),
                Text(
                  helpline.description,
                  style: const TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: helpline.themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.call, size: 14),
            label: Text(
              helpline.number,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            onPressed: () => ExternalLauncher.launchCall(helpline.number),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(GroundedSource src, bool isHindi) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  src.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: EvoraColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Verified',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: EvoraColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: EvoraColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  src.address,
                  style: const TextStyle(fontSize: 11.5, color: EvoraColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          if (src.operatingHours != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: EvoraColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    src.operatingHours!,
                    style: const TextStyle(fontSize: 11.5, color: EvoraColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          if (src.contactNumber != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.call, size: 13),
                  label: Text(
                    src.contactNumber!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => ExternalLauncher.launchCall(src.contactNumber!),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Parses markdown headings, bold text, and bullet points into styled Text spans.
  Widget _renderFormattedMarkdown(String rawText, bool isEmergency) {
    final lines = rawText.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              trimmed.substring(4),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isEmergency ? Colors.red.shade900 : EvoraColors.onSurface,
              ),
            ),
          ),
        );
      } else if (trimmed.startsWith('• ') || trimmed.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isEmergency ? Colors.red.shade800 : EvoraColors.primary,
                  ),
                ),
                Expanded(
                  child: _buildRichInlineSpans(
                    trimmed.substring(2),
                    isEmergency: isEmergency,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildRichInlineSpans(trimmed, isEmergency: isEmergency),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildRichInlineSpans(String text, {required bool isEmergency}) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: TextStyle(
              color: isEmergency ? Colors.red.shade900 : EvoraColors.onSurface,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isEmergency ? Colors.red.shade900 : EvoraColors.onSurface,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(
            color: isEmergency ? Colors.red.shade900 : EvoraColors.onSurface,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      );
    }

    return Text.rich(TextSpan(children: spans));
  }
}
