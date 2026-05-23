import 'package:flutter/material.dart';

final class PromptSuggestion {
  const PromptSuggestion({
    required this.label,
    required this.prompt,
    required this.icon,
  });

  final String label;
  final String prompt;
  final IconData icon;
}

const promptSuggestions = [
  PromptSuggestion(
    label: 'Build day plan',
    icon: Icons.route_outlined,
    prompt:
        'Create a rainy afternoon Montreal itinerary under \$50. Render an ItineraryPlan, one ActivityCard, and a short Checklist.',
  ),
  PromptSuggestion(
    label: 'Compare options',
    icon: Icons.compare_arrows,
    prompt:
        'Give me three low-cost indoor activity options and render a ChoicePicker so I can choose one.',
  ),
  PromptSuggestion(
    label: 'Prep checklist',
    icon: Icons.checklist,
    prompt:
        'Make a practical preparation checklist for a beginner-friendly Saturday city walk.',
  ),
  PromptSuggestion(
    label: 'Ask questions first',
    icon: Icons.help_outline,
    prompt:
        'Ask me two concise questions in a ChoicePicker before suggesting activities.',
  ),
];

class PromptSuggestionBar extends StatelessWidget {
  const PromptSuggestionBar({
    super.key,
    required this.isProcessing,
    required this.onPromptSelected,
  });

  final bool isProcessing;
  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final suggestion in promptSuggestions)
          ActionChip(
            avatar: Icon(suggestion.icon, size: 18),
            label: Text(suggestion.label),
            onPressed: isProcessing
                ? null
                : () => onPromptSelected(suggestion.prompt),
          ),
      ],
    );
  }
}
