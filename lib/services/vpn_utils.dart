const Map<String, String> flagToCountry = {
  '🇩🇪': 'Germany',
  '🇫🇮': 'Finland',
  '🇬🇧': 'UK',
  '🇫🇷': 'France',
  '🇳🇱': 'Netherlands',
  '🇹🇷': 'Turkey',
  '🇸🇬': 'Singapore',
  '🇨🇦': 'Canada',
  '🇯🇵': 'Japan',
  '🇮🇷': 'Iran',
  '🇮🇳': 'India',
  '🇦🇪': 'UAE',
  '🇺🇸': 'USA',
};

String getServerLabel(String link) {
  final idx = link.indexOf('#');
  if (idx == -1) return 'Unknown';

  String raw = Uri.decodeComponent(link.substring(idx + 1)).trim();
  if (raw.contains('📅')) return 'Bad Config';

  if (raw.contains('اضطراری')) return 'Emergency';

  final httpMatch = RegExp(r'\(𝗛𝗧𝗧𝗣\+\)').hasMatch(raw);

  // Extract flags
  final flagMatches = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}]{2}',
    unicode: true,
  ).allMatches(raw).map((m) => m.group(0)!).toList();

  if (flagMatches.isNotEmpty) {
    final selectedFlag = flagMatches.firstWhere(
      (flag) => flag != '🇮🇷',
      orElse: () => flagMatches.first,
    );

    final fallback = flagToCountry[selectedFlag];
    if (fallback != null) {
      return httpMatch ? '$fallback (𝗛𝗧𝗧𝗣+)' : fallback;
    }
  }

  return 'Emergency';
}
