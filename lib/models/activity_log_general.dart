class ActivityLogGeneral {
  final String id;
  final String userId;
  final String userRole;
  final String action;
  final String? description;
  final String? referenceId;
  final String? referenceType;
  final Map<String, dynamic>? metadata;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  const ActivityLogGeneral({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.action,
    this.description,
    this.referenceId,
    this.referenceType,
    this.metadata,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });

  factory ActivityLogGeneral.fromJson(Map<String, dynamic> json) {
    return ActivityLogGeneral(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userRole: json['user_role'] as String,
      action: json['action'] as String,
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String?,
      referenceType: json['reference_type'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_role': userRole,
      'action': action,
      'description': description,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'metadata': metadata,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper method to get display text for the activity
  String getDisplayText() {
    switch (action) {
      case 'fish_inspection':
        return description ?? 'Fish inspection completed';
      case 'fish_product_created':
        final species = metadata?['species'] as String?;
        final vessel = metadata?['vessel_name'] as String?;
        if (species != null && vessel != null) {
          return '$species recorded from $vessel';
        } else if (species != null) {
          return '$species recorded';
        }
        return 'Fish product created';
      case 'photo_captured':
        final species = metadata?['species'] as String?;
        return species != null
            ? 'Photo captured for $species'
            : 'Photo captured';
      case 'quality_assigned':
        final grade = metadata?['grade'] as String?;
        final species = metadata?['species'] as String?;
        if (grade != null && species != null) {
          return 'Quality Grade $grade assigned to $species';
        } else if (grade != null) {
          return 'Quality Grade $grade assigned';
        }
        return 'Quality grade assigned';
      case 'vessel_info_updated':
        return 'Vessel information updated';
      default:
        return description ?? action.replaceAll('_', ' ').toUpperCase();
    }
  }

  // Helper method to get appropriate icon for the activity
  String getIconName() {
    switch (action) {
      case 'fish_inspection':
        return 'search';
      case 'fish_product_created':
        return 'pets';
      case 'photo_captured':
        return 'camera_alt';
      case 'quality_assigned':
        return 'star';
      case 'vessel_info_updated':
        return 'directions_boat';
      default:
        return 'info';
    }
  }

  // Helper method to get appropriate color for the activity
  String getColorName() {
    switch (action) {
      case 'fish_inspection':
        return 'blue';
      case 'fish_product_created':
        return 'green';
      case 'photo_captured':
        return 'purple';
      case 'quality_assigned':
        return 'amber';
      case 'vessel_info_updated':
        return 'teal';
      default:
        return 'grey';
    }
  }

  // Helper method to get time ago string
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${difference.inDays ~/ 7} week${(difference.inDays ~/ 7) == 1 ? '' : 's'} ago';
    }
  }
}
