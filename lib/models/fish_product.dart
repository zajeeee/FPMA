class FishProduct {
  final String id;
  final String? inspectionId;
  final String species;
  final String? size;
  final double? weight;
  final String? vesselInfo;
  final String? vesselName;
  final String? vesselRegistration;
  final String? imageUrl;
  final String? qrCode;
  final String inspectorId;
  final String inspectorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'pending', 'approved', 'rejected', 'cleared'

  const FishProduct({
    required this.id,
    this.inspectionId,
    required this.species,
    this.size,
    this.weight,
    this.vesselInfo,
    this.vesselName,
    this.vesselRegistration,
    this.imageUrl,
    this.qrCode,
    required this.inspectorId,
    required this.inspectorName,
    required this.createdAt,
    required this.updatedAt,
    this.status = 'pending',
  });

  factory FishProduct.fromJson(Map<String, dynamic> json) {
    return FishProduct(
      id: json['id'] as String,
      inspectionId: json['inspection_id'] as String?,
      species: json['species'] as String,
      size: json['size'] as String?,
      weight:
          json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      vesselInfo: json['vessel_info'] as String?,
      vesselName: json['vessel_name'] as String?,
      vesselRegistration: json['vessel_registration'] as String?,
      imageUrl: json['image_url'] as String?,
      qrCode: json['qr_code'] as String?,
      inspectorId: json['inspector_id'] as String,
      inspectorName: json['inspector_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      status: json['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'species': species,
      'size': size,
      'weight': weight,
      'vessel_info': vesselInfo,
      'vessel_name': vesselName,
      'vessel_registration': vesselRegistration,
      'image_url': imageUrl,
      'qr_code': qrCode,
      'inspector_id': inspectorId,
      'inspector_name': inspectorName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'status': status,
    };
  }

  FishProduct copyWith({
    String? id,
    String? inspectionId,
    String? species,
    String? size,
    double? weight,
    String? vesselInfo,
    String? vesselName,
    String? vesselRegistration,
    String? imageUrl,
    String? qrCode,
    String? inspectorId,
    String? inspectorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return FishProduct(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      species: species ?? this.species,
      size: size ?? this.size,
      weight: weight ?? this.weight,
      vesselInfo: vesselInfo ?? this.vesselInfo,
      vesselName: vesselName ?? this.vesselName,
      vesselRegistration: vesselRegistration ?? this.vesselRegistration,
      imageUrl: imageUrl ?? this.imageUrl,
      qrCode: qrCode ?? this.qrCode,
      inspectorId: inspectorId ?? this.inspectorId,
      inspectorName: inspectorName ?? this.inspectorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }
}

// Fish species enum for dropdown
enum FishSpecies {
  bangus('Bangus', 'Milkfish'),
  tilapia('Tilapia', 'Tilapia'),
  galunggong('Galunggong', 'Round Scad'),
  tamban('Tamban', 'Sardine'),
  tulingan('Tulingan', 'Skipjack Tuna'),
  lapuLapu('Lapu-lapu', 'Grouper'),
  mayaMaya('Maya-maya', 'Red Snapper'),
  tanigue('Tanigue', 'Spanish Mackerel'),
  dalagangBukid('Dalagang Bukid', 'Yellowtail Fusilier'),
  sapsap('Sapsap', 'Ponyfish'),
  other('Other', 'Other Species');

  const FishSpecies(this.displayName, this.description);
  final String displayName;
  final String description;

  static FishSpecies fromString(String value) {
    return FishSpecies.values.firstWhere(
      (species) => species.name == value,
      orElse: () => FishSpecies.other,
    );
  }
}

// Fish product status enum
enum FishProductStatus {
  pending('Pending', 'Awaiting inspection'),
  approved('Approved', 'Passed inspection'),
  rejected('Rejected', 'Failed inspection'),
  cleared('Cleared', 'Ready for processing');

  const FishProductStatus(this.displayName, this.description);
  final String displayName;
  final String description;

  static FishProductStatus fromString(String value) {
    return FishProductStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => FishProductStatus.pending,
    );
  }
}
