import 'package:shieldnet/core/utils/logger.dart';
import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../security/crypto_utils.dart';

/// Modèle d'élément de liste noire avec numéro masqué pour affichage
class BlacklistedNumber {
  final String phoneHash;
  final String? maskedNumber;
  final String category; // 'fraud', 'telemarketing', 'financial_scam', etc.
  final int riskScore; // 0 à 100
  final int reportsCount;
  final String updatedAt;

  BlacklistedNumber({
    required this.phoneHash,
    this.maskedNumber,
    required this.category,
    required this.riskScore,
    required this.reportsCount,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'phone_hash': phoneHash,
      'masked_number': maskedNumber,
      'category': category,
      'risk_score': riskScore,
      'reports_count': reportsCount,
      'updated_at': updatedAt,
    };
  }

  factory BlacklistedNumber.fromMap(Map<String, dynamic> map) {
    return BlacklistedNumber(
      phoneHash: map['phone_hash'] as String,
      maskedNumber: map['masked_number'] as String?,
      category: (map['category'] as String?) ?? 'other',
      riskScore: (map['risk_score'] as int?) ?? 0,
      reportsCount: (map['reports_count'] as int?) ?? 1,
      updatedAt: (map['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }
}

/// Modèle d'un numéro d'urgence ou d'un contact en liste blanche prioritaire
class EmergencyContact {
  final String phoneHash;
  final String rawNumber;
  final String label;
  final bool isSystemCritical;
  final String createdAt;

  EmergencyContact({
    required this.phoneHash,
    required this.rawNumber,
    required this.label,
    this.isSystemCritical = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'phone_hash': phoneHash,
      'raw_number': rawNumber,
      'label': label,
      'is_system_critical': isSystemCritical ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      phoneHash: map['phone_hash'] as String,
      rawNumber: (map['raw_number'] as String?) ?? '',
      label: (map['label'] as String?) ?? 'Contact d\'urgence',
      isSystemCritical: ((map['is_system_critical'] as int?) ?? 0) == 1,
      createdAt: (map['created_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }
}

/// Helper SQLite local sécurisé
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // Numéros d'urgence canadiens / nord-américains protégés par défaut
  static const List<Map<String, String>> defaultEmergencyNumbers = [
    {'number': '911', 'label': 'Urgences (Police, Pompiers, Ambulance)'},
    {'number': '811', 'label': 'Info-Santé / Info-Social Québec'},
    {'number': '988', 'label': 'Prévention du Suicide & Crise (Canada)'},
    {'number': '211', 'label': 'Aide communautaire & Services sociaux'},
    {'number': '311', 'label': 'Services municipaux & Citoyens'},
    {'number': '511', 'label': 'Info Transports Québec'},
  ];

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shieldnet_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE blacklist (
        phone_hash TEXT PRIMARY KEY,
        masked_number TEXT,
        category TEXT NOT NULL,
        risk_score INTEGER NOT NULL,
        reports_count INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_category ON blacklist(category)
    ''');

    await db.execute('''
      CREATE TABLE user_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone_hash TEXT NOT NULL,
        category TEXT NOT NULL,
        comment TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE emergency_whitelist (
        phone_hash TEXT PRIMARY KEY,
        raw_number TEXT NOT NULL,
        label TEXT NOT NULL,
        is_system_critical INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await _seedDefaultEmergencyNumbers(db);
  }

  Future<void> _seedDefaultEmergencyNumbers(Database db) async {
    final now = DateTime.now().toIso8601String();
    for (final entry in defaultEmergencyNumbers) {
      final num = entry['number']!;
      final label = entry['label']!;
      final hash = await CryptoUtils.hashPhoneNumberAsync(num);
      await db.insert(
        'emergency_whitelist',
        {
          'phone_hash': hash,
          'raw_number': num,
          'label': label,
          'is_system_critical': 1,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE blacklist ADD COLUMN masked_number TEXT');
      } catch (e) {
        AppLogger.log('[DatabaseHelper] Colonne masked_number déjà présente ou ignorée: $e');
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS emergency_whitelist (
            phone_hash TEXT PRIMARY KEY,
            raw_number TEXT NOT NULL,
            label TEXT NOT NULL,
            is_system_critical INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await _seedDefaultEmergencyNumbers(db);
      } catch (e) {
        AppLogger.log('[DatabaseHelper] Table emergency_whitelist déjà présente ou erreur migration: $e');
      }
    }
  }

  /// Insère ou met à jour un numéro indésirable dans le cache
  Future<void> insertOrUpdateBlacklistedNumber(BlacklistedNumber number) async {
    final db = await instance.database;
    await db.insert(
      'blacklist',
      number.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await checkpointWAL();
  }

  /// Insère ou met à jour en lot un ensemble de numéros indésirables (optimisé via SQLite Batch)
  Future<void> batchInsertOrUpdateBlacklistedNumbers(List<BlacklistedNumber> numbers) async {
    if (numbers.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (final number in numbers) {
      batch.insert(
        'blacklist',
        number.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await checkpointWAL();
  }

  /// Supprime une liste de numéros par leurs hashs (réconciliation des faux-positifs / déblocage admin)
  Future<int> deleteBatchBlacklistedNumbers(List<String> hashes) async {
    if (hashes.isEmpty) return 0;
    final db = await instance.database;
    final batch = db.batch();
    for (final hash in hashes) {
      batch.delete('blacklist', where: 'phone_hash = ?', whereArgs: [hash]);
    }
    final results = await batch.commit(noResult: false);
    await checkpointWAL();
    return results.whereType<int>().fold<int>(0, (sum, count) => sum + count);
  }

  /// Force le commit WAL vers le fichier .db principal (accessible immédiatement par le code natif Android Kotlin)
  Future<void> checkpointWAL() async {
    try {
      final db = await instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL);');
    } catch (e) {
      AppLogger.log('[DatabaseHelper] WAL Checkpoint non supporté ou ignoré: $e');
    }
  }

  /// Retourne le chemin absolu du fichier SQLite
  Future<String> getDatabaseFilePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return join(docsDir.path, 'shieldnet_cache.db');
  }

  /// Vérifie si un numéro (non masqué) est présent dans la liste noire locale
  Future<BlacklistedNumber?> checkNumber(String rawPhoneNumber) async {
    final hash = await CryptoUtils.hashPhoneNumberAsync(rawPhoneNumber);
    final db = await instance.database;

    final maps = await db.query(
      'blacklist',
      where: 'phone_hash = ?',
      whereArgs: [hash],
    );

    if (maps.isNotEmpty) {
      return BlacklistedNumber.fromMap(maps.first);
    }
    return null;
  }

  /// Récupère l'ensemble du cache hors-ligne
  Future<List<BlacklistedNumber>> getAllBlacklistedNumbers() async {
    final db = await instance.database;
    final result = await db.query('blacklist', orderBy: 'risk_score DESC');
    return result.map((json) => BlacklistedNumber.fromMap(json)).toList();
  }

  /// Vide l'intégralité du cache local
  Future<int> clearCache() async {
    final db = await instance.database;
    final deleted = await db.delete('blacklist');
    await checkpointWAL();
    return deleted;
  }

  // ==================== LISTE BLANCHE D'URGENCE (EMERGENCY ALLOWLIST) ====================

  /// Récupère tous les numéros d'urgence et contacts prioritaires protégés
  Future<List<EmergencyContact>> getAllEmergencyContacts() async {
    final db = await instance.database;
    final maps = await db.query(
      'emergency_whitelist',
      orderBy: 'is_system_critical DESC, label ASC',
    );
    return maps.map((m) => EmergencyContact.fromMap(m)).toList();
  }

  /// Ajoute un contact d'urgence personnalisé (ex: médecin, hôpital, proche)
  Future<EmergencyContact> addEmergencyContact(String rawNumber, String label) async {
    final hash = await CryptoUtils.hashPhoneNumberAsync(rawNumber);
    final now = DateTime.now().toIso8601String();
    final contact = EmergencyContact(
      phoneHash: hash,
      rawNumber: rawNumber.trim(),
      label: label.trim(),
      isSystemCritical: false,
      createdAt: now,
    );

    final db = await instance.database;
    await db.insert(
      'emergency_whitelist',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await checkpointWAL();
    return contact;
  }

  /// Supprime un contact d'urgence personnalisé (les numéros système critiques 911/811/988 sont protégés)
  Future<bool> removeEmergencyContact(String phoneHash) async {
    final db = await instance.database;
    final deleted = await db.delete(
      'emergency_whitelist',
      where: 'phone_hash = ? AND is_system_critical = 0',
      whereArgs: [phoneHash],
    );
    await checkpointWAL();
    return deleted > 0;
  }

  /// Vérifie si un numéro donné bénéficie de l'immunité d'urgence
  Future<bool> isEmergencyNumber(String rawPhoneNumber) async {
    var cleanDigits = rawPhoneNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length == 4 && cleanDigits.startsWith('1')) {
      cleanDigits = cleanDigits.substring(1);
    }
    const standardEmergencyShortCodes = {'911', '112', '811', '988', '211', '311', '511'};
    if (standardEmergencyShortCodes.contains(cleanDigits) || standardEmergencyShortCodes.contains(rawPhoneNumber.trim())) {
      return true;
    }

    final hash = await CryptoUtils.hashPhoneNumberAsync(rawPhoneNumber);
    final db = await instance.database;
    final maps = await db.query(
      'emergency_whitelist',
      where: 'phone_hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return maps.isNotEmpty;
  }
}

