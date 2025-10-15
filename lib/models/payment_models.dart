class OrderOfPayment {
  final String id;
  final String fishProductId;
  final String orderNumber;
  final double amount;
  final int? quantity;
  final String collectorId;
  final String collectorName;
  final String status; // pending | issued | paid | cancelled
  final String? qrCode;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderOfPayment({
    required this.id,
    required this.fishProductId,
    required this.orderNumber,
    required this.amount,
    this.quantity,
    required this.collectorId,
    required this.collectorName,
    required this.status,
    this.qrCode,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderOfPayment.fromJson(Map<String, dynamic> json) {
    int? parseQuantity(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return OrderOfPayment(
      id: json['id'],
      fishProductId: json['fish_product_id'],
      orderNumber: json['order_number'],
      amount: (json['amount'] as num).toDouble(),
      quantity: parseQuantity(json['quantity']),
      collectorId: json['collector_id'],
      collectorName: json['collector_name'],
      status: json['status'],
      qrCode: json['qr_code'],
      dueDate:
          json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class OfficialReceipt {
  final String id;
  final String orderId;
  final String receiptNumber;
  final double amountPaid;
  final String tellerId;
  final String tellerName;
  final DateTime paymentDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  OfficialReceipt({
    required this.id,
    required this.orderId,
    required this.receiptNumber,
    required this.amountPaid,
    required this.tellerId,
    required this.tellerName,
    required this.paymentDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OfficialReceipt.fromJson(Map<String, dynamic> json) {
    return OfficialReceipt(
      id: json['id'],
      orderId: json['order_id'],
      receiptNumber: json['receipt_number'],
      amountPaid: (json['amount_paid'] as num).toDouble(),
      tellerId: json['teller_id'],
      tellerName: json['teller_name'],
      paymentDate: DateTime.parse(json['payment_date']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class ClearingCertificate {
  final String id;
  final String officialReceiptId;
  final String certificateNumber;
  final String? qrCode;
  final String status; // generated | validated | expired
  final DateTime? validatedAt;
  final String? validatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClearingCertificate({
    required this.id,
    required this.officialReceiptId,
    required this.certificateNumber,
    this.qrCode,
    required this.status,
    this.validatedAt,
    this.validatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClearingCertificate.fromJson(Map<String, dynamic> json) {
    return ClearingCertificate(
      id: json['id'],
      officialReceiptId: json['official_receipt_id'],
      certificateNumber: json['certificate_number'],
      qrCode: json['qr_code'],
      status: json['status'],
      validatedAt:
          json['validated_at'] != null
              ? DateTime.parse(json['validated_at'])
              : null,
      validatedBy: json['validated_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
