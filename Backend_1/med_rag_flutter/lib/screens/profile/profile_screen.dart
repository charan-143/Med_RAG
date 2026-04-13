import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final p = await ApiService.getProfile();
      if (mounted) setState(() { _profile = p; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_outlined, color: AppColors.onSurface),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Patient Profile', style: AppTextStyles.headline(18, FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
              child: Column(
                children: [
                  _ProfileHeader(profile: _profile ?? {}),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            _PersonalInfoCard(profile: _profile ?? {}),
                            const SizedBox(height: 20),
                            _EmergencyCard(profile: _profile ?? {}),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right column
                      Expanded(
                        flex: 8,
                        child: Column(
                          children: [
                            _MedicalSummaryRow(profile: _profile ?? {}),
                            const SizedBox(height: 20),
                            _ClinicalCompositionCard(profile: _profile ?? {}),
                            const SizedBox(height: 20),
                            _InsuranceCard(profile: _profile ?? {}),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Stack(
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
            ),
            child: Center(
              child: Text(
                _initials(profile['full_name'] ?? 'JT'),
                style: AppTextStyles.headline(36, FontWeight.w700, AppColors.primaryContainer),
              ),
            ),
          ),
          Positioned(
            right: -2, bottom: -2,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: const Icon(Icons.verified_outlined, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
      const SizedBox(width: 24),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profile['full_name'] ?? 'Patient',
              style: AppTextStyles.headline(30, FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text('Active Patient',
                    style: AppTextStyles.label(11, AppColors.primary)
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Text('Last Visit: Oct 12, 2023',
                  style: AppTextStyles.body(13, FontWeight.w400, AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
      const Spacer(),
      Row(
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.onSurfaceVariant,
                side: BorderSide.none, backgroundColor: AppColors.surfaceContainerHighest),
            onPressed: () {},
            child: const Text('Export File'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: () {}, child: const Text('Edit Profile')),
        ],
      ),
    ],
  );

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }
}

class _PersonalInfoCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _PersonalInfoCard({required this.profile});

  @override
  Widget build(BuildContext context) => _AsymCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Personal Identity', style: AppTextStyles.headline(16, FontWeight.w600)),
            const Icon(Icons.fingerprint, color: AppColors.onSurfaceVariant, size: 22),
          ],
        ),
        const SizedBox(height: 20),
        _InfoRow(label: 'Date of Birth', value: profile['dob'] ?? '—'),
        const SizedBox(height: 14),
        _InfoRow(label: 'Gender Identity', value: profile['gender'] ?? '—'),
        const SizedBox(height: 14),
        _InfoRow(label: 'Blood Type', value: profile['blood_type'] ?? '—', highlight: true),
        const SizedBox(height: 20),
        Divider(color: AppColors.outlineVariant.withOpacity(0.15)),
        const SizedBox(height: 14),
        Row(children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
              child: const Icon(Icons.call_outlined, size: 16, color: AppColors.onSurfaceVariant)),
          const SizedBox(width: 10),
          Text(profile['phone'] ?? '—',
              style: AppTextStyles.body(13, FontWeight.w500)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
              child: const Icon(Icons.mail_outlined, size: 16, color: AppColors.onSurfaceVariant)),
          const SizedBox(width: 10),
          Text(profile['email'] ?? '—',
              style: AppTextStyles.body(13, FontWeight.w500)),
        ]),
      ],
    ),
  );
}

class _EmergencyCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _EmergencyCard({required this.profile});

  @override
  Widget build(BuildContext context) => _AsymCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Emergency Nexus', style: AppTextStyles.headline(16, FontWeight.w600)),
        const SizedBox(height: 16),
        if (profile['emergency_name'] != null)
          _EmerContact(
              name: profile['emergency_name'] ?? '', rel: profile['emergency_rel'] ?? '',
              phone: profile['emergency_phone'] ?? ''),
        const SizedBox(height: 12),
        _EmerContact(name: 'Dr. Elena Ross', rel: 'GP', phone: '+1 (555) 998-0021',
            isGP: true),
      ],
    ),
  );
}

class _EmerContact extends StatelessWidget {
  final String name, rel, phone;
  final bool isGP;
  const _EmerContact({required this.name, required this.rel, required this.phone, this.isGP = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: AppTextStyles.body(13, FontWeight.w700)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isGP ? AppColors.primaryFixed : AppColors.tertiaryFixed,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(rel,
                  style: AppTextStyles.label(9, isGP ? AppColors.onPrimaryFixedVar : AppColors.onTertiaryFixedVar)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(phone, style: AppTextStyles.body(12, FontWeight.w400, AppColors.onSurfaceVariant)),
      ],
    ),
  );
}

class _MedicalSummaryRow extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _MedicalSummaryRow({required this.profile});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _StatChip(label: 'Chronic Balance', value: '02', unit: 'Conditions',
          accentColor: AppColors.primary)),
      const SizedBox(width: 16),
      Expanded(child: _StatChip(label: 'Immune Alerts', value: '01', unit: 'Allergy',
          accentColor: AppColors.tertiary)),
      const SizedBox(width: 16),
      Expanded(child: _StatChip(label: 'Active Scripts', value: '03', unit: 'Medications',
          accentColor: Colors.blue.shade300)),
    ],
  );
}

class _StatChip extends StatelessWidget {
  final String label, value, unit;
  final Color accentColor;
  const _StatChip({required this.label, required this.value, required this.unit, required this.accentColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.asymmetricBR,
      border: Border(left: BorderSide(color: accentColor, width: 4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: AppTextStyles.label(9, AppColors.onSurfaceVariant)
                .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppTextStyles.headline(24, FontWeight.w700,
                accentColor == AppColors.tertiary ? AppColors.tertiary : AppColors.onSurface)),
            const SizedBox(width: 4),
            Text(unit, style: AppTextStyles.body(11, FontWeight.w400, AppColors.onSurfaceVariant)),
          ],
        ),
      ],
    ),
  );
}

class _ClinicalCompositionCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ClinicalCompositionCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final meds = (profile['medications'] ?? 'Lisinopril 10mg, Metformin 500mg')
        .toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final conditions = (profile['conditions'] ?? 'Hypertension (Stage 1), Type 2 Diabetes')
        .toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final allergies = (profile['allergies'] ?? 'Penicillin')
        .toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return _AsymCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Clinical Composition', style: AppTextStyles.headline(18, FontWeight.w700)),
          const SizedBox(height: 20),
          // Medications
          Row(children: [
            const Icon(Icons.medication_outlined, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text('ACTIVE MEDICATIONS',
                style: AppTextStyles.label(10, AppColors.onSurfaceVariant)
                    .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: meds.map((m) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Text(m, style: AppTextStyles.body(13, FontWeight.w600)),
            )).toList(),
          ),
          const SizedBox(height: 24),
          // Allergies + Conditions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.warning_amber_outlined, color: AppColors.tertiary, size: 18),
                      const SizedBox(width: 8),
                      Text('CRITICAL ALLERGIES',
                          style: AppTextStyles.label(10, AppColors.onSurfaceVariant)
                              .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    ...allergies.map((a) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixed.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.tertiaryFixed),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.medication_outlined, color: AppColors.tertiary, size: 16),
                          const SizedBox(width: 8),
                          Text(a, style: AppTextStyles.body(13, FontWeight.w700, AppColors.onTertiaryFixedVar)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.description_outlined, size: 18, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('CHRONIC STATUS',
                          style: AppTextStyles.label(10, AppColors.onSurfaceVariant)
                              .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    ...conditions.map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c, style: AppTextStyles.body(13, FontWeight.w600)),
                          const Icon(Icons.chevron_right, size: 16,
                              color: AppColors.onSurfaceVariant),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsuranceCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _InsuranceCard({required this.profile});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1C1C),
      borderRadius: AppRadius.asymmetricBR,
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Financial Coverage',
                  style: AppTextStyles.headline(16, FontWeight.w700, Colors.white)),
              const SizedBox(height: 20),
              Row(children: [
                _InsChip(label: 'Provider', value: profile['insurance_provider'] ?? 'BlueShield'),
                const SizedBox(width: 20),
                _InsChip(label: 'Policy ID', value: profile['insurance_policy'] ?? 'BS-882-9910-X'),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _InsBox(label: 'Group No.', value: '7728-A'),
                const SizedBox(width: 12),
                _InsBox(label: 'Expiry', value: '12/2025'),
              ]),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 56, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.contactless_outlined, color: Colors.white60, size: 20),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Verified Coverage',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ],
        ),
      ],
    ),
  );
}

class _InsChip extends StatelessWidget {
  final String label, value;
  const _InsChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(),
          style: const TextStyle(color: Colors.white38, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      const SizedBox(height: 2),
      Text(value, style: AppTextStyles.headline(14, FontWeight.w600, Colors.white)),
    ],
  );
}

class _InsBox extends StatelessWidget {
  final String label, value;
  const _InsBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(color: Colors.white38, fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13,
            fontWeight: FontWeight.w700, letterSpacing: 2)),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _InfoRow({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(),
          style: AppTextStyles.label(9, AppColors.onSurfaceVariant)
              .copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      highlight
          ? Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Text(value,
                    style: AppTextStyles.body(12, FontWeight.w700, AppColors.error))),
              ),
              const SizedBox(width: 10),
              Text('Rhesus Positive', style: AppTextStyles.body(13, FontWeight.w500)),
            ])
          : Text(value, style: AppTextStyles.body(13, FontWeight.w500)),
    ],
  );
}

class _AsymCard extends StatelessWidget {
  final Widget child;
  const _AsymCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.asymmetricBR,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16)],
    ),
    child: child,
  );
}
