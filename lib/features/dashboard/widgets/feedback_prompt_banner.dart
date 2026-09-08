import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../feedback/controllers/feedback_prompt_controller.dart';

/// One-time dismissible "how's it going?" prompt (spec F-17, T-M3.3) —
/// renders nothing once [FeedbackPromptController]'s state is false, which
/// covers both "hasn't hit 10 expenses yet" and "already dismissed/answered".
class FeedbackPromptBanner extends ConsumerWidget {
  const FeedbackPromptBanner({super.key});

  Future<void> _openFeedback(BuildContext context, WidgetRef ref) async {
    // Tapping through counts as "answered" either way (spec: "never
    // reappears once dismissed or answered") — dismissed immediately rather
    // than only on a real submission, so backing out of the form without
    // submitting doesn't bring the banner back either.
    await ref.read(feedbackPromptControllerProvider.notifier).dismiss();
    if (context.mounted) context.push(AppRoutes.feedback);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(feedbackPromptControllerProvider);
    if (!visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'How useful is Kharcha so far?',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
            TextButton(
              onPressed: () => _openFeedback(context, ref),
              child: const Text('Tell us'),
            ),
            IconButton(
              icon: Icon(Icons.close, color: scheme.onSecondaryContainer),
              tooltip: 'Dismiss',
              onPressed: () =>
                  ref.read(feedbackPromptControllerProvider.notifier).dismiss(),
            ),
          ],
        ),
      ),
    );
  }
}
