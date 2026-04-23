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
          Container(
            width: 88, // Narrow rail width
            color: AppColors.surfaceContainer,
            child: Column(
              children: [
                Expanded(
                  child: NavigationRail(
                    extended: false,
                    labelType: NavigationRailLabelType.none,
                    backgroundColor: AppColors.surfaceContainer,
                    selectedIndex: _selected,
                    onDestinationSelected: (i) => setState(() => _selected = i),
                    // Logo Header
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Container(
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
                    ),
                    // Navigation Links
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('Overview'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.folder_outlined),
                        selectedIcon: Icon(Icons.folder_open),
                        label: Text('Vault'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.forum_outlined),
                        selectedIcon: Icon(Icons.forum),
                        label: Text('Chat'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.edit_note_outlined),
                        selectedIcon: Icon(Icons.edit_note),
                        label: Text('Notebook'),
                      ),
                    ],
                  ),
                ),
                // Profile Bottom Button (Anchored manually safely at bottom of parent column)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: const _AvatarButton(),
                ),
              ],
            ),
          ),
          Expanded(child: _screens[_selected]),
        ],
      ),
    );
  }
}

// ─── Avatar Profile Button ───────────────────────────────────────────────────
class _AvatarButton extends StatefulWidget {
  const _AvatarButton();

  @override
  State<_AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<_AvatarButton> {
  OverlayEntry? _avatarMenu;

  void _showAvatarMenu(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    _avatarMenu?.remove();
    _avatarMenu = OverlayEntry(builder: (_) => Stack(
      children: [
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAvatarMenu(context),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryFixed,
          child: Text('JT',
              style: AppTextStyles.body(12, FontWeight.w700, AppColors.primary)),
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

