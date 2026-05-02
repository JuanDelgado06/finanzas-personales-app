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
  double total;
  double minimum;
  String type;

  CreditCard({
    required this.id,
    required this.name,
    required this.total,
    required this.minimum,
    this.type = 'credit-card',
  });

  factory CreditCard.fromJson(Map<String, dynamic> json) => CreditCard(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] ?? '',
        total: (json['total'] ?? 0).toDouble(),
        minimum: (json['minimum'] ?? 0).toDouble(),
        type: json['type'] ?? 'credit-card',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'total': total, 'minimum': minimum, 'type': type};
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
