# edge_token

Prints a `Sec-MS-GEC` token for Microsoft Edge's online text-to-speech service.

```
edge_token                 # token for now
edge_token --time 1767225600
```

It is a Dart port of the token code in [edge-tts](https://github.com/rany2/edge-tts)
(`src/edge_tts/drm.py`, the v2 token used with `Sec-MS-GEC-Version: 2-143.0.3650.75`).
ZBot ships it as a separate small program and runs it to get a token; it is not built
into ZBot itself.

## Build

```
dart pub get
dart compile exe bin/edge_token.dart -o edge_token.exe
dart test
```

## Licence

GNU Lesser General Public License v3.0, as edge-tts — see [LICENSE](LICENSE).
Original code: Copyright (C) rany <rany@riseup.net> and the edge-tts contributors.
