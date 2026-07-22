# Pigeon generator

Rana pins Pigeon `27.2.0` in this isolated tool package because the app's
Riverpod 2 code-generation stack uses a different analyzer generation.

Run from the repository root:

```sh
dart --packages=tool/pigeon/.dart_tool/package_config.json \
  tool/pigeon/bin/generate.dart --input pigeons/rana_camera_api.dart
```

Both generated outputs are committed. CI should run the command and fail when
it changes either generated file.
