import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/domain/models/quest_location.dart';
import 'package:quest_guide/domain/models/quest_task_answer.dart';
import 'package:quest_guide/domain/models/quest_task.dart';

class AdminQuestEditorScreen extends StatefulWidget {
  final String questId;

  const AdminQuestEditorScreen({
    super.key,
    required this.questId,
  });

  @override
  State<AdminQuestEditorScreen> createState() => _AdminQuestEditorScreenState();
}

class _AdminQuestEditorScreenState extends State<AdminQuestEditorScreen> {
  final QuestRepository _questRepository = QuestRepository();
  final ProgressRepository _progressRepository = ProgressRepository();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _locationsJsonController =
      TextEditingController();
  final TextEditingController _tasksJsonController = TextEditingController();

  QuestDifficulty _difficulty = QuestDifficulty.easy;
  bool _isActive = false;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _jsonValidationError;

  Quest? _baseQuest;
  Set<String> _moderationTaskIds = const <String>{};
  bool _moderationLoading = false;
  String? _moderationError;
  List<QuestEvidenceStatusRecord> _moderationRecords =
      const <QuestEvidenceStatusRecord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _pointsController.dispose();
    _locationsJsonController.dispose();
    _tasksJsonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final content =
          await _questRepository.getQuestContentForAdmin(widget.questId);
      if (content == null) {
        if (!mounted) return;
        setState(() {
          _loadError = AppLocalizations.of(context).questNotFound;
          _loading = false;
        });
        return;
      }

      _baseQuest = content.quest;
      _titleController.text = content.quest.title;
      _cityController.text = content.quest.city;
      _descriptionController.text = content.quest.description;
      _durationController.text = content.quest.estimatedMinutes.toString();
      _distanceController.text = content.quest.distanceKm.toString();
      _pointsController.text = content.quest.totalPoints.toString();
      _difficulty = content.quest.difficulty;
      _isActive = content.quest.isActive;

      final normalizedLocations = content.locations.toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      _locationsJsonController.text = const JsonEncoder.withIndent('  ')
          .convert(normalizedLocations.map(_locationToJson).toList());

      _tasksJsonController.text = const JsonEncoder.withIndent('  ')
          .convert(content.tasks.map(_taskToJson).toList());

      _moderationTaskIds = content.tasks
          .where(
            (task) =>
                task.type == TaskType.photo || task.type == TaskType.findObject,
          )
          .map((task) => task.id)
          .toSet();

      await _loadModerationStatuses();

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = AppLocalizations.of(context).adminQuestEditorLoadError;
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_baseQuest == null) {
      setState(() {
        _jsonValidationError = l10n.adminQuestEditorLoadError;
      });
      return;
    }

    final parsed = _parseJsonInputs();
    if (parsed.error != null) {
      setState(() {
        _jsonValidationError = parsed.error;
      });
      return;
    }

    setState(() {
      _jsonValidationError = null;
      _saving = true;
    });

    try {
      final updatedQuest = _baseQuest!.copyWith(
        title: _titleController.text.trim(),
        city: _cityController.text.trim(),
        description: _descriptionController.text.trim(),
        estimatedMinutes: int.parse(_durationController.text.trim()),
        distanceKm: _parseDistanceValue(_distanceController.text),
        totalPoints: int.parse(_pointsController.text.trim()),
        difficulty: _difficulty,
        isActive: _isActive,
      );

      final content = QuestContentBundle(
        quest: updatedQuest,
        locations: parsed.locations!,
        tasks: parsed.tasks!,
      );

      await _questRepository.saveQuestContent(content);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminSaveSuccess)),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _jsonValidationError = l10n.saveError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _loadModerationStatuses() async {
    if (_moderationTaskIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _moderationLoading = false;
        _moderationError = null;
        _moderationRecords = const <QuestEvidenceStatusRecord>[];
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _moderationLoading = true;
      _moderationError = null;
    });

    try {
      final records = await _progressRepository.getEvidenceStatusesForQuest(
        questId: widget.questId,
        taskIds: _moderationTaskIds,
      );

      if (!mounted) return;
      setState(() {
        _moderationRecords = records;
        _moderationLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _moderationError = AppLocalizations.of(context).adminEvidenceLoadError;
        _moderationLoading = false;
      });
    }
  }

  _ParsedContent _parseJsonInputs() {
    final l10n = AppLocalizations.of(context);

    dynamic locationsRaw;
    dynamic tasksRaw;

    try {
      locationsRaw = jsonDecode(_locationsJsonController.text);
    } on FormatException catch (e) {
      return _ParsedContent(
        error: l10n.adminInvalidLocationsJson(e.message),
      );
    }

    try {
      tasksRaw = jsonDecode(_tasksJsonController.text);
    } on FormatException catch (e) {
      return _ParsedContent(
        error: l10n.adminInvalidTasksJson(e.message),
      );
    }

    if (locationsRaw is! List) {
      return _ParsedContent(error: l10n.adminLocationsMustBeArray);
    }
    if (tasksRaw is! List) {
      return _ParsedContent(error: l10n.adminTasksMustBeArray);
    }

    final locations = <QuestLocation>[];
    for (var i = 0; i < locationsRaw.length; i++) {
      final item = locationsRaw[i];
      if (item is! Map<String, dynamic>) {
        return _ParsedContent(
          error: l10n.adminLocationsItemMustBeObject(i + 1),
        );
      }

      final map = item;
      final id = (map['id'] as String? ?? '').trim();
      final name = (map['name'] as String? ?? '').trim();
      final taskId = (map['taskId'] as String? ?? '').trim();

      if (id.isEmpty) {
        return _ParsedContent(error: l10n.adminLocationIdRequired(i + 1));
      }
      if (name.isEmpty) {
        return _ParsedContent(error: l10n.adminLocationNameRequired(i + 1));
      }

      final latitude = (map['latitude'] as num?)?.toDouble();
      final longitude = (map['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        return _ParsedContent(
          error: l10n.adminLocationCoordinatesRequired(i + 1),
        );
      }

      final radius = map['radiusMeters'];
      final radiusMeters = radius is int
          ? radius
          : radius is num
              ? radius.round()
              : 50;

      locations.add(
        QuestLocation(
          id: id,
          questId: widget.questId,
          order: i,
          name: name,
          description: (map['description'] as String? ?? '').trim(),
          historicalInfo: (map['historicalInfo'] as String? ?? '').trim(),
          latitude: latitude,
          longitude: longitude,
          imageUrl: (map['imageUrl'] as String? ?? '').trim(),
          audioUrl: (map['audioUrl'] as String?)?.trim(),
          taskId: taskId,
          radiusMeters: radiusMeters,
        ),
      );
    }

    final tasks = <QuestTask>[];
    for (var i = 0; i < tasksRaw.length; i++) {
      final item = tasksRaw[i];
      if (item is! Map<String, dynamic>) {
        return _ParsedContent(
          error: l10n.adminTasksItemMustBeObject(i + 1),
        );
      }

      final map = item;
      final id = (map['id'] as String? ?? '').trim();
      final locationId = (map['locationId'] as String? ?? '').trim();
      final question = (map['question'] as String? ?? '').trim();

      if (id.isEmpty) {
        return _ParsedContent(error: l10n.adminTaskIdRequired(i + 1));
      }
      if (locationId.isEmpty) {
        return _ParsedContent(error: l10n.adminTaskLocationRequired(i + 1));
      }
      if (question.isEmpty) {
        return _ParsedContent(error: l10n.adminTaskQuestionRequired(i + 1));
      }

      final typeRaw = (map['type'] as String? ?? '').trim();
      final parsedType = TaskType.values.where((t) => t.name == typeRaw);
      if (parsedType.isEmpty) {
        return _ParsedContent(error: l10n.adminTaskTypeInvalid(i + 1, typeRaw));
      }

      final type = parsedType.first;
      final pointsRaw = map['points'];
      final points = pointsRaw is int
          ? pointsRaw
          : pointsRaw is num
              ? pointsRaw.round()
              : 50;

      final optionsRaw = map['options'];
      final options = optionsRaw is List
          ? optionsRaw.map((e) => e.toString()).toList(growable: false)
          : const <String>[];

      final correctIndexRaw = map['correctOptionIndex'];
      final correctOptionIndex = correctIndexRaw is int
          ? correctIndexRaw
          : correctIndexRaw is num
              ? correctIndexRaw.round()
              : 0;

      final timeLimitRaw = map['timeLimitSeconds'];
      final timeLimitSeconds = timeLimitRaw is int
          ? timeLimitRaw
          : timeLimitRaw is num
              ? timeLimitRaw.round()
              : 0;

      final correctAnswer = map['correctAnswer']?.toString().trim();

      tasks.add(
        QuestTask(
          id: id,
          locationId: locationId,
          type: type,
          question: question,
          hint: (map['hint'] as String?)?.trim(),
          points: points,
          options: options,
          correctOptionIndex: correctOptionIndex,
          correctAnswer:
              (correctAnswer?.isEmpty ?? true) ? null : correctAnswer,
          timeLimitSeconds: timeLimitSeconds,
        ),
      );
    }

    final locationIds = locations.map((location) => location.id).toSet();
    for (var i = 0; i < tasks.length; i++) {
      if (!locationIds.contains(tasks[i].locationId)) {
        return _ParsedContent(
          error: l10n.adminTaskLocationUnknown(i + 1, tasks[i].locationId),
        );
      }
    }

    final taskIds = tasks.map((task) => task.id).toSet();
    for (var i = 0; i < locations.length; i++) {
      final taskId = locations[i].taskId.trim();
      if (taskId.isEmpty) continue;

      if (!taskIds.contains(taskId)) {
        return _ParsedContent(
          error: l10n.adminLocationTaskUnknown(i + 1, taskId),
        );
      }
    }

    return _ParsedContent(
      locations: locations,
      tasks: tasks,
    );
  }

  Map<String, dynamic> _locationToJson(QuestLocation location) {
    return {
      'id': location.id,
      'name': location.name,
      'description': location.description,
      'historicalInfo': location.historicalInfo,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'imageUrl': location.imageUrl,
      'audioUrl': location.audioUrl,
      'taskId': location.taskId,
      'radiusMeters': location.radiusMeters,
    };
  }

  Map<String, dynamic> _taskToJson(QuestTask task) {
    return {
      'id': task.id,
      'locationId': task.locationId,
      'type': task.type.name,
      'question': task.question,
      'hint': task.hint,
      'points': task.points,
      'options': task.options,
      'correctOptionIndex': task.correctOptionIndex,
      'correctAnswer': task.correctAnswer,
      'timeLimitSeconds': task.timeLimitSeconds,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminQuestEditorTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _load,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionCard(
                          title: l10n.adminQuestBaseFields,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _titleController,
                                label: l10n.adminFieldTitle,
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return l10n.adminValidationRequired(
                                      l10n.adminFieldTitle,
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              _buildTextField(
                                controller: _cityController,
                                label: l10n.adminFieldCity,
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return l10n.adminValidationRequired(
                                      l10n.adminFieldCity,
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              _buildTextField(
                                controller: _descriptionController,
                                label: l10n.adminFieldDescription,
                                minLines: 3,
                                maxLines: 5,
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return l10n.adminValidationRequired(
                                      l10n.adminFieldDescription,
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _durationController,
                                      label: l10n.adminFieldEstimatedDuration,
                                      keyboardType: TextInputType.number,
                                      validator: _validateIntField,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _distanceController,
                                      label: l10n.adminFieldDistance,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      validator: _validateDoubleField,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildTextField(
                                controller: _pointsController,
                                label: l10n.adminFieldPoints,
                                keyboardType: TextInputType.number,
                                validator: _validateIntField,
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<QuestDifficulty>(
                                initialValue: _difficulty,
                                decoration: InputDecoration(
                                  labelText: l10n.adminFieldDifficulty,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                items: QuestDifficulty.values
                                    .map(
                                      (difficulty) => DropdownMenuItem(
                                        value: difficulty,
                                        child: Text(
                                          l10n.difficultyLabel(difficulty.name),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _difficulty = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _isActive,
                                onChanged: (value) {
                                  setState(() {
                                    _isActive = value;
                                  });
                                },
                                title: Text(l10n.adminFieldActive),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: l10n.adminLocationsJsonLabel,
                          subtitle: l10n.adminLocationsJsonHelp,
                          child: _buildJsonField(
                            controller: _locationsJsonController,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: l10n.adminTasksJsonLabel,
                          subtitle: l10n.adminTasksJsonHelp,
                          child: _buildJsonField(
                            controller: _tasksJsonController,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildEvidenceModerationSection(l10n),
                        if (_jsonValidationError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _jsonValidationError!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  String? _validateIntField(String? value) {
    final l10n = AppLocalizations.of(context);
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return l10n.adminValidationInvalidNumber;
    }

    final number = int.tryParse(raw);
    if (number == null || number < 0) {
      return l10n.adminValidationInvalidNumber;
    }

    return null;
  }

  String? _validateDoubleField(String? value) {
    final l10n = AppLocalizations.of(context);
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return l10n.adminValidationInvalidNumber;
    }

    final normalized = raw.replaceAll(',', '.');
    final number = double.tryParse(normalized);
    if (number == null || number < 0) {
      return l10n.adminValidationInvalidNumber;
    }

    return null;
  }

  double _parseDistanceValue(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    return double.parse(normalized);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: validator,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildJsonField({required TextEditingController controller}) {
    return TextFormField(
      controller: controller,
      minLines: 8,
      maxLines: 20,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.4,
      ),
      decoration: const InputDecoration(
        alignLabelWithHint: true,
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final locale = AppLocalizations.of(context).locale;
    return DateFormat('dd.MM.yyyy HH:mm', locale).format(value);
  }

  Color _evidenceStatusColor(EvidenceStatus? status) {
    switch (status) {
      case EvidenceStatus.uploaded:
        return AppColors.success;
      case EvidenceStatus.failed:
        return AppColors.error;
      case EvidenceStatus.pending:
      case null:
        return AppColors.accent;
    }
  }

  IconData _evidenceStatusIcon(EvidenceStatus? status) {
    switch (status) {
      case EvidenceStatus.uploaded:
        return Icons.cloud_done_outlined;
      case EvidenceStatus.failed:
        return Icons.cloud_off_outlined;
      case EvidenceStatus.pending:
      case null:
        return Icons.cloud_upload_outlined;
    }
  }

  String _evidenceStatusText(EvidenceStatus? status, AppLocalizations l10n) {
    switch (status) {
      case EvidenceStatus.uploaded:
        return l10n.evidenceStatusUploaded;
      case EvidenceStatus.failed:
        return l10n.evidenceStatusFailed;
      case EvidenceStatus.pending:
      case null:
        return l10n.evidenceStatusPending;
    }
  }

  String _moderationStatusText(
      ModerationStatus? status, AppLocalizations l10n) {
    switch (status) {
      case ModerationStatus.pendingReview:
        return l10n.moderationStatusPendingReview;
      case ModerationStatus.approved:
        return l10n.moderationStatusApproved;
      case ModerationStatus.rejected:
        return l10n.moderationStatusRejected;
      case null:
        return l10n.adminEvidenceStatusNoData;
    }
  }

  Widget _buildEvidenceModerationSection(AppLocalizations l10n) {
    return _SectionCard(
      title: l10n.adminEvidenceModerationTitle,
      subtitle: l10n.adminEvidenceModerationHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.adminEvidenceRecords(_moderationRecords.length),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Spacer(),
              IconButton(
                onPressed: _moderationLoading ? null : _loadModerationStatuses,
                icon: _moderationLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                tooltip: l10n.retry,
              ),
            ],
          ),
          if (_moderationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _moderationError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ],
          if (_moderationTaskIds.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.adminEvidenceNoPhotoTasks,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ] else if (!_moderationLoading && _moderationRecords.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.adminEvidenceStatusNoData,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ] else if (_moderationRecords.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._moderationRecords.take(8).map((record) {
              final color = _evidenceStatusColor(record.evidenceStatus);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_evidenceStatusIcon(record.evidenceStatus),
                        size: 17, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${record.taskType.name} • ${record.taskId}',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.evidenceStatusLabel}: ${_evidenceStatusText(record.evidenceStatus, l10n)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.moderationStatusLabel}: ${_moderationStatusText(record.moderationStatus, l10n)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if ((record.moderationComment ?? '')
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${l10n.moderationCommentLabel}: ${record.moderationComment!.trim()}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            l10n.adminEvidenceUpdatedAt(
                              _formatDateTime(record.progressUpdatedAt),
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ParsedContent {
  final List<QuestLocation>? locations;
  final List<QuestTask>? tasks;
  final String? error;

  const _ParsedContent({
    this.locations,
    this.tasks,
    this.error,
  });
}
