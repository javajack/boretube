import 'dart:convert';
import 'dart:typed_data';

/// ADB wire commands (little-endian ASCII).
class AdbCommand {
  static const int cnxn = 0x4e584e43;
  static const int auth = 0x48545541;
  static const int open = 0x4e45504f;
  static const int okay = 0x59414b4f;
  static const int clse = 0x45534c43;
  static const int wrte = 0x45545257;
  static const int stls = 0x534c5453;

  static String name(int cmd) => switch (cmd) {
        cnxn => 'CNXN',
        auth => 'AUTH',
        open => 'OPEN',
        okay => 'OKAY',
        clse => 'CLSE',
        wrte => 'WRTE',
        stls => 'STLS',
        _ => '0x${cmd.toRadixString(16)}',
      };
}

/// AUTH message arg0 values.
class AdbAuthType {
  static const int token = 1;
  static const int signature = 2;
  static const int rsaPublicKey = 3;
}

/// Protocol version that lets adbd skip the payload checksum.
const int adbVersion = 0x01000001;
const int adbMaxPayload = 256 * 1024;
const int adbHeaderLength = 24;

/// One ADB packet: a 24-byte header plus an optional payload.
class AdbMessage {
  final int command;
  final int arg0;
  final int arg1;
  final Uint8List payload;

  AdbMessage(this.command, this.arg0, this.arg1, [Uint8List? payload])
      : payload = payload ?? Uint8List(0);

  factory AdbMessage.text(int command, int arg0, int arg1, String text) =>
      AdbMessage(command, arg0, arg1,
          Uint8List.fromList(utf8.encode('$text\u0000')));

  Uint8List encode() {
    final out = Uint8List(adbHeaderLength + payload.length);
    final h = ByteData.sublistView(out, 0, adbHeaderLength);
    h.setUint32(0, command, Endian.little);
    h.setUint32(4, arg0, Endian.little);
    h.setUint32(8, arg1, Endian.little);
    h.setUint32(12, payload.length, Endian.little);
    h.setUint32(16, checksum(payload), Endian.little);
    h.setUint32(20, command ^ 0xffffffff, Endian.little);
    out.setRange(adbHeaderLength, out.length, payload);
    return out;
  }

  /// Decodes a header; returns the message with an empty payload and the
  /// payload length still to read.
  static (AdbMessage, int) decodeHeader(Uint8List header) {
    if (header.length != adbHeaderLength) {
      throw const FormatException('ADB header must be 24 bytes');
    }
    final h = ByteData.sublistView(header);
    final cmd = h.getUint32(0, Endian.little);
    final magic = h.getUint32(20, Endian.little);
    if (magic != (cmd ^ 0xffffffff)) {
      throw FormatException('Bad ADB magic for ${AdbCommand.name(cmd)}');
    }
    return (
      AdbMessage(cmd, h.getUint32(4, Endian.little),
          h.getUint32(8, Endian.little)),
      h.getUint32(12, Endian.little),
    );
  }

  /// Legacy byte-sum checksum; harmless to send even when not checked.
  static int checksum(Uint8List data) {
    var sum = 0;
    for (final b in data) {
      sum = (sum + b) & 0xffffffff;
    }
    return sum;
  }

  @override
  String toString() => '${AdbCommand.name(command)}($arg0, $arg1, '
      '${payload.length}b)';
}
