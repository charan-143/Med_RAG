import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _emailNotif = true;
  bool _smsNotif = false;
  bool _inAppNotif = true;
  bool _researchConsent = true;
  bool _autoTimeout = false;
  bool _isDark = false;
  bool _saving = false;
  Map<String, dynamic>? _profile;
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _pwCtrl = TextEditingController(text: '••••••••••••');

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await ApiService.getProfile();
      if (mounted) setState(() {
        _profile = p;
        _emailCtrl.text = p['email'] ?? '';
        _nameCtrl.text = p['full_name'] ?? '';
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.updateProfile({
        'email': _emailCtrl.text,
        'full_name': _nameCtrl.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Changes saved.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
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
        title: Text('System Preferences', style: AppTextStyles.headline(18, FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CONFIGURATION',
                    style: AppTextStyles.label(10, AppColors.primary)
                        .copyWith(letterSpacing: 2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Tailor your clinical environment.',
                    style: AppTextStyles.headline(32, FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Manage account security, notifications, and workspace aesthetics.',
                    style: AppTextStyles.body(14, FontWeight.w400, AppColors.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 36),

            // Bento grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account Integrity (left, 8/12)
                Expanded(
                  flex: 8,
                  child: _SettingsCard(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Account Integrity',
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primary.withOpacity(0.06),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _LabelField(
                                    label: 'Professional Email',
                                    child: TextField(
                                      controller: _emailCtrl,
                                      decoration: const InputDecoration(hintText: 'email@domain.med'),
                                      style: AppTextStyles.body(14),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _LabelField(
                                    label: 'Display Name',
                                    child: TextField(
                                      controller: _nameCtrl,
                                      decoration: const InputDecoration(hintText: 'Dr. Name'),
                                      style: AppTextStyles.body(14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                children: [
                                  _LabelField(
                                    label: 'Current Password',
                                    child: TextField(
                                      controller: _pwCtrl,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        suffix: TextButton(
                                          onPressed: () {},
                                          child: Text('Update',
                                              style: AppTextStyles.body(10, FontWeight.w700, AppColors.primary)),
                                        ),
                                      ),
                                      style: AppTextStyles.body(14),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(AppRadius.xl),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.verified_user_outlined,
                                            color: AppColors.primary, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Two-Factor Auth',
                                                  style: AppTextStyles.body(12, FontWeight.w700)),
                                              Text('Enabled via Authenticator App',
                                                  style: AppTextStyles.label(10, AppColors.onSurfaceVariant)),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, size: 18,
                                            color: AppColors.onSurfaceVariant),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Appearance (right, 4/12)
                Expanded(
                  flex: 4,
                  child: _SettingsCard(
                    icon: Icons.palette_outlined,
                    title: 'Atelier Style',
                    iconColor: AppColors.tertiary,
                    iconBg: AppColors.tertiary.withOpacity(0.08),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('INTERFACE THEME',
                            style: AppTextStyles.label(10, AppColors.onSurfaceVariant)
                                .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isDark = false),
                                child: _ThemeChip(
                                    icon: Icons.light_mode_outlined,
                                    label: 'Pristine',
                                    isSelected: !_isDark),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isDark = true),
                                child: _ThemeChip(
                                    icon: Icons.dark_mode_outlined,
                                    label: 'Obsidian',
                                    isSelected: _isDark,
                                    dark: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _LabelField(
                          label: 'System Language',
                          child: DropdownButtonFormField<String>(
                            value: 'English (Medical Standard)',
                            decoration: const InputDecoration(),
                            items: const [
                              DropdownMenuItem(value: 'English (Medical Standard)',
                                  child: Text('English (Medical Standard)')),
                              DropdownMenuItem(value: 'French (Clinical)',
                                  child: Text('French (Clinical)')),
                            ],
                            onChanged: (_) {},
                            style: AppTextStyles.body(13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notifications (5/12)
                Expanded(
                  flex: 5,
                  child: _SettingsCard(
                    icon: Icons.notifications_active_outlined,
                    title: 'Flow Alerts',
                    iconColor: Colors.blue.shade700,
                    iconBg: Colors.blue.shade50,
                    child: Column(
                      children: [
                        _ToggleRow(
                          label: 'Electronic Mail',
                          subtitle: 'Weekly digest and critical alerts',
                          value: _emailNotif,
                          onChanged: (v) => setState(() => _emailNotif = v),
                        ),
                        const SizedBox(height: 12),
                        _ToggleRow(
                          label: 'SMS Mobile Direct',
                          subtitle: 'Urgent patient record changes',
                          value: _smsNotif,
                          onChanged: (v) => setState(() => _smsNotif = v),
                        ),
                        const SizedBox(height: 12),
                        _ToggleRow(
                          label: 'In-App Banner',
                          subtitle: 'Real-time collaboration updates',
                          value: _inAppNotif,
                          onChanged: (v) => setState(() => _inAppNotif = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Security (7/12)
                Expanded(
                  flex: 7,
                  child: _SettingsCard(
                    icon: Icons.shield_outlined,
                    title: 'Security & Consent',
                    iconColor: Colors.orange.shade700,
                    iconBg: Colors.orange.shade50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CONNECTED INSTITUTIONS',
                                  style: AppTextStyles.label(10, AppColors.primary)
                                      .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: [
                                  _InstitutionChip(label: 'St. Jude Medical', icon: Icons.local_hospital_outlined),
                                  _InstitutionChip(label: 'BioPath Labs', icon: Icons.science_outlined),
                                  GestureDetector(
                                    onTap: () {},
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.add, size: 13, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text('Add Provider',
                                              style: AppTextStyles.body(11, FontWeight.w700, AppColors.primary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _CheckRow(
                          label: 'Anonymized Data Research',
                          subtitle: 'Contribute non-identifiable metrics to global Precision Care.',
                          value: _researchConsent,
                          onChanged: (v) => setState(() => _researchConsent = v!),
                        ),
                        const SizedBox(height: 10),
                        _CheckRow(
                          label: 'Automatic Session Timeout',
                          subtitle: 'Log out after 15 minutes of inactivity for HIPAA compliance.',
                          value: _autoTimeout,
                          onChanged: (v) => setState(() => _autoTimeout = v!),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Danger zone
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.xl + 8),
                border: Border.all(color: AppColors.error.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Critical Operations',
                            style: AppTextStyles.headline(16, FontWeight.w700, AppColors.error)),
                        const SizedBox(height: 4),
                        Text('Archiving your profile or resetting encryption keys.',
                            style: AppTextStyles.body(13, FontWeight.w400, AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text('Reset All Data',
                        style: AppTextStyles.body(12, FontWeight.w700, AppColors.error)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {},
                    child: const Text('Deactivate Account'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor, iconBg;
  final Widget child;
  const _SettingsCard({required this.icon, required this.title,
      required this.iconColor, required this.iconBg, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.asymmetricBR,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Text(title, style: AppTextStyles.headline(18, FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 24),
        child,
      ],
    ),
  );
}

class _LabelField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabelField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(),
          style: AppTextStyles.label(9, AppColors.onSurfaceVariant)
              .copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _ToggleRow extends StatelessWidget {
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.subtitle,
      required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.body(13, FontWeight.w700)),
            Text(subtitle, style: AppTextStyles.label(11, AppColors.onSurfaceVariant)),
          ],
        ),
      ),
      Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
    ],
  );
}

class _CheckRow extends StatelessWidget {
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _CheckRow({required this.label, required this.subtitle,
      required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Checkbox(value: value, onChanged: onChanged, activeColor: AppColors.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.body(13, FontWeight.w700)),
            Text(subtitle,
                style: AppTextStyles.label(11, AppColors.onSurfaceVariant)
                    .copyWith(height: 1.4)),
          ],
        ),
      ),
    ],
  );
}

class _ThemeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool dark;
  const _ThemeChip({required this.icon, required this.label,
      required this.isSelected, this.dark = false});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF1A1C1C) : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: Border.all(
        color: isSelected ? AppColors.primary : Colors.transparent,
        width: 2,
      ),
      boxShadow: isSelected
          ? [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 12)]
          : [],
    ),
    child: Column(
      children: [
        Icon(icon, color: dark ? Colors.white54 : AppColors.primary, size: 22),
        const SizedBox(height: 8),
        Text(label, style: AppTextStyles.body(11, FontWeight.w700,
            dark ? Colors.white54 : AppColors.onSurface)),
      ],
    ),
  );
}

class _InstitutionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InstitutionChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.body(12, FontWeight.w500)),
        const SizedBox(width: 8),
        const Icon(Icons.cancel_outlined, size: 13, color: AppColors.error),
      ],
    ),
  );
}
