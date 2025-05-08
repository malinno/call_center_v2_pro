class ZSolutionUser {
  final int id;
  final String userName;
  final String email;
  final String roleName;
  final String? extension;
  final String? host;
  final String? pass;
  final String token;

  ZSolutionUser({
    required this.id,
    required this.userName,
    required this.email,
    required this.roleName,
    this.extension,
    this.host,
    this.pass,
    required this.token,
  });

  factory ZSolutionUser.fromJson(Map<String, dynamic> json) {
    final userData = json['data']['user'];
    return ZSolutionUser(
      id: userData['id'],
      userName: userData['userName'] ?? '',
      email: userData['email'] ?? '',
      roleName: userData['roleName'] ?? '',
      extension: userData['extension'],
      host: userData['host'],
      pass: userData['pass'],
      token: json['data']['token'],
    );
  }

  bool get isAdmin => roleName == 'Admin';
  bool get isSystemAdministrator => roleName == 'systemAdministrator';
  bool get isSystemSuppervisor => roleName == 'SystemSuppervisor';
  bool get isManager => roleName == 'Manager';
  bool get isLeader => roleName == 'Leader';
  bool get isAgent => roleName == 'Agent';

  Map<String, dynamic> toJson() => {
    'id': id,
    'userName': userName,
    'email': email,
    'roleName': roleName,
    'extension': extension,
    'host': host,
    'pass': pass,
    'token': token,
  };
} 