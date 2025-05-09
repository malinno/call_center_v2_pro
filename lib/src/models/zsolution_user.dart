class ZSolutionUser {
  final int? id;
  final String? userName;
  final String? email;
  final String? roleName;
  final String? extension;
  final String? host;
  final String? pass;
  final String? token;

  ZSolutionUser({
    this.id,
    this.userName,
    this.email,
    this.roleName,
    this.extension,
    this.host,
    this.pass,
    this.token,
  });

  factory ZSolutionUser.fromJson(Map<String, dynamic> json) {
    return ZSolutionUser(
      id: json['id'],
      userName: json['userName'],
      email: json['email'],
      roleName: json['roleName'],
      extension: json['extension'],
      host: json['host'],
      pass: json['pass'],
      token: json['token'],
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