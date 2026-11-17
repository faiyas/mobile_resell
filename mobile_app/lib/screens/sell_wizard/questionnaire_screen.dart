import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
import 'quote_and_booking_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  final DeviceCategoryModel? category;
  final BrandModel brand;
  final PhoneModelItem model;
  final StorageVariantModel variant;

  const QuestionnaireScreen({
    super.key,
    this.category,
    required this.brand,
    required this.model,
    required this.variant,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;

  List<ConditionCategoryModel> _steps = [];
  int _currentStepIndex = 0;
  final Set<String> _selectedOptionCodes = {};

  @override
  void initState() {
    super.initState();
    _loadQuestionnaire();
  }

  Future<void> _loadQuestionnaire() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getConditionCategories();
      setState(() {
        _steps = data;
        _loading = false;
      });

      // Auto-select initial flawless/default options for single-selection steps
      if (data.isNotEmpty) {
        _ensureSingleSelectionDefaults(data);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _ensureSingleSelectionDefaults(List<ConditionCategoryModel> steps) {
    for (var step in steps) {
      final isSingle = step.selectionType == 'SINGLE';
      if (isSingle && step.options.isNotEmpty) {
        final hasSelection = step.options.any((o) => _selectedOptionCodes.contains(o.code));
        if (!hasSelection) {
          // Prefer option with 0 deduction (Flawless / No defect)
          final defaultOpt = step.options.firstWhere(
            (o) => o.defaultDeductionValue == 0,
            orElse: () => step.options.first,
          );
          _selectedOptionCodes.add(defaultOpt.code);
        }
      }
    }
  }

  void _toggleOption(ConditionOptionModel opt, bool isMultiple) {
    setState(() {
      final currentStep = _steps[_currentStepIndex];
      final isZeroDeduction = opt.defaultDeductionValue == 0 ||
          opt.code.toUpperCase().contains('NO_DEFECT') ||
          opt.code.toUpperCase().contains('FLAWLESS') ||
          opt.code.toUpperCase().contains('NO_FAULT');

      if (isMultiple) {
        if (_selectedOptionCodes.contains(opt.code)) {
          _selectedOptionCodes.remove(opt.code);
        } else {
          // If this option has an exclusive group, replace other options in the same group
          if (opt.exclusiveGroup.isNotEmpty) {
            for (var other in currentStep.options) {
              if (other.exclusiveGroup == opt.exclusiveGroup) {
                _selectedOptionCodes.remove(other.code);
              }
            }
          }

          // If user taps "No Defect / Flawless", deselect all defect options in this step
          if (isZeroDeduction) {
            for (var other in currentStep.options) {
              _selectedOptionCodes.remove(other.code);
            }
          } else {
            // If user taps a defect, deselect any "No Defect / Flawless" option in this step
            for (var other in currentStep.options) {
              final otherZero = other.defaultDeductionValue == 0 ||
                  other.code.toUpperCase().contains('NO_DEFECT') ||
                  other.code.toUpperCase().contains('FLAWLESS') ||
                  other.code.toUpperCase().contains('NO_FAULT');
              if (otherZero) {
                _selectedOptionCodes.remove(other.code);
              }
            }
          }

          _selectedOptionCodes.add(opt.code);
        }
      } else {
        // Single selection: replace previous selection in this step
        for (var o in currentStep.options) {
          _selectedOptionCodes.remove(o.code);
        }
        _selectedOptionCodes.add(opt.code);
      }
    });
  }

  void _nextStep() {
    final currentStep = _steps[_currentStepIndex];
    final isSingle = currentStep.selectionType == 'SINGLE';

    if (isSingle) {
      final hasSelected = currentStep.options.any((o) => _selectedOptionCodes.contains(o.code));
      if (!hasSelected && currentStep.options.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an option before continuing')),
        );
        return;
      }
    }

    if (_currentStepIndex < _steps.length - 1) {
      setState(() => _currentStepIndex++);
    } else {
      // Completed all 11 steps -> Proceed to Quote
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuoteAndBookingScreen(
            brand: widget.brand,
            model: widget.model,
            variant: widget.variant,
            selectedOptionCodes: _selectedOptionCodes.toList(),
          ),
        ),
      );
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() => _currentStepIndex--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.canvas,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    if (_steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device Evaluation')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No evaluation questions found.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final currentStep = _steps[_currentStepIndex];
    final isMultiple = currentStep.selectionType == 'MULTIPLE' ||
        currentStep.selectionType == 'ACCESSORY' ||
        currentStep.selectionType == 'WARRANTY';

    final progress = (_currentStepIndex + 1) / _steps.length;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.5,
                  ),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                title: Text('${widget.brand.name} · ${widget.model.name}'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _previousStep,
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.border.withValues(alpha: 0.5),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                    minHeight: 4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: GlassBackgroundMesh(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'Step ${_currentStepIndex + 1} of ${_steps.length}',
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    isMultiple ? 'Multiple selections allowed' : 'Select one option',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Step Title & Subtitle
              Text(
                currentStep.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (currentStep.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  currentStep.subtitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 16),

              // Visual Option Cards Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.12,
                ),
                itemCount: currentStep.options.length,
                itemBuilder: (context, idx) {
                  final opt = currentStep.options[idx];
                  final isSelected = _selectedOptionCodes.contains(opt.code);

                  return GlassContainer(
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: Border.all(
                      color: isSelected
                          ? (opt.isRejection ? Colors.red : AppTheme.primaryGreen)
                          : Colors.white.withValues(alpha: 0.85),
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    color: isSelected
                        ? (opt.isRejection
                            ? Colors.red.shade50.withValues(alpha: 0.8)
                            : AppTheme.lightGreen.withValues(alpha: 0.75))
                        : Colors.white.withValues(alpha: 0.8),
                    onTap: () => _toggleOption(opt, isMultiple),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 18),
                            Icon(
                              _getOptionIcon(opt.code),
                              size: 26,
                              color: isSelected
                                  ? (opt.isRejection ? Colors.red : AppTheme.primaryGreen)
                                  : AppTheme.textSecondary,
                            ),
                            Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              size: 18,
                              color: isSelected
                                  ? (opt.isRejection ? Colors.red : AppTheme.primaryGreen)
                                  : AppTheme.border,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? (opt.isRejection ? Colors.red.shade900 : AppTheme.darkGreen)
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: opt.defaultDeductionValue == 0
                                ? AppTheme.lightGreen
                                : opt.isRejection
                                    ? Colors.red.shade50
                                    : AppTheme.canvas,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            opt.defaultDeductionValue == 0
                                ? 'No Defect (₹0)'
                                : opt.deductionType == 'PERCENTAGE'
                                    ? '-${opt.defaultDeductionValue.toStringAsFixed(0)}%'
                                    : '-₹${opt.defaultDeductionValue.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: opt.defaultDeductionValue == 0
                                  ? AppTheme.darkGreen
                                  : opt.isRejection
                                      ? Colors.red.shade900
                                      : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Pro Tip Card
              if (currentStep.proTip.isNotEmpty)
                GlassContainer(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pro Tip',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.darkGreen,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentStep.proTip,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Previous', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _nextStep,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentStepIndex == _steps.length - 1
                                  ? 'Get Exact Quote'
                                  : 'Continue',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  }

  IconData _getOptionIcon(String code) {
    final c = code.toLowerCase();
    if (c.contains('cam') || c.contains('lens')) return Icons.camera_alt_outlined;
    if (c.contains('glass') || c.contains('crack')) return Icons.broken_image_outlined;
    if (c.contains('spot') || c.contains('line') || c.contains('display')) return Icons.phonelink_erase;
    if (c.contains('body') || c.contains('dent') || c.contains('bend')) return Icons.phone_android;
    if (c.contains('touch')) return Icons.touch_app_outlined;
    if (c.contains('mic')) return Icons.mic_outlined;
    if (c.contains('speaker') || c.contains('sound')) return Icons.volume_up_outlined;
    if (c.contains('sim') || c.contains('network') || c.contains('5g')) return Icons.sim_card_outlined;
    if (c.contains('wifi')) return Icons.wifi;
    if (c.contains('bluetooth')) return Icons.bluetooth;
    if (c.contains('battery') || c.contains('charge')) return Icons.battery_charging_full_outlined;
    if (c.contains('box')) return Icons.inventory_2_outlined;
    if (c.contains('charger') || c.contains('cable')) return Icons.cable_outlined;
    if (c.contains('bill') || c.contains('invoice') || c.contains('warranty')) return Icons.receipt_long_outlined;
    if (c.contains('flawless') || c.contains('no_defect') || c.contains('perfect')) return Icons.verified_outlined;
    return Icons.check_circle_outline;
  }
}
