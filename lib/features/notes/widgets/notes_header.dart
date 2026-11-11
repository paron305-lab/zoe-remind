import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/notes/controllers/note_list_logic.dart';
import 'package:zoe_remind/features/notes/widgets/note_styles.dart';

/// Gradient header: "Notes" + sort button + search bar.
/// Sumasampa sa likod ng status bar (gaya ng Home).
class NotesHeader extends StatelessWidget {
  final TextEditingController search;
  final VoidCallback onSortTap;

  const NotesHeader({super.key, required this.search, required this.onSortTap});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: BorderSide.none,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, topInset + 18, 22, 22),
      decoration: const BoxDecoration(gradient: NoteColors.headerGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Notes', style: NoteText.screenTitle)),
              Material(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onSortTap,
                  child: const SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(Icons.sort_rounded, color: Colors.white, size: 28,
                        semanticLabel: 'Sort notes'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ValueListenableBuilder → lalabas ang X kapag may na-type.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: search,
            builder: (context, value, _) => TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              cursorColor: HomeColors.lavender,
              style: NoteText.search,
              decoration: InputDecoration(
                hintText: 'Search your notes…',
                hintStyle: NoteText.searchHint,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 18, right: 8),
                  child: Icon(Icons.search_rounded, color: HomeColors.inkSoft, size: 26),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 52),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded, color: HomeColors.inkSoft),
                        onPressed: search.clear,
                      ),
                filled: true,
                fillColor: NoteColors.searchFill,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                border: border,
                enabledBorder: border,
                focusedBorder: border,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// All / Pinned / From Zoe / Typed — parehong one-tap pattern ng Tasks.
class NoteFilterChips extends StatelessWidget {
  final NoteFilter selected;
  final ValueChanged<NoteFilter> onChanged;

  const NoteFilterChips({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final f in NoteFilter.values) ...[
            Semantics(
              selected: f == selected,
              button: true,
              child: Material(
                color: f == selected ? const Color(0xFF8B7FE0) : HomeColors.lavenderLight,
                borderRadius: BorderRadius.circular(26),
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: () => onChanged(f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Text(
                      f.label,
                      style: NoteText.chip.copyWith(
                        color: f == selected ? Colors.white : const Color(0xFF5E5A85),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (f != NoteFilter.values.last) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}