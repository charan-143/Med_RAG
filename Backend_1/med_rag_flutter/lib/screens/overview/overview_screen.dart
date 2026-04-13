import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});
  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ApiService.getOverviewStats();
      if (mounted) setState(() { _stats = s; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(onRefresh: _load),
                  const SizedBox(height: 32),
                  _BentoGrid(stats: _stats ?? {}),
                  const SizedBox(height: 40),
                  _ClinicalInsightsSection(),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PATIENT DASHBOARD',
                style: AppTextStyles.label(10, AppColors.onSurfaceVariant)
                    .copyWith(letterSpacing: 2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Precision Overview',
                style: AppTextStyles.headline(32, FontWeight.w700)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(_today(), style: AppTextStyles.body(13, FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_outlined, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  String _today() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

class _BentoGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _BentoGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats['total_records'] ?? 0;
    final byType = (stats['by_type'] as Map<String, dynamic>?) ?? {};
    final recent = (stats['recent_files'] as List?) ?? [];

    return Column(
      children: [
        // Row 1: Total Records + Vitals
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: _TotalRecordsCard(total: total),
            ),
            const SizedBox(width: 24),
            const Expanded(flex: 8, child: _VitalsCard()),
          ],
        ),
        const SizedBox(height: 24),
        // Row 2: Distribution chart + Recent
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _DistributionCard(byType: byType)),
            const SizedBox(width: 24),
            Expanded(flex: 5, child: _RecentArchivesCard(recent: recent)),
          ],
        ),
      ],
    );
  }
}

class _TotalRecordsCard extends StatelessWidget {
  final int total;
  const _TotalRecordsCard({required this.total});

  @override
  Widget build(BuildContext context) => _BaseCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(Icons.description_outlined, color: AppColors.onPrimaryFixedVar),
            ),
            Text('+12% Monthly',
                style: AppTextStyles.body(11, FontWeight.w700, AppColors.tertiary)),
          ],
        ),
        const SizedBox(height: 16),
        Text('TOTAL RECORDS',
            style: AppTextStyles.label(10, AppColors.onSurfaceVariant)
                .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('$total',
            style: AppTextStyles.headline(52, FontWeight.w700, AppColors.primary)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 0.72,
            minHeight: 6,
            backgroundColor: AppColors.surfaceContainerHigh,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text('Vault capacity at 72%',
            style: AppTextStyles.label(10, AppColors.onSurfaceVariant)),
      ],
    ),
  );
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard();

  @override
  Widget build(BuildContext context) => _BaseCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Vitals', style: AppTextStyles.headline(18, FontWeight.w600)),
            TextButton(
              onPressed: () {},
              child: Text('Full Report',
                  style: AppTextStyles.body(13, FontWeight.w600, AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _VitalTile(icon: Icons.favorite_outline, label: 'Heart Rate',
                value: '72', unit: 'BPM', color: AppColors.tertiary)),
            const SizedBox(width: 16),
            Expanded(child: _VitalTile(icon: Icons.monitor_heart_outlined, label: 'Blood Pressure',
                value: '120/80', unit: 'mmHg', color: AppColors.primary)),
            const SizedBox(width: 16),
            Expanded(child: _VitalTile(icon: Icons.thermostat_outlined, label: 'Temperature',
                value: '98.6', unit: '°F', color: AppColors.onPrimaryFixedVar)),
          ],
        ),
      ],
    ),
  );
}

class _VitalTile extends StatelessWidget {
  final IconData icon;
  final String label, value, unit;
  final Color color;
  const _VitalTile({required this.icon, required this.label,
      required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 10),
        Text(label.toUpperCase(),
            style: AppTextStyles.label(9, AppColors.onSurfaceVariant)
                .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppTextStyles.headline(26, FontWeight.w700)),
            const SizedBox(width: 4),
            Text(unit, style: AppTextStyles.body(11, FontWeight.w400, AppColors.onSurfaceVariant)),
          ],
        ),
      ],
    ),
  );
}

class _DistributionCard extends StatelessWidget {
  final Map<String, dynamic> byType;
  const _DistributionCard({required this.byType});

  static const _labels = ['PDF', 'IMAGE', 'DICOM', 'REPORT', 'OTHER'];
  static const _colors = [AppColors.primary, AppColors.primaryFixedDim,
      AppColors.tertiaryFixed, AppColors.tertiary, AppColors.surfaceContainerHigh];

  @override
  Widget build(BuildContext context) {
    final total = byType.values.fold<num>(0, (a, b) => a + (b as num));
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Record Distribution', style: AppTextStyles.headline(18, FontWeight.w600)),
          Text('Categorized by type', style: AppTextStyles.body(13, FontWeight.w400, AppColors.onSurfaceVariant)),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: byType.isEmpty
                  ? _emptyBars()
                  : byType.entries.toList().asMap().entries.map((e) {
                      final pct = total > 0 ? (e.value.value as num) / total : 0.0;
                      final color = _colors[e.key % _colors.length];
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: pct.toDouble().clamp(0.05, 1.0),
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                e.value.key.toString().toUpperCase(),
                                style: AppTextStyles.label(8, AppColors.onSurfaceVariant)
                                    .copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _emptyBars() => _labels.asMap().entries.map((e) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: FractionallySizedBox(
              heightFactor: [0.65, 0.45, 0.85, 0.30, 0.55][e.key],
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: _colors[e.key % _colors.length],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(e.value, style: AppTextStyles.label(8, AppColors.onSurfaceVariant)
              .copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  )).toList();
}

class _RecentArchivesCard extends StatelessWidget {
  final List recent;
  const _RecentArchivesCard({required this.recent});

  @override
  Widget build(BuildContext context) => _BaseCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Archives', style: AppTextStyles.headline(18, FontWeight.w600)),
        const SizedBox(height: 20),
        ...recent.take(4).map((f) => _RecentEntry(file: f)).toList(),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No records yet',
                  style: AppTextStyles.body(13, FontWeight.w400, AppColors.onSurfaceVariant)),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: () {},
            child: Text('View All Archives',
                style: AppTextStyles.body(13, FontWeight.w600, AppColors.onSurfaceVariant)),
          ),
        ),
      ],
    ),
  );
}

class _RecentEntry extends StatelessWidget {
  final Map<String, dynamic> file;
  const _RecentEntry({required this.file});

  @override
  Widget build(BuildContext context) {
    final type = file['file_type'] ?? 'pdf';
    final icon = type == 'image' ? Icons.image_outlined : Icons.description_outlined;
    final color = type == 'image' ? AppColors.tertiary : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceContainerHigh,
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file['ai_name'] ?? file['original_name'] ?? 'Unknown',
                    style: AppTextStyles.body(12, FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(file['file_type'] ?? '',
                    style: AppTextStyles.label(10, AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Text(_ago(file['uploaded_at']),
              style: AppTextStyles.label(9, AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _ago(String? ts) {
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ClinicalInsightsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Clinical Insights', style: AppTextStyles.headline(22, FontWeight.w700)),
            const SizedBox(width: 16),
            Expanded(child: Divider(color: AppColors.outlineVariant.withOpacity(0.15))),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.tertiaryFixed.withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.priority_high, color: AppColors.tertiary),
                    const SizedBox(height: 12),
                    Text('Annual Screen Pending',
                        style: AppTextStyles.headline(14, FontWeight.w700, AppColors.onTertiaryFixedVar)),
                    const SizedBox(height: 6),
                    Text('Your metabolic profile requires an update. Schedule your panel to maintain precision tracking.',
                        style: AppTextStyles.body(12, FontWeight.w400, AppColors.onTertiaryFixedVar)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _BaseCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Medication Adherence', style: AppTextStyles.headline(14, FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('All treatments are synchronized with your biometric data.',
                        style: AppTextStyles.body(12, FontWeight.w400, AppColors.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 16),
                          const SizedBox(width: 8),
                          Text('Stable Baseline',
                              style: AppTextStyles.body(12, FontWeight.w700, AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _BaseCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.primary, size: 32),
                    const SizedBox(height: 12),
                    Text('Secure Vault', style: AppTextStyles.headline(14, FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Your data is encrypted with 256-bit clinical-grade security.',
                        style: AppTextStyles.body(12, FontWeight.w400, AppColors.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Manage Encryption',
                            style: AppTextStyles.body(11, FontWeight.w700, AppColors.primary)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Shared base card ──────────────────────────────────────────────────────────
class _BaseCard extends StatelessWidget {
  final Widget child;
  const _BaseCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.asymmetricBR,
      boxShadow: [
        BoxShadow(
          color: AppColors.onSurface.withOpacity(0.04),
          blurRadius: 24, offset: const Offset(0, 4),
        )
      ],
    ),
    child: child,
  );
}
