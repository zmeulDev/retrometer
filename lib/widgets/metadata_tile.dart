import 'package:flutter/material.dart';

import 'cards.dart';

/// The shared chrome for the competition / stage / history tiles: a
/// [TappableCard] (read-only when [onTap] is null, e.g. history entries) with
/// standard inner padding, an expanded [child] body, and an optional
/// [trailing] actions column separated by a small gap.
///
/// Previously each tile re-rolled `TappableCard > Padding > Row[Expanded,
/// SizedBox, trailing]`. The bodies differ enough (chips vs info lines vs
/// actions) to stay caller-owned; this widget owns only the chrome.
class MetadataTile extends StatelessWidget {
  const MetadataTile({
    super.key,
    this.onTap,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 12, 12),
  });

  final VoidCallback? onTap;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return TappableCard(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: trailing == null
            ? child
            : Row(
                children: [
                  Expanded(child: child),
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ),
      ),
    );
  }
}