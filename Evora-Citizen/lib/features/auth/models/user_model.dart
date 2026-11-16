/// EVORA User Profile Model
/// Represents both the global account (`users/{uid}`) and tenant-scoped profile.
class EvoraUser {
  final String uid;
  final String displayName;
  final String? email;
  final String? phoneNumber;
  final String? photoUrl;
  final String tenantId;
  final String selectedLocality;
  final String? selectedWardId;
  final String preferredLanguage; // 'en' or 'hi'
  final int ecoCoinBalance;
  final String role; // 'citizen', 'ward_officer', 'worker', 'admin'
  final String accountStatus; // 'registered', 'restricted', 'suspended'
  final bool consentAccepted;
  final String consentVersion;
  final DateTime createdAt;

  const EvoraUser({
    required this.uid,
    required this.displayName,
    this.email,
    this.phoneNumber,
    this.photoUrl,
    required this.tenantId,
    required this.selectedLocality,
    this.selectedWardId,
    this.preferredLanguage = 'en',
    this.ecoCoinBalance = 0,
    this.role = 'citizen',
    this.accountStatus = 'registered',
    this.consentAccepted = true,
    this.consentVersion = '1.0',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'tenantId': tenantId,
      'selectedLocality': selectedLocality,
      'selectedWardId': selectedWardId,
      'preferredLanguage': preferredLanguage,
      'ecoCoinBalance': ecoCoinBalance,
      'role': role,
      'accountStatus': accountStatus,
      'consentAccepted': consentAccepted,
      'consentVersion': consentVersion,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory EvoraUser.fromMap(Map<String, dynamic> map, {required String uid}) {
    return EvoraUser(
      uid: uid,
      displayName: map['displayName'] ?? 'Local Resident',
      email: map['email'],
      phoneNumber: map['phoneNumber'],
      photoUrl: map['photoUrl'],
      tenantId: map['tenantId'] ?? 'tenant_dehradun_01',
      selectedLocality: map['selectedLocality'] ?? 'Dehradun Central',
      selectedWardId: map['selectedWardId'],
      preferredLanguage: map['preferredLanguage'] ?? 'en',
      ecoCoinBalance: (map['ecoCoinBalance'] as num?)?.toInt() ?? 0,
      role: map['role'] ?? 'citizen',
      accountStatus: map['accountStatus'] ?? 'registered',
      consentAccepted: map['consentAccepted'] ?? false,
      consentVersion: map['consentVersion'] ?? '1.0',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  EvoraUser copyWith({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    String? tenantId,
    String? selectedLocality,
    String? selectedWardId,
    String? preferredLanguage,
    int? ecoCoinBalance,
    String? role,
    String? accountStatus,
    bool? consentAccepted,
    String? consentVersion,
  }) {
    return EvoraUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      tenantId: tenantId ?? this.tenantId,
      selectedLocality: selectedLocality ?? this.selectedLocality,
      selectedWardId: selectedWardId ?? this.selectedWardId,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      ecoCoinBalance: ecoCoinBalance ?? this.ecoCoinBalance,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      consentVersion: consentVersion ?? this.consentVersion,
      createdAt: createdAt,
    );
  }
}
