import 'budget_item.dart';

class MonthlyBudget {
  final String? id;
  final String monthName;
  final String? monthSlug;
  final List<BudgetItem> assets;
  final List<BudgetItem> owed;
  final List<dynamic> liabilities; // mix of Liability and CreditCard
  final List<MicroExpense> microExpenses;
  final List<String> microExpenseCategories;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final double partialNetWorth;
  final String createdAt;
  final String? authorId;
  final String? authorName;
  final String? authorEmail;

  MonthlyBudget({
    this.id,
    required this.monthName,
    this.monthSlug,
    required this.assets,
    required this.owed,
    required this.liabilities,
    required this.microExpenses,
    required this.microExpenseCategories,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.partialNetWorth,
    required this.createdAt,
    this.authorId,
    this.authorName,
    this.authorEmail,
  });

  static String? _parseId(dynamic raw) {
    if (raw == null) return null;
    if (raw is String && raw.isNotEmpty) return raw;
    // MongoDB ObjectId serializado como { "$oid": "..." }
    if (raw is Map) {
      final oid = raw['\$oid'] ?? raw['oid'];
      if (oid != null) return oid.toString();
    }
    final s = raw.toString();
    return s.isNotEmpty ? s : null;
  }

  factory MonthlyBudget.fromJson(Map<String, dynamic> json) {
    final rawLiabilities = (json['liabilities'] as List? ?? []);
    final parsedLiabilities = rawLiabilities.map((l) {
      if (l['type'] == 'credit-card') return CreditCard.fromJson(l);
      return Liability.fromJson(l);
    }).toList();

    return MonthlyBudget(
      id: _parseId(json['_id']) ?? _parseId(json['id']),
      monthName: json['monthName'] ?? '',
      monthSlug: json['monthSlug']?.toString(),
      assets: (json['assets'] as List? ?? []).map((a) => BudgetItem.fromJson(a)).toList(),
      owed: (json['owed'] as List? ?? []).map((a) => BudgetItem.fromJson(a)).toList(),
      liabilities: parsedLiabilities,
      microExpenses:
          (json['microExpenses'] as List? ?? []).map((m) => MicroExpense.fromJson(m)).toList(),
      microExpenseCategories:
          (json['microExpenseCategories'] as List? ?? []).map((c) => c.toString()).toList(),
      totalAssets: (json['totalAssets'] ?? 0).toDouble(),
      totalLiabilities: (json['totalLiabilities'] ?? 0).toDouble(),
      netWorth: (json['netWorth'] ?? 0).toDouble(),
      partialNetWorth: (json['partialNetWorth'] ?? 0).toDouble(),
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      authorId: json['authorId'],
      authorName: json['authorName'],
      authorEmail: json['authorEmail'],
    );
  }

  Map<String, dynamic> toJson() => {
        'monthName': monthName,
        'assets': assets.map((a) => a.toJson()).toList(),
        'owed': owed.map((a) => a.toJson()).toList(),
        'liabilities': liabilities.map((l) {
          if (l is CreditCard) return l.toJson();
          if (l is Liability) return l.toJson();
          return l;
        }).toList(),
        'microExpenses': microExpenses.map((m) => m.toJson()).toList(),
        'microExpenseCategories': microExpenseCategories,
        'totalAssets': totalAssets,
        'totalLiabilities': totalLiabilities,
        'netWorth': netWorth,
        'partialNetWorth': partialNetWorth,
        'createdAt': createdAt,
        'authorId': authorId,
        'authorName': authorName,
        'authorEmail': authorEmail,
      };
}
