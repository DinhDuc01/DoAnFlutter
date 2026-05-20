class AccountProfile {
  const AccountProfile({
    required this.name,
    required this.email,
    required this.role,
    required this.avatarInitial,
    required this.inboundCount,
    required this.outboundCount,
    required this.inventoryCount,
    required this.assignedWarehouse,
    required this.notificationsEnabled,
    required this.darkModeEnabled,
    required this.language,
  });

  final String name;
  final String email;
  final String role;
  final String avatarInitial;
  final int inboundCount;
  final int outboundCount;
  final int inventoryCount;
  final String assignedWarehouse;
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final String language;

  AccountProfile copyWith({
    bool? notificationsEnabled,
    bool? darkModeEnabled,
  }) {
    return AccountProfile(
      name: name,
      email: email,
      role: role,
      avatarInitial: avatarInitial,
      inboundCount: inboundCount,
      outboundCount: outboundCount,
      inventoryCount: inventoryCount,
      assignedWarehouse: assignedWarehouse,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      language: language,
    );
  }
}
