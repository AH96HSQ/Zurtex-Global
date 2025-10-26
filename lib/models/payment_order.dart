class PaymentOrder {
  final String orderId;
  final String email;
  final String planType;
  final String paymentAddress;
  final double amount;
  final double amountUSD;
  final String qrCode;
  final DateTime expiresAt;
  final String status;
  final String? txHash;
  final int confirmations;
  final double amountReceived;
  final DateTime? paidAt;
  final DateTime? completedAt;

  PaymentOrder({
    required this.orderId,
    required this.email,
    required this.planType,
    required this.paymentAddress,
    required this.amount,
    required this.amountUSD,
    required this.qrCode,
    required this.expiresAt,
    this.status = 'pending',
    this.txHash,
    this.confirmations = 0,
    this.amountReceived = 0,
    this.paidAt,
    this.completedAt,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    return PaymentOrder(
      orderId: json['orderId'] ?? '',
      email: json['email'] ?? '',
      planType: json['planType'] ?? '',
      paymentAddress: json['paymentAddress'] ?? '',
      amount: _parseDouble(json['amount']),
      amountUSD: _parseDouble(json['amountUSD']),
      qrCode: json['qrCode'] ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : DateTime.now(),
      status: json['status'] ?? 'pending',
      txHash: json['txHash'],
      confirmations: json['confirmations'] ?? 0,
      amountReceived: _parseDouble(json['amountReceived']),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'email': email,
      'planType': planType,
      'paymentAddress': paymentAddress,
      'amount': amount,
      'amountUSD': amountUSD,
      'qrCode': qrCode,
      'expiresAt': expiresAt.toIso8601String(),
      'status': status,
      'txHash': txHash,
      'confirmations': confirmations,
      'amountReceived': amountReceived,
      'paidAt': paidAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  String getPlanDisplayName() {
    switch (planType) {
      case '30_days':
        return '1 Month';
      case '730_days':
        return '2 Years';
      default:
        return planType;
    }
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isConfirming => status == 'confirming';
  bool get isUnderpaid => status == 'underpaid';

  String getStatusMessage() {
    switch (status) {
      case 'pending':
        return 'Waiting for payment...';
      case 'confirming':
        return 'Payment received, confirming...';
      case 'completed':
        return 'Payment completed!';
      case 'underpaid':
        final shortage = amount - amountReceived;
        return 'Underpaid by ${shortage.toStringAsFixed(8)} LTC';
      case 'expired':
        return 'Payment expired';
      default:
        return status.toUpperCase();
    }
  }
}

class PaymentPlan {
  final String type;
  final double priceUSD;
  final double priceLTC;
  final int days;

  PaymentPlan({
    required this.type,
    required this.priceUSD,
    required this.priceLTC,
    required this.days,
  });

  factory PaymentPlan.fromJson(Map<String, dynamic> json) {
    return PaymentPlan(
      type: json['type'] ?? '',
      priceUSD: _parseDouble(json['priceUSD']),
      priceLTC: _parseDouble(json['priceLTC']),
      days: json['days'] ?? 0,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String getDisplayName() {
    if (days == 30) return '1 Month';
    if (days == 730) return '2 Years';
    return '$days Days';
  }

  double getMonthlyPrice() {
    final months = days / 30;
    return priceUSD / months;
  }

  double? getDiscountPercentage() {
    if (days == 30) return null; // No discount for 1 month
    if (days == 730) return 40.0; // 40% discount for 2 years
    return null;
  }

  double? getOriginalPrice() {
    final discount = getDiscountPercentage();
    if (discount == null) return null;
    return priceUSD / (1 - discount / 100);
  }
}
