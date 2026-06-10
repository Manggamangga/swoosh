import 'package:equatable/equatable.dart';

enum ConnectionStatus { pending, active, expired, revoked }

class BankConnection extends Equatable {
  const BankConnection({
    required this.id,
    required this.userId,
    required this.provider,
    this.institutionId,
    this.institutionName,
    this.requisitionId,
    required this.status,
    this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String provider;
  final String? institutionId;
  final String? institutionName;
  final String? requisitionId;
  final ConnectionStatus status;
  final DateTime? expiresAt;
  final DateTime createdAt;

  bool get needsReauth =>
      status == ConnectionStatus.expired ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));

  factory BankConnection.fromJson(Map<String, dynamic> json) {
    return BankConnection(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      provider: json['provider'] as String? ?? 'enable_banking',
      institutionId: json['institution_id'] as String?,
      institutionName: json['institution_name'] as String?,
      requisitionId: json['requisition_id'] as String?,
      status: ConnectionStatus.values.byName(json['status'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, status, institutionName];
}
