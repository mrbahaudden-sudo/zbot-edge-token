// edge_token [--time <unix seconds>]
// Prints the Sec-MS-GEC token for now (or for the given time) on one line.
//
// Part of edge_token, a Dart port of edge-tts' token code. LGPL-3.0; see LICENSE.
import 'package:edge_token/edge_token.dart';

void main(List<String> args) {
  final i = args.indexOf('--time');
  final t = i >= 0 && i + 1 < args.length ? double.parse(args[i + 1]) : DateTime.now().millisecondsSinceEpoch / 1000;
  print(secMsGec(t));
}
