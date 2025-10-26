import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_order.dart';
import 'app_config.dart';
import 'auth_service.dart';

class PaymentService {
  static const String _paymentOrderKey = 'current_payment_order';

  // Get payment backend URL
  static String get _baseUrl {
    final backendUrl = AppConfig.backendBaseUrl;
    // Replace /global with /litecoinpayment
    return backendUrl.replaceAll('/global', '/litecoinpayment');
  }

  /// Get available payment plans
  static Future<List<PaymentPlan>> getPlans() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/payment/plans'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> plansJson = data['plans'] ?? [];
        return plansJson.map((p) => PaymentPlan.fromJson(p)).toList();
      } else {
        throw Exception('Failed to load plans: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error loading plans: $e', name: 'PaymentService');
      rethrow;
    }
  }

  /// Create a new payment order
  static Future<PaymentOrder> createPayment(String planType) async {
    try {
      final email = await AuthService.getUserEmail();
      if (email == null) {
        throw Exception('User not logged in');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/payment/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'planType': planType}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final order = PaymentOrder.fromJson({
          ...data,
          'email': email,
          'planType': planType,
        });

        // Save to local storage
        await _savePaymentOrder(order);

        developer.log(
          'Payment order created: ${order.orderId}',
          name: 'PaymentService',
        );
        return order;
      } else {
        throw Exception('Failed to create payment: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error creating payment: $e', name: 'PaymentService');
      rethrow;
    }
  }

  /// Check payment status
  static Future<PaymentOrder> checkPaymentStatus(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/payment/status/$orderId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Get stored order for email and planType
        final storedOrder = await getCurrentPaymentOrder();

        final order = PaymentOrder.fromJson({
          ...data,
          'email': storedOrder?.email ?? '',
          'planType': storedOrder?.planType ?? '',
          'qrCode': storedOrder?.qrCode ?? '',
        });

        // Update local storage
        await _savePaymentOrder(order);

        developer.log(
          'Payment status: ${order.status}',
          name: 'PaymentService',
        );
        return order;
      } else {
        throw Exception('Failed to check status: ${response.statusCode}');
      }
    } catch (e) {
      developer.log(
        'Error checking payment status: $e',
        name: 'PaymentService',
      );
      rethrow;
    }
  }

  /// Manually refresh payment status (triggers backend check)
  static Future<PaymentOrder> refreshPaymentStatus(String orderId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/payment/refresh/$orderId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Get stored order for full details
        final storedOrder = await getCurrentPaymentOrder();

        final order = PaymentOrder.fromJson({
          'orderId': data['orderId'],
          'status': data['status'],
          'amount': data['amount'],
          'amountUSD': storedOrder?.amountUSD ?? 0,
          'paymentAddress': storedOrder?.paymentAddress ?? '',
          'txHash': data['txHash'],
          'confirmations': data['confirmations'],
          'amountReceived': data['amountReceived'],
          'expiresAt': storedOrder?.expiresAt.toIso8601String() ?? '',
          'email': storedOrder?.email ?? '',
          'planType': storedOrder?.planType ?? '',
          'qrCode': storedOrder?.qrCode ?? '',
        });

        // Update local storage
        await _savePaymentOrder(order);

        developer.log(
          'Payment refreshed: ${order.status}',
          name: 'PaymentService',
        );
        return order;
      } else {
        throw Exception('Failed to refresh status: ${response.statusCode}');
      }
    } catch (e) {
      developer.log(
        'Error refreshing payment status: $e',
        name: 'PaymentService',
      );
      rethrow;
    }
  }

  /// Cancel payment (locally only, removes from storage)
  static Future<void> cancelPayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_paymentOrderKey);
      developer.log('Payment order cancelled locally', name: 'PaymentService');
    } catch (e) {
      developer.log('Error cancelling payment: $e', name: 'PaymentService');
      rethrow;
    }
  }

  /// Get current payment order from local storage
  static Future<PaymentOrder?> getCurrentPaymentOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderJson = prefs.getString(_paymentOrderKey);

      if (orderJson != null) {
        final data = json.decode(orderJson);
        return PaymentOrder.fromJson(data);
      }

      return null;
    } catch (e) {
      developer.log('Error loading payment order: $e', name: 'PaymentService');
      return null;
    }
  }

  /// Save payment order to local storage
  static Future<void> _savePaymentOrder(PaymentOrder order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderJson = json.encode(order.toJson());
      await prefs.setString(_paymentOrderKey, orderJson);
    } catch (e) {
      developer.log('Error saving payment order: $e', name: 'PaymentService');
      rethrow;
    }
  }

  /// Clear completed payment
  static Future<void> clearCompletedPayment() async {
    final order = await getCurrentPaymentOrder();
    if (order?.isCompleted == true) {
      await cancelPayment();
    }
  }
}
