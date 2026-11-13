String? localeForLanguage(String language) {
  final normalized = language.trim().replaceAll('_', '-');
  if (RegExp(r'^[a-z]{2,3}-[A-Za-z]{2,8}(?:-[A-Za-z0-9]{2,8})*$')
      .hasMatch(normalized)) {
    return normalized;
  }
  return const {
    'japanese': 'ja-JP',
    'ja': 'ja-JP',
    'spanish': 'es-ES',
    'es': 'es-ES',
    'english': 'en-US',
    'en': 'en-US',
    'french': 'fr-FR',
    'fr': 'fr-FR',
    'german': 'de-DE',
    'de': 'de-DE',
    'korean': 'ko-KR',
    'ko': 'ko-KR',
    'chinese': 'zh-CN',
    'zh': 'zh-CN',
  }[normalized.toLowerCase()];
}
