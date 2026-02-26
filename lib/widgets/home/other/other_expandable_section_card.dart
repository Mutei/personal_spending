import 'package:flutter/material.dart';

class OtherExpandableSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  /// Show the content expanded by default?
  final bool initiallyExpanded;

  /// Optional subtitle under title (ex: “10 categories”)
  final String? subtitle;

  /// Optional right-side badge (ex: number)
  final String? badgeText;

  /// Optional icon on the left
  final IconData? leadingIcon;

  /// Optional padding for the expanded content
  final EdgeInsetsGeometry contentPadding;

  /// Optional margin for the card
  final EdgeInsetsGeometry? margin;

  const OtherExpandableSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
    this.subtitle,
    this.badgeText,
    this.leadingIcon,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Theme(
        // prevents default ExpansionTile divider lines
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('OtherExpandableSectionCard:$title'),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          childrenPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: leadingIcon == null
              ? null
              : Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(leadingIcon, color: cs.primary),
                ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: text.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText!,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          children: [Padding(padding: contentPadding, child: child)],
        ),
      ),
    );
  }
}
