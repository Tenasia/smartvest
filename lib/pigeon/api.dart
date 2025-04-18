import 'package:pigeon/pigeon.dart';

class UserDetails {
  String? userID;
  String? email;
  String? displayName;
}

@HostApi()
abstract class UserApi {
  UserDetails getUserDetails(String userId);
}