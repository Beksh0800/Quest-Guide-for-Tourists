import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_guide/core/di/app_router.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/domain/models/quest.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key});

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  final QuestRepository _questRepository = QuestRepository();

  late Future<List<Quest>> _questsFuture;
  bool _createInProgress = false;

  @override
  void initState() {
    super.initState();
    _questsFuture = _questRepository.getAllQuestsForAdmin();
  }

  void _reload() {
    setState(() {
      _questsFuture = _questRepository.getAllQuestsForAdmin();
    });
  }

  Future<void> _openEditor(String questId) async {
    final route = AppRoutes.adminQuestEditor.replaceFirst(':questId', questId);
    await context.push(route);
    if (!mounted) return;
    _reload();
  }

  Future<void> _createDraftQuest() async {
    if (_createInProgress) return;

    final l10n = AppLocalizations.of(context);

    setState(() {
      _createInProgress = true;
    });

    try {
      final bundle = await _questRepository.createDraftQuest();
      if (!mounted) return;

      await _openEditor(bundle.quest.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _createInProgress = false;
        });
      }
    }
  }

  Future<void> _deleteQuest(Quest quest) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.adminDeleteQuestConfirmTitle),
          content: Text(l10n.adminDeleteQuestConfirmBody(quest.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                l10n.adminDeleteQuest,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _questRepository.deleteQuest(quest.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.adminDeleteSuccess)),
    );
    _reload();
  }

  Color _difficultyColor(QuestDifficulty difficulty) {
    switch (difficulty) {
      case QuestDifficulty.easy:
        return AppColors.success;
      case QuestDifficulty.medium:
        return AppColors.accent;
      case QuestDifficulty.hard:
        return const Color(0xFFE91E63);
    }
  }

  Future<void> _showQuestDetails(Quest quest) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Подробности квеста',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailLine('Название', quest.title),
                  _buildDetailLine('ID', quest.id),
                  _buildDetailLine('Город', quest.city),
                  _buildDetailLine(
                    'Статус',
                    quest.isActive
                        ? l10n.adminStatusActive
                        : l10n.adminStatusDraft,
                  ),
                  _buildDetailLine(
                    'Описание',
                    quest.description.trim().isEmpty
                        ? 'Описание не заполнено'
                        : quest.description,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminContentTitle),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.retry,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createInProgress ? null : _createDraftQuest,
        icon: _createInProgress
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded),
        label: Text(l10n.adminCreateQuest),
      ),
      body: FutureBuilder<List<Quest>>(
        future: _questsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 36),
                    const SizedBox(height: 10),
                    Text(
                      l10n.adminQuestEditorLoadError,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _reload,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            );
          }

          final quests = snapshot.data ?? const <Quest>[];
          if (quests.isEmpty) {
            return Center(child: Text(l10n.adminEmptyContent));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: quests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final quest = quests[index];
              final difficultyColor = _difficultyColor(quest.difficulty);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 8,
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quest.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                quest.city,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (quest.isActive
                                    ? AppColors.success
                                    : AppColors.textSecondary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            quest.isActive
                                ? l10n.adminStatusActive
                                : l10n.adminStatusDraft,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: quest.isActive
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _AdminMetaChip(
                          icon: Icons.timer_outlined,
                          label: '${quest.estimatedMinutes} min',
                        ),
                        _AdminMetaChip(
                          icon: Icons.route_outlined,
                          label:
                              '${quest.distanceKm.toStringAsFixed(1)} ${l10n.kmLabel}',
                        ),
                        _AdminMetaChip(
                          icon: Icons.stars_rounded,
                          label: '${quest.totalPoints}',
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: difficultyColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.difficultyLabel(quest.difficulty.name),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: difficultyColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 420;

                        final detailsButton = TextButton.icon(
                          onPressed: () => _showQuestDetails(quest),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Подробнее'),
                        );

                        final editButton = OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () => _openEditor(quest.id),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(l10n.adminEditQuest),
                        );

                        final deleteButton = IconButton.filledTonal(
                          onPressed: () => _deleteQuest(quest),
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: AppColors.error,
                        );

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              detailsButton,
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Spacer(),
                                  Flexible(child: editButton),
                                  const SizedBox(width: 8),
                                  deleteButton,
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            detailsButton,
                            const Spacer(),
                            Flexible(child: editButton),
                            const SizedBox(width: 8),
                            deleteButton,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AdminMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
