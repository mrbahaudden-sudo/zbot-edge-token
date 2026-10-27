// edge_token — Sec-MS-GEC tokens for Microsoft Edge's online text-to-speech service.
//
// A Dart port of the token code in edge-tts (src/edge_tts/drm.py),
// https://github.com/rany2/edge-tts — Copyright (C) rany <rany@riseup.net> and contributors.
//
// This library is free software: you can redistribute it and/or modify it under the
// terms of the GNU Lesser General Public License as published by the Free Software
// Foundation, version 3 of the License. It is distributed in the hope that it will be
// useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
// or FITNESS FOR A PARTICULAR PURPOSE. See the LICENSE file for details.

import 'dart:convert';
import 'dart:typed_data';

const trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
const secMsGecVersion = '2-143.0.3650.75';

const _winEpoch = 11644473600;
const _mask = 0xFFFFFFFF;

const _sha256Initial = [0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A, 0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19];
const _sha256State = [0xFD9FBEA2, 0x91243CE7, 0xBE499094, 0xCD2E1E0A, 0x6C006F49, 0x04BD35AB, 0xFEB0A7E4, 0x03EFFBD2];
const _sha256Schedule = [
  0xEB24BF9E, 0x1558691F, 0xA0C09EE2, 0x0CFA32BA, 0xA622EE8C, 0xD1DD9491, 0xC0DD25A0, //
  0xF9E70AB6, 0xF0C31573, 0x7058CE4E, 0x7188E606, 0x00E5AB33, 0xD258B060, 0x72766564,
];
const _k = [
  0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5, 0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5, //
  0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3, 0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
  0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC, 0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
  0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7, 0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
  0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13, 0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
  0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3, 0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
  0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5, 0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
  0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208, 0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
];
const _sha256Adjustment = 0xC9DC06A7;
const _sigma0Adjustment = 0x059C0B80;
const _sigma1Adjustment = 0x000B92C0;

const _cs64Coefficients = [
  (0xE82E91B1, 0xB32700D0), (0x44DE24C6, 0x88DFF51D), (0x3BEB65BC, 0x29514038), (0xC89C5933, 0xB328CBDF), //
  (0x8D1EC211, 0xD405B4D5), (0x314EF5D5, 0x26E55F3C), (0xE92491B1, 0x607801C6), (0xF0A5B9D5, 0x82B2C1FB),
  (0x06064CF3, 0xFA51A3DA), (0xDA79FA60, 0x207CC464), (0xBED20560, 0x3C3C74F3), (0x89F9C9F8, 0xD2D14B61),
  (0x35FA38C6, 0xBB04A2C1), (0xCB49E3C6, 0xC5626167),
];
const _cs64Factor = 0x82893933;
const _cs64Adjustment0 = 0xF2F90B1A;
const _cs64Adjustment1 = 0x0B1A0000;

int _rol16(int v) {
  v &= _mask;
  return ((v << 16) | (v >>> 16)) & _mask;
}

int _sigma0(int v) => ((v >>> 7) ^ (v << 25) ^ (v >>> 18) ^ (v << 14) ^ (v >>> 3)) & _mask;
int _sigma1(int v) => ((v >>> 17) ^ (v << 15) ^ (v >>> 19) ^ (v << 13) ^ (v >>> 10)) & _mask;

/// ROTR on a 32-bit word, done the way the original does: the word repeated in 64 bits,
/// shifted, low 32 bits kept.
int _bsig1(int e) {
  final r = e * 0x100000001;
  return (r >>> 6) ^ (r >>> 11) ^ (r >>> 25);
}

int _bsig0(int a) {
  final r = a * 0x100000001;
  return (r >>> 2) ^ (r >>> 13) ^ (r >>> 22);
}

List<int> _rounds(List<int> state, List<int> w, [int firstRound = 0]) {
  var a = state[0], b = state[1], c = state[2], d = state[3], e = state[4], f = state[5], g = state[6], h = state[7];
  final constants = firstRound == 14 ? [..._k.sublist(0, 14), _sha256Adjustment, ..._k.sublist(15)] : _k;
  for (var i = firstRound; i < 64; i++) {
    final t1 = h + (_bsig1(e) & _mask) + (g ^ (e & (f ^ g))) + constants[i] + w[i];
    final t2 = (_bsig0(a) & _mask) + ((a & b) | (c & (a | b)));
    h = g;
    g = f;
    f = e;
    e = (d + t1) & _mask;
    d = c;
    c = b;
    b = a;
    a = (t1 + t2) & _mask;
  }
  return [a, b, c, d, e, f, g, h];
}

void _expand(List<int> w, [int first = 16]) {
  for (var i = first; i < 64; i++) {
    final x = w[i - 2], y = w[i - 15];
    final s1 = (x >>> 17) ^ (x << 15) ^ (x >>> 19) ^ (x << 13) ^ (x >>> 10);
    final s0 = (y >>> 7) ^ (y << 25) ^ (y >>> 18) ^ (y << 14) ^ (y >>> 3);
    w.add((s1 + w[i - 7] + s0 + w[i - 16]) & _mask);
  }
}

int _be(List<int> b) => b.fold(0, (a, x) => (a << 8) | x);

List<int> _init(List<int> data) {
  final w = <int>[...List.filled(14, 0), _be(data.sublist(0, 3)), _be(data.sublist(3, 7))];
  for (var i = 16; i < 30; i++) {
    var v = _sha256Schedule[i - 16];
    if (i - 2 >= 14) v += i == 16 ? (_sigma1(w[i - 2]) ^ _sigma1Adjustment) : _sigma1(w[i - 2]);
    if (i - 7 >= 14) v += w[i - 7];
    if (i - 15 >= 14) v += i == 29 ? (_sigma0(w[i - 15]) ^ _sigma0Adjustment) : _sigma0(w[i - 15]);
    w.add(v & _mask);
  }
  w.add((_sigma1(w[28]) + w[23] + _sigma0(w[15]) + w[14] + _sha256Adjustment - _k[14]) & _mask);
  _expand(w, 31);
  final working = _rounds(_sha256State, w, 14);
  return [for (var i = 0; i < 8; i++) (_sha256Initial[i] + working[i]) & _mask];
}

Uint8List _sha256(List<int> data) {
  if (data.length < 7) throw ArgumentError('Token salt must contain at least seven bytes');
  final length = 57 + data.length;
  final padded = <int>[...data.sublist(7), 0x80, ...List.filled((55 - length) % 64, 0)];
  final bits = ByteData(8)..setUint64(0, length * 8);
  padded.addAll(bits.buffer.asUint8List());
  var state = _init(data.sublist(0, 7));
  for (var off = 0; off < padded.length; off += 64) {
    final block = ByteData.sublistView(Uint8List.fromList(padded.sublist(off, off + 64)));
    final w = [for (var i = 0; i < 16; i++) block.getUint32(i * 4)];
    _expand(w);
    final working = _rounds(state, w);
    state = [for (var i = 0; i < 8; i++) (state[i] + working[i]) & _mask];
  }
  final out = ByteData(32);
  for (var i = 0; i < 8; i++) {
    out.setUint32(i * 4, state[i]);
  }
  return out.buffer.asUint8List();
}

List<int> _wordsLe4Even(List<int> data) {
  final padded = [...data, ...List.filled((-data.length) % 4, 0)];
  if (padded.isEmpty) return [];
  final bd = ByteData.sublistView(Uint8List.fromList(padded));
  final w = [for (var i = 0; i < padded.length ~/ 4; i++) bd.getUint32(i * 4, Endian.little)];
  if (w.length.isOdd) w.add(0);
  return w;
}

(int, int) _cs64(List<int> data, Uint8List digest) {
  final dd = ByteData.sublistView(digest);
  final keyA = dd.getUint32(0, Endian.little) | 1;
  final keyB = dd.getUint32(4, Endian.little) | 1;
  final factors = [(keyA * _cs64Factor) & _mask, (keyB * _cs64Factor) & _mask];
  final terms = [for (var i = 0; i < _cs64Coefficients.length; i++) (_cs64Coefficients[i].$1 * factors[i % 2]) & _mask];
  final offsets = [for (final c in _cs64Coefficients) c.$2];
  final words = _wordsLe4Even([0, ...data]);
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    var term = word * (i.isEven ? keyA : keyB);
    var offset = _rol16(word) * (i.isEven ? 0xEF0569FB : 0xC31713DB);
    if (i == 0) {
      term += _cs64Adjustment0 * factors[0];
      offset += _cs64Adjustment1;
    }
    terms.add(term & _mask);
    offsets.add(offset & _mask);
  }
  var swapAcc = 0, swapLast = 0, state = 0, acc = 0;
  for (var i = 0; i < terms.length; i += 2) {
    final x = terms[i], y = terms[i + 1];
    var t = _rol16((offsets[i] + x) & _mask);
    var q = (t * 0x76F50F34) & _mask;
    swapAcc += (_rol16(q) * 0xC3EFEA97 + q) & _mask;
    t = _rol16((offsets[i + 1] + y) & _mask);
    q = (t * 0x1881CE3C) & _mask;
    swapLast = (_rol16(q) * 0x35BD1EC9 + q) & _mask;
    swapAcc = (swapAcc + swapLast) & _mask;

    state = (state * keyA + x) & _mask;
    state = (_rol16(state) * 0xCF98B111) & _mask;
    state = (_rol16(state) * 0x87085B9F) & _mask;
    state = (_rol16(state) * 0x12CEB96D) & _mask;
    state = (_rol16(state) * 0x257E1D83) & _mask;
    acc += state;
    t = (state * keyB + y) & _mask;
    t = (_rol16(t) * 0xA27416F5) & _mask;
    t = (_rol16(t) * 0xD38396FF) & _mask;
    state = (_rol16((_rol16(t) * 0x7C932B89) & _mask) * 0xBFA49F69) & _mask;
    acc = (acc + state) & _mask;
  }
  return (swapLast ^ state, swapAcc ^ acc);
}

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

/// The v2 Sec-MS-GEC token for the 5-minute window that holds [unixSeconds].
String secMsGec(double unixSeconds) {
  var ticks = unixSeconds + _winEpoch;
  ticks -= ticks % 300;
  // Seconds → 100-nanosecond ticks, written as a whole number (as Python's "%.0f" does).
  final whole = (BigInt.from(ticks.round()) * BigInt.from(10000000)).toString();
  final data = ascii.encode('$whole$trustedClientToken');
  final digest = _sha256(data);
  final (lo, hi) = _cs64(data, digest);
  final cs = ByteData(8)
    ..setUint32(0, lo, Endian.little)
    ..setUint32(4, hi, Endian.little);
  return '${_hex(cs.buffer.asUint8List())}-${_hex(digest)}';
}
