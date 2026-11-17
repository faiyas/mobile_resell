import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
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
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _toggleOption(ConditionOptionModel opt, bool isMultiple) {
    setState(() {
      if (isMultiple) {
        if (_selectedOptionCodes.contains(opt.code)) {
          _selectedOptionCodes.remove(opt.code);
        } else {
          _selectedOptionCodes.add(opt.code);
        }
      } else {
        // Single selection within this step: unselect others in the same step
        final currentStep = _steps[_currentStepIndex];
        for (var o in currentStep.options) {
          _selectedOptionCodes.remove(o.code);
        }
        _selectedOptionCodes.add(opt.code);
      }
    });
  }

  void _nextStep() {
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
      appBar: AppBar(
        title: Text('${widget.brand.name} · ${widget.model.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousStep,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            minHeight: 4,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(10),
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
                  isMultiple ? 'Select all that apply' : 'Select one option',
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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: currentStep.options.length <= 4 ? 2 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemCount: currentStep.options.length,
              itemBuilder: (context, idx) {
                final opt = currentStep.options[idx];
                final isSelected = _selectedOptionCodes.contains(opt.code);

                return InkWell(
                  onTap: () => _toggleOption(opt, isMultiple),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryGreen : AppTheme.border,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 18),
                            Icon(
                              _getOptionIcon(opt.code),
                              size: 28,
                              color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                            ),
                            Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              size: 18,
                              color: isSelected ? AppTheme.primaryGreen : AppTheme.border,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          opt.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? AppTheme.darkGreen : AppTheme.textPrimary,
                          ),
                        ),
                        if (opt.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            opt.description,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Pro Tip Card
            if (currentStep.proTip.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
                ),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
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
    );
  }

  IconData _getOptionIcon(String code) {
    final c = code.toLowerCase();
    if (c.contains('cam')) return Icons.camera_alt_outlined;
    if (c.contains('screen') || c.contains('glass')) return Icons.smartphone;
    if (c.contains('body') || c.contains('dent')) return Icons.broken_image_outlined;
    if (c.contains('touch')) return Icons.touch_app_outlined;
    if (c.contains('mic')) return Icons.mic_outlined;
    if (c.contains('speaker')) return Icons.volume_up_outlined;
    if (c.contains('box')) return Icons.inventory_2_outlined;
    if (c.contains('charger') || c.contains('cable')) return Icons.cable_outlined;
    if (c.contains('bill') || c.contains('warranty')) return Icons.receipt_long_outlined;
    return Icons.check_circle_outline;
  }
}
