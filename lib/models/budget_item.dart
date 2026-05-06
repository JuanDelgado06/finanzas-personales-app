class BudgetItem {
  final String id;
  String name;
  double amount;

  BudgetItem({required this.id, required this.name, required this.amount});

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'amount': amount};

  BudgetItem copyWith({String? name, double? amount}) =>
      BudgetItem(id: id, name: name ?? this.name, amount: amount ?? this.amount);
}

class CreditCard {
  final String id;
  String name;
  double creditLimit;
  double balance;
  double minimum;
  double paymentTotal;
  int? cutoffDay;
  int? paymentDay;
  String type;

  CreditCard({
    required this.id,
    required this.name,
    required this.creditLimit,
    required this.balance,
    required this.minimum,
    required this.paymentTotal,
    this.cutoffDay,
    this.paymentDay,
    this.type = 'credit-card',
  });

  static int? _parseOptionalDay(dynamic value) {
    if (value == null) return null;
    final parsed = int.tryParse(value.toString());
    if (parsed == null || parsed < 1 || parsed > 31) return null;
    return parsed;
  }

  factory CreditCard.fromJson(Map<String, dynamic> json) => CreditCard(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] ?? '',
        creditLimit:
            (json['creditLimit'] ?? json['limit'] ?? json['cupo'] ?? 0).toDouble(),
        balance: (json['balance'] ?? json['total'] ?? 0).toDouble(),
        minimum: (json['minimum'] ?? 0).toDouble(),
        paymentTotal:
            (json['paymentTotal'] ?? json['totalPayment'] ?? json['total'] ?? 0).toDouble(),
        cutoffDay: _parseOptionalDay(json['cutoffDay'] ?? json['cutoffDate']),
        paymentDay: _parseOptionalDay(json['paymentDay'] ?? json['paymentDate']),
        type: json['type'] ?? 'credit-card',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        // Compatibilidad con backend/datos antiguos que usan total/minimum.
        'total': paymentTotal,
        'minimum': minimum,
        'creditLimit': creditLimit,
        'balance': balance,
        'paymentTotal': paymentTotal,
        'cutoffDay': cutoffDay,
        'paymentDay': paymentDay,
        'type': type,
      };
}

class Liability {
  final String id;
  String name;
  double amount;
  String type;

  Liability({required this.id, required this.name, required this.amount, this.type = 'standard'});

  factory Liability.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'credit-card') {
      throw Exception('Use CreditCard.fromJson for credit-card type');
    }
    return Liability(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type'] ?? 'standard',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'amount': amount, 'type': type};
}

class MicroExpense {
  final String id;
  double amount;
  String category;
  String paymentMethod;

  MicroExpense({
    required this.id,
    required this.amount,
    required this.category,
    required this.paymentMethod,
  });

  factory MicroExpense.fromJson(Map<String, dynamic> json) => MicroExpense(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        amount: (json['amount'] ?? 0).toDouble(),
        category: json['category'] ?? 'General',
        paymentMethod: json['paymentMethod'] ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'amount': amount, 'category': category, 'paymentMethod': paymentMethod};
}
