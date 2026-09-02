import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Placeholder file explorer tree.
///
/// This is a static, non-functional file tree that gives the IDE a
/// professional look.  A real implementation would integrate with the
/// local filesystem, but for now it shows a representative structure.
class FileTree extends StatefulWidget {
  const FileTree({super.key});

  @override
  State<FileTree> createState() => _FileTreeState();
}

class _FileTreeState extends State<FileTree> {
  final Set<String> _expanded = {'/project', '/project/src'};

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: AppTheme.panelBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.panelBorder, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text('EXPLORER', style: AppTheme.uiLabel),
              ],
            ),
          ),

          // ── Tree ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _buildFolder('/project', 'my_project', 0, children: [
                  _buildFolder('/project/src', 'src', 1, children: [
                    _buildFile('main.py', 1, Icons.description_outlined, AppTheme.success),
                    _buildFile('utils.py', 1, Icons.description_outlined, AppTheme.success),
                    _buildFile('main.cpp', 1, Icons.description_outlined, AppTheme.info),
                    _buildFile('Main.java', 1, Icons.description_outlined, AppTheme.warning),
                  ]),
                  _buildFile('README.md', 1, Icons.article_outlined, AppTheme.textSecondary),
                  _buildFile('.gitignore', 1, Icons.settings_outlined, AppTheme.textMuted),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolder(
    String path,
    String name,
    int depth, {
    List<Widget> children = const [],
  }) {
    final isExpanded = _expanded.contains(path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TreeRow(
          depth: depth,
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expanded.remove(path);
              } else {
                _expanded.add(path);
              }
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_right_rounded,
                size: 16,
                color: AppTheme.textMuted,
              ),
              Icon(
                isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded,
                size: 15,
                color: const Color(0xFFE8B76B),
              ),
              const SizedBox(width: 6),
              Text(name, style: AppTheme.uiTextSmall),
            ],
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(children: children),
          ),
      ],
    );
  }

  Widget _buildFile(String name, int depth, IconData icon, Color color) {
    return _TreeRow(
      depth: depth,
      onTap: () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 16), // indent past the expand arrow
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              style: AppTheme.uiTextSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single row in the file tree with hover highlight.
class _TreeRow extends StatefulWidget {
  final int depth;
  final VoidCallback onTap;
  final Widget child;

  const _TreeRow({
    required this.depth,
    required this.onTap,
    required this.child,
  });

  @override
  State<_TreeRow> createState() => _TreeRowState();
}

class _TreeRowState extends State<_TreeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 26,
          padding: EdgeInsets.only(left: 8.0 + widget.depth * 12),
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.surfaceVariant.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
