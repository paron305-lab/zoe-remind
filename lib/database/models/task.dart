class Task {
  final int? id;
  final String title;
  final String? description;
  final String? date;
  final String? time;
  final int priority;
  final String status;
  final String createdAt;
  final String? completedAt;

  const Task({
    this.id,
    required this.title,
    this.description,
    this.date,
    this.time,
    this.priority = 0,
    this.status = 'pending',
    required this.createdAt,
    this.completedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date,
        'time': time,
        'priority': priority,
        'status': status,
        'created_at': createdAt,
        'completed_at': completedAt,
      };

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: m['id'] as int?,
        title: m['title'] as String,
        description: m['description'] as String?,
        date: m['date'] as String?,
        time: m['time'] as String?,
        priority: m['priority'] as int,
        status: m['status'] as String,
        createdAt: m['created_at'] as String,
        completedAt: m['completed_at'] as String?,
      );
}