# Pip branding sources

`app_icon.png` and `pip_foreground.png` are rendered from the existing
`PipMascot` CustomPainter by `flutter test tool/generate_brand_assets.dart`.
They are 1024x1024. `play_store_icon.png` is the generated opaque 512x512 icon
from `web/icons/Icon-512.png`.

Regenerate platform assets with `dart run flutter_launcher_icons` and
`dart run flutter_native_splash:create`. The YAML generator configs repeat
`LingoPalette` values because native generators run outside Flutter's theme.
