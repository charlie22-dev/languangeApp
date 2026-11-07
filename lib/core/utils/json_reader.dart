typedef JsonMap = Map<String, dynamic>;

abstract final class JsonReader {
  static JsonMap object(Object? value, String field) {
    if (value is! JsonMap) throw FormatException('$field must be an object');
    return value;
  }

  static String text(JsonMap json, String field) {
    final value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a nonempty string');
    }
    return value;
  }

  static List<dynamic> list(JsonMap json, String field) {
    final value = json[field];
    if (value is! List) throw FormatException('$field must be an array');
    return value;
  }

  static List<String> strings(JsonMap json, String field) =>
      list(json, field).map((value) => text({field: value}, field)).toList();

  static int integer(JsonMap json, String field) {
    final value = json[field];
    if (value is! int) throw FormatException('$field must be an integer');
    return value;
  }

  static void unique(Iterable<String> values, String field) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) throw FormatException('Duplicate $field: $value');
    }
  }
}
