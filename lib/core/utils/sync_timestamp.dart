int nextSyncTimestamp(int previous, DateTime now) {
  final current = now.toUtc().microsecondsSinceEpoch;
  return current > previous ? current : previous + 1;
}
