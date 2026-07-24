// lib/models/recurring_config.dart
class RecurringConfig {
  final bool isRecurring;
  final String frequency;      // 'Weekly' | 'Monthly' | 'Quarterly' | 'Yearly'
  final DateTime? nextGenerationDate;
  final DateTime? endDate;
  final int reminderDaysBeforeDue;

  RecurringConfig({
    this.isRecurring = false,
    this.frequency = 'Monthly',
    this.nextGenerationDate,
    this.endDate,
    this.reminderDaysBeforeDue = 3,
  });

  factory RecurringConfig.fromMap(Map<String, dynamic>? m) {
    if (m == null) return RecurringConfig();
    return RecurringConfig(
      isRecurring: m['is_recurring'] ?? false,
      frequency: m['frequency']?.toString() ?? 'Monthly',
      nextGenerationDate: m['next_generation_date'] != null
          ? DateTime.tryParse(m['next_generation_date'].toString())
          : null,
      endDate: m['end_date'] != null ? DateTime.tryParse(m['end_date'].toString()) : null,
      reminderDaysBeforeDue: (m['reminder_days'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toMap() => {
    'is_recurring': isRecurring,
    'frequency': frequency,
    'next_generation_date': nextGenerationDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'reminder_days': reminderDaysBeforeDue,
  };
}