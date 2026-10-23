final RegExp _letterPattern = RegExp(r'\p{L}', unicode: true);

/// Space and Storage Spot names: 1-30 characters, containing at least one letter.
bool isValidSpaceOrSpotName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 30) return false;
  return _letterPattern.hasMatch(trimmed);
}
