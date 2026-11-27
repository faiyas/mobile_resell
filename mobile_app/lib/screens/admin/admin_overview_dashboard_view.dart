import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../widgets/glass_container.dart';
import 'admin_sidebar_drawer.dart';

class AdminOverviewDashboardView extends StatefulWidget {
  final List<SaleOrderModel> orders;
  final List<AgentUserModel> agents;
  final VoidCallback onRefresh;
  final Function(AdminNavSection) onNavigateSection;

  const AdminOverviewDashboardView({
    super.key,
    required this.orders,
    required this.agents,
    required this.onRefresh,
    required this.onNavigateSection,
  });

  @override
  State<AdminOverviewDashboardView> createState() => _AdminOverviewDashboardViewState();
}

class _AdminOverviewDashboardViewState extends State<AdminOverviewDashboardView> {
  String _trendMetric = 'sales'; // 'sales' | 'payouts'

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;
    final totalSales = orders.length;
    final paidOrders = orders.where((o) => o.status == 'PAYMENT_COMPLETED').toList();
    final totalDisbursed = paidOrders.fold<double>(0.0, (sum, o) => sum + (o.finalPrice ?? o.estimatedPrice));
    final awaitingPayout = orders.where((o) => ['OWNERSHIP_TRANSFERRED', 'CUSTOMER_ACCEPTED'].contains(o.status)).length;
    final pendingPickups = orders.where((o) => ['SUBMITTED', 'PICKUP_SCHEDULED', 'PICKED_UP', 'INSPECTION_PENDING'].contains(o.status)).length;

    // Category breakdown
    int mobileCount = 0;
    int tabletCount = 0;
    int laptopCount = 0;
    int watchCount = 0;

    for (var o in orders) {
      final name = '${o.brandName} ${o.modelName}'.toLowerCase();
      if (name.contains('tab') || name.contains('pad')) {
        tabletCount++;
      } else if (name.contains('mac') || name.contains('book') || name.contains('laptop')) {
        laptopCount++;
      } else if (name.contains('watch')) {
        watchCount++;
      } else {
        mobileCount++;
      }
    }

    final totalCat = math.max(1, totalSales);
    final mobilePct = (mobileCount / totalCat * 100).round();
    final tabletPct = (tabletCount / totalCat * 100).round();
    final laptopPct = (laptopCount / totalCat * 100).round();
    final watchPct = math.max(0, 100 - (mobilePct + tabletPct + laptopPct));

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: AppTheme.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Banner Welcome Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'OPERATIONS DESK',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Overview Dashboard',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
                onPressed: widget.onRefresh,
                tooltip: 'Refresh data',
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Key Metrics 4-Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Sales',
                  value: '$totalSales',
                  icon: Icons.shopping_bag_outlined,
                  color: AppTheme.primaryGreen,
                  onTap: () => widget.onNavigateSection(AdminNavSection.operations),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: 'Pending Pickups',
                  value: '$pendingPickups',
                  icon: Icons.local_shipping_outlined,
                  color: Colors.orange.shade700,
                  onTap: () => widget.onNavigateSection(AdminNavSection.operations),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Awaiting Payout',
                  value: '$awaitingPayout',
                  icon: Icons.pending_actions_rounded,
                  color: Colors.amber.shade800,
                  onTap: () => widget.onNavigateSection(AdminNavSection.payouts),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Disbursed',
                  value: '₹${totalDisbursed.toStringAsFixed(0)}',
                  icon: Icons.check_circle_outline_rounded,
                  color: Colors.teal.shade700,
                  onTap: () => widget.onNavigateSection(AdminNavSection.payoutHistory),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Sales Trend Chart Card
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.trending_up_rounded, color: AppTheme.primaryGreen, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Sales & Payout Trend',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    // Toggle sales / payouts
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          _buildTrendToggle('Sales', 'sales'),
                          _buildTrendToggle('Payouts', 'payouts'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _TrendLinePainter(
                      dataPoints: _trendMetric == 'sales'
                          ? [2.0, 1.0, 3.0, 4.0, 3.0, 5.0, math.max(3.0, totalSales.toDouble())]
                          : [0.0, 0.0, 1.0, 2.0, 1.0, 3.0, paidOrders.length.toDouble()],
                      lineColor: _trendMetric == 'sales' ? AppTheme.primaryGreen : Colors.teal.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('17 Nov', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    Text('19 Nov', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    Text('21 Nov', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    Text('Today', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Sales by Category Donut Card
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sales by Category',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                    ),
                    Text(
                      '$totalSales Total Devices',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Donut Canvas
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(
                        painter: _CategoryDonutPainter(
                          mobilePct: mobilePct / 100.0,
                          tabletPct: tabletPct / 100.0,
                          laptopPct: laptopPct / 100.0,
                          watchPct: watchPct / 100.0,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$totalSales',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.textPrimary),
                              ),
                              const Text(
                                'TOTAL',
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Legend
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCategoryLegend('Mobile', '$mobilePct%', AppTheme.primaryGreen, mobileCount),
                          const SizedBox(height: 8),
                          _buildCategoryLegend('Tablet', '$tabletPct%', const Color(0xFF10B981), tabletCount),
                          const SizedBox(height: 8),
                          _buildCategoryLegend('Laptop', '$laptopPct%', Colors.blueGrey.shade400, laptopCount),
                          const SizedBox(height: 8),
                          _buildCategoryLegend('Smartwatch', '$watchPct%', Colors.grey.shade400, watchCount),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Quick Actions Row
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Quick Actions',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionBtn(
                  icon: Icons.price_change_outlined,
                  label: 'Update Prices',
                  color: Colors.amber.shade700,
                  onTap: () => widget.onNavigateSection(AdminNavSection.catalog),
                ),
                const SizedBox(width: 10),
                _buildQuickActionBtn(
                  icon: Icons.quiz_outlined,
                  label: 'Edit Triage',
                  color: Colors.blue.shade700,
                  onTap: () => widget.onNavigateSection(AdminNavSection.triage),
                ),
                const SizedBox(width: 10),
                _buildQuickActionBtn(
                  icon: Icons.calculate_outlined,
                  label: 'Simulator',
                  color: Colors.purple.shade700,
                  onTap: () => widget.onNavigateSection(AdminNavSection.simulator),
                ),
                const SizedBox(width: 10),
                _buildQuickActionBtn(
                  icon: Icons.image_outlined,
                  label: 'Hero Banners',
                  color: Colors.teal.shade700,
                  onTap: () => widget.onNavigateSection(AdminNavSection.cms),
                ),
                const SizedBox(width: 10),
                _buildQuickActionBtn(
                  icon: Icons.people_outline_rounded,
                  label: 'Customers',
                  color: AppTheme.primaryGreen,
                  onTap: () => widget.onNavigateSection(AdminNavSection.customers),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Recent Activities Feed
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Activities',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                    ),
                    InkWell(
                      onTap: () => widget.onNavigateSection(AdminNavSection.operations),
                      child: const Text(
                        'View All →',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryGreen),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No activities recorded yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                  )
                else
                  ...orders.take(5).map((order) {
                    final isPaid = order.status == 'PAYMENT_COMPLETED';
                    final isScheduled = order.status == 'PICKUP_SCHEDULED';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? Colors.green.shade50
                                  : (isScheduled ? Colors.orange.shade50 : Colors.purple.shade50),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPaid
                                  ? Icons.currency_rupee_rounded
                                  : (isScheduled ? Icons.inventory_2_outlined : Icons.receipt_long_outlined),
                              size: 16,
                              color: isPaid
                                  ? Colors.green.shade700
                                  : (isScheduled ? Colors.orange.shade700 : Colors.purple.shade700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPaid
                                      ? 'Payment disbursed for ${order.brandName} ${order.modelName}'
                                      : (isScheduled
                                          ? 'Pickup scheduled for ${order.brandName}'
                                          : 'New order ${order.saleCode} submitted'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'TXN #${order.saleCode} · ${order.status.replaceAll('_', ' ')}',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${(order.finalPrice ?? order.estimatedPrice).toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.primaryGreen),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTrendToggle(String label, String key) {
    final isSelected = _trendMetric == key;
    return InkWell(
      onTap: () => setState(() => _trendMetric = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryLegend(String label, String pct, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
        ),
        Text(
          '$count ($pct)',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<double> dataPoints;
  final Color lineColor;

  _TrendLinePainter({required this.dataPoints, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final maxVal = dataPoints.reduce(math.max);
    final minVal = dataPoints.reduce(math.min);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (dataPoints.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < dataPoints.length; i++) {
      final normalizedY = 1.0 - ((dataPoints[i] - minVal) / range);
      final x = i * stepX;
      final y = 10.0 + (normalizedY * (size.height - 20.0));
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final ctrlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(ctrlX, p0.dy, ctrlX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(ctrlX, p0.dy, ctrlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    // Fill gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [lineColor.withValues(alpha: 0.25), lineColor.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke path
    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // Draw dots
    final dotPaint = Paint()..color = lineColor;
    final dotInner = Paint()..color = Colors.white;

    for (final p in points) {
      canvas.drawCircle(p, 4.0, dotPaint);
      canvas.drawCircle(p, 2.0, dotInner);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) => true;
}

class _CategoryDonutPainter extends CustomPainter {
  final double mobilePct;
  final double tabletPct;
  final double laptopPct;
  final double watchPct;

  _CategoryDonutPainter({
    required this.mobilePct,
    required this.tabletPct,
    required this.laptopPct,
    required this.watchPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    final paintBg = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, paintBg);

    double startAngle = -math.pi / 2;

    void drawSegment(double pct, Color color) {
      if (pct <= 0) return;
      final sweepAngle = pct * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    drawSegment(mobilePct, AppTheme.primaryGreen);
    drawSegment(tabletPct, const Color(0xFF10B981));
    drawSegment(laptopPct, Colors.blueGrey.shade400);
    drawSegment(watchPct, Colors.grey.shade400);
  }

  @override
  bool shouldRepaint(covariant _CategoryDonutPainter oldDelegate) => true;
}
