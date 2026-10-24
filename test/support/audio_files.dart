import 'dart:io';
import 'dart:typed_data';

/// Minimal valid MPEG-1 Layer III stream (silent frames, 128 kbps, 44.1 kHz).
///
/// With [emptyId3] an empty ID3v2.4 header is prepended; audio_metadata_reader
/// can only *update* existing tags, so tests that write tags need it.
void writeMp3(File f, {int frames = 40, bool emptyId3 = false}) {
  final frame = Uint8List(417)
    ..[0] = 0xFF
    ..[1] = 0xFB
    ..[2] = 0x90
    ..[3] = 0x00;
  final out = BytesBuilder();
  if (emptyId3) {
    out.add(const [0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0, 0, 0, 0]);
  }
  for (var i = 0; i < frames; i++) {
    out.add(frame);
  }
  f.createSync(recursive: true);
  f.writeAsBytesSync(out.toBytes());
}

/// 8 kHz mono 16-bit PCM WAV of [seconds] of silence.
void writeWav(File f, {int seconds = 2}) {
  const rate = 8000;
  final dataLen = rate * 2 * seconds;
  final b = ByteData(44 + dataLen);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + dataLen, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, dataLen, Endian.little);
  f.createSync(recursive: true);
  f.writeAsBytesSync(b.buffer.asUint8List());
}
