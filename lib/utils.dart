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
}
