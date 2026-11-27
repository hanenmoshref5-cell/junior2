// موديل بيانات المستخدم - محدّث مع Supabase
class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String gender;
  final DateTime birthDate;
  final double weight;
  final double height;
  final String? profileImageUrl;

  const UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.gender,
    required this.birthDate,
    required this.weight,
    required this.height,
    this.profileImageUrl,
  });

  String get fullName => '$firstName $lastName';

  int get age {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) age--;
    return age;
  }

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? gender,
    DateTime? birthDate,
    double? weight,
    double? height,
    String? profileImageUrl,
  }) {
    return UserModel(
      id              : id,
      firstName       : firstName ?? this.firstName,
      lastName        : lastName  ?? this.lastName,
      email           : email     ?? this.email,
      gender          : gender    ?? this.gender,
      birthDate       : birthDate ?? this.birthDate,
      weight          : weight    ?? this.weight,
      height          : height    ?? this.height,
      profileImageUrl : profileImageUrl ?? this.profileImageUrl,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id              : json['id'] as String,
    firstName       : json['first_name'] as String,
    lastName        : json['last_name'] as String,
    email           : json['email'] as String? ?? '',
    gender          : json['gender'] as String? ?? '',
    birthDate       : DateTime.parse(json['birth_date'] as String),
    weight          : (json['weight'] as num).toDouble(),
    height          : (json['height'] as num).toDouble(),
    profileImageUrl : json['profile_image_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id'               : id,
    'first_name'       : firstName,
    'last_name'        : lastName,
    'email'            : email,
    'gender'           : gender,
    'birth_date'       : birthDate.toIso8601String().split('T')[0],
    'weight'           : weight,
    'height'           : height,
    'profile_image_url': profileImageUrl,
  };
}
