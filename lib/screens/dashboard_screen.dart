import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = provider.data;

        return RefreshIndicator(
          onRefresh: provider.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data.alerts.isNotEmpty) ...[
                _buildAlertsSection(data.alerts),
                const SizedBox(height: 16),
              ],
              _buildChartsSection(data),
              const SizedBox(height: 16),
              if (data.birthdayStudents.isNotEmpty) ...[
                _buildBirthdaySection(data.birthdayStudents),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertsSection(List<String> alerts) {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[800]),
                const SizedBox(width: 8),
                Text(
                  '\u05d4\u05ea\u05e8\u05d0\u05d5\u05ea',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...alerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.orange[800]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alert,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(DashboardData data) {
    return Column(
      children: [
        _buildStatCard(
          title: '\u05d0\u05d7\u05d5\u05d6 \u05e0\u05d5\u05db\u05d7\u05d5\u05ea \u05d1\u05e9\u05d9\u05e2\u05d5\u05e8 \u05d4\u05d0\u05d7\u05e8\u05d5\u05df',
          value: '${data.lastSessionAttendanceRate.toStringAsFixed(0)}%',
          chart: _buildPieChart(data.lastSessionAttendanceRate),
          color: Colors.blue,
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          title: '\u05d4\u05ea\u05e7\u05d3\u05de\u05d5\u05ea \u05ea\u05e8\u05d2\u05d9\u05dc\u05d9\u05dd',
          value: '${data.exercisesProgress.toStringAsFixed(0)}%',
          chart: _buildLinearProgress(data.exercisesProgress),
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _showAbsenteesSheet(context),
          child: _buildStatCard(
            title: '\u05ea\u05dc\u05de\u05d9\u05d3\u05d9\u05dd \u05e2\u05dd 3 \u05d4\u05d9\u05e2\u05d3\u05e8\u05d5\u05d9\u05d5\u05ea \u05d1\u05e8\u05e6\u05e3',
            value: '${data.studentsWithThreeAbsences}',
            chart: _buildNumberDisplay(data.studentsWithThreeAbsences),
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  void _showAbsenteesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Consumer<DashboardProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final absentees = provider.data.studentsWithConsecutiveAbsences;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_off),
                      const SizedBox(width: 8),
                      const Text(
                        '\u05e8\u05e9\u05d9\u05de\u05ea \u05de\u05d7\u05e1\u05d9\u05e8\u05d9\u05dd',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${absentees.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (absentees.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '\u05d0\u05d9\u05df \u05ea\u05dc\u05de\u05d9\u05d3\u05d9\u05dd \u05e2\u05dd 3 \u05d7\u05d9\u05e1\u05d5\u05e8\u05d9\u05dd \u05e8\u05e6\u05d5\u05e4\u05d9\u05dd',
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: ListView.separated(
                        itemCount: absentees.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = absentees[index];
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(item.student.name),
                            subtitle: Text(
                              '\u05d7\u05d9\u05e1\u05d5\u05e8\u05d9\u05dd \u05e8\u05e6\u05d5\u05e4\u05d9\u05dd: ${item.consecutiveAbsences}',
                            ),
                            trailing: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.red[100],
                              child: Text(
                                '${item.consecutiveAbsences}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Widget chart,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: chart,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(double percentage) {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: percentage,
            color: Colors.blue,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: 100 - percentage,
            color: Colors.grey[300],
            title: '',
            radius: 50,
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 0,
      ),
    );
  }

  Widget _buildLinearProgress(double percentage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 20,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(0)}% \u05d4\u05d5\u05e9\u05dc\u05de\u05d5',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberDisplay(int number) {
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: number > 0 ? Colors.red[100] : Colors.green[100],
        ),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: number > 0 ? Colors.red : Colors.green,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBirthdaySection(List students) {
    return Card(
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cake, color: Colors.purple[800]),
                const SizedBox(width: 8),
                Text(
                  '\u05d9\u05de\u05d9 \u05d4\u05d5\u05dc\u05d3\u05ea \u05d4\u05e9\u05d1\u05d5\u05e2',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...students.map((student) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.celebration, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        student.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
