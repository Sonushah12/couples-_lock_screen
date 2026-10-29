/// The space owns relationship details; a profile owns personal preferences.
Map<String, dynamic> mergeProfileState(
  Map<String, dynamic> current,
  Map<String, dynamic> profile,
  Map<String, dynamic> shared,
) => {...current, ...profile, ...shared};

/// Historical answers must never be attributed to a newly joined partner.
String activePartnerAnswer(Map<String, dynamic> state, String uid, String day) {
  final members = (state['memberIds'] as List?) ?? [];
  if (!members.contains(uid) ||
      ((state['answers'] as Map?)?[day] as String? ?? '').isEmpty) {
    return '';
  }
  final partner = members.where((id) => id != uid).firstOrNull;
  return partner == null
      ? ''
      : (state['answerAuthors'] as Map?)?[partner] as String? ?? '';
}
