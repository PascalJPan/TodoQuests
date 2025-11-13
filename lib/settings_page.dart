import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'xp_service.dart';
import 'milestone_helper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiKeyController = TextEditingController();
  final _baseXPController = TextEditingController();
  final _multiplierController = TextEditingController();
  final _exponentController = TextEditingController();
  final _xpKeywordsController = TextEditingController();
  final _milestoneLevelsController = TextEditingController();
  final _startingXPController = TextEditingController();

  DateTime? _startDate;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('apiKey') ?? '';
      _baseXPController.text = (prefs.getDouble('baseXP') ?? 990).toString();
      _multiplierController.text =
          (prefs.getDouble('levelMultiplier') ?? 10).toString();
      _exponentController.text =
          (prefs.getDouble('levelExponent') ?? 2.25).toString();
      _xpKeywordsController.text =
          prefs.getString('xpKeywords') ?? 'xp,XP,Xp,xP';
      _milestoneLevelsController.text =
          prefs.getString('milestoneLevels') ?? '10,20,30,40,50';
      _startingXPController.text = (prefs.getInt('startingXP') ?? 0).toString();
      final dateString = prefs.getString('startDate');
      if (dateString != null) {
        _startDate = DateTime.tryParse(dateString);
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiKey', _apiKeyController.text);
    await prefs.setDouble('baseXP',
        double.tryParse(_baseXPController.text) ?? 990);
    await prefs.setDouble('levelMultiplier',
        double.tryParse(_multiplierController.text) ?? 10);
    await prefs.setDouble('levelExponent',
        double.tryParse(_exponentController.text) ?? 2.25);
    await prefs.setString('xpKeywords', _xpKeywordsController.text);
    await prefs.setString('milestoneLevels', _milestoneLevelsController.text);
    await prefs.setInt('startingXP',
        int.tryParse(_startingXPController.text) ?? 0);
    if (_startDate != null) {
      await prefs.setString('startDate', _startDate!.toIso8601String());
    }

    await prefs.reload();

    // Trigger refresh after saving settings
    await LifeQuestService().refreshXP();

    if (mounted) Navigator.pop(context, true);

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'XP Formulas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Total XP = Starting XP + sum of task XP\n'
            'XP Required for Level = baseXP × level + multiplier × level^exponent',
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _baseXPController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Base XP (default 990)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _multiplierController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Level Multiplier (default 10)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _exponentController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Level Exponent (default 2.25)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _xpKeywordsController,
            decoration: const InputDecoration(
              labelText: 'XP Keywords (comma-separated)',
              hintText: 'e.g. xp,XP,Xp,xP',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _milestoneLevelsController,
            decoration: const InputDecoration(
              labelText: 'Milestone Levels (comma-separated)',
              hintText: 'e.g. 10,20,30,40,50',
              helperText: 'Levels that trigger special celebration colors',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('Start Date for XP Counting'),
            subtitle: Text(
              _startDate == null
                  ? 'Not set'
                  : _startDate!.toIso8601String().split('T').first,
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 7)),
              );
              if (picked != null) {
                setState(() => _startDate = picked);
              }
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _startingXPController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Starting XP (default 0)',
              hintText: 'e.g. 10000',
              helperText: 'Base XP offset added to calculated XP (for app reinstalls or migration)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 30),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to Use',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Use the widget on your home screen and tap it to refresh your XP from completed Todoist tasks. '
                    'You can customize the XP keyword identifier (e.g., "10xp") and adjust how leveling works using the formula above. '
                    'Milestone levels will display a trophy emoji to celebrate your achievements!\n\n'
                    'Note: When first starting, only the last 200 completed tasks are fetched from Todoist. '
                    'The app will build up a cache over time to track more than 200 tasks.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
