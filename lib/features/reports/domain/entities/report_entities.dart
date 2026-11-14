typedef ReportRow = Map<String, dynamic>;

class ReportDateRange {
  final DateTime start;
  final DateTime end;

  const ReportDateRange({required this.start, required this.end});

  String get startIso =>
      DateTime(start.year, start.month, start.day).toUtc().toIso8601String();

  String get endIso => DateTime(
    end.year,
    end.month,
    end.day,
    23,
    59,
    59,
    999,
  ).toUtc().toIso8601String();
}
