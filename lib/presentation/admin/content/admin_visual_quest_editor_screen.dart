import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();

  QuestDifficulty _difficulty = QuestDifficulty.easy;
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
    _cityController.dispose();
    _descriptionController.dispose();
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
          _cityController.text = bundle.quest.city;
          _descriptionController.text = bundle.quest.description;
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
    setState(() => _saving = true);

    try {
      final updatedQuest = Quest(
        id: widget.questId,
        title: _titleController.text,
        city: _cityController.text,
        description: _descriptionController.text,
        estimatedMinutes: int.parse(_durationController.text),
        distanceKm: double.parse(_distanceController.text),
        totalPoints: int.parse(_pointsController.text),
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
            TextButton.icon(
              onPressed: _saveQuest,
              icon: const Icon(Icons.save),
              label: const Text('Сохранить'),
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
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    switch (_tabController.index) {
      case 1:
        return PremiumButton(
          onPressed: _addLocation,
          icon: Icons.add_location,
          text: 'Добавить локацию',
        );
      case 2:
        return PremiumButton(
          onPressed: _addTask,
          icon: Icons.add_task,
          text: 'Добавить задание',
        );
      case 0:
      default:
        return null;
    }
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
                    _buildTextField(
                      controller: _cityController,
                      label: 'Город',
                      icon: Icons.location_city,
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
          child: Row(
            children: [
              Icon(Icons.location_on, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Точки маршрута (${_locations.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              if (_locations.isEmpty)
                Text(
                  'Добавьте точки маршрута',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                        label: 'Задание: ${location.taskId}',
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: ListTile(
              leading: const Icon(Icons.quiz, color: AppColors.primary),
              title: Text('Задание ${index + 1}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.question.isNotEmpty) Text(task.question),
                  Text('Тип: ${_getTaskTypeLabel(task.type)}'),
                  Text('Очки: ${task.points}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _editTask(index),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    onPressed: () => _deleteTask(index),
                    icon: const Icon(Icons.delete, color: AppColors.error),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _editLocation(int index) {
    final location = _locations[index];
    _showLocationEditDialog(location, index);
  }

  void _deleteLocation(int index) {
    setState(() {
      _locations.removeAt(index);
    });
  }

  void _editTask(int index) {
    final task = _tasks[index];
    _showTaskEditDialog(task, index);
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать локацию'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название')),
              TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Описание')),
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
                      ),
                    ),
                  );

                  if (selectedPosition != null) {
                    latController.text = selectedPosition.latitude.toString();
                    lngController.text = selectedPosition.longitude.toString();
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: latController,
                          decoration:
                              const InputDecoration(labelText: 'Широта'),
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: lngController,
                          decoration:
                              const InputDecoration(labelText: 'Долгота'),
                          keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                  controller: imageUrlController,
                  decoration:
                      const InputDecoration(labelText: 'URL картинки локации')),
              const SizedBox(height: 8),
              PremiumButton(
                text: 'Загрузить картинку локации',
                icon: Icons.image,
                onPressed: () async {
                  try {
                    final url = await _storageRepository.pickAndUploadImage(
                        folder: 'locations');
                    if (url != null) {
                      imageUrlController.text = url;
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка загрузки: $e')),
                      );
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
              setState(() {
                _locations[index] = QuestLocation(
                  id: location.id,
                  questId: location.questId,
                  order: location.order,
                  name: nameController.text,
                  description: descriptionController.text,
                  historicalInfo: location.historicalInfo,
                  latitude: double.tryParse(latController.text) ?? 0.0,
                  longitude: double.tryParse(lngController.text) ?? 0.0,
                  imageUrl: imageUrlController.text,
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
      ),
    );
  }

  void _showTaskEditDialog(QuestTask task, int index) {
    final questionController = TextEditingController(text: task.question);
    final pointsController =
        TextEditingController(text: task.points.toString());
    final correctController =
        TextEditingController(text: task.correctAnswer ?? '');
    final imageUrlController = TextEditingController(text: task.imageUrl ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать задание'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: questionController,
                  decoration: const InputDecoration(labelText: 'Вопрос')),
              TextField(
                  controller: pointsController,
                  decoration: const InputDecoration(labelText: 'Очки'),
                  keyboardType: TextInputType.number),
              DropdownButtonFormField<TaskType>(
                initialValue: task.type,
                decoration: const InputDecoration(labelText: 'Тип задания'),
                items: TaskType.values.map((type) {
                  return DropdownMenuItem(
                      value: type, child: Text(_getTaskTypeLabel(type)));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _tasks[index] = task.copyWith(type: value);
                    });
                  }
                },
              ),
              TextField(
                  controller: correctController,
                  decoration:
                      const InputDecoration(labelText: 'Правильный ответ')),
              const SizedBox(height: 16),
              TextField(
                  controller: imageUrlController,
                  decoration:
                      const InputDecoration(labelText: 'URL картинки задания')),
              const SizedBox(height: 8),
              PremiumButton(
                text: 'Загрузить картинку задания',
                icon: Icons.image,
                onPressed: () async {
                  try {
                    final url = await _storageRepository.pickAndUploadImage(
                        folder: 'tasks');
                    if (url != null) {
                      imageUrlController.text = url;
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка загрузки: $e')),
                      );
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
              setState(() {
                _tasks[index] = QuestTask(
                  id: task.id,
                  locationId: task.locationId,
                  type: task.type,
                  question: questionController.text,
                  points: int.tryParse(pointsController.text) ?? 10,
                  options: task.options,
                  correctOptionIndex: task.correctOptionIndex,
                  correctAnswer: correctController.text,
                  timeLimitSeconds: task.timeLimitSeconds,
                  imageUrl: imageUrlController.text,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
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
