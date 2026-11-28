class StorageConstants {
  static const dbName = 'zoe.db';
  static const dbVersion = 1;

  static const tasksTable = 'tasks';
  static const remindersTable = 'reminders';
  static const completionHistoryTable = 'completion_history';
  static const reminderOccurrencesTable = 'reminder_occurrences';
  static const taskCategoriesTable = 'task_categories';
  static const taskHistoryTable = 'task_history';
  static const notesTable = 'notes';
  static const eventsTable = 'events';
  static const conversationsTable = 'ai_conversations';
  static const messagesTable = 'ai_messages';
  static const memoriesTable = 'memories';
  static const moodTable = 'zoe_mood';
  static const moodLogTable = 'mood_log';

  // RAG (v13): FTS4 na kopya ng notes at memories para sa paghahanap.
  // docid = id sa notes / memories. Pinupuno ng triggers.
  static const notesFtsTable = 'notes_fts';
  static const memoriesFtsTable = 'memories_fts';

  // R6 (v16): natututo si Zoe sa phone. Kasama sa "Burahin lahat".
  //   search_log      = bawat paghahanap sa chat + ang nangyari ("oo" / "hindi yan")
  //   learned_terms   = natutunang salita ("net" ↔ "wifi")
  //   search_feedback = "oo" / binuksan / "hindi yan" bawat item (maliit na boost)
  static const searchLogTable = 'search_log';
  static const learnedTermsTable = 'learned_terms';
  static const searchFeedbackTable = 'search_feedback';
}