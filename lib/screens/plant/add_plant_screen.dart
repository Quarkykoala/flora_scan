import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../models/plant.dart';
import '../../providers/plant_provider.dart';
import '../../utils/haptics.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glassmorphic_card.dart';

class AddPlantScreen extends ConsumerStatefulWidget {
  const AddPlantScreen({super.key});

  @override
  ConsumerState<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends ConsumerState<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _speciesCommonController = TextEditingController();
  final _speciesScientificController = TextEditingController();

  String _locationType = 'indoor';
  String _lightSource = 'unknown';
  String _potType = 'unknown';
  String _soilMix = 'unknown';
  String _sunExposure = 'unknown';

  @override
  void dispose() {
    _nicknameController.dispose();
    _speciesCommonController.dispose();
    _speciesScientificController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await AppHaptics.selection();

    final plant = await ref.read(plantNotifierProvider.notifier).createPlant(
          nickname: _nicknameController.text.trim(),
          speciesCommon: _speciesCommonController.text.trim().isNotEmpty
              ? _speciesCommonController.text.trim()
              : null,
          speciesScientific: _speciesScientificController.text.trim().isNotEmpty
              ? _speciesScientificController.text.trim()
              : null,
          environmentProfile: EnvironmentProfile(
            locationType: _locationType,
            lightSource: _lightSource,
            potType: _potType,
            soilMix: _soilMix,
            sunExposureBand: _sunExposure,
          ),
        );

    if (plant != null && mounted) {
      ref.invalidate(plantsProvider);
      context.go('/plant/${plant.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final plantState = ref.watch(plantNotifierProvider);

    return AmbientBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Plant'),
        ),
        body: AnimationLimiter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 500),
                  childAnimationBuilder: (widget) => SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: widget,
                    ),
                  ),
                  children: [
                    // Plant Info Card
                    GlassmorphicCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plant Information',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),

                          // Nickname (required)
                          TextFormField(
                            controller: _nicknameController,
                            decoration: const InputDecoration(
                              labelText: 'Plant Nickname *',
                              hintText: 'e.g., Living Room Fern',
                              prefixIcon: Icon(Icons.eco),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please give your plant a nickname';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Common species name (optional)
                          TextFormField(
                            controller: _speciesCommonController,
                            decoration: const InputDecoration(
                              labelText: 'Common Name (optional)',
                              hintText: 'e.g., Boston Fern',
                              prefixIcon: Icon(Icons.local_florist),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),

                          // Scientific name (optional)
                          TextFormField(
                            controller: _speciesScientificController,
                            decoration: const InputDecoration(
                              labelText: 'Scientific Name (optional)',
                              hintText: 'e.g., Nephrolepis exaltata',
                              prefixIcon: Icon(Icons.science),
                            ),
                            textInputAction: TextInputAction.done,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Environment Profile Card
                    GlassmorphicCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Environment Profile',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Help us give better diagnostics by describing the plant\'s environment.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.black54,
                                ),
                          ),
                          const SizedBox(height: 16),

                          // Location type
                          _buildDropdown(
                            label: 'Location',
                            icon: Icons.location_on,
                            value: _locationType,
                            items: EnvironmentProfile.locationTypes,
                            onChanged: (v) => setState(() => _locationType = v!),
                          ),
                          const SizedBox(height: 12),

                          // Light source
                          _buildDropdown(
                            label: 'Light Source',
                            icon: Icons.light_mode,
                            value: _lightSource,
                            items: EnvironmentProfile.lightSources,
                            onChanged: (v) => setState(() => _lightSource = v!),
                          ),
                          const SizedBox(height: 12),

                          // Pot type
                          _buildDropdown(
                            label: 'Pot Type',
                            icon: Icons.yard,
                            value: _potType,
                            items: EnvironmentProfile.potTypes,
                            onChanged: (v) => setState(() => _potType = v!),
                          ),
                          const SizedBox(height: 12),

                          // Soil mix
                          _buildDropdown(
                            label: 'Soil Mix',
                            icon: Icons.grass,
                            value: _soilMix,
                            items: EnvironmentProfile.soilMixes,
                            onChanged: (v) => setState(() => _soilMix = v!),
                          ),
                          const SizedBox(height: 12),

                          // Sun exposure
                          _buildDropdown(
                            label: 'Sun Exposure',
                            icon: Icons.wb_sunny,
                            value: _sunExposure,
                            items: EnvironmentProfile.sunExposureBands,
                            onChanged: (v) => setState(() => _sunExposure = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: plantState is AsyncLoading ? null : _save,
                        icon: plantState is AsyncLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Save Plant'),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item.replaceAll('_', ' '),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
