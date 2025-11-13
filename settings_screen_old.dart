import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _keywordsController = TextEditingController();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));

  double _baseXP = 400.0;
  double _levelMultiplier = 100.0;
  double _levelExponent = 1.05;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tokenController.text = prefs.getString('todoist_token') ?? '';
      _keywordsController.text =
          (prefs.getStringList('xp_keywords') ?? ['xp', 'Xp', 'XP', 'xP'])
              .join(', ');
      _startDate = DateTime.tryParse(prefs.getString('start_date') ?? '') ??
          DateTime.now().subtract(const Duration(days: 7));
      _baseXP = prefs.getDouble('base_xp') ?? 400.0;
      _levelMultiplier = prefs.getDouble('level_multiplier') ?? 100.0;
      _levelExponent = prefs.getDouble('level_exponent') ?? 1.05;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('todoist_token', _tokenController.text.trim());
    await prefs.setStringList(
      'xp_keywords',
      _keywordsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
    await prefs.setString('start_date', _startDate.toIso8601String());
    await prefs.setDouble('base_xp', _baseXP);
    await prefs.setDouble('level_multiplier', _levelMultiplier);
    await prefs.setDouble('level_exponent', _levelExponent);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved ✅')),
      );
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ LifeQuests Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _tokenController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Todoist API Key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              ListTile(
                title: const Text('Start date'),
                subtitle: Text(
                  '${_startDate.year}-${_startDate.month}-${_startDate.day}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickStartDate,
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _keywordsController,
                decoration: const InputDecoration(
                  labelText: 'XP Keywords (comma-separated)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Level formula:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'XP required = baseXP + levelMultiplier × (level ^ levelExponent)',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),

              const SizedBox(height: 16),
              TextFormField(
                initialValue: _baseXP.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Base XP (default: 400)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _baseXP = double.tryParse(v) ?? _baseXP,
              ),

              const SizedBox(height: 16),
              TextFormField(
                initialValue: _levelMultiplier.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Level Multiplier (default: 100)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    _levelMultiplier = double.tryParse(v) ?? _levelMultiplier,
              ),

              const SizedBox(height: 16),
              TextFormField(
                initialValue: _levelExponent.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Level Exponent (default: 1.05)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    _levelExponent = double.tryParse(v) ?? _levelExponent,
              ),

              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
