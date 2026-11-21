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
}