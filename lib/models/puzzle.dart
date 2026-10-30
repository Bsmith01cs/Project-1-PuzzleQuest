class Puzzle {
  const Puzzle({
    this.id,
    required this.answer,
    required this.clue,
    required this.category,
    required this.difficulty,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Puzzle.fromMap(Map<String, Object?> map) {
    return Puzzle(
      id: map['id'] as int?,
      answer: map['answer'] as String,
      clue: map['clue'] as String,
      category: map['category'] as String,
      difficulty: map['difficulty'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  final int? id;
  final String answer;
  final String clue;
  final String category;
  final int difficulty;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'answer': answer,
      'clue': clue,
      'category': category,
      'difficulty': difficulty,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
