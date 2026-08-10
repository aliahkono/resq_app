import 'package:flutter/material.dart';
import 'package:resq/views/home/eligible_home_view.dart';
import 'package:resq/views/home/ineligible_home_view.dart';
import 'package:resq/utils/helpers/eligibility_rules.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _isLoading = true;
  bool _isEligible = false;
  int _daysRemaining = 0; // Days until eligible if deferred

  @override
  void initState() {
    super.initState();
    _evaluateEligibility();
  }

  Future<void> _evaluateEligibility() async {
    // 1. Fetch donor screening data & last donation date
    // 2. Pass data to your Decision Tree / Eligibility Algorithm
    // (Simulating assessment calculation delay)
    await Future.delayed(const Duration(milliseconds: 500));

    // Example logic check:
    bool eligibleResult = true; // Replace with result from your decision tree algorithm
    int deferralDays = 45;       // Replace with remaining recovery days if deferred

    if (mounted) {
      setState(() {
        _isEligible = eligibleResult;
        _daysRemaining = deferralDays;
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

    // Dynamic Routing based on Algorithm Output
    return _isEligible
        ? const EligibleHomeView()
        : IneligibleHomeView(daysRemaining: _daysRemaining);
  }
}