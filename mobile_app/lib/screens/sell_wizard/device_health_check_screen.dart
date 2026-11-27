import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/image_helper.dart';
import 'questionnaire_screen.dart';
import 'quote_and_booking_screen.dart';

class DeviceHealthCheckScreen extends StatefulWidget {
  final DeviceCategoryModel? category;
  final BrandModel brand;
  final PhoneModelItem model;
  final StorageVariantModel variant;
  final bool isCustomDevice;
  final String? customDeviceName;
  final String? customDeviceCategory;
  final String? customDeviceSpecs;
  final double? customExpectedPrice;

  const DeviceHealthCheckScreen({
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
  State<DeviceHealthCheckScreen> createState() => _DeviceHealthCheckScreenState();
}

class _DeviceHealthCheckScreenState extends State<DeviceHealthCheckScreen> {
  final ApiService _api = ApiService();
  final Map<String, String> _answers = {}; // code -> 'YES' | 'NO'

  // Brand primary red matching screenshots
  static const Color brandRed = Color(0xFFE50914);
  static const Color brandRedDark = Color(0xFFB80710);
  static const Color brandRedBg = Color(0xFFFFF1F2);

  List<EvaluationTriageQuestionModel> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final remote = await _api.getTriageQuestions();
      if (remote.isNotEmpty) {
        if (mounted) {
          setState(() {
            _questions = remote;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback default 4 questions matching screenshots
    if (mounted) {
      setState(() {
        _questions = [
          EvaluationTriageQuestionModel(
            id: 1,
            code: 'WORKING_CONDITION',
            questionText: '1. Is the phone in proper working condition?',
            subtitle: 'Check if the phone powers on and confirm that it is in working condition',
            isPowerOnGate: true,
            deductionType: 'PERCENTAGE',
            deductionValueOnNo: 70.0,
            displayOrder: 1,
          ),
          EvaluationTriageQuestionModel(
            id: 2,
            code: 'TOUCH_WORKING',
            questionText: '2. Is the touchscreen on your phone working properly?',
            subtitle: 'Check the touch screen functionality of your phone',
            isPowerOnGate: false,
            deductionType: 'PERCENTAGE',
            deductionValueOnNo: 20.0,
            displayOrder: 2,
          ),
          EvaluationTriageQuestionModel(
            id: 3,
            code: 'DISPLAY_ORIGINAL',
            questionText: "3. Is the phone's display original?",
            subtitle: 'Select "Yes" if the screen was never changed or was changed by the Authorized Service Center. Select "No" if the screen was changed at a local shop or UnAuthorized Service Center',
            isPowerOnGate: false,
            deductionType: 'PERCENTAGE',
            deductionValueOnNo: 15.0,
            displayOrder: 3,
          ),
          EvaluationTriageQuestionModel(
            id: 4,
            code: 'VALID_WARRANTY',
            questionText: '4. Is there a valid warranty for your phone?',
            subtitle: "You'll get a better price if your device has a manufacturer warranty",
            isPowerOnGate: false,
            deductionType: 'PERCENTAGE',
            deductionValueOnNo: 5.0,
            displayOrder: 4,
          ),
        ];
        _isLoading = false;
      });
    }
  }

  void _onAnswer(String code, String value) {
    setState(() {
      _answers[code] = value;

      // If answered NO, dynamically clear answers for any question that is disabled by this rule
      final qObj = _questions.firstWhere((q) => q.code == code, orElse: () => _questions.first);
      if (value == 'NO' && qObj.disablesQuestionCodes.isNotEmpty) {
        for (final disabledCode in qObj.disablesQuestionCodes) {
          _answers.remove(disabledCode);
        }
      }

      // Backward-compatible fallback for WORKING_CONDITION
      if (code == 'WORKING_CONDITION' && value == 'NO') {
        _answers.remove('TOUCH_WORKING');
        _answers.remove('DISPLAY_ORIGINAL');
        _answers.remove('VALID_WARRANTY');
      }
    });
  }

  bool get _isPowerOnGateNo {
    return _answers.entries.any((entry) {
      if (entry.value != 'NO') return false;
      final q = _questions.firstWhere((item) => item.code == entry.key, orElse: () => _questions.first);
      return q.isPowerOnGate;
    });
  }

  Set<String> get _disabledQuestionCodes {
    final Set<String> disabled = {};
    for (final q in _questions) {
      if (_answers[q.code] == 'NO') {
        disabled.addAll(q.disablesQuestionCodes);
        if (q.isPowerOnGate) {
          // If a power on gate is NO, turn off all downstream questions
          final qIndex = _questions.indexOf(q);
          for (int j = qIndex + 1; j < _questions.length; j++) {
            disabled.add(_questions[j].code);
          }
        }
      }
    }
    return disabled;
  }

  bool _isQuestionVisible(int index) {
    if (index < 0 || index >= _questions.length) return false;
    final currentQ = _questions[index];
    if (_disabledQuestionCodes.contains(currentQ.code)) return false;

    if (index == 0) return true; // First question is always visible unless disabled

    // Progressive disclosure: Question is visible only if previous non-disabled question is answered
    for (int i = index - 1; i >= 0; i--) {
      final prevQ = _questions[i];
      if (!_disabledQuestionCodes.contains(prevQ.code)) {
        return _answers.containsKey(prevQ.code);
      }
    }
    return true;
  }

  bool get _canProceed {
    if (_isPowerOnGateNo) return true; // Can finish immediately as dead phone
    if (_questions.isEmpty) return false;
    // All currently visible questions must be answered
    for (int i = 0; i < _questions.length; i++) {
      if (_isQuestionVisible(i) && !_answers.containsKey(_questions[i].code)) {
        return false;
      }
    }
    return true;
  }

  void _handleContinue() {
    if (!_canProceed) return;

    if (_isPowerOnGateNo) {
      // Dead phone flow: direct to quote/booking with dead device valuation
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuoteAndBookingScreen(
            brand: widget.brand,
            model: widget.model,
            variant: widget.variant,
            selectedOptionCodes: const [],
            triageAnswers: _answers,
            isCustomDevice: widget.isCustomDevice,
            customDeviceName: widget.customDeviceName,
            customDeviceCategory: widget.customDeviceCategory,
            customDeviceSpecs: widget.customDeviceSpecs,
            customExpectedPrice: widget.customExpectedPrice,
          ),
        ),
      );
    } else {
      // Normal flow: proceed to detailed cosmetic questionnaire
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionnaireScreen(
            category: widget.category,
            brand: widget.brand,
            model: widget.model,
            variant: widget.variant,
            triageAnswers: _answers,
            isCustomDevice: widget.isCustomDevice,
            customDeviceName: widget.customDeviceName,
            customDeviceCategory: widget.customDeviceCategory,
            customDeviceSpecs: widget.customDeviceSpecs,
            customExpectedPrice: widget.customExpectedPrice,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceTitle = '${widget.brand.name} ${widget.model.name} (${widget.variant.storage})';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Device > Brand > Model > Variant > Price > Evaluation',
          style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandRed))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================= 1. EVALUATION DEVICE CARD =================
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black.withOpacity(0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Device Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade50,
                                      child: widget.model.imageBase64 != null && widget.model.imageBase64!.isNotEmpty
                                          ? Image.memory(
                                              base64Decode(widget.model.imageBase64!.contains(',')
                                                  ? widget.model.imageBase64!.split(',').last
                                                  : widget.model.imageBase64!),
                                              fit: BoxFit.contain,
                                            )
                                          : const Icon(Icons.phone_iphone_rounded, color: brandRed, size: 36),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Evaluating',
                                          style: TextStyle(
                                            color: brandRed,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          deviceTitle,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14.5,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Red Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 4,
                                  width: double.infinity,
                                  color: Colors.grey.shade200,
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: _isPowerOnGateNo
                                        ? 1.0
                                        : (_answers.length / (_questions.isEmpty ? 1 : _questions.length)).clamp(0.2, 1.0),
                                    child: Container(color: brandRed),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'View Evaluation Summary >',
                                  style: TextStyle(
                                    color: Colors.black87.withOpacity(0.7),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ================= 2. THE 4 PROGRESSIVE QUESTIONS =================
                        for (int i = 0; i < _questions.length; i++) ...[
                          if (_isQuestionVisible(i)) ...[
                            _buildQuestionItem(
                              question: _questions[i],
                              index: i + 1,
                              selectedAnswer: _answers[_questions[i].code],
                              onAnswer: (val) => _onAnswer(_questions[i].code, val),
                            ),
                            const SizedBox(height: 22),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                // ================= 3. BOTTOM ACTION BAR =================
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _canProceed ? _handleContinue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          disabledBackgroundColor: brandRed.withOpacity(0.4),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _isPowerOnGateNo ? 'Finish' : 'Next',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQuestionItem({
    required EvaluationTriageQuestionModel question,
    required int index,
    required String? selectedAnswer,
    required ValueChanged<String> onAnswer,
  }) {
    final isYes = selectedAnswer == 'YES';
    final isNo = selectedAnswer == 'NO';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question Title
        Text(
          question.questionText.startsWith('$index.')
              ? question.questionText
              : '$index. ${question.questionText}',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            height: 1.3,
          ),
        ),
        if (question.subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            question.subtitle,
            style: TextStyle(
              color: Colors.black54.withOpacity(0.6),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 12),
        // YES / NO Pill Buttons
        Row(
          children: [
            Expanded(
              child: _buildChoiceButton(
                label: 'Yes',
                icon: Icons.check_rounded,
                isSelected: isYes,
                onTap: () => onAnswer('YES'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildChoiceButton(
                label: 'No',
                icon: Icons.close_rounded,
                isSelected: isNo,
                onTap: () => onAnswer('NO'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        decoration: BoxDecoration(
          color: isSelected ? brandRedBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? brandRed : Colors.grey.shade300,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? brandRed : Colors.black87,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? brandRed : Colors.black87,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
