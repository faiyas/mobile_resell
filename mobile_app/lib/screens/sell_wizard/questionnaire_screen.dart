import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/draft_sell_service.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/brand_logo.dart';
import 'quote_and_booking_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  final DeviceCategoryModel? category;
  final BrandModel brand;
  final PhoneModelItem model;
  final StorageVariantModel variant;
  final bool isCustomDevice;
  final String? customDeviceName;
  final String? customDeviceCategory;
  final String? customDeviceSpecs;
  final double? customExpectedPrice;

  const QuestionnaireScreen({
    super.key,
    this.category,
    required this.brand,
    required this.model,
    required this.variant,
    this.isCustomDevice = false,
    this.customDeviceName,
    this.customDeviceCategory,
    this.customDeviceSpecs,
    this.customExpectedPrice,
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
  final Map<String, TextEditingController> _stepControllers = {};
  final Map<String, String> _stepCustomNotes = {};

  TextEditingController _getController(String stepName) {
    if (!_stepControllers.containsKey(stepName)) {
      _stepControllers[stepName] = TextEditingController(text: _stepCustomNotes[stepName] ?? '');
    }
    return _stepControllers[stepName]!;
  }

  @override
  void dispose() {
    for (var c in _stepControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadQuestionnaire();
  }

  Future<void> _loadQuestionnaire() async {
    setState(() => _loading = true);
    try {
      var data = await _api.getConditionCategories(brandId: widget.brand.id);
      if (!widget.model.hasWarranty) {
        // Old model without warranty: filter out warranty options and warranty steps
        data = data.map((cat) {
          final filtered = cat.options.where((o) => !o.isWarranty).toList();
          return ConditionCategoryModel(
            id: cat.id,
            name: cat.name,
            subtitle: cat.subtitle,
            stepNumber: cat.stepNumber,
            selectionType: cat.selectionType,
            isMandatory: cat.isMandatory,
            brandId: cat.brandId,
            brandName: cat.brandName,
            options: filtered,
          );
        }).where((cat) => cat.options.isNotEmpty && !cat.name.toLowerCase().contains('warranty')).toList();
      }
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
    _autoSaveDraft();
  }

  void _autoSaveDraft() {
    DraftSellService.saveDraft(
      SellDraftData(
        isCustomDevice: widget.isCustomDevice,
        customDeviceName: widget.customDeviceName,
        customDeviceCategory: widget.customDeviceCategory,
        customDeviceSpecs: widget.customDeviceSpecs,
        customExpectedPrice: widget.customExpectedPrice,
        brand: widget.brand,
        model: widget.model,
        variant: widget.variant,
        selectedOptionCodes: _selectedOptionCodes.toList(),
        customStepNotes: Map<String, String>.from(_stepCustomNotes),
        otherDefectsNotes: _stepCustomNotes.values.where((v) => v.trim().isNotEmpty).join(', '),
        estimatedPrice: widget.customExpectedPrice ?? widget.variant.basePrice,
        savedAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  void _showDefectPreviewDialog(ConditionOptionModel opt) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      opt.title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (opt.imageBase64 != null && opt.imageBase64!.trim().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.black12,
                    child: Image.memory(
                      base64Decode(opt.imageBase64!.contains(',') ? opt.imageBase64!.split(',').last : opt.imageBase64!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, size: 40, color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                opt.description.isNotEmpty ? opt.description : 'Physical condition inspection criteria used during doorstep verification.',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Doorstep Verification by Certified Agent',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGreen,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Understood'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nextStep() {
    final currentStep = _steps[_currentStepIndex];

    if (currentStep.isMandatory && currentStep.options.isNotEmpty) {
      final hasSelected = currentStep.options.any((o) => _selectedOptionCodes.contains(o.code));
      if (!hasSelected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please complete: "${currentStep.name}" before proceeding.',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }
    }

    if (_currentStepIndex < _steps.length - 1) {
      setState(() => _currentStepIndex++);
    } else {
      // Completed all steps -> Proceed to Quote
      final combinedNotes = _stepCustomNotes.entries
          .where((e) => e.value.trim().isNotEmpty)
          .map((e) => '${e.key}: "${e.value.trim()}"')
          .join('\n');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuoteAndBookingScreen(
            brand: widget.brand,
            model: widget.model,
            variant: widget.variant,
            selectedOptionCodes: _selectedOptionCodes.toList(),
            isCustomDevice: widget.isCustomDevice,
            customDeviceName: widget.customDeviceName,
            customDeviceCategory: widget.customDeviceCategory,
            customDeviceSpecs: widget.customDeviceSpecs,
            customExpectedPrice: widget.customExpectedPrice,
            otherDefectsNotes: combinedNotes,
            customStepNotes: Map<String, String>.from(_stepCustomNotes),
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
        body: Center(
          child: RecellBrandLoader(message: 'Evaluating device condition checklist...'),
        ),
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
                  childAspectRatio: 0.96,
                ),
                itemCount: currentStep.options.length,
                itemBuilder: (context, idx) {
                  final opt = currentStep.options[idx];
                  final isSelected = _selectedOptionCodes.contains(opt.code);

                  return GlassContainer(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(12),
                    border: Border.all(
                      color: isSelected
                          ? (opt.isRejection ? Colors.red : AppTheme.primaryGreen)
                          : Colors.white.withValues(alpha: 0.85),
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    color: isSelected
                        ? (opt.isRejection
                            ? Colors.red.shade50.withValues(alpha: 0.85)
                            : AppTheme.lightGreen.withValues(alpha: 0.85))
                        : Colors.white.withValues(alpha: 0.85),
                    onTap: () => _toggleOption(opt, isMultiple),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                            size: 20,
                            color: isSelected
                                ? (opt.isRejection ? Colors.red : AppTheme.primaryGreen)
                                : AppTheme.border,
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildOptionVisual(opt, isSelected),
                              const SizedBox(height: 10),
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
                                  color: opt.isRejection
                                      ? Colors.red.shade50
                                      : (isSelected ? AppTheme.lightGreen : AppTheme.canvas),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  opt.isRejection
                                      ? 'Critical Check'
                                      : opt.isAccessoryBonus
                                          ? 'Accessory'
                                          : (isSelected ? 'Selected' : 'Doorstep QC'),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: opt.isRejection
                                        ? Colors.red.shade900
                                        : (isSelected ? AppTheme.darkGreen : AppTheme.textSecondary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Smart Warning Banner if Invoice Bill is not selected in accessories step
              if (currentStep.options.any((o) => o.code.toLowerCase().contains('bill')) &&
                  !_selectedOptionCodes.any((c) => c.toLowerCase().contains('bill'))) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Invoice Bill not selected. Warranty is set to "No Warranty".',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Dynamic "Others (Specify Custom Defect/Detail)" Card
              GlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.all(14),
                border: Border.all(
                  color: (_stepCustomNotes[currentStep.name]?.isNotEmpty == true)
                      ? AppTheme.primaryGreen
                      : Colors.white.withOpacity(0.85),
                  width: (_stepCustomNotes[currentStep.name]?.isNotEmpty == true) ? 2 : 1.2,
                ),
                color: Colors.white.withOpacity(0.85),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryGreen, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Other ${currentStep.name} Issue / Custom Note',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                              ),
                              const Text(
                                'Specify any unlisted defect or special remark for this step',
                                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (_stepCustomNotes[currentStep.name]?.isNotEmpty == true)
                          const Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen, size: 18),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _getController(currentStep.name),
                      decoration: InputDecoration(
                        hintText: 'e.g. Minor scratch near camera, loose volume button, etc...',
                        hintStyle: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withOpacity(0.7)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5)),
                      ),
                      maxLines: 2,
                      onChanged: (val) {
                        setState(() {
                          _stepCustomNotes[currentStep.name] = val.trim();
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

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

  Widget _buildOptionVisual(ConditionOptionModel opt, bool isSelected) {
    if (opt.imageBase64 != null && opt.imageBase64!.trim().isNotEmpty && !opt.imageBase64!.contains('svg')) {
      try {
        final clean = opt.imageBase64!.contains(',') ? opt.imageBase64!.split(',').last : opt.imageBase64!;
        final bytes = base64Decode(clean);
        return Image.memory(
          bytes,
          height: 44,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildVectorIllustration(opt.code, isSelected),
        );
      } catch (_) {
        return _buildVectorIllustration(opt.code, isSelected);
      }
    }
    return _buildVectorIllustration(opt.code, isSelected);
  }

  Widget _buildVectorIllustration(String code, bool isSelected) {
    final c = code.toLowerCase();

    // Battery Health visualization cards matching demo screenshots
    if (c.contains('batt_85') || (c.contains('battery') && c.contains('85'))) {
      return Container(
        width: 76,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF0BAA4B),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0BAA4B).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: const Center(
          child: Text(
            '85%+',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ),
      );
    }
    if (c.contains('batt_81') || (c.contains('battery') && c.contains('81'))) {
      return Container(
        width: 76,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: const Center(
          child: Text(
            '81-85%',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ),
      );
    }
    if (c.contains('batt_80') || (c.contains('battery') && (c.contains('80') || c.contains('below')))) {
      return Container(
        width: 76,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: const Center(
          child: Text(
            '≤80%',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ),
      );
    }

    // Accessories
    if (c.contains('box')) {
      return const Icon(Icons.inventory_2_outlined, size: 44, color: AppTheme.primaryGreen);
    }
    if (c.contains('charger') && !c.contains('cable')) {
      return const Icon(Icons.power_outlined, size: 44, color: AppTheme.primaryGreen);
    }
    if (c.contains('cable')) {
      return const Icon(Icons.cable_rounded, size: 44, color: AppTheme.primaryGreen);
    }
    if (c.contains('bill') || c.contains('invoice')) {
      return const Icon(Icons.receipt_long_rounded, size: 44, color: AppTheme.primaryGreen);
    }
    if (c.contains('icloud')) {
      return const Icon(Icons.cloud_outlined, size: 44, color: Color(0xFF3B82F6));
    }
    if (c.contains('cam')) {
      return const Icon(Icons.camera_alt_outlined, size: 42, color: AppTheme.primaryGreen);
    }
    if (c.contains('crack') || c.contains('shatter')) {
      return const Icon(Icons.broken_image_outlined, size: 44, color: Colors.redAccent);
    }
    if (c.contains('scratch') || c.contains('dent')) {
      return const Icon(Icons.phonelink_erase_rounded, size: 44, color: Color(0xFFF59E0B));
    }
    if (c.contains('flawless') || c.contains('perfect') || c.contains('switch_on')) {
      return const Icon(Icons.verified_rounded, size: 44, color: AppTheme.primaryGreen);
    }

    return Icon(
      _getOptionIcon(code),
      size: 42,
      color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
    );
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
