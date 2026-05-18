import 'dart:math';
import 'package:flutter/material.dart';

class CategoryAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final List<String> allCategories;
  final String labelText;
  final String hintText;
  final int maxOptions;

  const CategoryAutocompleteField({
    super.key,
    required this.controller,
    required this.allCategories,
    this.focusNode,
    this.labelText = "Category (optional)",
    this.hintText = "Start typing…",
    this.maxOptions = 8,
  });

  @override
  State<CategoryAutocompleteField> createState() =>
      _CategoryAutocompleteFieldState();
}

class _CategoryAutocompleteFieldState extends State<CategoryAutocompleteField> {
  final LayerLink _link = LayerLink();
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  OverlayEntry? _entry;

  List<String> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant CategoryAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
    }
  }

  void _handleFocus() {
    if (_focusNode.hasFocus) {
      _recomputeAndShow();
    } else {
      _removeOverlay();
    }
  }

  void _handleTextChanged() {
    if (_focusNode.hasFocus) _recomputeAndShow();
  }

  void _recomputeAndShow() {
    final q = widget.controller.text.trim().toLowerCase();

    if (q.isEmpty) {
      _filtered = const [];
      _removeOverlay();
      return;
    }

    final starts = widget.allCategories
        .where((c) => c.toLowerCase().startsWith(q))
        .toList();

    final contains = widget.allCategories
        .where(
          (c) => !c.toLowerCase().startsWith(q) && c.toLowerCase().contains(q),
        )
        .toList();

    _filtered = [...starts, ...contains].take(widget.maxOptions).toList();

    if (_filtered.isEmpty) {
      _removeOverlay();
      return;
    }

    _showOverlay();
  }

  void _showOverlay() {
    _removeOverlay();

    _entry = OverlayEntry(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;

        // Available height above keyboard
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final screenH = MediaQuery.of(context).size.height;
        final safeTop = MediaQuery.of(context).padding.top;

        // We'll place the dropdown BELOW the field by default,
        // but if keyboard is covering, we'll flip ABOVE the field.
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _removeOverlay,
            child: Stack(
              children: [
                CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  offset: const Offset(0, 56), // below the field (approx)
                  child: Material(
                    color: Colors.transparent,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Max height of list (avoid keyboard)
                        final maxH = max(
                          120.0,
                          screenH - bottomInset - safeTop - 220,
                        ).clamp(120.0, 260.0);

                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                            maxHeight: maxH,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: cs.outlineVariant.withOpacity(0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.shadow.withOpacity(0.12),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shrinkWrap: true,
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: cs.outlineVariant.withOpacity(0.35),
                              ),
                              itemBuilder: (context, i) {
                                final opt = _filtered[i];
                                return InkWell(
                                  onTap: () {
                                    widget.controller.text = opt;
                                    widget.controller.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(offset: opt.length),
                                        );
                                    _removeOverlay();
                                    _focusNode.unfocus();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.search_rounded,
                                          size: 18,
                                          color: cs.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            opt,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_handleFocus);
    widget.controller.removeListener(_handleTextChanged);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _focusNode.unfocus(),
      ),
    );
  }
}
