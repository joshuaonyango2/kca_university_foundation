// lib/models/donation.dart

class Donation {
  final String donationId;
  final String userId;
  final String campaignId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final bool isRecurring;
  final String? recurrenceFrequency;
  final bool isAnonymous;
  final String donationStatus;
  final double paymentFee;
  final double netAmount;
  final String? transactionReference;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? campaignTitle;
  final String? campaignSlug;
  final String? campaignImage;

  Donation({
    required this.donationId,
    required this.userId,
    required this.campaignId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.isRecurring,
    this.recurrenceFrequency,
    required this.isAnonymous,
    required this.donationStatus,
    required this.paymentFee,
    required this.netAmount,
    this.transactionReference,
    required this.createdAt,
    this.completedAt,
    this.campaignTitle,
    this.campaignSlug,
    this.campaignImage,
  });

  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      donationId: json['donation_id'],
      userId: json['user_id'],
      campaignId: json['campaign_id'],
      amount: double.parse(json['amount'].toString()),
      currency: json['currency'] ?? 'KES',
      paymentMethod: json['payment_method'],
      isRecurring: json['is_recurring'] ?? false,
      recurrenceFrequency: json['recurrence_frequency'],
      isAnonymous: json['is_anonymous'] ?? false,
      donationStatus: json['donation_status'],
      paymentFee: double.parse(json['payment_fee']?.toString() ?? '0'),
      netAmount: double.parse(json['net_amount']?.toString() ?? '0'),
      transactionReference: json['transaction_reference'],
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      campaignTitle: json['campaign_title'],
      campaignSlug: json['campaign_slug'],
      campaignImage: json['campaign_image'],
    );
  }

  String get statusDisplay {
    switch (donationStatus) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      default:
        return 'Unknown';
    }
  }

  bool get isCompleted => donationStatus == 'completed';
  bool get isPending => donationStatus == 'pending';
  bool get isFailed => donationStatus == 'failed';
}