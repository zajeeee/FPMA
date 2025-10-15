import 'package:flutter/material.dart';

enum UserRole {
  admin,
  inspector,
  collector,
  teller,
  gateCollector,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.inspector:
        return 'Inspector';
      case UserRole.collector:
        return 'Collector';
      case UserRole.teller:
        return 'Teller';
      case UserRole.gateCollector:
        return 'Gate Collector';
    }
  }

  String get description {
    switch (this) {
      case UserRole.admin:
        return 'Full system access and user management';
      case UserRole.inspector:
        return 'Inspect fish products and input vessel details';
      case UserRole.collector:
        return 'Issue Order of Payment and generate QR codes';
      case UserRole.teller:
        return 'Issue Official Receipt and process payments';
      case UserRole.gateCollector:
        return 'Scan certificates and validate entries';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.inspector:
        return Icons.search;
      case UserRole.collector:
        return Icons.receipt_long;
      case UserRole.teller:
        return Icons.payment;
      case UserRole.gateCollector:
        return Icons.qr_code_scanner;
    }
  }

  List<String> get permissions {
    switch (this) {
      case UserRole.admin:
        return [
          'user_management',
          'view_all_reports',
          'system_settings',
          'fish_inspection',
          'order_payment',
          'official_receipt',
          'clearing_certificate',
          'gate_validation',
        ];
      case UserRole.inspector:
        return [
          'fish_inspection',
          'view_inspector_reports',
        ];
      case UserRole.collector:
        return [
          'order_payment',
          'view_collector_reports',
        ];
      case UserRole.teller:
        return [
          'official_receipt',
          'view_teller_reports',
        ];
      case UserRole.gateCollector:
        return [
          'gate_validation',
          'view_gate_reports',
        ];
    }
  }

  bool hasPermission(String permission) {
    return permissions.contains(permission);
  }
}
