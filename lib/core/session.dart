/// What /api/api-login returns that the app needs afterwards. Mirrors the
/// `menuContext` + `userData` that lms_k12's AuthContext persists.
class Session {
  Session({
    required this.token,
    required this.userId,
    required this.subInstituteId,
    required this.clientId,
    required this.userProfileId,
    required this.userProfileName,
    required this.name,
    required this.email,
    required this.schoolName,
    this.logoUrl,
    this.imageUrl,
    this.mobileSyear,
    this.raw = const {},
  });

  final String token;
  final int userId;
  final int subInstituteId;
  final int clientId;
  final int userProfileId;
  final String userProfileName;
  final String name;
  final String email;
  final String schoolName;
  final String? logoUrl;
  final String? imageUrl;
  final String? mobileSyear;
  final Map<String, dynamic> raw;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Body shared by every menu call, as lms_k12's useMenuRights sends it.
  Map<String, dynamic> get menuContext => {
        'type': 'API',
        'sub_institute_id': subInstituteId,
        'user_id': userId,
        'user_profile_name': userProfileName,
        'user_profile_id': userProfileId,
        'client_id': clientId,
      };

  /// `data` is the login response's `data` object (or the whole response).
  factory Session.fromLogin(Map<String, dynamic> response, String fallbackEmail, String host) {
    final data = (response['data'] is Map<String, dynamic>)
        ? response['data'] as Map<String, dynamic>
        : response;

    int num_(dynamic v) => int.tryParse('${v ?? ''}') ?? 0;
    String str(dynamic v) => v == null ? '' : '$v';

    final email = str(data['email']).isNotEmpty ? str(data['email']) : fallbackEmail;
    final fullName = [data['first_name'], data['middle_name'], data['last_name']]
        .map(str)
        .where((p) => p.trim().isNotEmpty)
        .join(' ');
    final name = fullName.isNotEmpty
        ? fullName
        : (str(data['user_name']).isNotEmpty ? str(data['user_name']) : email.split('@').first);

    final hostName = str(data['host_name']).isNotEmpty ? str(data['host_name']) : host;
    final logo = str(data['logo']);
    final image = str(data['image']);

    return Session(
      token: str(data['user_token']),
      userId: num_(data['id'] ?? data['user_id']),
      subInstituteId: num_(data['sub_institute_id']),
      clientId: num_(data['client_id']),
      userProfileId: num_(data['user_profile_id']),
      userProfileName: str(data['user_profile'] ?? data['user_profile_name']),
      name: name,
      email: email,
      schoolName: str(data['school_name']),
      logoUrl: logo.isEmpty ? null : '$hostName/admin_dep/images/$logo',
      imageUrl: image.isEmpty ? null : image,
      mobileSyear: str(data['mobile_syear']).isEmpty ? null : str(data['mobile_syear']),
      raw: data,
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'userId': userId,
        'subInstituteId': subInstituteId,
        'clientId': clientId,
        'userProfileId': userProfileId,
        'userProfileName': userProfileName,
        'name': name,
        'email': email,
        'schoolName': schoolName,
        'logoUrl': logoUrl,
        'imageUrl': imageUrl,
        'mobileSyear': mobileSyear,
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        token: j['token'] as String? ?? '',
        userId: j['userId'] as int? ?? 0,
        subInstituteId: j['subInstituteId'] as int? ?? 0,
        clientId: j['clientId'] as int? ?? 0,
        userProfileId: j['userProfileId'] as int? ?? 0,
        userProfileName: j['userProfileName'] as String? ?? '',
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        schoolName: j['schoolName'] as String? ?? '',
        logoUrl: j['logoUrl'] as String?,
        imageUrl: j['imageUrl'] as String?,
        mobileSyear: j['mobileSyear'] as String?,
      );
}
