import 'package:flutter/material.dart';
import 'dashboard_view.dart';
import 'dashboard_view_variant1.dart';
import 'dashboard_view_variant2.dart';
import 'dashboard_view_variant3.dart';
import 'dashboard_view_variant4.dart';

class DashboardNavigationContainer extends StatefulWidget {
  const DashboardNavigationContainer({super.key});

  @override
  State<DashboardNavigationContainer> createState() => _DashboardNavigationContainerState();
}

class _DashboardNavigationContainerState extends State<DashboardNavigationContainer> {
  int _currentIndex = 0;

  final List<Widget> _dashboardViews = const [
    DashboardView(),
    DashboardViewVariant1(),
    DashboardViewVariant2(),
    DashboardViewVariant3(),
    DashboardViewVariant4(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _dashboardViews,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Main',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.palette),
            label: 'Variant 1',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.style),
            label: 'Variant 2',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.design_services),
            label: 'Variant 3',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.brush),
            label: 'Variant 4',
          ),
        ],
      ),
    );
  }
}
