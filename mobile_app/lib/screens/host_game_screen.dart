import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../widgets/sport_chip.dart';

class HostGameScreen extends ConsumerStatefulWidget {
  const HostGameScreen({super.key});

  @override
  ConsumerState<HostGameScreen> createState() => _HostGameScreenState();
}

class _HostGameScreenState extends ConsumerState<HostGameScreen> {
  String? _selectedSport;
  final _venueCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _maxPlayers = 10;
  String _skillLevel = 'All Levels';
  bool _isPublic = true;

  static const _sports = [
    {'name': 'Cricket', 'emoji': '\ud83c\udfd0'},
    {'name': 'Football', 'emoji': '\u26bd'},
    {'name': 'Basketball', 'emoji': '\ud83c\udfc0'},
    {'name': 'Badminton', 'emoji': '\ud83c\udff8'},
    {'name': 'Tennis', 'emoji': '\ud83c\udfbe'},
  ];

  static const _levels = ['All Levels', 'Beginner', 'Intermediate', 'Advanced'];

  @override
  void dispose() {
    _venueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Host a Game')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Sport selection
          Text('Select Sport',
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sports
                .map((s) => SportChip(
                      label: s['name']!,
                      emoji: s['emoji'],
                      selected: _selectedSport == s['name'],
                      onTap: () => setState(() => _selectedSport = s['name']),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),

          // Venue
          Text('Venue',
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _venueCtrl,
            decoration:
                const InputDecoration(hintText: 'Enter venue name or address'),
          ),
          const SizedBox(height: 24),

          // Date & Time
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  label: 'Date',
                  value: _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Select',
                  icon: Icons.calendar_today,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerTile(
                  label: 'Time',
                  value: _selectedTime != null
                      ? _selectedTime!.format(context)
                      : 'Select',
                  icon: Icons.access_time,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 18, minute: 0),
                    );
                    if (time != null) setState(() => _selectedTime = time);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Max players
          Text('Max Players',
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              _CounterButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (_maxPlayers > 2) setState(() => _maxPlayers--);
                  }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('$_maxPlayers',
                    style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
              ),
              _CounterButton(
                  icon: Icons.add,
                  onTap: () {
                    if (_maxPlayers < 30) setState(() => _maxPlayers++);
                  }),
            ],
          ),
          const SizedBox(height: 24),

          // Skill level
          Text('Skill Level',
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _skillLevel,
            dropdownColor: colors.card,
            items: _levels
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _skillLevel = v);
            },
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 24),

          // Visibility toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isPublic ? 'Public Game' : 'Private Game',
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600)),
                    Text(_isPublic ? 'Anyone can join' : 'Invite only',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 12)),
                  ],
                ),
                Switch(
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Publish
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedSport == null
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Game published!')),
                      );
                      context.pop();
                    },
              child: const Text('Publish Game'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.textSecondary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(fontSize: 11, color: colors.textSecondary)),
                Text(value,
                    style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Icon(icon, color: colors.textPrimary),
      ),
    );
  }
}
