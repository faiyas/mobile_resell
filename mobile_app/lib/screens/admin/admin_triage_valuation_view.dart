import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class AdminTriageValuationView extends StatefulWidget {
  final VoidCallback onRefresh;

  const AdminTriageValuationView({super.key, required this.onRefresh});

  @override
  State<AdminTriageValuationView> createState() => _AdminTriageValuationViewState();
}

class _AdminTriageValuationViewState extends State<AdminTriageValuationView> {
  final ApiService _api = ApiService();
  List<EvaluationTriageQuestionModel> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getTriageQuestions();
      if (mounted) {
        setState(() {
          _questions = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.rule_folder_rounded, color: AppTheme.primaryGreen),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Health Check Triage Questions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    Text('Controls initial pass/fail gates and deduction rules', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadQuestions),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
              : _questions.isEmpty
                  ? const Center(child: Text('No triage questions configured'))
                  : RefreshIndicator(
                      onRefresh: _loadQuestions,
                      color: AppTheme.primaryGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _questions.length,
                        itemBuilder: (ctx, idx) {
                          final q = _questions[idx];
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
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: q.deductionValueOnNo > 30 ? Colors.red.shade50 : Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'No Penalty: -${q.deductionValueOnNo.toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            color: q.deductionValueOnNo > 30 ? Colors.red.shade700 : Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
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
        ),
      ],
    );
  }
}
