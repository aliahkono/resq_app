import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/home/eligible_home_view.dart';
import 'package:resq/views/home/ineligible_home_view.dart';
import 'package:resq/widgets/custom_bot_nav_bar.dart';

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
  int _currentTabIndex = 0;
  bool _isLoading = true;
  late ClassificationResult _effectiveResult;
  late bool _isFirstTime;

  @override
  void initState() {
    super.initState();
    _evaluateEligibility();
  }

  Future<void> _evaluateEligibility() async {
    if (widget.classificationResult != null) {
      _effectiveResult = widget.classificationResult!;
      _isFirstTime = widget.isFirstTimeDonor;
    } else if (widget.screeningModel != null) {
      _effectiveResult = widget.screeningModel!.evaluateEligibility();
      _isFirstTime = widget.screeningModel!.screensNPT.isFirstTimeDonor;
    } else {
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

  Widget _buildBody() {
    switch (_currentTabIndex) {
      case 0:
        return _effectiveResult.isEligible
            ? EligibleHomeView(isFirstTimeDonor: _isFirstTime)
            : IneligibleHomeView(
          classificationResult: _effectiveResult,
          isFirstTimeDonor: _isFirstTime,
        );
      case 1:
        return const Center(child: Text('Donation Appointments & Schedule'));
      case 2:
        return const Center(child: Text('Donor Profile & Settings'));
      default:
        return const SizedBox.shrink();
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

    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
      ),
    );
  }
}