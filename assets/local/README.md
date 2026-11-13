# Local client configuration

Run `python tool/prepare_local_config.py` from the project root to generate
`client.env` from the ignored `config.local.json`.

`client.env` is ignored by Git and contains only public client configuration.
It is bundled locally so plain `flutter run` can connect to your project.
Never use a secret or service-role key. Dart defines override this fallback.
Clones without this file still build and show an explicit configuration error.
