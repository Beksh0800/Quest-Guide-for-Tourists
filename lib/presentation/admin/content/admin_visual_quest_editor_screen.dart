import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:quest_guide/core/constants/kazakhstan_cities.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/domain/models/quest.dart';
import 'package:quest_guide/domain/models/quest_location.dart';
import 'package:quest_guide/domain/models/quest_task.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quest_guide/presentation/common/admin_map_picker_screen.dart';
import 'package:quest_guide/data/repositories/supabase_admin_storage_repository.dart';
import 'package:quest_guide/presentation/common/premium_button.dart';
import 'package:quest_guide/presentation/common/glass_card.dart';
import 'package:quest_guide/presentation/common/custom_text_field.dart';
import 'package:quest_guide/presentation/common/fullscreen_image_viewer.dart';

class AdminVisualQuestEditorScreen extends StatefulWidget {
  final String questId;

  const AdminVisualQuestEditorScreen({
    super.key,
    required this.questId,
  });

  @override
  State<AdminVisualQuestEditorScreen> createState() =>
      _AdminVisualQuestEditorScreenState();
}

class _AdminVisualQuestEditorScreenState
    extends State<AdminVisualQuestEditorScreen> with TickerProviderStateMixin {
  final QuestRepository _questRepository = QuestRepository();
  final SupabaseAdminStorageRepository _storageRepository =
      SupabaseAdminStorageRepository();
  late TabController _tabController;

  // Basic quest fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _questImageUrlController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  QuestDifficulty _difficulty = QuestDifficulty.easy;
  String _selectedCity = KazakhstanCities.defaultCity;
  bool _isActive = false;
  bool _loading = true;
  bool _saving = false;

  Quest? _quest;
  List<QuestLocation> _locations = [];
  List<QuestTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadQuest();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _questImageUrlController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _loadQuest() async {
    try {
      // Временно используем демо-данные
      final bundle =
          await _questRepository.getQuestContentForAdmin(widget.questId);
      if (bundle != null) {
        setState(() {
          _quest = bundle.quest;
          _titleController.text = bundle.quest.title;
          _selectedCity = KazakhstanCities.contains(bundle.quest.city)
              ? bundle.quest.city
              : KazakhstanCities.defaultCity;
          _descriptionController.text = bundle.quest.description;
          _questImageUrlController.text = bundle.quest.imageUrl;
          _durationController.text = bundle.quest.estimatedMinutes.toString();
          _distanceController.text = bundle.quest.distanceKm.toString();
          _pointsController.text = bundle.quest.totalPoints.toString();
          _difficulty = bundle.quest.difficulty;
          _isActive = bundle.quest.isActive;
          _locations = List.from(bundle.locations);
          _tasks = List.from(bundle.tasks);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveQuest() async {
    final validationError = _validateBeforeSave();
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    final estimatedMinutes = int.tryParse(_durationController.text.trim());
    final distanceKm = double.tryParse(_distanceController.text.trim());
    final totalPoints = int.tryParse(_pointsController.text.trim());
    if (estimatedMinutes == null || distanceKm == null || totalPoints == null) {
      _showError('Проверьте числовые поля: длительность, дистанция, очки.');
      return;
    }

    setState(() => _saving = true);

    try {
      final updatedQuest = Quest(
        id: widget.questId,
        title: _titleController.text,
        city: _selectedCity,
        description: _descriptionController.text,
        imageUrl: _questImageUrlController.text.trim(),
        estimatedMinutes: estimatedMinutes,
        distanceKm: distanceKm,
        totalPoints: totalPoints,
        difficulty: _difficulty,
        isActive: _isActive,
        createdAt: _quest?.createdAt ?? DateTime.now(),
        locationIds: _locations.map((loc) => loc.id).toList(),
      );

      final bundle = QuestContentBundle(
        quest: updatedQuest,
        locations: _locations,
        tasks: _tasks,
      );

      await _questRepository.saveQuestContent(bundle);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Квест успешно сохранен!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  String? _validateBeforeSave() {
    if (_titleController.text.trim().isEmpty) {
      return 'Укажите название квеста.';
    }
    if (_selectedCity.trim().isEmpty) {
      return 'Укажите город квеста.';
    }

    final estimatedMinutes = int.tryParse(_durationController.text.trim());
    if (estimatedMinutes == null || estimatedMinutes <= 0) {
      return 'Длительность должна быть положительным числом.';
    }

    final distanceKm = double.tryParse(_distanceController.text.trim());
    if (distanceKm == null || distanceKm <= 0) {
      return 'Дистанция должна быть больше 0.';
    }

    final totalPoints = int.tryParse(_pointsController.text.trim());
    if (totalPoints == null || totalPoints <= 0) {
      return 'Очки должны быть положительным числом.';
    }

    if (_locations.isEmpty) {
      return 'Добавьте хотя бы одну локацию.';
    }
    if (_tasks.isEmpty) {
      return 'Добавьте хотя бы одно задание.';
    }

    for (final location in _locations) {
      if (location.name.trim().isEmpty) {
        return 'У всех локаций должно быть название.';
      }
    }

    for (final task in _tasks) {
      if (task.locationId.trim().isEmpty) {
        return 'У каждого задания должна быть привязка к локации.';
      }
      if (task.question.trim().isEmpty) {
        return 'У каждого задания должен быть текст вопроса.';
      }
    }

    return null;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  String _formatUploadError(Object error) {
    final text = error.toString().trim();
    final cleaned = text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
    if (cleaned.isEmpty) {
      return 'Не удалось загрузить изображение. Повторите попытку.';
    }
    return cleaned;
  }

  Widget _buildDialogErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openImageViewer(String imageUrl) async {
    final url = imageUrl.trim();
    if (url.isEmpty) return;
    await FullscreenImageViewer.show(context, imageUrl: url);
  }

  void _addLocation() {
    final newLocation = QuestLocation(
      id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
      questId: widget.questId,
      order: _locations.length + 1,
      name: '',
      description: '',
      historicalInfo: '',
      latitude: 0.0,
      longitude: 0.0,
      imageUrl: '',
      audioUrl: '',
      taskId: '',
      radiusMeters: 50,
    );

    setState(() {
      _locations.add(newLocation);
    });

    _tabController.animateTo(1); // Переключить на вкладку локаций
  }

  void _addTask() {
    if (_locations.isEmpty) {
      _showError('Сначала добавьте хотя бы одну локацию.');
      _tabController.animateTo(1);
      return;
    }

    final newTask = QuestTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      locationId: _locations.isNotEmpty ? _locations.first.id : '',
      type: TaskType.quiz,
      question: '',
      points: 10,
      options: [],
      correctOptionIndex: 0,
      correctAnswer: '',
      timeLimitSeconds: 60,
    );

    setState(() {
      _tasks.add(newTask);
    });

    _tabController.animateTo(2); // Переключить на вкладку заданий
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Визуальный редактор квеста'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FilledButton.icon(
                onPressed: _saveQuest,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Сохранить'),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.info), text: 'Основное'),
                    Tab(icon: Icon(Icons.location_on), text: 'Локации'),
                    Tab(icon: Icon(Icons.quiz), text: 'Задания'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBasicInfoTab(),
                      _buildLocationsTab(),
                      _buildTasksTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    final double buttonWidth = math.min(
      420,
      math.max(220, MediaQuery.of(context).size.width - 24),
    );

    Widget? button;
    switch (_tabController.index) {
      case 1:
        button = PremiumButton(
          onPressed: _addLocation,
          icon: Icons.add_location,
          text: 'Добавить локацию',
        );
        break;
      case 2:
        button = PremiumButton(
          onPressed: _addTask,
          icon: Icons.add_task,
          text: 'Добавить задание',
        );
        break;
      case 0:
      default:
        return null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(width: buttonWidth, child: button),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Основная информация',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _titleController,
                      label: 'Название квеста',
                      icon: Icons.title,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCity,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Город',
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      items: KazakhstanCities.names
                          .map(
                            (city) => DropdownMenuItem<String>(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedCity = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _questImageUrlController,
                      label: 'URL обложки квеста',
                      icon: Icons.image_outlined,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: PremiumButton(
                            text: 'Загрузить обложку',
                            icon: Icons.upload_file_rounded,
                            onPressed: () async {
                              try {
                                final url = await _storageRepository
                                    .pickAndUploadImage(folder: 'quests');
                                if (url != null && mounted) {
                                  setState(() {
                                    _questImageUrlController.text = url;
                                  });
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка загрузки: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_questImageUrlController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            _openImageViewer(_questImageUrlController.text),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _questImageUrlController.text.trim(),
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: double.infinity,
                              height: 160,
                              color: AppColors.surfaceVariant,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_questImageUrlController.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Нажмите на изображение, чтобы открыть на весь экран',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Описание',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Описание квеста',
                      icon: Icons.description,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Параметры',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _durationController,
                            label: 'Длительность (мин)',
                            icon: Icons.timer,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _distanceController,
                            label: 'Дистанция (км)',
                            icon: Icons.directions,
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _pointsController,
                            label: 'Очки',
                            icon: Icons.stars,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _buildDifficultyDropdown(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildActiveSwitch(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return CustomTextField(
      controller: controller,
      hintText: label,
      prefixIcon: icon,
      maxLines: maxLines,
      keyboardType: keyboardType,
    );
  }

  Widget _buildDifficultyDropdown() {
    return DropdownButtonFormField<QuestDifficulty>(
      initialValue: _difficulty,
      decoration: InputDecoration(
        labelText: 'Сложность',
        prefixIcon:
            const Icon(Icons.signal_cellular_alt, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: AppColors.textSecondary),
      ),
      items: QuestDifficulty.values.map((difficulty) {
        return DropdownMenuItem(
          value: difficulty,
          child: Text(_getDifficultyLabel(difficulty)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _difficulty = value!);
      },
      isExpanded: true,
    );
  }

  Widget _buildActiveSwitch() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.visibility, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Опубликовать квест',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                  ),
                  Text(
                    'Активный квест будет доступен пользователям',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isActive,
              activeThumbColor: AppColors.primary,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsTab() {
    return Column(
      children: [
        // Заголовок с информацией
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Точки маршрута (${_locations.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              if (_locations.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Добавьте точки маршрута',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
        // Список локаций
        Expanded(
          child: _locations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет локаций',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textHint,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Нажмите на кнопку ниже чтобы добавить первую точку',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
                  itemCount: _locations.length,
                  itemBuilder: (context, index) {
                    final location = _locations[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Заголовок локации
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      location.name.isEmpty
                                          ? 'Локация ${index + 1}'
                                          : location.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () => _editLocation(index),
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Редактировать',
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteLocation(index),
                                        icon: const Icon(Icons.delete_outline,
                                            color: AppColors.error),
                                        tooltip: 'Удалить',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Описание
                              if (location.description.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Описание',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(location.description),
                                    ],
                                  ),
                                ),
                              // Историческая справка
                              if (location.historicalInfo.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Историческая справка',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(location.historicalInfo),
                                    ],
                                  ),
                                ),
                              // Координаты и доп. информация
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (location.latitude != 0 ||
                                        location.longitude != 0)
                                      _InfoChip(
                                        icon: Icons.gps_fixed,
                                        label:
                                            '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                                      ),
                                    if (location.radiusMeters > 0)
                                      _InfoChip(
                                        icon: Icons.radio_button_unchecked,
                                        label:
                                            'Радиус: ${location.radiusMeters}м',
                                      ),
                                    if (location.taskId.isNotEmpty)
                                      _InfoChip(
                                        icon: Icons.task_alt,
                                        label:
                                            'Задание: ${_taskTitleById(location.taskId)}',
                                      ),
                                  ],
                                ),
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
    );
  }

  Widget _buildTasksTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.quiz, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Задания (${_tasks.length})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет заданий',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textHint,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Нажмите кнопку ниже, чтобы добавить первое задание',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    final locationName = _locationNameById(task.locationId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      task.question.trim().isEmpty
                                          ? 'Задание ${index + 1}'
                                          : task.question.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoChip(
                                    icon: Icons.category_outlined,
                                    label: _getTaskTypeLabel(task.type),
                                  ),
                                  _InfoChip(
                                    icon: Icons.location_on_outlined,
                                    label: locationName,
                                  ),
                                  _InfoChip(
                                    icon: Icons.stars_outlined,
                                    label: '${task.points} очков',
                                  ),
                                  if ((task.imageUrl ?? '').trim().isNotEmpty)
                                    const _InfoChip(
                                      icon: Icons.image_outlined,
                                      label: 'Есть изображение',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showTaskDetails(task),
                                    icon: const Icon(Icons.open_in_new_rounded),
                                    label: const Text('Подробнее'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _editTask(index),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Изменить'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _deleteTask(index),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.error,
                                    ),
                                    label: const Text(
                                      'Удалить',
                                      style: TextStyle(color: AppColors.error),
                                    ),
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
    );
  }

  String _locationNameById(String locationId) {
    QuestLocation? location;
    for (final item in _locations) {
      if (item.id == locationId) {
        location = item;
        break;
      }
    }
    if (location == null) return 'Не выбрана';
    final name = location.name.trim();
    return name.isEmpty ? 'Локация ${location.order}' : name;
  }

  String _taskTitleById(String taskId) {
    QuestTask? task;
    for (final item in _tasks) {
      if (item.id == taskId) {
        task = item;
        break;
      }
    }
    if (task == null) return taskId;
    final question = task.question.trim();
    if (question.isEmpty) return task.id;
    return question;
  }

  Future<void> _showTaskDetails(QuestTask task) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final locationName = _locationNameById(task.locationId);
        final options = task.options.where((e) => e.trim().isNotEmpty).toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Подробности задания',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildTaskDetailLine('ID', task.id),
                  _buildTaskDetailLine('Локация', locationName),
                  _buildTaskDetailLine('Location ID', task.locationId),
                  _buildTaskDetailLine('Тип', _getTaskTypeLabel(task.type)),
                  _buildTaskDetailLine('Вопрос', task.question.trim()),
                  if ((task.hint ?? '').trim().isNotEmpty)
                    _buildTaskDetailLine('Подсказка', task.hint!.trim()),
                  if ((task.correctAnswer ?? '').trim().isNotEmpty)
                    _buildTaskDetailLine(
                        'Правильный ответ', task.correctAnswer!.trim()),
                  if (options.isNotEmpty)
                    _buildTaskDetailLine('Варианты', options.join('\n')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskDetailLine(String label, String value) {
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
            TextSpan(text: value.isEmpty ? 'Не заполнено' : value),
          ],
        ),
      ),
    );
  }

  void _editLocation(int index) {
    final location = _locations[index];
    _showLocationEditDialog(location, index);
  }

  void _deleteLocation(int index) {
    final deleted = _locations[index];
    setState(() {
      _locations.removeAt(index);
      for (var i = 0; i < _locations.length; i++) {
        _locations[i] = _locations[i].copyWith(order: i + 1);
      }

      // Сбрасываем привязки удаленной локации в заданиях.
      for (var i = 0; i < _tasks.length; i++) {
        if (_tasks[i].locationId == deleted.id) {
          _tasks[i] = _tasks[i].copyWith(
            locationId: _locations.isNotEmpty ? _locations.first.id : '',
          );
        }
      }
    });
  }

  void _editTask(int index) {
    final task = _tasks[index];
    _showTaskEditDialog(task, index);
  }

  void _deleteTask(int index) {
    final deletedTaskId = _tasks[index].id;
    setState(() {
      _tasks.removeAt(index);
      for (var i = 0; i < _locations.length; i++) {
        if (_locations[i].taskId == deletedTaskId) {
          _locations[i] = _locations[i].copyWith(taskId: '');
        }
      }
    });
  }

  void _showLocationEditDialog(QuestLocation location, int index) {
    final nameController = TextEditingController(text: location.name);
    final descriptionController =
        TextEditingController(text: location.description);
    final latController =
        TextEditingController(text: location.latitude.toString());
    final lngController =
        TextEditingController(text: location.longitude.toString());
    final imageUrlController = TextEditingController(text: location.imageUrl);
    final selectedCity = KazakhstanCities.cityByName(_selectedCity);
    String? dialogError;
    bool uploadingImage = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: const Text('Редактировать локацию'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                      if (dialogError != null) ...[
                        _buildDialogErrorBanner(dialogError!),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Название'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'Описание'),
                      ),
                      const SizedBox(height: 16),
                      PremiumButton(
                        text: 'Выбрать на карте',
                        icon: Icons.map,
                        onPressed: () async {
                          final currentLat = double.tryParse(latController.text) ?? 0.0;
                          final currentLng = double.tryParse(lngController.text) ?? 0.0;
                          final selectedPosition = await Navigator.push<LatLng>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminMapPickerScreen(
                                initialPosition: LatLng(currentLat, currentLng),
                                cityCenter: LatLng(
                                  selectedCity.latitude,
                                  selectedCity.longitude,
                                ),
                              ),
                            ),
                          );

                          if (selectedPosition != null) {
                            setDialogState(() {
                              latController.text = selectedPosition.latitude.toString();
                              lngController.text = selectedPosition.longitude.toString();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: latController,
                              decoration: const InputDecoration(labelText: 'Широта'),
                              keyboardType: const TextInputType.numberWithOptions(
                                signed: true,
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lngController,
                              decoration: const InputDecoration(labelText: 'Долгота'),
                              keyboardType: const TextInputType.numberWithOptions(
                                signed: true,
                                decimal: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: imageUrlController,
                        decoration: const InputDecoration(labelText: 'URL картинки локации'),
                      ),
                      const SizedBox(height: 8),
                      PremiumButton(
                        text: 'Загрузить картинку локации',
                        icon: Icons.image,
                        isLoading: uploadingImage,
                        onPressed: uploadingImage
                            ? null
                            : () async {
                                setDialogState(() {
                                  uploadingImage = true;
                                  dialogError = null;
                                });
                                try {
                                  final url = await _storageRepository.pickAndUploadImage(
                                    folder: 'locations',
                                  );
                                  if (url != null && context.mounted) {
                                    setDialogState(() {
                                      imageUrlController.text = url;
                                    });
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setDialogState(() {
                                    dialogError = _formatUploadError(e);
                                  });
                                } finally {
                                  if (context.mounted) {
                                    setDialogState(() {
                                      uploadingImage = false;
                                    });
                                  }
                                }
                              },
                      ),
                    ],
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    setDialogState(() {
                      dialogError = 'Название локации не может быть пустым.';
                    });
                    return;
                  }

                  setState(() {
                    _locations[index] = QuestLocation(
                      id: location.id,
                      questId: location.questId,
                      order: location.order,
                      name: name,
                      description: descriptionController.text.trim(),
                      historicalInfo: location.historicalInfo,
                      latitude: double.tryParse(latController.text) ?? 0.0,
                      longitude: double.tryParse(lngController.text) ?? 0.0,
                      imageUrl: imageUrlController.text.trim(),
                      audioUrl: location.audioUrl,
                      taskId: location.taskId,
                      radiusMeters: location.radiusMeters,
                    );
                  });
                  Navigator.pop(context);
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTaskEditDialog(QuestTask task, int index) {
    final questionController = TextEditingController(text: task.question);
    final pointsController =
        TextEditingController(text: task.points.toString());
    final hintController = TextEditingController(text: task.hint ?? '');
    final correctController =
        TextEditingController(text: task.correctAnswer ?? '');
    final optionsController =
        TextEditingController(text: task.options.join('\n'));
    final timeLimitController =
        TextEditingController(text: task.timeLimitSeconds.toString());
    final imageUrlController = TextEditingController(text: task.imageUrl ?? '');
    TaskType selectedType = task.type;
    String selectedLocationId = task.locationId;
    String? dialogError;
    bool uploadingImage = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: const Text('Редактировать задание'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                if (dialogError != null) ...[
                  _buildDialogErrorBanner(dialogError!),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: questionController,
                  decoration: const InputDecoration(labelText: 'Вопрос'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue:
                      _locations.any((location) => location.id == selectedLocationId)
                          ? selectedLocationId
                          : null,
                  decoration: const InputDecoration(labelText: 'Локация'),
                  items: _locations
                      .map(
                        (location) => DropdownMenuItem(
                          value: location.id,
                          child: Text(
                            location.name.trim().isNotEmpty
                                ? location.name.trim()
                                : 'Локация ${location.order}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedLocationId = value ?? '';
                      dialogError = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pointsController,
                  decoration: const InputDecoration(labelText: 'Очки'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<TaskType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Тип задания'),
                  items: TaskType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getTaskTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      selectedType = value;
                      dialogError = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: hintController,
                  decoration:
                      const InputDecoration(labelText: 'Подсказка (опц.)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: correctController,
                  decoration:
                      const InputDecoration(labelText: 'Правильный ответ'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: timeLimitController,
                  decoration:
                      const InputDecoration(labelText: 'Лимит времени (сек)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: optionsController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Варианты ответа (по одному в строке)',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: imageUrlController,
                  decoration:
                      const InputDecoration(labelText: 'URL картинки задания'),
                ),
                const SizedBox(height: 8),
                PremiumButton(
                  text: 'Загрузить картинку задания',
                  icon: Icons.image,
                  isLoading: uploadingImage,
                  onPressed: uploadingImage
                      ? null
                      : () async {
                          setDialogState(() {
                            uploadingImage = true;
                            dialogError = null;
                          });
                          try {
                            final url = await _storageRepository.pickAndUploadImage(
                              folder: 'tasks',
                            );
                            if (url != null && context.mounted) {
                              setDialogState(() {
                                imageUrlController.text = url;
                              });
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            setDialogState(() {
                              dialogError = _formatUploadError(e);
                            });
                          } finally {
                            if (context.mounted) {
                              setDialogState(() {
                                uploadingImage = false;
                              });
                            }
                          }
                        },
                ),
                if (imageUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openImageViewer(imageUrlController.text),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrlController.text.trim(),
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: double.infinity,
                          height: 120,
                          color: AppColors.surfaceVariant,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Нажмите на изображение, чтобы открыть на весь экран',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
                    ],
                  ),
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final question = questionController.text.trim();
                final points = int.tryParse(pointsController.text.trim()) ?? 10;
                final timeLimit = int.tryParse(timeLimitController.text.trim()) ?? 0;
                final options = optionsController.text
                    .split('\n')
                    .map((option) => option.trim())
                    .where((option) => option.isNotEmpty)
                    .toList(growable: false);

                if (question.isEmpty) {
                  setDialogState(() {
                    dialogError = 'Вопрос задания не может быть пустым.';
                  });
                  return;
                }
                if (selectedLocationId.trim().isEmpty) {
                  setDialogState(() {
                    dialogError = 'Выберите локацию для задания.';
                  });
                  return;
                }
                if (points <= 0) {
                  setDialogState(() {
                    dialogError = 'Очки задания должны быть больше 0.';
                  });
                  return;
                }
                if (timeLimit < 0) {
                  setDialogState(() {
                    dialogError = 'Лимит времени не может быть отрицательным.';
                  });
                  return;
                }

                setState(() {
                  _tasks[index] = QuestTask(
                    id: task.id,
                    locationId: selectedLocationId,
                    type: selectedType,
                    question: question,
                    hint: hintController.text.trim().isEmpty
                        ? null
                        : hintController.text.trim(),
                    points: points,
                    options: options,
                    correctOptionIndex: task.correctOptionIndex,
                    correctAnswer: correctController.text.trim(),
                    timeLimitSeconds: timeLimit,
                    imageUrl: imageUrlController.text.trim().isEmpty
                        ? null
                        : imageUrlController.text.trim(),
                  );

                  // Проставляем taskId у выбранной локации, если он еще пуст.
                  for (var i = 0; i < _locations.length; i++) {
                    if (_locations[i].id == selectedLocationId &&
                        _locations[i].taskId.isEmpty) {
                      _locations[i] = _locations[i].copyWith(taskId: task.id);
                    }
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
          );
        },
      ),
    );
  }

  String _getDifficultyLabel(QuestDifficulty difficulty) {
    switch (difficulty) {
      case QuestDifficulty.easy:
        return 'Легкий';
      case QuestDifficulty.medium:
        return 'Средний';
      case QuestDifficulty.hard:
        return 'Сложный';
    }
  }

  String _getTaskTypeLabel(TaskType type) {
    switch (type) {
      case TaskType.quiz:
        return 'Викторина';
      case TaskType.textInput:
        return 'Текстовый ответ';
      case TaskType.riddle:
        return 'Загадка';
      case TaskType.findObject:
        return 'Найти объект';
      case TaskType.photo:
        return 'Фото';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
