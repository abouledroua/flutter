import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';

void main() {
  final buffer = List<int>.filled(0xfffff, 0);
  for (var i = 0; i < buffer.length; ++i) {
    buffer[i] = i % 256;
  }

  test('stream/NO_COMPRESSION', () {
    // compress the buffer (assumption: deflate works correctly).
    final deflated = Deflate(buffer, level: Deflate.NO_COMPRESSION).getBytes();

    // re-cast the deflated bytes as a Uint8List (which is it's native type).
    // Do this so we can use use Uint8List.view to section off chunks of the
    // data to test streamed inflation.
    final deflatedBytes = deflated as Uint8List;

    // Create a stream inflator.
    final inflate = Inflate.stream();

    var bi = 0;

    // The section of the input buffer we're currently streaming.
    var streamOffset = 0;
    var streamSize = 1049;
    // Continue while we haven't streamed all of the data yet.
    while (streamOffset < deflatedBytes.length) {
      // Create a view of the input data for the bytes we're currently
      // streaming.
      final streamBytes =
          Uint8List.view(deflatedBytes.buffer, streamOffset, streamSize);
      streamOffset += streamBytes.length;

      // Set the bytes as the stream input.
      inflate.streamInput(streamBytes);

      // Inflate all of blocks available from the stream input.
      var inflated = inflate.inflateNext();
      while (inflated != null) {
        // Verify the current block we inflated matches the original buffer.
        for (var i = 0; i < inflated.length; ++i) {
          expect(inflated[i], equals(buffer[bi++]));
        }
        inflated = inflate.inflateNext();
      }
    }
  });

  test('git inflate block', () {
    final output = ZLibDecoder().decodeBytes(gitInflateInput);
    expect(output, equals(gitExpectedOutput));
  });
}

// Note: only 148 bytes consumed
List<int> gitInflateInput = const <int>[
  120, 156, 157, 203, 81, 10, 2, 33, 16, 0, 208, 127, 79, //
  225, 5, 138, 209, 209, 84, 136, 40, 250, 232, 28, 227, 104, 187, 11, 153, 49,
  184, 219, 245, 139, 142, 208, 255, 123, 67, 106, 213, 209, 39, 196, 152, 44,
  23, 99, 28, 101, 6, 182, 228, 114, 200, 72, 214, 115, 41, 236, 130, 225, 2,
  169, 168, 23, 73, 125, 14, 29, 3, 102, 247, 181, 181, 6, 111, 83, 102, 36,
  174, 132, 181, 128, 203, 16, 114, 102, 123, 72, 22, 248, 206, 138, 214, 49,
  119, 209, 55, 90, 133, 54, 125, 153, 72, 222, 244, 208, 199, 73, 182, 51, 207,
  210, 219,
  178,
  182, 125, 151, 233, 164, 13, 70, 140, 30, 146, 117, 122, 7, 17, 64, 113, 111,
  109, 25, 163, 254, 149, 213, 245, 183, 181, 87, 31, 225, 213, 68, 12, 159, 13,
  120, 156, 157, 203, 75, 10, 2, 49, 12, 0, 208, 125, 79, 209, 11, 40, 109, 147,
  54, 17, 68, 20, 23, 158, 35, 182, 153, 15, 56, 86, 74, 103, 188, 190, 226, 17,
  92, 63, 94, 111, 170, 54, 160, 39, 41, 69, 15, 153, 10, 201, 224, 196, 1, 0,
  249, 52, 8, 164, 72, 16, 83, 33, 197, 44, 98, 94, 210, 244, 217, 45, 35, 33,
  39,
  197, 194, 81, 2, 40, 37, 70, 230, 224, 129, 98, 8, 105, 72, 46, 220, 51, 127,
  17, 141, 172, 125, 170, 205, 222, 100, 109, 178, 217, 203, 40, 237, 45, 15,
  123,
  28, 219, 118, 206, 83, 171, 203, 188, 46, 251, 218, 198, 147, 245, 192, 192,
  209, 241, 193, 219, 157, 99, 231, 76, 174, 203, 50, 247, 174, 127, 101, 115,
  253, 109, 139, 230, 3, 184, 202, 66, 11, 159, 13, 120, 156, 157, 203, 75, 10,
  194, 48, 16, 0, 208, 125, 78, 145, 11, 40, 147, 207, 212, 25, 16, 81, 92, 120,
  142, 73, 154, 180, 5, 107, 100, 72, 235, 245, 5, 143, 224, 219, 191, 174, 165,
  88, 25, 144, 209, 229, 49, 103, 87, 176, 58, 25, 41, 122, 244, 1, 113, 32,
  116,
  33, 97, 138, 0, 145, 9, 205, 91, 180, 188, 186, 229, 68, 65, 124, 226, 44, 64,
  133, 137, 235, 0, 222, 87, 6, 143, 174, 84, 207, 181, 158, 18, 115, 116, 209,
  200, 214, 231, 166, 246, 33, 155, 202, 110, 111, 147, 232, 71, 158, 246, 60,
  233, 126, 205, 179, 182, 117, 217, 214, 99, 211, 233, 98, 93, 160, 64, 8, 20,
  208, 30, 128, 0, 76, 110, 235, 186, 244, 94, 254, 202, 230, 254, 219, 54, 152,
  47, 159, 221, 66, 7, 159, 13, 120, 156, 157, 203, 65, 14, 194, 32, 16, 0, 192,
  59, 175, 216, 15, 104, 96, 233, 2, 77, 140, 209, 120, 240, 29, 11, 11, 109,
  19,
  43, 134, 208, 250, 125, 141, 79, 240, 56, 135, 233, 45, 103, 224, 108, 9, 209,
  20, 77, 130, 35, 69, 178, 193, 15, 62, 14, 18, 71, 19, 138, 13, 218, 74, 46,
  134, 152, 212, 139, 91, 126, 118, 136, 214, 39, 137, 36, 78, 163, 33, 135,
  100,
  140, 20, 255, 133, 24, 55, 48, 178, 150, 52, 114, 198, 18, 20, 111, 125, 174,
  13, 238, 188, 53, 222, 225, 58, 113, 123, 243, 3, 78, 83, 219, 47, 105, 110,
  117, 93, 182, 245, 88, 219, 116, 6, 99, 131, 13, 164, 189, 67, 56, 232, 160,
  181, 74, 117, 93, 151, 222, 243, 95, 89, 221, 126, 27, 80, 125, 0, 241, 245,
  66,
  153, 159, 10, 120, 156, 157, 203, 75, 10, 194, 48, 16, 0, 208, 125, 78, 49,
  23,
  80, 102, 76, 243, 41, 72, 81, 186, 240, 28, 99, 38, 166, 5, 67, 96, 72, 234,
  245, 5, 143, 224, 219, 191, 174, 57, 67, 32, 241, 129, 232, 133, 115, 20, 177,
  214, 59, 78, 153, 132, 109, 228, 231, 68, 78, 144, 103, 97, 116, 65, 12, 143,
  190, 53, 133, 7, 15, 229, 3, 238, 133, 245, 195, 111, 184, 22, 61, 110, 105,
  211, 86, 247, 81, 207, 77, 203, 2, 100, 163, 141, 14, 195, 197, 195, 9, 35,
  162,
  73, 173, 214, 189, 247, 252, 87, 54, 235, 111, 3, 153, 47, 177, 98, 53, 137,
  174, 2, 120, 156, 51, 52, 48, 48, 51, 49, 81, 40, 72, 76, 206, 142, 79, 203,
  204, 73, 141, 47, 73, 45, 46, 209, 43, 169, 40, 97, 184, 189, 234, 228, 183,
  208, 189, 133, 25, 252, 146, 97, 183, 252, 28, 123, 210, 59, 143, 213, 52, 2,
  0,
  138, 233, 18, 240, 183, 5, 120, 156, 11, 201, 200, 44, 86, 0, 162, 146, 140,
  84,
  133, 146, 212, 226, 18, 133, 180, 252, 34, 133, 130, 196, 228, 108, 133, 180,
  204, 156, 212, 98, 61, 174, 16, 168, 130, 178, 212, 162, 226, 204, 252, 60, 5,
  35, 133, 252, 52, 176, 28, 166, 148, 9, 66, 10, 0, 44, 45, 29, 91, 173, 5,
  120,
  156, 51, 52, 48, 48, 51, 49, 81, 40, 72, 76, 206, 142, 79, 203, 204, 73, 141,
  207, 204, 75, 73, 173, 208, 43, 169, 40, 97, 224, 185, 166, 30, 214, 80, 215,
  177, 106, 203, 133, 142, 37, 27, 255, 27, 84, 116, 87, 132, 188, 54, 68, 87,
  94,
  146, 90, 92, 2, 86, 125, 123, 213, 201, 111, 161, 123, 11, 51, 248, 37, 195,
  110, 249, 57, 246, 164, 119, 30, 171, 105, 4, 0, 170, 76, 38, 187, 184, 3,
  120,
  156, 11, 201, 200, 44, 86, 0, 162, 68, 133, 146, 212, 226, 18, 133, 180, 252,
  34, 133, 130, 196, 228, 108, 133, 204, 188, 148, 212, 10, 133, 180, 204, 156,
  212, 98, 61, 174, 16, 168, 162, 178, 212, 162, 226, 204, 252, 60, 5, 35, 61,
  46,
  0, 44, 106, 19, 3, 173, 5, 120, 156, 51, 52, 48, 48, 51, 49, 81, 40, 72, 76,
  206, 142, 79, 203, 204, 73, 141, 207, 204, 75, 73, 173, 208, 43, 169, 40, 97,
  56, 83, 113, 253, 78, 200, 29, 189, 228, 9, 177, 107, 95, 179, 173, 221, 195,
  225, 246, 251, 164, 178, 33, 186, 242, 146, 212, 226, 18, 176, 234, 218, 201,
  71, 23, 61, 125, 119, 140, 67, 219, 137, 173, 233, 195, 191, 59, 159, 238,
  158,
  119, 217, 0, 0, 196, 63, 40, 215, 181, 2, 120, 156, 11, 201, 200, 44, 86, 0,
  162, 68, 133, 146, 212, 226, 18, 133, 180, 252, 34, 133, 130, 196, 228, 108,
  133, 204, 188, 148, 212, 10, 133, 180, 204, 156, 212, 98, 61, 46, 0, 245, 188,
  12, 191, 100, 129, 88, 120, 156, 11, 183, 153, 96, 3, 0, 3, 112, 1, 96, 174,
  2,
  120, 156, 51, 52, 48, 48, 51, 49, 81, 40, 72, 76, 206, 142, 79, 203, 204, 73,
  141, 47, 73, 45, 46, 209, 43, 169, 40, 97, 168, 157, 124, 116, 209, 211, 119,
  199, 56, 180, 157, 216, 154, 62, 252, 187, 243, 233, 238, 121, 151, 13, 0,
  148,
  124, 21, 4, 174, 2, 120, 156, 51, 52, 48, 48, 51, 49, 81, 40, 72, 76, 206,
  142,
  79, 203, 204, 73, 141, 47, 73, 45, 46, 209
];

List<int> gitExpectedOutput = const <int>[
  116, 114, 101, 101, 32, 56, 53, 57, 51, 51, 56, 57, //
  50, 99, 100, 49, 49, 52, 97, 98, 99, 48, 99, 50, 97, 52, 98, 55, 98, 51, 97,
  50,
  53, 99, 100, 100, 99, 52, 55, 49, 99, 100, 48, 57, 100, 10, 112, 97, 114, 101,
  110, 116, 32, 56, 55, 51, 98, 52, 100, 49, 49, 101, 101, 55, 53, 50, 57, 98,
  99,
  51, 97, 99, 101, 97, 51, 101, 100, 48, 52, 98, 48, 55, 98, 98, 99, 50, 54, 57,
  50, 48, 99, 102, 99, 10, 97, 117, 116, 104, 111, 114, 32, 71, 97, 117, 114,
  97,
  118, 32, 65, 103, 97, 114, 119, 97, 108, 32, 60, 103, 114, 118, 64, 99, 104,
  114, 111, 109, 105, 117, 109, 46, 111, 114, 103, 62, 32, 49, 51, 56, 51, 56,
  53,
  48, 57, 50, 52, 32, 45, 48, 56, 48, 48, 10, 99, 111, 109, 109, 105, 116, 116,
  101, 114, 32, 71, 97, 117, 114, 97, 118, 32, 65, 103, 97, 114, 119, 97, 108,
  32,
  60, 103, 114, 118, 64, 99, 104, 114, 111, 109, 105, 117, 109, 46, 111, 114,
  103,
  62, 32, 49, 51, 56, 51, 56, 53, 48, 57, 50, 52, 32, 45, 48, 56, 48, 48, 10,
  10,
  67, 111, 109, 109, 105, 116, 32, 53, 10
];
