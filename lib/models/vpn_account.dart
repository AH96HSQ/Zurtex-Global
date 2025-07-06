class VpnAccount {
  final String username;
  final bool test;
  final int expiryTime;
  final int gigBytes;
  final String? status;
  final List<String> takLinks;
  final bool hasPendingReceipt;
  final List<String> messages;
  final String? latestVersion; // ✅ NEW
  final String? updateUrl; // ✅ NEW

  VpnAccount({
    required this.username,
    required this.test,
    required this.expiryTime,
    required this.gigBytes,
    required this.status,
    required this.takLinks,
    required this.hasPendingReceipt,
    required this.messages,
    this.latestVersion,
    this.updateUrl,
  });

  factory VpnAccount.fromJson(Map<String, dynamic> json) {
    return VpnAccount(
      username: json['username'] ?? '',
      test: json['test'] ?? false,
      expiryTime: json['expiryTime'] ?? 0,
      gigBytes: json['gig_byte'] ?? 0,
      status: json['status'],
      takLinks: List<String>.from(json['tak_links'] ?? []),
      hasPendingReceipt: json['hasPendingReceipt'] ?? false,
      messages: List<String>.from(json['messages'] ?? []),
      latestVersion: json['latestVersion'], // ✅ Parse new field
      updateUrl: json['updateUrl'], // ✅ Parse new field
    );
  }

  int get remainingDays {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final secondsLeft = expiryTime - nowSec;
    return (secondsLeft / 86400).ceil();
  }

  double get remainingGB => gigBytes / (1024 * 1024 * 1024);
}
