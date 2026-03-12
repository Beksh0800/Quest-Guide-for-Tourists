import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/domain/models/quest_task.dart';
import 'package:quest_guide/domain/models/quest_task_answer.dart';

class AdminModerationQueueScreen extends StatefulWidget {
  const AdminModerationQueueScreen({super.key});

  @override
  State<AdminModerationQueueScreen> createState() =>
      _AdminModerationQueueScreenState();
}

class _AdminModerationQueueScreenState
    extends State<AdminModerationQueueScreen> {
  final ProgressRepository _progressRepository = ProgressRepository();

  bool _loading = true;
  bool _actionInProgress = false;
  String? _error;
  List<QuestModerationQueueItem> _items = const <QuestModerationQueueItem>[];

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _progressRepository.getModerationQueue();

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context).adminModerationLoadError;
        _loading = false;
      });
    }
  }

  String _resolveModeratorIdentity() {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }

    final uid = user?.uid.trim();
    if (uid != null && uid.isNotEmpty) {
      return uid;
    }

    return 'admin';
  }

  Future<void> _approve(QuestModerationQueueItem item) async {
    if (_actionInProgress) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _actionInProgress = true;
    });

    try {
      final success = await _progressRepository.approveEvidence(
        progressId: item.progressId,
        taskId: item.taskId,
        moderatedBy: _resolveModeratorIdentity(),
      );

      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminModerationActionError)),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminModerationApprovedSuccess)),
      );

      unawaited(_loadQueue());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminModerationActionError)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
        });
      }
    }
  }

  Future<void> _reject(QuestModerationQueueItem item) async {
    if (_actionInProgress) return;
    final l10n = AppLocalizations.of(context);

    final reason = await _showRejectDialog();
    if (reason == null) return;

    setState(() {
      _actionInProgress = true;
    });

    try {
      final success = await _progressRepository.rejectEvidence(
        progressId: item.progressId,
        taskId: item.taskId,
        comment: reason,
        moderatedBy: _resolveModeratorIdentity(),
      );

      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminModerationActionError)),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminModerationRejectedSuccess)),
      );

      unawaited(_loadQueue());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminModerationActionError)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
        });
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    String? validationError;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(l10n.adminModerationRejectDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.adminModerationRejectReasonLabel,
                      hintText: l10n.adminModerationRejectReasonHint,
                      errorText: validationError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setStateDialog(() {
                        validationError =
                            l10n.adminModerationRejectReasonRequired;
                      });
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: Text(
                    l10n.adminModerationReject,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  String _formatDateTime(DateTime value) {
    final locale = AppLocalizations.of(context).locale;
    return DateFormat('dd.MM.yyyy HH:mm', locale).format(value);
  }

  String _moderationStatusText(ModerationStatus status, AppLocalizations l10n) {
    switch (status) {
      case ModerationStatus.pendingReview:
        return l10n.moderationStatusPendingReview;
      case ModerationStatus.approved:
        return l10n.moderationStatusApproved;
      case ModerationStatus.rejected:
        return l10n.moderationStatusRejected;
    }
  }

  String _evidenceStatusText(EvidenceStatus? status, AppLocalizations l10n) {
    switch (status) {
      case EvidenceStatus.uploaded:
        return l10n.evidenceStatusUploaded;
      case EvidenceStatus.pending:
        return l10n.evidenceStatusPending;
      case EvidenceStatus.failed:
        return l10n.evidenceStatusFailed;
      case null:
        return l10n.adminEvidenceStatusNoData;
    }
  }

  Widget _buildPreview(QuestModerationQueueItem item, AppLocalizations l10n) {
    final path = item.evidencePath;
    if (path != null && path.trim().isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            file,
            height: 78,
            width: 78,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    final remoteUrl = item.evidenceRemoteUrl;
    final parsedRemote = remoteUrl == null ? null : Uri.tryParse(remoteUrl);
    final canUseRemote = parsedRemote != null &&
        parsedRemote.hasAbsolutePath &&
        parsedRemote.scheme.isNotEmpty;
    if (canUseRemote) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          remoteUrl!,
          height: 78,
          width: 78,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildMissingPreview(l10n),
        ),
      );
    }

    return _buildMissingPreview(l10n);
  }

  Widget _buildMissingPreview(AppLocalizations l10n) {
    return Container(
      height: 78,
      width: 78,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          l10n.adminModerationPreviewUnavailable,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminModerationQueueTitle),
        actions: [
          IconButton(
            onPressed: (_loading || _actionInProgress) ? null : _loadQueue,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.retry,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.error, size: 36),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _loadQueue,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        l10n.adminModerationEmpty,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _items[index];

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPreview(item, l10n),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${l10n.adminModerationUserLabel}: ${item.userId}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${l10n.adminModerationQuestTaskLabel}: ${item.questId} / ${item.taskId}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${l10n.evidenceStatusLabel}: ${_evidenceStatusText(item.evidenceStatus, l10n)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${l10n.adminModerationAnsweredAtLabel}: ${_formatDateTime(item.answeredAt)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${l10n.moderationStatusLabel}: ${_moderationStatusText(item.moderationStatus, l10n)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _actionInProgress
                                          ? null
                                          : () => _reject(item),
                                      icon: const Icon(Icons.close_rounded),
                                      label: Text(l10n.adminModerationReject),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _actionInProgress
                                          ? null
                                          : () => _approve(item),
                                      icon: const Icon(Icons.check_rounded),
                                      label: Text(l10n.adminModerationApprove),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
