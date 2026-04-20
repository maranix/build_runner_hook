import 'package:dart_mappable/dart_mappable.dart';

part 'user.mapper.dart';

@MappableClass()
final class User with UserMappable {
  const User(this.id, this.name);

  final int id;
  final String name;
}
