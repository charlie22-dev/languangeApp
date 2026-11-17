/// Orthographic helpers for the bundled courses; the device keyboard remains
/// available for every language. These are learning content, not UI translations.
String writingHints(String? locale) =>
    switch (locale?.replaceAll('_', '-').split('-').first.toLowerCase()) {
      'es' => 'áéíóúñ¿¡',
      'fr' => 'àâçéèêëîïôùûüÿœ',
      'de' => 'äöüß',
      'it' => 'àèéìòù',
      'pt' => 'áâãàçéêíóôõú',
      _ => '',
    };
