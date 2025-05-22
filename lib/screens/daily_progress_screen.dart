// lib/screens/daily_progress_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

const String walkReminderEnabledKeyDaily = 'walk_reminder_enabled_v2';

class DailyProgressScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const DailyProgressScreen({Key? key, this.userData}) : super(key: key);

  @override
  _DailyProgressScreenState createState() => _DailyProgressScreenState();
}

class _DailyProgressScreenState extends State<DailyProgressScreen> {
  List<Map<String, dynamic>> _dailyTasks = [];
  bool _isLoading = true;
  final String _todayFormatted = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final String _todayStorageKey = 'daily_progress_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';

  @override
  void initState() {
    super.initState();
    _initializeTasks();
  }

  Future<void> _initializeTasks() async {
    if(!mounted) return;
    setState(() => _isLoading = true);
    await _carryOverMissedTasks();
    await _loadDailyTasks();
    if(mounted) setState(() => _isLoading = false);
  }

  Future<void> _carryOverMissedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final DateTime today = DateTime.now();
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final String yesterdayFormatted = DateFormat('yyyy-MM-dd').format(yesterday);
    final String yesterdayStorageKey = 'daily_progress_$yesterdayFormatted';

    List<String>? yesterdayTasksJson = prefs.getStringList(yesterdayStorageKey);
    List<Map<String,dynamic>> todayExistingTasks = [];
    List<String>? todayTasksJsonRaw = prefs.getStringList(_todayStorageKey);

    if(todayTasksJsonRaw != null){
      todayExistingTasks = todayTasksJsonRaw.map((tJson) {
        try { return jsonDecode(tJson) as Map<String,dynamic>; }
        catch(e) { return <String,dynamic>{}; }
      }).where((task) => task.isNotEmpty).toList();
    }

    if (yesterdayTasksJson != null && yesterdayTasksJson.isNotEmpty) {
      List<Map<String,dynamic>> tasksToCarryOver = [];
      for (String taskJson in yesterdayTasksJson) {
        try {
          Map<String, dynamic> task = jsonDecode(taskJson);
          // Carry over non-static, incomplete tasks
          // CORRECTED CONDITION:
          if ( (task['isDone'] == null || (task['isDone'] as bool) == false) &&
              task['type'] != 'static') {
            bool alreadyExistsToday = todayExistingTasks.any((t) => t['id'] == task['id']);
            if (!alreadyExistsToday) {
              Map<String, dynamic> newTaskForToday = Map.from(task);
              newTaskForToday['timestamp'] = DateTime.now().toIso8601String();
              newTaskForToday['isDone'] = false;
              tasksToCarryOver.add(newTaskForToday);
            }
          }
        } catch (e) {
          if (kDebugMode) print("Error processing task for carry-over: $e");
        }
      }

      if (tasksToCarryOver.isNotEmpty) {
        todayExistingTasks.insertAll(0, tasksToCarryOver);
        List<String> updatedTodayTasksJson = todayExistingTasks.map((t) => jsonEncode(t)).toList();
        await prefs.setStringList(_todayStorageKey, updatedTodayTasksJson);
        if (kDebugMode) print("Carried over ${tasksToCarryOver.length} tasks from $yesterdayFormatted.");
      }
      await prefs.remove(yesterdayStorageKey);
      if (kDebugMode) print("Cleared yesterday's tasks: $yesterdayStorageKey");
    }
  }

  Future<void> _loadDailyTasks() async {
    if(!mounted) return;
    if(_dailyTasks.isEmpty && mounted) setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final List<String>? tasksJson = prefs.getStringList(_todayStorageKey);
    final List<Map<String, dynamic>> loadedTasks = [];
    if (tasksJson != null) {
      for (String taskJson in tasksJson) {
        try {
          loadedTasks.add(jsonDecode(taskJson) as Map<String, dynamic>);
        } catch (e) {
          if (kDebugMode) print("Error decoding task from SharedPreferences: $e");
        }
      }
    }

    bool walkEnabled = prefs.getBool(walkReminderEnabledKeyDaily) ?? true;
    if (walkEnabled && widget.userData?['wakeTime'] != null && (widget.userData!['wakeTime'] as String).isNotEmpty) {
      final wakeTimeParts = (widget.userData!['wakeTime'] as String).split(':');
      String walkTaskTitle = '🚶‍♂️ Walk for 30 minutes';
      if(wakeTimeParts.length == 2) {
        try {
          TimeOfDay wakeTime = TimeOfDay(hour: int.parse(wakeTimeParts[0]), minute: int.parse(wakeTimeParts[1]));
          DateTime walkTimeDt = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, wakeTime.hour, wakeTime.minute).add(const Duration(minutes: 15));
          walkTaskTitle = '🚶‍♂️ Walk for 30 min (around ${DateFormat.jm().format(walkTimeDt)})';
        } catch (e) { if (kDebugMode) print("Error parsing wakeTime for walk task title: $e");}
      }
      _addStaticTaskIfNotExists(loadedTasks, walkTaskTitle, 'static_walk_30min',
          isDoneInitially: prefs.getBool('${_todayStorageKey}_static_walk_30min_done') ?? false
      );
    }

    if (mounted) {
      loadedTasks.sort((a, b) {
        if (a['type'] == 'static' && b['type'] != 'static') return -1;
        if (a['type'] != 'static' && b['type'] == 'static') return 1;
        try { return (a['timestamp'] as String).compareTo(b['timestamp'] as String); }
        catch(_){return 0;}
      });
      setState(() {
        _dailyTasks = loadedTasks;
        _isLoading = false;
      });
    }
  }

  void _addStaticTaskIfNotExists(List<Map<String,dynamic>> tasks, String title, String id, {bool isDoneInitially = false}) {
    int existingIndex = tasks.indexWhere((task) => task['id'] == id);
    if (existingIndex == -1) {
      tasks.insert(0, {
        'id': id, 'title': title, 'timestamp': DateTime.now().toIso8601String(),
        'isDone': isDoneInitially, 'type': 'static'
      });
    } else {
      if(tasks[existingIndex]['isDone'] != isDoneInitially) {
        tasks[existingIndex]['isDone'] = isDoneInitially;
      }
    }
  }

  Future<void> _updateTaskStatus(int index, bool isDone) async {
    if(!mounted || index < 0 || index >= _dailyTasks.length ) return;

    Map<String, dynamic> updatedTask = Map.from(_dailyTasks[index]);
    updatedTask['isDone'] = isDone;

    List<Map<String, dynamic>> newTasksList = List.from(_dailyTasks);
    newTasksList[index] = updatedTask;

    setState(() { _dailyTasks = newTasksList; });

    final prefs = await SharedPreferences.getInstance();
    if (updatedTask['type'] == 'static') {
      await prefs.setBool('${_todayStorageKey}_${updatedTask['id']}_done', isDone);
    }
    List<String> tasksJsonList = newTasksList.map((task) => jsonEncode(task)).toList();
    await prefs.setStringList(_todayStorageKey, tasksJsonList);
  }

  Future<void> _deleteTask(int index) async {
    if (index < 0 || index >= _dailyTasks.length) return;
    if (!mounted) return;

    final taskToDelete = _dailyTasks[index];
    final taskId = taskToDelete['id'] as String;

    List<Map<String, dynamic>> newTasksList = List.from(_dailyTasks);
    newTasksList.removeAt(index);

    setState(() {
      _dailyTasks = newTasksList;
    });

    final prefs = await SharedPreferences.getInstance();
    List<String> tasksJson = newTasksList.map((task) => jsonEncode(task)).toList();
    await prefs.setStringList(_todayStorageKey, tasksJson);

    if (taskToDelete['type'] == 'static') {
      await prefs.remove('${_todayStorageKey}_${taskId}_done');
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task "${taskToDelete['title']}" deleted.')));
  }

  Future<void> _clearOldTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final todayFormatted = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (String key in keys) {
      if (key.startsWith('daily_progress_') && !key.startsWith('daily_progress_$todayFormatted')) {
        await prefs.remove(key);
      }
      if(key.contains('_static_') && key.endsWith('_done') && !key.contains(todayFormatted)){
        await prefs.remove(key);
      }
    }
    if (kDebugMode) print("Old daily progress tasks cleared.");
    await _initializeTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Today\'s Tasks (${DateFormat('MMM d').format(DateTime.now())})'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _initializeTasks, tooltip: "Refresh Tasks"),
          // if (kDebugMode) IconButton(icon: const Icon(Icons.delete_sweep_outlined), onPressed: _clearOldTasks, tooltip: "Clear Old Tasks (Debug)"),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dailyTasks.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_box_outline_blank, size: 60, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
              const SizedBox(height: 20),
              Text('No tasks for today yet!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
              const SizedBox(height: 12),
              Text('Mark items as "Interested" in the Feed tab, or check your reminder settings in Profile.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _dailyTasks.length,
        itemBuilder: (context, index) {
          final task = _dailyTasks[index];
          final bool isStatic = task['type'] == 'static';
          final bool isDone = task['isDone'] as bool? ?? false;
          String subtitle;
          try {
            subtitle = isStatic ?
            (task['id'] == 'static_walk_30min' ? 'Routine: Around wake-up + 15min' : 'Routine Task')
                : 'From Feed - Added ${DateFormat('h:mm a').format(DateTime.parse(task['timestamp'] as String))}';
          } catch(e){
            subtitle = isStatic ? "Routine Task" : "From Feed";
          }

          return Card(
            elevation: isDone ? 1 : 2,
            color: isDone ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5) : Theme.of(context).cardColor,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: ListTile(
              leading: Checkbox(
                value: isDone,
                onChanged: (bool? value) {
                  if (value != null) {
                    _updateTaskStatus(index, value);
                  }
                },
                activeColor: Theme.of(context).colorScheme.primary,
                checkColor: Theme.of(context).colorScheme.onPrimary,
              ),
              title: Text(
                task['title'] as String? ?? 'Untitled Task',
                style: TextStyle(
                  decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                  color: isDone ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5) : Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: isStatic ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDone ? Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.4) : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)
                  )
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isStatic) Icon(Icons.repeat, color: Theme.of(context).colorScheme.secondary.withOpacity(isDone ? 0.4 : 0.7))
                  else Icon(Icons.article_outlined, color: Theme.of(context).colorScheme.tertiary.withOpacity(isDone ? 0.4 : 0.7)),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error.withOpacity(0.8)),
                    onPressed: () => _deleteTask(index),
                    tooltip: "Delete Task",
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}