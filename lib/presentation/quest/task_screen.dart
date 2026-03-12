import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/data/services/task_evidence_storage.dart';
import 'package:quest_guide/domain/models/quest_location.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:quest_guide/domain/models/quest_task.dart';
import 'package:quest_guide/domain/models/quest_task_answer.dart';
import 'package:quest_guide/presentation/common/audio_guide_player.dart';
import 'package:quest_guide/presentation/common/custom_text_field.dart';
import 'package:quest_guide/presentation/common/premium_button.dart';
import 'package:quest_guide/presentation/common/glass_card.dart';

class TaskScreen extends StatefulWidget {
  final String questId;
  final String locationIndex;

  const TaskScreen({
    super.key,
    required this.questId,
    required this.locationIndex,
  });

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final _questRepo = QuestRepository();
  final _progressRepo = ProgressRepository();
  final _imagePicker = ImagePicker();
  final TaskEvidenceStorage _evidenceStorage = SupabaseTaskEvidenceStorage();

  bool _loading = true;
  String? _error;
  List<QuestLocation> _locations = [];
  QuestTask? _currentTask;
  QuestProgress? _progress;

  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  final _textController = TextEditingController();

  int _totalScore = 0;
  int _correctAnswers = 0;
  int _totalAnswers = 0;
  final Set<String> _completedTaskIds = <String>{};
  final Map<String, QuestTaskAnswer> _taskAnswers = <String, QuestTaskAnswer>{};

  String? _selectedEvidencePath;
  EvidenceStatus? _selectedEvidenceStatus;
  String? _selectedEvidenceRemotePath;
  String? _selectedEvidenceRemoteUrl;
  String? _selectedEvidenceErrorCode;
  ModerationStatus? _selectedModerationStatus;
  String? _selectedModerationComment;
  DateTime? _selectedModeratedAt;
  String? _selectedModeratedBy;
  bool _evidenceLoading = false;
  String? _evidenceError;

  @override
  void initState() {
    super.initState();
    final routeIndex = int.tryParse(widget.locationIndex) ?? 0;
    _currentIndex = routeIndex < 0 ? 0 : routeIndex;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final locations = await _questRepo.getLocations(widget.questId);
      locations.sort((a, b) => a.order.compareTo(b.order));

      if (locations.isEmpty) {
        if (!mounted) return;
        setState(() {
          _locations = [];
          _loading = false;
          _error = AppLocalizations.of(context).noLocations;
        });
        return;
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      QuestProgress? progress;

      if (userId != null) {
        progress =
            await _progressRepo.getActiveProgress(userId, widget.questId);

        final requestedIndex = _currentIndex.clamp(0, locations.length - 1);
        progress ??= await _progressRepo.startQuest(
          userId: userId,
          questId: widget.questId,
          initialLocationIndex: requestedIndex,
        );

        _bindProgress(progress);

        if (requestedIndex != progress.currentLocationIndex) {
          _progress = _progress!.copyWith(currentLocationIndex: requestedIndex);
          await _progressRepo.updateProgress(_progress!);
        }
      }

      _currentIndex = (_progress?.currentLocationIndex ?? _currentIndex)
          .clamp(0, locations.length - 1);

      final task = await _loadTaskForCurrentIndex(locations, _currentIndex);

      if (!mounted) return;
      setState(() {
        _locations = locations;
        _currentTask = task;
        _loading = false;
        _error = null;
        _restoreTaskState(task);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${AppLocalizations.of(context).error}: $e';
        _loading = false;
      });
    }
  }

  void _bindProgress(QuestProgress progress) {
    _progress = progress;
    _totalScore = progress.earnedPoints;
    _correctAnswers = progress.correctAnswers;
    _totalAnswers = progress.totalAnswers;
    _completedTaskIds
      ..clear()
      ..addAll(progress.completedTaskIds);
    _taskAnswers
      ..clear()
      ..addAll(progress.taskAnswers);
  }

  bool _isTaskAnswered(QuestTask task) {
    if (!_completedTaskIds.contains(task.id)) return false;

    if (task.type == TaskType.photo || task.type == TaskType.findObject) {
      final answer = _taskAnswers[task.id];
      if (answer?.moderationStatus == ModerationStatus.rejected) {
        // rejected evidence должно позволять re-upload/retry.
        return false;
      }
      return task.checkAnswer(
        evidencePath: answer?.evidencePath,
        evidenceStatus: answer?.evidenceStatus,
      );
    }

    return true;
  }

  void _restoreTaskState(QuestTask? task) {
    _selectedAnswer = null;
    _textController.clear();
    _selectedEvidencePath = null;
    _selectedEvidenceStatus = null;
    _selectedEvidenceRemotePath = null;
    _selectedEvidenceRemoteUrl = null;
    _selectedEvidenceErrorCode = null;
    _selectedModerationStatus = null;
    _selectedModerationComment = null;
    _selectedModeratedAt = null;
    _selectedModeratedBy = null;
    _evidenceError = null;

    if (task == null) {
      _answered = false;
      return;
    }

    final savedAnswer = _taskAnswers[task.id];
    _answered = _isTaskAnswered(task);

    if (task.type == TaskType.quiz) {
      _selectedAnswer = savedAnswer?.selectedOptionIndex;
      return;
    }

    if (task.type == TaskType.textInput || task.type == TaskType.riddle) {
      _textController.text = savedAnswer?.textAnswer ?? '';
      return;
    }

    if (task.type == TaskType.photo || task.type == TaskType.findObject) {
      _selectedEvidencePath = savedAnswer?.evidencePath;
      _selectedEvidenceStatus = savedAnswer?.evidenceStatus;
      _selectedEvidenceRemotePath = savedAnswer?.evidenceRemotePath;
      _selectedEvidenceRemoteUrl = savedAnswer?.evidenceRemoteUrl;
      _selectedEvidenceErrorCode = savedAnswer?.evidenceError;
      _selectedModerationStatus = savedAnswer?.moderationStatus;
      _selectedModerationComment = savedAnswer?.moderationComment;
      _selectedModeratedAt = savedAnswer?.moderatedAt;
      _selectedModeratedBy = savedAnswer?.moderatedBy;
    }
  }

  Future<QuestTask?> _loadTaskForCurrentIndex(
    List<QuestLocation> locations,
    int index,
  ) async {
    if (index >= locations.length) return null;
    final taskId = locations[index].taskId;
    if (taskId.isEmpty) return null;
    return _questRepo.getTaskForLocation(widget.questId, taskId);
  }

  Future<void> _persistProgress() async {
    final progress = _progress;
    if (progress == null) return;

    final updated = progress.copyWith(
      currentLocationIndex: _currentIndex,
      earnedPoints: _totalScore,
      correctAnswers: _correctAnswers,
      totalAnswers: _totalAnswers,
      completedTaskIds: _completedTaskIds.toList(),
      taskAnswers: Map<String, QuestTaskAnswer>.from(_taskAnswers),
      lastUpdatedAt: DateTime.now(),
    );

    _progress = updated;
    await _progressRepo.updateProgress(updated);
  }

  Future<void> _saveAnswerResult({
    required QuestTask task,
    required bool isCorrect,
    required int pointsEarned,
    int? selectedOptionIndex,
    String? textAnswer,
    String? evidencePath,
    EvidenceStatus? evidenceStatus,
    String? evidenceRemotePath,
    String? evidenceRemoteUrl,
    String? evidenceError,
    bool updateOnly = false,
  }) async {
    final alreadyCompleted = _completedTaskIds.contains(task.id);
    final previousAnswer = _taskAnswers[task.id];
    final now = DateTime.now();

    QuestTaskAnswer nextAnswer;
    if (task.type == TaskType.photo || task.type == TaskType.findObject) {
      final baseline = previousAnswer ??
          QuestTaskAnswer(
            taskId: task.id,
            taskType: task.type,
            selectedOptionIndex: selectedOptionIndex,
            textAnswer: textAnswer,
            evidencePath: evidencePath,
            evidenceStatus: evidenceStatus,
            evidenceRemotePath: evidenceRemotePath,
            evidenceRemoteUrl: evidenceRemoteUrl,
            evidenceError: evidenceError,
            answeredAt: now,
          );

      nextAnswer = baseline.withEvidenceUploadUpdate(
        evidencePath: evidencePath,
        evidenceStatus: evidenceStatus,
        evidenceRemotePath: evidenceRemotePath,
        evidenceRemoteUrl: evidenceRemoteUrl,
        evidenceError: evidenceError,
        answeredAt: now,
      );
    } else {
      nextAnswer = QuestTaskAnswer(
        taskId: task.id,
        taskType: task.type,
        selectedOptionIndex: selectedOptionIndex,
        textAnswer: textAnswer,
        evidencePath: evidencePath,
        evidenceStatus: evidenceStatus,
        evidenceRemotePath: evidenceRemotePath,
        evidenceRemoteUrl: evidenceRemoteUrl,
        evidenceError: evidenceError,
        answeredAt: now,
      );
    }

    _taskAnswers[task.id] = nextAnswer;

    if (task.type == TaskType.photo || task.type == TaskType.findObject) {
      _selectedEvidencePath = nextAnswer.evidencePath;
      _selectedEvidenceStatus = nextAnswer.evidenceStatus;
      _selectedEvidenceRemotePath = nextAnswer.evidenceRemotePath;
      _selectedEvidenceRemoteUrl = nextAnswer.evidenceRemoteUrl;
      _selectedEvidenceErrorCode = nextAnswer.evidenceError;
      _selectedModerationStatus = nextAnswer.moderationStatus;
      _selectedModerationComment = nextAnswer.moderationComment;
      _selectedModeratedAt = nextAnswer.moderatedAt;
      _selectedModeratedBy = nextAnswer.moderatedBy;
    }

    if (!alreadyCompleted && !updateOnly) {
      _completedTaskIds.add(task.id);
      _totalAnswers += 1;
      if (isCorrect) {
        _correctAnswers += 1;
      }
      _totalScore += pointsEarned;
    }

    await _persistProgress();
  }

  Future<void> _onAnswerSelected(int index) async {
    if (_answered || _currentTask == null) return;

    final task = _currentTask!;
    final isCorrect = task.correctOptionIndex == index;

    setState(() {
      _selectedAnswer = index;
      _answered = true;
    });

    await _saveAnswerResult(
      task: task,
      isCorrect: isCorrect,
      pointsEarned: isCorrect ? task.points : 0,
      selectedOptionIndex: index,
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _onTextSubmitted() async {
    if (_answered || _currentTask == null) return;

    final answer = _textController.text.trim();
    if (answer.isEmpty) return;

    final task = _currentTask!;
    final isCorrect = task.checkAnswer(textAnswer: answer);

    setState(() {
      _answered = true;
    });

    await _saveAnswerResult(
      task: task,
      isCorrect: isCorrect,
      pointsEarned: isCorrect ? task.points : 0,
      textAnswer: answer,
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<ImageSource?> _selectImageSource() {
    final l10n = AppLocalizations.of(context);

    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(l10n.photoFromGallery),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text(l10n.photoFromCamera),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickEvidencePhoto() async {
    final task = _currentTask;
    if (task == null) return;

    final source = await _selectImageSource();
    if (source == null) return;

    if (!mounted) return;
    setState(() {
      _evidenceLoading = true;
      _evidenceError = null;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
      );

      if (image == null) {
        if (!mounted) return;
        setState(() {
          _evidenceLoading = false;
        });
        return;
      }

      final saveResult = await _evidenceStorage.saveEvidence(
        questId: widget.questId,
        taskId: task.id,
        userId: FirebaseAuth.instance.currentUser?.uid,
        sourceFile: image,
      );

      final previousPath = _selectedEvidencePath;
      final previousRemotePath = _selectedEvidenceRemotePath;

      if (!mounted) return;
      setState(() {
        _selectedEvidencePath = saveResult.localPath;
        _selectedEvidenceStatus = saveResult.status;
        _selectedEvidenceRemotePath = saveResult.remotePath;
        _selectedEvidenceRemoteUrl = saveResult.remoteDownloadUrl;
        _selectedEvidenceErrorCode = saveResult.errorCode;
        if (saveResult.status == EvidenceStatus.uploaded) {
          _selectedModerationStatus = ModerationStatus.pendingReview;
          _selectedModerationComment = null;
          _selectedModeratedAt = null;
          _selectedModeratedBy = null;
        }
        _evidenceLoading = false;
      });

      await _saveAnswerResult(
        task: task,
        isCorrect: true,
        pointsEarned: 0,
        evidencePath: saveResult.localPath,
        evidenceStatus: saveResult.status,
        evidenceRemotePath: saveResult.remotePath,
        evidenceRemoteUrl: saveResult.remoteDownloadUrl,
        evidenceError: saveResult.errorCode,
        updateOnly: true,
      );

      if (previousPath != null && previousPath != saveResult.localPath) {
        await _evidenceStorage.deleteEvidence(
          localPath: previousPath,
          remotePath: previousRemotePath,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _evidenceLoading = false;
        _evidenceError = AppLocalizations.of(context).photoPickFailed;
      });
    }
  }

  Future<void> _retryEvidenceUpload() async {
    final task = _currentTask;
    final localPath = _selectedEvidencePath;
    if (task == null || localPath == null || localPath.trim().isEmpty) return;

    if (!mounted) return;
    setState(() {
      _evidenceLoading = true;
      _evidenceError = null;
    });

    try {
      final retryResult = await _evidenceStorage.retryUpload(
        questId: widget.questId,
        taskId: task.id,
        userId: FirebaseAuth.instance.currentUser?.uid,
        localEvidencePath: localPath,
      );

      if (!mounted) return;
      setState(() {
        _selectedEvidenceStatus = retryResult.status;
        _selectedEvidenceRemotePath = retryResult.remotePath;
        _selectedEvidenceRemoteUrl = retryResult.remoteDownloadUrl;
        _selectedEvidenceErrorCode = retryResult.errorCode;
        if (retryResult.status == EvidenceStatus.uploaded) {
          _selectedModerationStatus = ModerationStatus.pendingReview;
          _selectedModerationComment = null;
          _selectedModeratedAt = null;
          _selectedModeratedBy = null;
        }
        _evidenceLoading = false;
      });

      await _saveAnswerResult(
        task: task,
        isCorrect: true,
        pointsEarned: 0,
        evidencePath: retryResult.localPath,
        evidenceStatus: retryResult.status,
        evidenceRemotePath: retryResult.remotePath,
        evidenceRemoteUrl: retryResult.remoteDownloadUrl,
        evidenceError: retryResult.errorCode,
        updateOnly: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _evidenceLoading = false;
        _evidenceError = AppLocalizations.of(context).evidenceRetryFailed;
      });
    }
  }

  Future<void> _submitEvidenceTask() async {
    if (_answered || _currentTask == null) return;

    final task = _currentTask!;
    final evidencePath = _selectedEvidencePath;
    final evidenceStatus = _selectedEvidenceStatus;

    if (!task.checkAnswer(
      evidencePath: evidencePath,
      evidenceStatus: evidenceStatus,
    )) {
      if (!mounted) return;
      setState(() {
        _evidenceError = evidencePath == null || evidencePath.trim().isEmpty
            ? AppLocalizations.of(context).photoRequiredError
            : AppLocalizations.of(context).evidenceCloudUploadRequired;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _answered = true;
      _evidenceError = null;
    });

    await _saveAnswerResult(
      task: task,
      isCorrect: true,
      pointsEarned: task.points,
      evidencePath: evidencePath,
      evidenceStatus: evidenceStatus,
      evidenceRemotePath: _selectedEvidenceRemotePath,
      evidenceRemoteUrl: _selectedEvidenceRemoteUrl,
      evidenceError: null,
    );

    if (!mounted) return;
    setState(() {});
  }

  String _evidenceHint(QuestTask task, AppLocalizations l10n) {
    if (task.type == TaskType.photo) {
      return l10n.photoTaskEvidenceHint;
    }
    return l10n.findObjectEvidenceHint;
  }

  String _evidenceSubmitLabel(QuestTask task, AppLocalizations l10n) {
    if (task.type == TaskType.photo) {
      return l10n.submitPhotoEvidence;
    }
    return l10n.submitFindObjectEvidence;
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

  String _evidenceStatusLabel(EvidenceStatus? status, AppLocalizations l10n) {
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

  String _evidenceErrorMessageByCode(String? code, AppLocalizations l10n) {
    switch (code) {
      case TaskEvidenceErrorCode.unauthenticated:
        return l10n.evidenceErrorUnauthenticated;
      case TaskEvidenceErrorCode.localFileMissing:
        return l10n.evidenceErrorLocalFileMissing;
      case TaskEvidenceErrorCode.cloudUnavailable:
        return l10n.evidenceErrorCloudUnavailable;
      case TaskEvidenceErrorCode.uploadFailed:
        return l10n.evidenceErrorUploadFailed;
      case null:
      case '':
        return l10n.evidenceErrorUnknown;
      default:
        return '${l10n.evidenceErrorUploadFailed} ($code)';
    }
  }

  String? _evidenceStatusMessage(AppLocalizations l10n) {
    switch (_selectedEvidenceStatus) {
      case EvidenceStatus.uploaded:
        return l10n.evidenceUploadedMessage;
      case EvidenceStatus.pending:
        return _evidenceErrorMessageByCode(_selectedEvidenceErrorCode, l10n);
      case EvidenceStatus.failed:
        return _evidenceErrorMessageByCode(_selectedEvidenceErrorCode, l10n);
      case null:
        return null;
    }
  }

  Color _moderationStatusColor(ModerationStatus? status) {
    switch (status) {
      case ModerationStatus.approved:
        return AppColors.success;
      case ModerationStatus.rejected:
        return AppColors.error;
      case ModerationStatus.pendingReview:
      case null:
        return AppColors.accent;
    }
  }

  IconData _moderationStatusIcon(ModerationStatus? status) {
    switch (status) {
      case ModerationStatus.approved:
        return Icons.verified_rounded;
      case ModerationStatus.rejected:
        return Icons.gpp_bad_rounded;
      case ModerationStatus.pendingReview:
      case null:
        return Icons.fact_check_outlined;
    }
  }

  String _moderationStatusLabel(
      ModerationStatus? status, AppLocalizations l10n) {
    switch (status) {
      case ModerationStatus.approved:
        return l10n.moderationStatusApproved;
      case ModerationStatus.rejected:
        return l10n.moderationStatusRejected;
      case ModerationStatus.pendingReview:
      case null:
        return l10n.moderationStatusPendingReview;
    }
  }

  String? _moderationStatusMessage(AppLocalizations l10n) {
    switch (_selectedModerationStatus) {
      case ModerationStatus.approved:
        return l10n.moderationApprovedMessage;
      case ModerationStatus.rejected:
        return l10n.moderationRejectedMessage;
      case ModerationStatus.pendingReview:
        return l10n.moderationPendingReviewMessage;
      case null:
        return null;
    }
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatModeratedAt(DateTime value) {
    final local = value.toLocal();
    return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String? _moderationMetaLabel() {
    final parts = <String>[];
    final moderatedBy = _selectedModeratedBy?.trim();
    if (moderatedBy != null && moderatedBy.isNotEmpty) {
      parts.add(moderatedBy);
    }

    if (_selectedModeratedAt != null) {
      parts.add(_formatModeratedAt(_selectedModeratedAt!));
    }

    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' • ');
  }

  bool _canShowPendingReviewBanner(QuestTask task) {
    if (task.type != TaskType.photo && task.type != TaskType.findObject) {
      return false;
    }

    final answer = _taskAnswers[task.id];
    if (answer == null) return false;
    return answer.evidenceStatus == EvidenceStatus.uploaded &&
        answer.moderationStatus == ModerationStatus.pendingReview;
  }

  bool _canSubmitEvidenceTask(QuestTask task) {
    if (_selectedModerationStatus == ModerationStatus.rejected) {
      return false;
    }

    return task.checkAnswer(
      evidencePath: _selectedEvidencePath,
      evidenceStatus: _selectedEvidenceStatus,
    );
  }

  Widget _buildEvidenceSection(QuestTask task, AppLocalizations l10n) {
    final selectedPath = _selectedEvidencePath;
    final selectedStatus = _selectedEvidenceStatus;
    final previewPath = selectedPath == null
        ? null
        : _evidenceStorage.resolvePreviewPath(selectedPath);
    final previewFile = previewPath == null ? null : File(previewPath);
    final hasPreview = previewFile?.existsSync() ?? false;
    final statusMessage = _evidenceStatusMessage(l10n);
    final moderationStatus = _selectedModerationStatus;
    final moderationMessage = _moderationStatusMessage(l10n);
    final moderationMeta = _moderationMetaLabel();
    final isModerationRejected = moderationStatus == ModerationStatus.rejected;
    final canRetry = selectedPath != null &&
        (selectedStatus != EvidenceStatus.uploaded || isModerationRejected);
    final canSubmit = _canSubmitEvidenceTask(task);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _evidenceHint(task, l10n),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.photoPreview,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: double.infinity,
            child: Container(
              constraints: const BoxConstraints(minHeight: 160, maxHeight: 240),
              child: hasPreview
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        previewFile!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.photoNotSelected,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PremiumButton(
          text: selectedPath == null ? l10n.attachPhoto : l10n.replacePhoto,
          icon: Icons.add_a_photo_outlined,
          isSecondary: true,
          isLoading: _evidenceLoading,
          onPressed: _pickEvidencePhoto,
        ),
        if (selectedPath != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  _evidenceStatusColor(selectedStatus).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _evidenceStatusColor(selectedStatus)
                    .withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _evidenceStatusIcon(selectedStatus),
                  size: 18,
                  color: _evidenceStatusColor(selectedStatus),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.evidenceStatusLabel}: ${_evidenceStatusLabel(selectedStatus, l10n)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (statusMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          statusMessage,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (moderationStatus != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _moderationStatusColor(moderationStatus)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _moderationStatusColor(moderationStatus)
                    .withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _moderationStatusIcon(moderationStatus),
                  size: 18,
                  color: _moderationStatusColor(moderationStatus),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.moderationStatusLabel}: ${_moderationStatusLabel(moderationStatus, l10n)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (moderationMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          moderationMessage,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                      if ((_selectedModerationComment ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${l10n.moderationCommentLabel}: ${_selectedModerationComment!.trim()}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                        ),
                      ],
                      if (moderationMeta != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          moderationMeta,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (isModerationRejected && selectedPath != null) ...[
          const SizedBox(height: 8),
          PremiumButton(
            text: l10n.moderationRetryCta,
            icon: Icons.add_a_photo_outlined,
            isSecondary: true,
            isLoading: _evidenceLoading,
            onPressed: _pickEvidencePhoto,
          ),
        ],
        if (!_answered && canRetry) ...[
          const SizedBox(height: 8),
          PremiumButton(
            text: l10n.evidenceRetryUpload,
            icon: Icons.refresh_rounded,
            isSecondary: true,
            isLoading: _evidenceLoading,
            onPressed: _retryEvidenceUpload,
          ),
        ],
        if (_evidenceError != null) ...[
          const SizedBox(height: 8),
          Text(
            _evidenceError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
          ),
        ],
        if (_answered) ...[
          const SizedBox(height: 12),
          Text(task.type == TaskType.photo
              ? l10n.photoAccepted
              : l10n.objectFound),
        ] else ...[
          const SizedBox(height: 12),
          PremiumButton(
            text: _evidenceSubmitLabel(task, l10n),
            isLoading: _evidenceLoading,
            onPressed: (!canSubmit) ? null : _submitEvidenceTask,
          ),
          if (selectedPath != null && !canSubmit) ...[
            const SizedBox(height: 8),
            Text(
              _selectedModerationStatus == ModerationStatus.rejected
                  ? l10n.moderationRejectedMessage
                  : l10n.evidenceCloudUploadRequired,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _goNext() async {
    if (_locations.isEmpty) return;

    if (_currentIndex + 1 >= _locations.length) {
      final progressId = _progress?.id;
      context.go(
        '/quest/${widget.questId}/complete?score=$_totalScore&total=${_locations.length}&progressId=${progressId ?? ''}&correct=$_correctAnswers&answers=$_totalAnswers',
      );
      return;
    }

    setState(() {
      _currentIndex += 1;
      _loading = true;
      _answered = false;
      _selectedAnswer = null;
      _textController.clear();
      _selectedEvidencePath = null;
      _selectedEvidenceStatus = null;
      _selectedEvidenceRemotePath = null;
      _selectedEvidenceRemoteUrl = null;
      _selectedEvidenceErrorCode = null;
      _selectedModerationStatus = null;
      _selectedModerationComment = null;
      _selectedModeratedAt = null;
      _selectedModeratedBy = null;
      _evidenceError = null;
    });

    await _persistProgress();

    try {
      final task = await _loadTaskForCurrentIndex(_locations, _currentIndex);
      if (!mounted) return;
      setState(() {
        _currentTask = task;
        _loading = false;
        _restoreTaskState(task);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${AppLocalizations.of(context).error}: $e';
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }

    final location =
        _currentIndex < _locations.length ? _locations[_currentIndex] : null;
    final task = _currentTask;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pointOf(_currentIndex + 1, _locations.length)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 4),
                Text('$_totalScore ${l10n.pointsLabel}',
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _locations.length,
              backgroundColor: AppColors.divider,
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 20),
            if (location != null) ...[
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(location.name,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(location.description,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (location.historicalInfo.isNotEmpty) ...[
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(location.historicalInfo,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ],
              if (location.audioUrl != null &&
                  location.audioUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                AudioGuidePlayer(audioUrl: location.audioUrl!),
              ],
            ],
            const SizedBox(height: 24),
            if (task != null) ...[
              Text(l10n.taskLabel,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(task.question,
                  style: Theme.of(context).textTheme.titleLarge),
              if (task.hint != null && task.hint!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${l10n.hintLabel}: ${task.hint}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: 20),
              if (task.type == TaskType.quiz && task.options.isNotEmpty) ...[
                ...task.options.asMap().entries.map(
                      (entry) => _AnswerOption(
                        index: entry.key,
                        text: entry.value,
                        isSelected: _selectedAnswer == entry.key,
                        isCorrect: entry.key == task.correctOptionIndex,
                        isAnswered: _answered,
                        onTap: () => _onAnswerSelected(entry.key),
                      ),
                    ),
              ],
              if (task.type == TaskType.textInput ||
                  task.type == TaskType.riddle) ...[
                CustomTextField(
                  controller: _textController,
                  enabled: !_answered,
                  hintText: l10n.enterAnswer,
                  suffixIcon: !_answered
                      ? IconButton(
                          icon: const Icon(Icons.send_rounded,
                              color: AppColors.primary),
                          onPressed: _onTextSubmitted,
                        )
                      : null,
                ),
                if (_answered) ...[
                  const SizedBox(height: 12),
                  _AnswerResultBanner(
                    isCorrect: _currentTask!
                        .checkAnswer(textAnswer: _textController.text.trim()),
                    successText: l10n.correctAnswer(_currentTask!.points),
                    failureText:
                        '${l10n.wrongAnswer}. ${l10n.correctAnswerIs}: ${_currentTask!.correctAnswer ?? "—"}',
                  ),
                ],
              ],
              if (task.type == TaskType.photo ||
                  task.type == TaskType.findObject) ...[
                _buildEvidenceSection(task, l10n),
              ],
              const SizedBox(height: 24),
              if (_answered) ...[
                if (task.type == TaskType.quiz)
                  _AnswerResultBanner(
                    isCorrect: _selectedAnswer == task.correctOptionIndex,
                    successText: l10n.correctAnswer(task.points),
                    failureText: l10n.wrongAnswer,
                  ),
                if (_canShowPendingReviewBanner(task)) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.hourglass_top_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.moderationPendingReviewMessage,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                PremiumButton(
                  text: _currentIndex + 1 >= _locations.length
                      ? l10n.finishQuest
                      : l10n.nextPoint,
                  onPressed: _goNext,
                ),
              ],
            ],
            if (task == null && location != null) ...[
              Text(l10n.noTask),
              const SizedBox(height: 20),
              PremiumButton(
                text: _currentIndex + 1 >= _locations.length
                    ? l10n.finishQuest
                    : l10n.nextPoint,
                onPressed: _goNext,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerResultBanner extends StatelessWidget {
  final bool isCorrect;
  final String successText;
  final String failureText;

  const _AnswerResultBanner({
    required this.isCorrect,
    required this.successText,
    required this.failureText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isCorrect ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isCorrect ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(isCorrect ? successText : failureText)),
        ],
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  final int index;
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isAnswered;
  final VoidCallback onTap;

  const _AnswerOption({
    required this.index,
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isAnswered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = AppColors.divider;
    Color bgColor = AppColors.surface;
    Color textColor = AppColors.textPrimary;

    if (isAnswered && isSelected && isCorrect) {
      borderColor = AppColors.success;
      bgColor = AppColors.success.withValues(alpha: 0.1);
    } else if (isAnswered && isSelected && !isCorrect) {
      borderColor = AppColors.error;
      bgColor = AppColors.error.withValues(alpha: 0.1);
      textColor = AppColors.error;
    } else if (isAnswered && isCorrect) {
      borderColor = AppColors.success;
      bgColor = AppColors.success.withValues(alpha: 0.05);
    }

    return GestureDetector(
      onTap: isAnswered ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: borderColor.withValues(alpha: 0.2),
              child: Text(
                ['A', 'B', 'C', 'D'][index % 4],
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Text(text, style: TextStyle(color: textColor, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
