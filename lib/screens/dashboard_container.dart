import 'package:flutter/material.dart';
import 'dashboard_view_variant1.dart';
import 'dashboard_view_variant2.dart';
import 'dashboard_view_variant3.dart';
import 'dashboard_view_variant4.dart';

class DashboardContainer extends StatefulWidget {
  const DashboardContainer({super.key});

  @override
  State<DashboardContainer> createState() => _DashboardContainerState();
}

class _DashboardContainerState extends State<DashboardContainer> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: const [
          DashboardViewVariant1(),
          DashboardViewVariant2(),
          DashboardViewVariant3(),
          DashboardViewVariant4(),
        ],
      ),
      bottomNavigationBar: _buildPageIndicator(),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentPage == index
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          );
        }),
      ),
    );
  }
}
