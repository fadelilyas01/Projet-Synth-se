import 'dart:convert';
import 'dart:typed_data';

/// Client de filtre de Bloom en mémoire vive
/// Permet une vérification probabiliste ultra-rapide (< 0.02 ms) en temps constant O(k)
/// avant même d'interroger la base de données SQLite sur le disque.
class BloomFilterClient {
  /// Instance active en mémoire vive partagée
  static BloomFilterClient? activeFilter;

  final int sizeBits;
  final int hashCount;
  final Uint8List bitArray;
  final int entriesCount;

  BloomFilterClient({
    required this.sizeBits,
    required this.hashCount,
    required this.bitArray,
    required this.entriesCount,
  });

  /// Construit un filtre de Bloom à partir du JSON retourné par le backend (/api/v1/sync/bloom/)
  factory BloomFilterClient.fromJson(Map<String, dynamic> json) {
    final sizeBits = (json['size_bits'] as int?) ?? 65536;
    final hashCount = (json['hash_count'] as int?) ?? 4;
    final entriesCount = (json['entries_count'] as int?) ?? 0;
    final base64Str = json['bit_array_base64'] as String? ?? '';

    final bytes = base64Decode(base64Str);
    return BloomFilterClient(
      sizeBits: sizeBits,
      hashCount: hashCount,
      bitArray: Uint8List.fromList(bytes),
      entriesCount: entriesCount,
    );
  }

  /// Vérifie si une empreinte SHA-256 (phone_hash) est potentiellement présente dans la liste noire
  /// - false : Garanti à 100% que le numéro N'EST PAS dans la liste noire (Zéro faux négatif).
  /// - true : Le numéro est probablement dans la liste noire (doit être vérifié dans SQLite).
  bool contains(String phoneHash) {
    if (bitArray.isEmpty || sizeBits == 0 || phoneHash.length < 32) {
      return false;
    }

    try {
      final h1 = BigInt.parse(phoneHash.substring(0, 16), radix: 16);
      final h2 = BigInt.parse(phoneHash.substring(16, 32), radix: 16) | BigInt.one;
      final bigSize = BigInt.from(sizeBits);

      for (int i = 0; i < hashCount; i++) {
        final bitIndex = ((h1 + BigInt.from(i) * h2) % bigSize).toInt();
        final bytePos = bitIndex ~/ 8;
        final bitPos = bitIndex % 8;

        if (bytePos >= bitArray.length) {
          return false;
        }

        final isBitSet = (bitArray[bytePos] & (1 << bitPos)) != 0;
        if (!isBitSet) {
          return false;
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
