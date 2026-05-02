import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/monthly_budget.dart';

class ApiService {
  static const String _baseUrl = 'https://finanzas-jj.vercel.app';

  final Future<String?> Function() _getIdToken;

  ApiService({required Future<String?> Function() getIdToken}) : _getIdToken = getIdToken;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getIdToken();
    if (token == null) return {'Content-Type': 'application/json'};
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<MonthlyBudget>> getBudgets() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/api/budgets'), headers: headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((b) => MonthlyBudget.fromJson(b)).toList();
    }
    throw Exception('Error cargando presupuestos: ${response.statusCode}');
  }

  Future<MonthlyBudget> saveBudget(MonthlyBudget budget) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/budgets'),
      headers: headers,
      body: jsonEncode(budget.toJson()),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return MonthlyBudget.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error guardando presupuesto: ${response.statusCode}');
  }

  Future<void> deleteBudget(String id) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/budgets?id=$id'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Error eliminando presupuesto: ${response.statusCode}');
    }
  }
}
