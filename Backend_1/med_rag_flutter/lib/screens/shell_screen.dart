import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../screens/overview/overview_screen.dart';
import '../screens/vault/vault_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/notebook/notebook_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _selected = 0;

  static const _navItems = [
    _NavItem(Icons.dashboard_outlined,    Icons.dashboard,         'Overview'),
    _NavItem(Icons.folder_outlined,        Icons.folder_open,       'Vault'),
    _NavItem(Icons.forum_outlined,         Icons.forum,             'Chat'),
    _NavItem(Icons.edit_note_outlined,     Icons.edit_note,         'Notebook'),
  ];

  final _screens = const [
    OverviewScreen(),
    VaultScreen(),
    ChatScreen(),
    NotebookScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          _Sidebar(
            selected: _selected,
            navItems: _navItems,
            onTap: (i) => setState(() => _selected = i),
          ),
          Expanded(child: _screens[_selected]),
        ],
      ),
    );
  }
}

// ─── Sidebar ───────────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _Sidebar extends StatefulWidget {
  final int selected;
  final List<_NavItem> navItems;
  final ValueChanged<int> onTap;
  const _Sidebar({required this.selected, required this.navItems, required this.onTap});

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  OverlayEntry? _avatarMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryContainer],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.health_and_safety_outlined, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clinical Atelier',
                        style: AppTextStyles.headline(15, FontWeight.w700, AppColors.primaryContainer)),
                    Text('PRECISION HEALTH',
                        style: AppTextStyles.label(9, AppColors.onSurfaceVariant)
                            .copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),

          // ── Nav Items ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: List.generate(widget.navItems.length, (i) {
                  final active = widget.selected == i;
                  final item = widget.navItems[i];
                  return _NavButton(
                    icon: active ? item.activeIcon : item.icon,
                    label: item.label,
                    active: active,
                    onTap: () => widget.onTap(i),
                  );
                }),
              ),
            ),
          ),

          // ── New Record Button ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryContainer],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 12, offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  onPressed: () => _showUploadDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('New Record', style: AppTextStyles.body(13, FontWeight.w600, Colors.white)),
                ),
              ),
            ),
          ),

          // ── Avatar / Profile / Settings ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
            child: Builder(builder: (ctx) => GestureDetector(
              onTap: () => _showAvatarMenu(ctx),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryFixed,
                      child: Text('JT',
                          style: AppTextStyles.body(12, FontWeight.w700, AppColors.primary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Julian Thorne',
                              style: AppTextStyles.body(12, FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                          Text('Patient',
                              style: AppTextStyles.label(10, AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const Icon(Icons.expand_less, size: 16, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  void _showAvatarMenu(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    _avatarMenu?.remove();
    _avatarMenu = OverlayEntry(builder: (_) => Stack(
      children: [
        // Dismiss overlay
        Positioned.fill(child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () { _avatarMenu?.remove(); _avatarMenu = null; },
          child: const SizedBox(),
        )),
        Positioned(
          left: offset.dx + box.size.width,
          bottom: MediaQuery.of(ctx).size.height - offset.dy - box.size.height,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: AppColors.surfaceContainerLowest,
            child: Container(
              width: 180,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MenuTile(
                    icon: Icons.account_circle_outlined,
                    label: 'Profile',
                    onTap: () {
                      _avatarMenu?.remove(); _avatarMenu = null;
                      Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
                    },
                  ),
                  _MenuTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      _avatarMenu?.remove(); _avatarMenu = null;
                      Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ));
    Overlay.of(ctx).insert(_avatarMenu!);
  }

  void _showUploadDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _UploadQuickDialog());
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: active ? AppColors.surfaceContainerLowest.withOpacity(0.7) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 20,
                        color: active ? AppColors.primaryContainer : AppColors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(label,
                        style: AppTextStyles.body(
                          13, FontWeight.w600,
                          active ? AppColors.primaryContainer : AppColors.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              // Active pill
              if (active)
                Positioned(
                  left: 0, top: 8, bottom: 8,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryFixed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
    title: Text(label, style: AppTextStyles.body(13, FontWeight.w500)),
    onTap: onTap,
  );
}

// Quick-launch upload dialog (minimal; full version in vault/upload_dialog.dart)
class _UploadQuickDialog extends StatelessWidget {
  const _UploadQuickDialog();
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: AppRadius.asymmetric,
    title: Text('New Record', style: AppTextStyles.headline(18, FontWeight.w700)),
    content: Text('Open the Vault screen to upload a new medical record.',
        style: AppTextStyles.body(14, FontWeight.w400, AppColors.onSurfaceVariant)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go to Vault')),
    ],
  );
}
