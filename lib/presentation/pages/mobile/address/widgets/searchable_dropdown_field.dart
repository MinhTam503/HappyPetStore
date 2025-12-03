import 'package:flutter/material.dart';
import 'package:pet_shop/core/constants/app_constants.dart';

/// A form-friendly, searchable dropdown that shows a bottom sheet for selection.
/// - Fully supports validator via FormField.
/// - Vietnamese-friendly search (case-insensitive with basic diacritic folding).
class SearchableDropdownField extends FormField<String> {
  SearchableDropdownField({
    super.key,
    super.initialValue,
    required this.labelText,
    this.hintText,
    required this.items,
    required this.onChanged,
    super.enabled = true,
    this.prefixIcon,
    super.validator,
  }) : super(
          builder: (state) {
            final field = state as _SearchableDropdownFieldState;
            return _SearchableDropdownFieldView(
              labelText: labelText,
              hintText: hintText,
              value: state.value,
              enabled: (state.widget as SearchableDropdownField).enabled,
              prefixIcon: prefixIcon,
              errorText: state.errorText,
              onTap: () => field._openBottomSheet(state.context),
              clearValue: () => state.didChange(null),
            );
          },
        );

  final String labelText;
  final String? hintText;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData? prefixIcon;

  @override
  FormFieldState<String> createState() => _SearchableDropdownFieldState();
}

class _SearchableDropdownFieldState extends FormFieldState<String> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openBottomSheet(BuildContext context) async {
    final widget = this.widget as SearchableDropdownField;
    if (!widget.enabled) return;
    _searchController.text = '';

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final bottomPadding = media.viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: StatefulBuilder(
            builder: (context, sheetSetState) => DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: widget.hintText ?? 'Tìm kiếm...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onChanged: (_) => sheetSetState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            tooltip: 'Đóng',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _SearchList(
                        allItems: widget.items,
                        query: _searchController.text,
                        onSelect: (val) => Navigator.pop(context, val),
                        controller: scrollController,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (selected != null) {
      didChange(selected);
      (widget).onChanged(selected);
    }
  }
}

class _SearchableDropdownFieldView extends StatelessWidget {
  const _SearchableDropdownFieldView({
    required this.labelText,
    required this.hintText,
    required this.value,
    required this.enabled,
    required this.prefixIcon,
    required this.errorText,
    required this.onTap,
    required this.clearValue,
  });

  final String labelText;
  final String? hintText;
  final String? value;
  final bool enabled;
  final IconData? prefixIcon;
  final String? errorText;
  final VoidCallback onTap;
  final VoidCallback clearValue;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));
    final labelStyle = TextStyle(color: enabled ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7) : Theme.of(context).colorScheme.onSurface.withOpacity(0.5));

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: labelStyle,
          border: border,
          enabledBorder: border,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          errorText: errorText,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                IconButton(
                  tooltip: 'Xóa chọn',
                  onPressed: enabled ? clearValue : null,
                  icon: const Icon(Icons.clear, size: 20),
                ),
              Icon(
                Icons.arrow_drop_down,
                color: enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
        isEmpty: value == null || value!.isEmpty,
        child: Text(
          value ?? (hintText ?? ''),
          style: TextStyle(
            color: enabled
                ? (value == null ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6) : Theme.of(context).colorScheme.onSurface)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _SearchList extends StatelessWidget {
  const _SearchList({
    required this.allItems,
    required this.query,
    required this.onSelect,
    required this.controller,
  });

  final List<String> allItems;
  final String query;
  final ValueChanged<String> onSelect;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final q = _fold(query);
    final filtered = allItems
        .where((e) => _fold(e).contains(q))
        .toList(growable: false);

    return ListView.separated(
      controller: controller,
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final item = filtered[idx];
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          title: Text(item),
          onTap: () => onSelect(item),
        );
      },
    );
  }

  // Basic Vietnamese diacritic folding for more forgiving search
  String _fold(String input) {
    final lower = input.toLowerCase();
    final noDiacritics = lower
        .replaceAll(RegExp(r"[àáạảãâầấậẩẫăằắặẳẵ]"), 'a')
        .replaceAll(RegExp(r"[èéẹẻẽêềếệểễ]"), 'e')
        .replaceAll(RegExp(r"[ìíịỉĩ]"), 'i')
        .replaceAll(RegExp(r"[òóọỏõôồốộổỗơờớợởỡ]"), 'o')
        .replaceAll(RegExp(r"[ùúụủũưừứựửữ]"), 'u')
        .replaceAll(RegExp(r"[ỳýỵỷỹ]"), 'y')
        .replaceAll(RegExp(r"[đ]"), 'd');
    // Remove spaces and punctuation for more flexible matching (e.g., "ha" -> "hanoi")
    return noDiacritics.replaceAll(RegExp(r"[^a-z0-9]"), '');
  }
}
