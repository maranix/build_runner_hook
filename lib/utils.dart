import 'dart:io' as io;

import 'package:path/path.dart' as p;

extension type TempDirectory._(String path) {
  TempDirectory() : path = p.normalize(io.Directory.systemTemp.path);

  TempDirectory.resolveFor(String relativePath)
    : path = p.normalize(
        p.join(
          io.Directory.systemTemp.path,
          relativePath,
        ),
      );

  io.Directory get asDirectory => io.Directory(path);

  io.File file(String filename) => io.File(
    p.normalize(
      p.join(path, filename),
    ),
  );

  io.Directory directory(String dirname) => io.Directory(
    p.normalize(
      p.join(path, dirname),
    ),
  );
}

extension type TempFile._(io.File file) {
  TempFile.fromPath(String path, String filename)
    : file = io.File(
        p.normalize(
          p.join(path, filename),
        ),
      );

  io.File get asFile => file;

  bool get existsSync => file.existsSync();
  Future<bool> get exists => file.exists();

  Future<io.File> create({
    bool recursive = false,
    bool exclusive = false,
  }) async {
    final exists = await file.exists();
    if (exists) return file;

    return file.create(recursive: recursive, exclusive: exclusive);
  }

  Future<void> delete({bool recursive = false}) async {
    final exists = await file.exists();
    if (!exists) return;

    await file.delete(recursive: recursive);
  }
}
