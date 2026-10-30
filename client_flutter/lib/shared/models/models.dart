import 'dart:convert';

class UserModel {
  final String id;
  final String idCard;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final DateTime? birthDate;
  final List<String> roles;
  final bool mustChangePassword;

  UserModel({
    required this.id,
    required this.idCard,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.birthDate,
    required this.roles,
    required this.mustChangePassword,
  });

  bool get isAdmin => roles.contains('ADMIN');
  bool get isReceptionist => roles.contains('RECEPTIONIST');
  bool get isDoctor => roles.contains('DOCTOR');
  bool get isSupport => roles.contains('SUPPORT');
  bool get isAffiliate => roles.contains('AFFILIATE');

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      idCard: json['idCard'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'],
      birthDate: json['birthDate'] != null ? DateTime.tryParse(json['birthDate']) : null,
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['AFFILIATE'],
      mustChangePassword: json['mustChangePassword'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idCard': idCard,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'birthDate': birthDate?.toIso8601String(),
      'roles': roles,
      'mustChangePassword': mustChangePassword,
    };
  }

  String toRawJson() => json.encode(toJson());
  factory UserModel.fromRawJson(String str) => UserModel.fromJson(json.decode(str));
}

class SpecialtyModel {
  final String id;
  final String code;
  final String name;
  final String description;
  final bool requiresReferral;

  SpecialtyModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.requiresReferral,
  });

  factory SpecialtyModel.fromJson(Map<String, dynamic> json) {
    return SpecialtyModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      requiresReferral: json['requiresReferral'] ?? false,
    );
  }
}

class FacilityModel {
  final String id;
  final String code;
  final String name;
  final String address;
  final String city;
  final String phone;

  FacilityModel({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
  });

  factory FacilityModel.fromJson(Map<String, dynamic> json) {
    return FacilityModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      phone: json['phone'] ?? '',
    );
  }
}

class SlotModel {
  final String id;
  final String doctorId;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAvailable;
  final String doctorName;
  final String specialtyName;
  final String specialtyCode;
  final bool requiresReferral;
  final String facilityName;
  final String facilityCity;

  SlotModel({
    required this.id,
    required this.doctorId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    required this.doctorName,
    required this.specialtyName,
    required this.specialtyCode,
    required this.requiresReferral,
    required this.facilityName,
    required this.facilityCity,
  });

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    final doctor = json['doctor'] ?? {};
    final user = doctor['user'] ?? {};
    final specialty = doctor['specialty'] ?? {};
    final facility = doctor['facility'] ?? {};

    return SlotModel(
      id: json['id'] ?? '',
      doctorId: json['doctorId'] ?? '',
      date: DateTime.parse(json['date']),
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      isAvailable: json['isAvailable'] ?? true,
      doctorName: user['fullName'] ?? 'Médico General',
      specialtyName: specialty['name'] ?? 'Especialidad',
      specialtyCode: specialty['code'] ?? '',
      requiresReferral: specialty['requiresReferral'] ?? false,
      facilityName: facility['name'] ?? 'Establecimiento IESS',
      facilityCity: facility['city'] ?? 'Quito',
    );
  }
}

class AppointmentModel {
  final String id;
  final String affiliateId;
  final String affiliateName;
  final String affiliateIdCard;
  final String specialtyName;
  final String facilityName;
  final String facilityAddress;
  final String doctorName;
  final DateTime scheduledAt;
  final String status;
  final String? cancellationReason;

  AppointmentModel({
    required this.id,
    required this.affiliateId,
    required this.affiliateName,
    required this.affiliateIdCard,
    required this.specialtyName,
    required this.facilityName,
    required this.facilityAddress,
    required this.doctorName,
    required this.scheduledAt,
    required this.status,
    this.cancellationReason,
  });

  bool get isScheduled => status == 'SCHEDULED';
  bool get isRescheduled => status == 'RESCHEDULED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isActive => isScheduled || isRescheduled;

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final specialty = json['specialty'] is Map ? json['specialty'] : {};
    final facility = json['facility'] is Map ? json['facility'] : {};
    final doctor = json['doctor'] is Map ? json['doctor'] : {};
    final docUser = doctor is Map && doctor['user'] is Map ? doctor['user'] : {};
    final affiliate = json['affiliate'] is Map ? json['affiliate'] : {};

    return AppointmentModel(
      id: json['id'] ?? '',
      affiliateId: json['affiliateId'] ?? affiliate['id'] ?? '',
      affiliateName: json['patientName'] ?? affiliate['fullName'] ?? 'Afiliado Titular',
      affiliateIdCard: affiliate['idCard'] ?? '',
      specialtyName: json['specialty'] is String ? json['specialty'] : (specialty['name'] ?? 'Medicina General'),
      facilityName: json['facility'] is String ? json['facility'] : (facility['name'] ?? 'Hospital General'),
      facilityAddress: json['facilityAddress'] ?? facility['address'] ?? '',
      doctorName: json['doctor'] is String ? json['doctor'] : (docUser['fullName'] ?? 'Médico Asignado'),
      scheduledAt: DateTime.parse(json['scheduledAt']),
      status: json['status'] ?? 'SCHEDULED',
      cancellationReason: json['cancellationReason'],
    );
  }
}

class FamilyAuthorizationModel {
  final String id;
  final String principalUserId;
  final String representativeUserId;
  final String representativeName;
  final String representativeIdCard;
  final String principalName;
  final String principalIdCard;
  final String relationship;
  final String verificationMethod;
  final String status;
  final DateTime validUntil;

  FamilyAuthorizationModel({
    required this.id,
    required this.principalUserId,
    required this.representativeUserId,
    required this.representativeName,
    required this.representativeIdCard,
    required this.principalName,
    required this.principalIdCard,
    required this.relationship,
    required this.verificationMethod,
    required this.status,
    required this.validUntil,
  });

  factory FamilyAuthorizationModel.fromJson(Map<String, dynamic> json) {
    final rep = json['representative'] ?? {};
    final prin = json['principal'] ?? {};

    return FamilyAuthorizationModel(
      id: json['id'] ?? '',
      principalUserId: json['principalUserId'] ?? '',
      representativeUserId: json['representativeUserId'] ?? '',
      representativeName: rep['fullName'] ?? '',
      representativeIdCard: rep['idCard'] ?? '',
      principalName: prin['fullName'] ?? '',
      principalIdCard: prin['idCard'] ?? '',
      relationship: json['relationship'] ?? 'FAMILIAR',
      verificationMethod: json['verificationMethod'] ?? 'OTP_CONTACTO',
      status: json['status'] ?? 'ACTIVE',
      validUntil: DateTime.parse(json['validUntil']),
    );
  }
}

