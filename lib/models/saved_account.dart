class SavedAccount {
  final String uid;
  final String identifier; // email or username used to login
  final String? email;
  final String? displayName;
  final DateTime lastUsed;

  SavedAccount({
    required this.uid,
    required this.identifier,
    this.email,
    this.displayName,
    DateTime? lastUsed,
  }) : lastUsed = lastUsed ?? DateTime.now();

  SavedAccount copyWith({DateTime? lastUsed}) => SavedAccount(
    uid: uid,
    identifier: identifier,
    email: email,
    displayName: displayName,
    lastUsed: lastUsed ?? this.lastUsed,
  );

  Map<String, dynamic> toMap() => {
    "uid": uid,
    "identifier": identifier,
    "email": email,
    "displayName": displayName,
    "lastUsed": lastUsed.toIso8601String(),
  };

  static SavedAccount fromMap(Map<String, dynamic> m) => SavedAccount(
    uid: m["uid"],
    identifier: m["identifier"],
    email: m["email"],
    displayName: m["displayName"],
    lastUsed: DateTime.tryParse(m["lastUsed"] ?? "") ?? DateTime.now(),
  );
}
