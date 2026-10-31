import 'package:flutter/material.dart';

import '../settings/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Holds the value while the slider is being dragged, so the preference is
  // written once on release instead of on every tick.
  double? _draggedThreshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final settings = widget.settings.settings;
        final threshold =
            _draggedThreshold ?? settings.hintThresholdSeconds.toDouble();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SwitchListTile(
              title: const Text('Dark theme'),
              subtitle: const Text('Use the dark Material 3 palette.'),
              value: settings.darkTheme,
              onChanged: widget.settings.setDarkTheme,
            ),
            SwitchListTile(
              title: const Text('Reduced motion'),
              subtitle: const Text(
                'Minimize nonessential animations and transitions.',
              ),
              value: settings.reducedMotion,
              onChanged: widget.settings.setReducedMotion,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hint threshold', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Wait ${threshold.round()} seconds before a hint becomes '
                    'available.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Slider(
              value: threshold,
              min: minHintThresholdSeconds.toDouble(),
              max: maxHintThresholdSeconds.toDouble(),
              divisions:
                  (maxHintThresholdSeconds - minHintThresholdSeconds) ~/ 5,
              label: '${threshold.round()} seconds',
              semanticFormatterCallback: (value) => '${value.round()} seconds',
              onChanged: (value) => setState(() => _draggedThreshold = value),
              onChangeEnd: (value) {
                setState(() => _draggedThreshold = null);
                widget.settings.setHintThreshold(value.round());
              },
            ),
            if (widget.settings.preferencesUnavailable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Settings could not be saved on this device. They apply '
                  'until the app closes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
