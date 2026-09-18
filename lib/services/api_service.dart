import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/monthly_budget.dart';

class ApiService {
  // Configurable en build/run con:
  //   flutter run --dart-define=API_BASE_URL=https://mi-entorno.vercel.app
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://finanzas-jj.vercel.app',
  );

  final Future<String?> Function() _getIdToken;

  ApiService({required Future<String?> Function() getIdToken})
    : _getIdToken = getIdToken;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hay una sesión autenticada para cargar presupuestos');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  List<dynamic> _extractBudgetList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final candidates = [
        decoded['budgets'],
        decoded['data'],
        decoded['items'],
      ];
      for (final c in candidates) {
        if (c is List) return c;
      }
    }
    throw Exception('Formato inesperado al cargar presupuestos');
  }

  Map<String, dynamic> _extractBudgetObject(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final candidates = [decoded['budget'], decoded['data'], decoded['item']];
      for (final c in candidates) {
        if (c is Map<String, dynamic>) return c;
      }
      return decoded;
    }
    throw Exception('Formato inesperado al guardar presupuesto');
  }

  Future<List<MonthlyBudget>> getBudgets() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/api/budgets'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> data = _extractBudgetList(decoded);
      return data.map((b) => MonthlyBudget.fromJson(b)).toList();
    }
    throw Exception(
      'Error cargando presupuestos: ${response.statusCode} - ${response.body}',
    );
  }

  Future<MonthlyBudget> saveBudget(MonthlyBudget budget) async {
    final headers = await _authHeaders();
    final payload = budget.toJson();
    final response = await http.post(
      Uri.parse('$_baseUrl/api/budgets'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      final budgetMap = _extractBudgetObject(decoded);
      return MonthlyBudget.fromJson(budgetMap);
    }
    throw Exception(
      'Error guardando presupuesto: ${response.statusCode} - ${response.body}',
    );
  }

  Future<void> deleteBudget(String monthSlug) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/budgets?monthSlug=$monthSlug'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Error eliminando presupuesto: ${response.statusCode}');
    }
  }
}
