import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../filter_view_model.dart';
import '../../../core/theme/app_theme.dart';

class BeautySlider extends ConsumerWidget {
  const BeautySlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filterViewModelProvider);
    final notifier = ref.read(filterViewModelProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          _buildSlider('磨皮', state.smooth, (v) => notifier.setSmooth(v)),
          const SizedBox(height: 8),
          _buildSlider('美白', state.whiten, (v) => notifier.setWhiten(v)),
          const SizedBox(height: 8),
          _buildSlider('瘦脸', state.slim, (v) => notifier.setSlim(v)),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.2),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '${value.round()}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}