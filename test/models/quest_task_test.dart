import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/domain/models/quest_task.dart';

void main() {
  group('QuestTask.checkAnswer', () {
    test('quiz — correct index returns true', () {
      const task = QuestTask(
        id: 't1',
        locationId: 'l1',
        type: TaskType.quiz,
        question: 'Q?',
        options: ['A', 'B', 'C'],
        correctOptionIndex: 1,
      );
      expect(task.checkAnswer(selectedIndex: 1), isTrue);
    });

    test('quiz — wrong index returns false', () {
      const task = QuestTask(
        id: 't1',
        locationId: 'l1',
        type: TaskType.quiz,
        question: 'Q?',
        options: ['A', 'B', 'C'],
        correctOptionIndex: 1,
      );
      expect(task.checkAnswer(selectedIndex: 0), isFalse);
      expect(task.checkAnswer(selectedIndex: 2), isFalse);
    });

    test('textInput — case-insensitive match', () {
      const task = QuestTask(
        id: 't2',
        locationId: 'l1',
        type: TaskType.textInput,
        question: 'Q?',
        correctAnswer: 'Фостер',
      );
      expect(task.checkAnswer(textAnswer: 'фостер'), isTrue);
      expect(task.checkAnswer(textAnswer: 'ФОСТЕР'), isTrue);
      expect(task.checkAnswer(textAnswer: '  фостер  '), isTrue);
    });

    test('textInput — wrong answer returns false', () {
      const task = QuestTask(
        id: 't2',
        locationId: 'l1',
        type: TaskType.textInput,
        question: 'Q?',
        correctAnswer: 'Фостер',
      );
      expect(task.checkAnswer(textAnswer: 'Норман'), isFalse);
    });

    test('textInput — null answer returns false', () {
      const task = QuestTask(
        id: 't2',
        locationId: 'l1',
        type: TaskType.textInput,
        question: 'Q?',
        correctAnswer: 'Фостер',
      );
      expect(task.checkAnswer(), isFalse);
    });

    test('riddle — correct answer', () {
      const task = QuestTask(
        id: 't3',
        locationId: 'l1',
        type: TaskType.riddle,
        question: 'Riddle?',
        correctAnswer: 'базар',
      );
      expect(task.checkAnswer(textAnswer: 'Базар'), isTrue);
    });

    test('photo — true only when evidencePath is provided and uploaded', () {
      const task = QuestTask(
        id: 't4',
        locationId: 'l1',
        type: TaskType.photo,
        question: 'Take a photo',
      );
      expect(task.checkAnswer(), isFalse);
      expect(task.checkAnswer(evidencePath: ''), isFalse);
      expect(task.checkAnswer(evidencePath: 'local/path/photo.jpg'), isFalse);
      expect(
        task.checkAnswer(
          evidencePath: 'local/path/photo.jpg',
          evidenceStatus: EvidenceStatus.pending,
        ),
        isFalse,
      );
      expect(
        task.checkAnswer(
          evidencePath: 'local/path/photo.jpg',
          evidenceStatus: EvidenceStatus.failed,
        ),
        isFalse,
      );
      expect(
        task.checkAnswer(
          evidencePath: 'local/path/photo.jpg',
          evidenceStatus: EvidenceStatus.uploaded,
        ),
        isTrue,
      );
    });

    test('findObject — true only when evidencePath is provided and uploaded',
        () {
      const task = QuestTask(
        id: 't5',
        locationId: 'l1',
        type: TaskType.findObject,
        question: 'Find it',
      );
      expect(task.checkAnswer(), isFalse);
      expect(task.checkAnswer(evidencePath: '  '), isFalse);
      expect(task.checkAnswer(evidencePath: 'local/path/object.jpg'), isFalse);
      expect(
        task.checkAnswer(
          evidencePath: 'local/path/object.jpg',
          evidenceStatus: EvidenceStatus.uploaded,
        ),
        isTrue,
      );
    });
  });

  group('QuestTask.fromMap / toMap', () {
    test('roundtrip preserves data', () {
      const original = QuestTask(
        id: 'task_01',
        locationId: 'loc_01',
        type: TaskType.quiz,
        question: 'What year?',
        options: ['1991', '1997', '2000'],
        correctOptionIndex: 1,
        points: 75,
        hint: 'A hint',
        timeLimitSeconds: 30,
      );

      final map = original.toMap();
      final restored = QuestTask.fromMap(map, 'task_01');

      expect(restored.id, original.id);
      expect(restored.locationId, original.locationId);
      expect(restored.type, original.type);
      expect(restored.question, original.question);
      expect(restored.options, original.options);
      expect(restored.correctOptionIndex, original.correctOptionIndex);
      expect(restored.points, original.points);
      expect(restored.hint, original.hint);
      expect(restored.timeLimitSeconds, original.timeLimitSeconds);
    });

    test('fromMap handles missing fields with defaults', () {
      final task = QuestTask.fromMap(const {}, 'empty');
      expect(task.id, 'empty');
      expect(task.type, TaskType.quiz);
      expect(task.points, 50);
      expect(task.options, isEmpty);
    });
  });
}
