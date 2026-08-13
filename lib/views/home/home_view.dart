import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/home/eligible_home_view.dart';
import 'package:resq/views/home/ineligible_home_view.dart';

class HomeView extends StatefulWidget {
  final ScreenNPTModel? screeningModel;
  final ClassificationResult? classificationResult;
  final bool isFirstTimeDonor;

  const HomeView({
    super.key,
    this.screeningModel,
    this.classificationResult,
    this.isFirstTimeDonor = true,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _isLoading = true;
  late ClassificationResult _effectiveResult;
  late bool _isFirstTime;

  @override
  void initState() {
    super.initState();
    _evaluateEligibility();
  }

  Future<void> _evaluateEligibility() async {
    // 1. If explicit result was passed during registration/login, use it
    if (widget.classificationResult != null) {
      _effectiveResult = widget.classificationResult!;
      _isFirstTime = widget.isFirstTimeDonor;
    } else if (widget.screeningModel != null) {
      _effectiveResult = widget.screeningModel!.evaluateEligibility();
      _isFirstTime = widget.screeningModel!.screensNPT.isFirstTimeDonor;
    } else {
      // 2. Default fallback or simulate fetching stored profile screening state
      await Future.delayed(const Duration(milliseconds: 300));
      _effectiveResult = ClassificationResult(status: EligibleStats.eligible);
      _isFirstTime = widget.isFirstTimeDonor;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Route to Eligible or Ineligible Home View based on Decision Tree classification
    return _effectiveResult.isEligible
        ? EligibleHomeView(
      isFirstTimeDonor: _isFirstTime,
    )
        : IneligibleHomeView(
      classificationResult: _effectiveResult,
      isFirstTimeDonor: _isFirstTime,
    );
  }
}