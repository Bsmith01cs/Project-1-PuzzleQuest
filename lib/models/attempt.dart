class Attempt {
  const Attempt({
    this.id,
    required this.puzzleId,
    required this.status,
    this.wrongGuesses = 0,
    this.hintsUsed = 0,
    this.hintKinds,
    this.elapsedSeconds = 0,
    this.lastGuess,
    this.userNote,
    required this.startedAt,
    this.finishedAt,
  });

  factory Attempt.fromMap(Map<String, Object?> map) {
    final finishedAt = map['finished_at'] as String?;

    return Attempt(
      id: map['id'] as int?,
      puzzleId: map['puzzle_id'] as int,
      status: map['status'] as String,
      wrongGuesses: map['wrong_guesses'] as int,
      hintsUsed: map['hints_used'] as int,
      hintKinds: map['hint_kinds'] as String?,
      elapsedSeconds: map['elapsed_seconds'] as int,
      lastGuess: map['last_guess'] as String?,
      userNote: map['user_note'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String),
      finishedAt: finishedAt == null ? null : DateTime.parse(finishedAt),
    );
  }

  static const statusInProgress = 'in_progress';
  static const statusPaused = 'paused';
  static const statusSolved = 'solved';

  final int? id;
  final int puzzleId;
  final String status;
  final int wrongGuesses;
  final int hintsUsed;

  /// Which hint kinds the player accepted, as stored by the hint rules.
  /// Null on rows written before the column existed: the count is then all
  /// that is known about them.
  final String? hintKinds;
  final int elapsedSeconds;
  final String? lastGuess;
  final String? userNote;
  final DateTime startedAt;
  final DateTime? finishedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'puzzle_id': puzzleId,
      'status': status,
      'wrong_guesses': wrongGuesses,
      'hints_used': hintsUsed,
      'hint_kinds': hintKinds,
      'elapsed_seconds': elapsedSeconds,
      'last_guess': lastGuess,
      'user_note': userNote,
      'started_at': startedAt.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
    };
  }
}
