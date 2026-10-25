import 'package:flutter/material.dart';
import '../../../database/models/task.dart';
import '../../../database/repositories/task_repository.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _repo = TaskRepository();
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await _repo.getAll();
    setState(() => _tasks = t);
  }

  Future<void> _add() async {
    await _repo.add(Task(
      title: 'Test task ${_tasks.length + 1}',
      createdAt: DateTime.now().toIso8601String(),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton:
          FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: ListView(
        children: _tasks
            .map((t) => ListTile(title: Text(t.title), subtitle: Text(t.status)))
            .toList(),
      ),
    );
  }
}