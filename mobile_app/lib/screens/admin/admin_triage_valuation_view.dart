import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
import '../../utils/image_helper.dart';

class AdminTriageValuationView extends StatefulWidget {
  final VoidCallback onRefresh;

  const AdminTriageValuationView({super.key, required this.onRefresh});

  @override
  State<AdminTriageValuationView> createState() => _AdminTriageValuationViewState();
}

class _AdminTriageValuationViewState extends State<AdminTriageValuationView> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;

  List<EvaluationTriageQuestionModel> _triageQuestions = [];
  List<ConditionCategoryModel> _conditionSteps = [];
  List<BrandModel> _brands = [];
  BrandModel? _selectedBrandFilter;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllValuationData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllValuationData() async {
    setState(() => _isLoading = true);
    try {
      final triage = await _api.getTriageQuestions();
      final brands = await _api.getBrands();
      final steps = await _api.getConditionCategories(brandId: _selectedBrandFilter?.id, forceRefresh: true);

      if (mounted) {
        setState(() {
          _triageQuestions = triage;
          _brands = brands;
          _conditionSteps = steps;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= 1. TRIAGE QUESTION CRUD =================
  void _showTriageQuestionModal([EvaluationTriageQuestionModel? existing]) {
    final textCtrl = TextEditingController(text: existing?.questionText ?? '');
    final subCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final orderCtrl = TextEditingController(text: (existing?.displayOrder ?? (_triageQuestions.length + 1)).toString());
    final deductionCtrl = TextEditingController(text: (existing?.deductionValueOnNo ?? 0.0).toStringAsFixed(0));
    bool isGate = existing?.isPowerOnGate ?? false;
    String deductionType = existing?.deductionType ?? 'PERCENTAGE';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              Text(existing == null ? 'Add Triage Health Check' : 'Edit Triage Gate #${existing.displayOrder}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Text('Initial pre-qualification Yes/No question for device valuation', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Question Text', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: textCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Does the phone switch on?',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Subtitle / Hint', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: subCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Device must display home screen without charger',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Deduction on "NO" (%)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: deductionCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: '%',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gate Order', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: orderCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Power-On Gate (Auto-Reject if NO)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('If answer is NO, immediate dead device flow is triggered', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                value: isGate,
                activeColor: Colors.redAccent,
                onChanged: (val) => setM(() => isGate = val),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final qText = textCtrl.text.trim();
                          if (qText.isEmpty) return;
                          final order = int.tryParse(orderCtrl.text) ?? 1;
                          final ded = double.tryParse(deductionCtrl.text) ?? 0.0;
                          setM(() => isSaving = true);
                          try {
                            final payload = {
                              'question_text': qText,
                              'subtitle': subCtrl.text.trim(),
                              'display_order': order,
                              'deduction_value_on_no': ded,
                              'deduction_type': deductionType,
                              'is_power_on_gate': isGate,
                              'is_active': true,
                            };
                            if (existing == null) {
                              await _api.createTriageQuestion(payload);
                            } else {
                              await _api.updateTriageQuestion(existing.id, payload);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadAllValuationData();
                          } catch (e) {
                            setM(() => isSaving = false);
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(existing == null ? 'Create Question' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteTriage(EvaluationTriageQuestionModel q) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Triage Question?'),
        content: Text('Remove "${q.questionText}" from pre-qualification?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteTriageQuestion(q.id);
                _loadAllValuationData();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ================= 2. CONDITION STEP (QUESTIONNAIRE) CRUD =================
  void _showConditionStepModal([ConditionCategoryModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final subCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final stepCtrl = TextEditingController(text: (existing?.stepNumber ?? (_conditionSteps.length + 1)).toString());
    String selType = existing?.selectionType ?? 'MULTIPLE';
    int? brandId = existing?.brand ?? _selectedBrandFilter?.id;
    String? base64Img = existing?.imageBase64;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              Text(existing == null ? 'Add Questionnaire Step' : 'Edit Step: ${existing.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Text('Questionnaire evaluation section for device defects/accessories', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Step Name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Screen Condition, Body / Frame, Functional Tests',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Subtitle / Guidance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: subCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Select all physical cracks and dead pixels',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selType,
                      decoration: InputDecoration(
                        labelText: 'Selection Type',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'SINGLE', child: Text('Single Choice')),
                        DropdownMenuItem(value: 'MULTIPLE', child: Text('Multi-Select')),
                        DropdownMenuItem(value: 'ACCESSORY', child: Text('Accessories')),
                        DropdownMenuItem(value: 'WARRANTY', child: Text('Warranty Gate')),
                      ],
                      onChanged: (val) => setM(() => selType = val ?? 'MULTIPLE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: stepCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Step #',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: brandId,
                decoration: InputDecoration(
                  labelText: 'Brand Specific (Optional)',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Universal (All Brands)')),
                  ..._brands.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                ],
                onChanged: (val) => setM(() => brandId = val),
              ),
              const SizedBox(height: 14),
              const Text('Step Icon / Illustration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                    child: base64Img != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(ImageHelper.decodeBase64(base64Img)!, fit: BoxFit.contain))
                        : const Icon(Icons.category_rounded, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87),
                    icon: const Icon(Icons.upload, size: 16),
                    label: Text(base64Img != null ? 'Change Icon' : 'Pick Icon', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final xfile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 400);
                      if (xfile != null) {
                        final bytes = await xfile.readAsBytes();
                        setM(() => base64Img = base64Encode(bytes));
                      }
                    },
                  ),
                  if (base64Img != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: 'Remove Icon',
                      onPressed: () => setM(() => base64Img = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          final sNum = int.tryParse(stepCtrl.text) ?? 1;
                          setM(() => isSaving = true);
                          try {
                            final payload = {
                              'name': name,
                              'subtitle': subCtrl.text.trim(),
                              'step_number': sNum,
                              'selection_type': selType,
                              'brand': brandId,
                              if (base64Img != null) 'image_base64': base64Img,
                              'is_active': true,
                            };
                            if (existing == null) {
                              await _api.createConditionCategory(payload);
                            } else {
                              await _api.updateConditionCategory(existing.id, payload);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadAllValuationData();
                          } catch (e) {
                            setM(() => isSaving = false);
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(existing == null ? 'Create Step' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteStep(ConditionCategoryModel step) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Step: ${step.name}?'),
        content: const Text('This will remove the step and all its options. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteConditionCategory(step.id);
                _loadAllValuationData();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ================= 3. CLONE QUESTIONS MODAL =================
  void _showCloneModal() {
    int? fromBrandId;
    int? toBrandId;
    bool isCloning = false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              const Text('Clone Questionnaire Steps', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Text('Copy all evaluation steps & deduction rules from one brand to another', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: fromBrandId,
                decoration: InputDecoration(
                  labelText: 'Source Brand (Copy From)',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _brands.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                onChanged: (val) => setM(() => fromBrandId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: toBrandId,
                decoration: InputDecoration(
                  labelText: 'Target Brand (Copy To)',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _brands.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                onChanged: (val) => setM(() => toBrandId = val),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isCloning || fromBrandId == null || toBrandId == null || fromBrandId == toBrandId
                      ? null
                      : () async {
                          setM(() => isCloning = true);
                          try {
                            await _api.copyQuestionsFromBrand(sourceBrandId: fromBrandId!, targetBrandId: toBrandId!);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadAllValuationData();
                          } catch (e) {
                            setM(() => isCloning = false);
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                  child: isCloning
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Clone Entire Questionnaire', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= 4. DEDUCTION OPTION CRUD =================
  void _showOptionModal(ConditionCategoryModel step, [ConditionOptionModel? existing]) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final valCtrl = TextEditingController(text: (existing?.defaultDeductionValue ?? 10.0).toStringAsFixed(0));
    String dedType = existing?.deductionType ?? 'PERCENTAGE';
    bool isRejection = existing?.isRejection ?? false;
    bool isBonus = existing?.isAccessoryBonus ?? false;
    String? base64Img = existing?.imageBase64;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              Text(existing == null ? 'Add Deduction Rule · ${step.name}' : 'Edit Rule: ${existing.title}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Option Title (e.g. Major Scratch, Screen Broken)',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: 'Customer Description',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: dedType,
                      decoration: InputDecoration(
                        labelText: 'Deduction Type',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage (%)')),
                        DropdownMenuItem(value: 'FLAT', child: Text('Flat Amount (₹)')),
                      ],
                      onChanged: (val) => setM(() => dedType = val ?? 'PERCENTAGE'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: valCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Penalty Value',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-Rejection (Dead/Unsalvageable)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                value: isRejection,
                activeColor: Colors.redAccent,
                onChanged: (val) => setM(() => isRejection = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Accessory Bonus (Adds Value instead of Deduction)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                value: isBonus,
                activeColor: AppTheme.primaryGreen,
                onChanged: (val) => setM(() => isBonus = val),
              ),
              const SizedBox(height: 12),
              const Text('Sample Defect / Accessory Photo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                    child: base64Img != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(ImageHelper.decodeBase64(base64Img)!, fit: BoxFit.contain))
                        : const Icon(Icons.broken_image_rounded, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87),
                    icon: const Icon(Icons.upload, size: 16),
                    label: Text(base64Img != null ? 'Change Photo' : 'Pick Photo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final xfile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 500);
                      if (xfile != null) {
                        final bytes = await xfile.readAsBytes();
                        setM(() => base64Img = base64Encode(bytes));
                      }
                    },
                  ),
                  if (base64Img != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: 'Remove Photo',
                      onPressed: () => setM(() => base64Img = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) return;
                          final val = double.tryParse(valCtrl.text) ?? 0.0;
                          setM(() => isSaving = true);
                          try {
                            final payload = {
                              'category': step.id,
                              'title': title,
                              'description': descCtrl.text.trim(),
                              'deduction_type': dedType,
                              'default_deduction_value': val,
                              'is_rejection': isRejection,
                              'is_accessory_bonus': isBonus,
                              if (base64Img != null) 'image_base64': base64Img,
                              'is_active': true,
                            };
                            if (existing == null) {
                              await _api.createConditionOption(payload);
                            } else {
                              await _api.updateConditionOption(existing.id, payload);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadAllValuationData();
                          } catch (e) {
                            setM(() => isSaving = false);
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(existing == null ? 'Create Rule' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteOption(ConditionOptionModel opt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Rule: ${opt.title}?'),
        content: const Text('Remove this deduction option from valuation calculations?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteConditionOption(opt.id);
                _loadAllValuationData();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TabBar Header
        Container(
          color: Colors.white,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryGreen,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primaryGreen,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                tabs: const [
                  Tab(text: 'Triage Gates'),
                  Tab(text: 'Questionnaire Steps'),
                  Tab(text: 'Deduction Rules'),
                ],
              ),
              // Brand Filter Bar for Steps and Deduction Rules
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Filter: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ChoiceChip(
                            label: const Text('All Brands'),
                            selected: _selectedBrandFilter == null,
                            selectedColor: AppTheme.lightGreen,
                            labelStyle: TextStyle(fontSize: 11, fontWeight: _selectedBrandFilter == null ? FontWeight.w900 : FontWeight.w600),
                            onSelected: (_) {
                              setState(() => _selectedBrandFilter = null);
                              _loadAllValuationData();
                            },
                          ),
                          ..._brands.map((b) => Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  label: Text(b.name),
                                  selected: _selectedBrandFilter?.id == b.id,
                                  selectedColor: AppTheme.lightGreen,
                                  labelStyle: TextStyle(fontSize: 11, fontWeight: _selectedBrandFilter?.id == b.id ? FontWeight.w900 : FontWeight.w600),
                                  onSelected: (_) {
                                    setState(() => _selectedBrandFilter = b);
                                    _loadAllValuationData();
                                  },
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // TabBarView Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTriageTab(),
                    _buildStepsTab(),
                    _buildDeductionsTab(),
                  ],
                ),
        ),
      ],
    );
  }

  // TAB 1: TRIAGE GATES
  Widget _buildTriageTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              const Text('Pre-Qualification Gates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Gate Question', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showTriageQuestionModal(),
              ),
            ],
          ),
        ),
        Expanded(
          child: _triageQuestions.isEmpty
              ? const Center(child: Text('No triage questions configured'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _triageQuestions.length,
                  itemBuilder: (ctx, idx) {
                    final q = _triageQuestions[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: GlassContainer(
                        borderRadius: 18,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(6)),
                                  child: Text('Gate #${q.displayOrder}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppTheme.darkGreen)),
                                ),
                                if (q.isPowerOnGate) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                                    child: const Text('POWER-ON GATE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.red)),
                                  ),
                                ],
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: q.deductionValueOnNo > 30 ? Colors.red.shade50 : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'No: -${q.deductionValueOnNo.toStringAsFixed(0)}%',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: q.deductionValueOnNo > 30 ? Colors.red.shade700 : Colors.amber.shade900),
                                  ),
                                ),
                                IconButton(icon: const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary), onPressed: () => _showTriageQuestionModal(q)),
                                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => _confirmDeleteTriage(q)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(q.questionText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                            if (q.subtitle.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(q.subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 2: QUESTIONNAIRE STEPS
  Widget _buildStepsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Clone Steps', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _showCloneModal,
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Step', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showConditionStepModal(),
              ),
            ],
          ),
        ),
        Expanded(
          child: _conditionSteps.isEmpty
              ? const Center(child: Text('No questionnaire steps configured'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _conditionSteps.length,
                  itemBuilder: (ctx, idx) {
                    final s = _conditionSteps[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: GlassContainer(
                        borderRadius: 18,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                  child: Text('Step #${s.stepNumber}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.blue)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                                  child: Text(s.selectionType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.textSecondary)),
                                ),
                                if (s.brandName != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(6)),
                                    child: Text(s.brandName!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppTheme.darkGreen)),
                                  ),
                                ],
                                const Spacer(),
                                IconButton(icon: const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary), onPressed: () => _showConditionStepModal(s)),
                                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => _confirmDeleteStep(s)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            if (s.subtitle.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(s.subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ),
                            const SizedBox(height: 8),
                            Text('${s.options.length} deduction rules linked', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 3: DEDUCTION RULES
  Widget _buildDeductionsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // 1. TOP SECTION: Initial Triage Gate Deductions
        if (_triageQuestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            child: GlassContainer(
              borderRadius: 18,
              padding: const EdgeInsets.all(12),
              child: ExpansionTile(
                initiallyExpanded: true,
                shape: const Border(),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
                ),
                title: const Text('Initial Triage Gate Deductions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                subtitle: Text('${_triageQuestions.length} gate questions (auto-rejection & gate penalties)', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                children: [
                  const Divider(),
                  ..._triageQuestions.map((q) => ListTile(
                        dense: true,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                q.questionText,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: q.isPowerOnGate ? Colors.red.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: q.isPowerOnGate ? Colors.red.shade200 : Colors.orange.shade200),
                              ),
                              child: Text(
                                q.isPowerOnGate
                                    ? 'REJECT IF NO'
                                    : (q.deductionType == 'PERCENTAGE'
                                        ? '-${q.deductionValueOnNo.toStringAsFixed(0)}% IF NO'
                                        : '-₹${q.deductionValueOnNo.toStringAsFixed(0)} IF NO'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: q.isPowerOnGate ? Colors.red.shade700 : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: q.subtitle.isNotEmpty ? Text(q.subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary),
                          tooltip: 'Edit Gate Deduction',
                          onPressed: () => _showTriageQuestionModal(q),
                        ),
                      )),
                ],
              ),
            ),
          ),

        // 2. Physical Condition Steps & Deduction Rules
        if (_conditionSteps.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No steps configured')))
        else
          ..._conditionSteps.map((step) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(12),
                  child: ExpansionTile(
                    shape: const Border(),
                    title: Text(step.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    subtitle: Text('${step.options.length} deduction rules · Step #${step.stepNumber}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    children: [
                      const Divider(),
                      ...step.options.map((opt) => ListTile(
                            dense: true,
                            leading: opt.imageBase64 != null && opt.imageBase64!.isNotEmpty
                                ? Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: Image.memory(ImageHelper.decodeBase64(opt.imageBase64)!, fit: BoxFit.contain),
                                    ),
                                  )
                                : null,
                            title: Row(
                              children: [
                                Expanded(child: Text(opt.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: opt.isRejection ? Colors.red.shade50 : (opt.isAccessoryBonus ? AppTheme.lightGreen : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    opt.isRejection
                                        ? 'REJECT'
                                        : (opt.isAccessoryBonus
                                            ? '+₹${opt.defaultDeductionValue.toStringAsFixed(0)}'
                                            : (opt.deductionType == 'PERCENTAGE' ? '-${opt.defaultDeductionValue.toStringAsFixed(0)}%' : '-₹${opt.defaultDeductionValue.toStringAsFixed(0)}')),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: opt.isRejection ? Colors.red : (opt.isAccessoryBonus ? AppTheme.darkGreen : Colors.black87),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: opt.description.isNotEmpty ? Text(opt.description, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)) : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary), onPressed: () => _showOptionModal(step, opt)),
                                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => _confirmDeleteOption(opt)),
                              ],
                            ),
                          )),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryGreen,
                              side: const BorderSide(color: AppTheme.primaryGreen),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Deduction Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () => _showOptionModal(step),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}
