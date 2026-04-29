import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/providers/translation_provider.dart';
import 'package:multilingual_chat_app/services/translation_service.dart';

class SubtitleOverlay extends ConsumerStatefulWidget {
  const SubtitleOverlay({
    super.key,
    this.onToggleTranslation,
    this.displayDuration = const Duration(seconds: 5),
    this.statusOverride,
    this.subtitleOverride,
    this.bannerText,
    this.isListening,
    this.latencyMs,
  });

  final VoidCallback? onToggleTranslation;
  final Duration displayDuration;
  final TranslationStatus? statusOverride;
  final SubtitleEvent? subtitleOverride;
  final String? bannerText;
  final bool? isListening;
  final int? latencyMs;

  @override
  ConsumerState<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends ConsumerState<SubtitleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  SubtitleEvent? _displayedEvent;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _show(SubtitleEvent event) {
    _dismissTimer?.cancel();
    setState(() => _displayedEvent = event);
    _animCtrl.forward(from: 0);
    _dismissTimer = Timer(widget.displayDuration, () {
      if (mounted) _animCtrl.reverse();
    });
  }

  void _openHistory(
      BuildContext context, List<SubtitleEvent> history) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151626),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HistorySheet(history: history),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SubtitleEvent?>(latestSubtitleProvider, (_, next) {
      if (next != null) _show(next);
    });

    final providerStatus = ref.watch(translationStatusProvider);
    final history = ref.watch(subtitleHistoryProvider);
    final status = widget.statusOverride ?? providerStatus;
    final subtitleEvent = widget.subtitleOverride ?? _displayedEvent;
    final isActive = status == TranslationStatus.active;
    final isPaused = status == TranslationStatus.paused;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status pill
        _StatusPill(
          status: status,
          onToggle: widget.onToggleTranslation,
          historyCount: history.length,
          onOpenHistory: history.isNotEmpty
              ? () => _openHistory(context, history)
              : null,
        ),
        const SizedBox(height: 8),

        // Subtitle card
        if (isActive || isPaused)
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: subtitleEvent != null
                  ? _SubtitleCard(
                      event: subtitleEvent,
                      latencyMsOverride: widget.latencyMs,
                    )
                  : const _WaitingCard(),
            ),
          ),
      ],
    );
  }
}

// ─── Status pill ─────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.historyCount,
    this.bannerText,
    this.isListening,
    this.onToggle,
    this.onOpenHistory,
  });

  final TranslationStatus status;
  final int historyCount;
  final String? bannerText;
  final bool? isListening;
  final VoidCallback? onToggle;
  final VoidCallback? onOpenHistory;

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    String label;
    switch (status) {
      case TranslationStatus.active:
        dotColor = const Color(0xFF34D399);
        label = 'Translation ON';
      case TranslationStatus.paused:
        dotColor = const Color(0xFFFBBF24);
        label = 'Translation PAUSED';
      case TranslationStatus.initialising:
        dotColor = const Color(0xFF22D3EE);
        label = 'Starting…';
      case TranslationStatus.error:
        dotColor = Colors.redAccent;
        label = 'Translation ERROR';
      case TranslationStatus.idle:
        dotColor = const Color(0xFF475569);
        label = 'Translation OFF';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1E31).withOpacity(0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: dotColor.withOpacity(0.35), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(
                    color: dotColor,
                    animate:
                        status == TranslationStatus.active),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      color: dotColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    )),
                if (bannerText != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    bannerText!,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (isListening != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    isListening! ? 'Listening' : 'Waiting mic',
                    style: const TextStyle(
                      color: Color(0xFF818CF8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (historyCount > 0) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onOpenHistory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1)
                            .withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$historyCount',
                          style: const TextStyle(
                            color: Color(0xFF818CF8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Pulse dot ───────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.animate});
  final Color color;
  final bool animate;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.animate && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
              color: widget.color, shape: BoxShape.circle)),
    );
  }
}

// ─── Subtitle card ───────────────────────────────────────────────────────────

class _SubtitleCard extends StatelessWidget {
  const _SubtitleCard({required this.event, this.latencyMsOverride});
  final SubtitleEvent event;
  final int? latencyMsOverride;

  @override
  Widget build(BuildContext context) {
    final accent =
        event.isLocal ? const Color(0xFF6366F1) : const Color(0xFF22D3EE);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1E31).withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
                event.isLocal
                    ? Icons.person_rounded
                    : Icons.person_outline_rounded,
                size: 13,
                color: accent),
            const SizedBox(width: 4),
            Text(event.isLocal ? 'You said' : 'They said',
                style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
            if ((latencyMsOverride ?? event.latencyMs) != null) ...[
              const Spacer(),
              Text('${latencyMsOverride ?? event.latencyMs}ms',
                  style: const TextStyle(
                      color: Color(0xFF475569), fontSize: 9)),
            ],
          ]),
          const SizedBox(height: 6),
          Text(event.translated,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFFF1F5F9),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.35)),
          if (event.original.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(event.original,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11,
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

// ─── Waiting card ────────────────────────────────────────────────────────────

class _WaitingCard extends StatelessWidget {
  const _WaitingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1E31).withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF475569).withOpacity(0.2),
            width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Color(0xFF94A3B8)),
          ),
          SizedBox(width: 8),
          Text('Listening for speech…',
              style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

// ─── History sheet ────────────────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.history});
  final List<SubtitleEvent> history;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF475569).withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(Icons.history_rounded,
                size: 18, color: Color(0xFF818CF8)),
            SizedBox(width: 8),
            Text('Translation History',
                style: TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final event = history[history.length - 1 - i];
              final accent = event.isLocal
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF22D3EE);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1E31),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                      left: BorderSide(color: accent, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.translated,
                        style: const TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    if (event.original.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(event.original,
                          style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 11,
                              fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── TranslationToggleButton ──────────────────────────────────────────────────

/// Drop-in replacement for the translate icon button in the call controls bar.
class TranslationToggleButton extends ConsumerWidget {
  const TranslationToggleButton({super.key, required this.onToggle});
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(translationStatusProvider);
    final isOn = status == TranslationStatus.active ||
        status == TranslationStatus.paused;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn
              ? const Color(0xFF7A52F4)
              : const Color(0xFF2B2D55),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color:
                        const Color(0xFF7A52F4).withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ]
              : [],
        ),
        child: const Icon(Icons.translate_rounded,
            color: Colors.white, size: 24),
      ),
    );
  }
}