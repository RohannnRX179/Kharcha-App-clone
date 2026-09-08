import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/errors/failure.dart';
import '../../../data/repositories/feedback_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/enums.dart';

const _categoryLabels = {
  FeedbackCategory.general: 'General',
  FeedbackCategory.bug: 'Bug',
  FeedbackCategory.idea: 'Idea',
  FeedbackCategory.confusing: 'Confusing',
  FeedbackCategory.praise: 'Praise',
};

/// Feedback (spec F-17, T-M3.2): 1-5 star rating, a category, and free
/// text. Reachable from Settings (permanently), Diagnostics ("a bug report
/// can follow a log share"), and the Dashboard's one-time prompt
/// (`FeedbackPromptBanner`) — all three just push this same route.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _messageController = TextEditingController();
  int? _rating;
  FeedbackCategory _category = FeedbackCategory.general;
  bool _submitting = false;
  Failure? _error;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting && _messageController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref
        .read(feedbackRepositoryProvider)
        .submit(
          rating: _rating,
          category: _category,
          message: _messageController.text.trim(),
          householdId: ref.read(currentHouseholdIdProvider),
        );
    if (!mounted) return;
    result.fold(
      (_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for the feedback!')),
        );
      },
      (failure) => setState(() {
        _submitting = false;
        _error = failure;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'How useful is Kharcha so far?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 32,
                  icon: Icon(
                    _rating != null && i <= _rating!
                        ? Icons.star
                        : Icons.star_border,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  onPressed: () => setState(() => _rating = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _categoryLabels.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _category == entry.key,
                  onSelected: (_) => setState(() => _category = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLength: 2000,
            minLines: 4,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'What worked, what didn\'t, what would help?',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null
                  ? '…'
                  : '${info.version} (${info.buildNumber})';
              return Text(
                'App version $version and your platform are attached '
                'automatically.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send feedback'),
          ),
        ],
      ),
    );
  }
}
