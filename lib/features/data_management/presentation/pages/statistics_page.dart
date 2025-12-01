import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/repositories/email_repository.dart';
import '../../../../core/models/email_message.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final EmailRepository _emailRepository = EmailRepository();
  bool _isLoading = true;
  
  // 统计数据
  Map<String, int> _dailyEmailCount = {};
  Map<String, int> _senderCount = {};
  int _totalEmails = 0;
  int _totalNotes = 0;
  int _avgEmailsPerDay = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    
    try {
      final emails = await _emailRepository.getLocalEmails(limit: 10000);
      
      // 按日期统计
      final dailyCount = <String, int>{};
      final senderCount = <String, int>{};
      
      for (final email in emails) {
        // 日期统计（最近7天）
        final dateKey = '${email.receivedDate.month}/${email.receivedDate.day}';
        dailyCount[dateKey] = (dailyCount[dateKey] ?? 0) + 1;
        
        // 发件人统计
        senderCount[email.senderEmail] = (senderCount[email.senderEmail] ?? 0) + 1;
      }
      
      // 只保留最近7天
      final now = DateTime.now();
      final last7Days = <String, int>{};
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = '${date.month}/${date.day}';
        last7Days[key] = dailyCount[key] ?? 0;
      }
      
      // 发件人排序（取前10）
      final sortedSenders = senderCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top10Senders = Map.fromEntries(sortedSenders.take(10));
      
      setState(() {
        _dailyEmailCount = last7Days;
        _senderCount = top10Senders;
        _totalEmails = emails.length;
        _totalNotes = emails.where((e) => e.notes != null && e.notes!.isNotEmpty).length;
        _avgEmailsPerDay = emails.isNotEmpty 
            ? (emails.length / 7).round() 
            : 0;
      });
    } catch (e) {
      debugPrint('加载统计数据失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOverviewCards(),
                  const SizedBox(height: 24),
                  _buildDailyTrendChart(),
                  const SizedBox(height: 24),
                  _buildTopSendersChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '总邮件',
            _totalEmails.toString(),
            Icons.email,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '笔记数',
            _totalNotes.toString(),
            Icons.note,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '日均',
            _avgEmailsPerDay.toString(),
            Icons.trending_up,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTrendChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.show_chart, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  '最近7天邮件趋势',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: _dailyEmailCount.isEmpty
                  ? const Center(child: Text('暂无数据'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _dailyEmailCount.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < _dailyEmailCount.keys.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _dailyEmailCount.keys.elementAt(index),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _dailyEmailCount.entries.toList().asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.value.toDouble(),
                                color: AppTheme.primaryColor,
                                width: 16,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSendersChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  'Top 10 发件人',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_senderCount.isEmpty)
              const Center(child: Text('暂无数据'))
            else
              ..._senderCount.entries.map((entry) {
                final maxCount = _senderCount.values.reduce((a, b) => a > b ? a : b);
                final percentage = (entry.value / maxCount * 100).round();
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
