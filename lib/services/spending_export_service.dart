import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class SpendingExportService {
  SpendingExportService._();
  static final instance = SpendingExportService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> _fetchSpendings({
    String? type, // 'personal', 'other', or null for all
  }) async {
    final uid = _auth.currentUser!.uid;
    Query query = _db.collection('users').doc(uid).collection('spendings');

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    final snap = await query.orderBy('date', descending: false).get();

    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return {
        'amount': data['amount'] ?? 0,
        'category': data['category'] ?? '',
        'note': data['note'] ?? '',
        'date': (data['date'] as Timestamp?)?.toDate(),
        'type': data['type'] ?? '',
      };
    }).toList();
  }

  /// 📁 Get an app documents subfolder
  Future<Directory> _getExportDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  // ---------------------------------------------------------------------------
  //  EXCEL / CSV EXPORT
  // ---------------------------------------------------------------------------
  Future<File> exportToCsv({String? type}) async {
    final spendings = await _fetchSpendings(type: type);
    final dir = await _getExportDir();

    final now = DateTime.now();
    final typeLabel = type ?? 'all';
    final file = File(
      '${dir.path}/spendings_${typeLabel}_${now.millisecondsSinceEpoch}.csv',
    );

    // header row
    final rows = <List<dynamic>>[
      ['Date', 'Type', 'Category', 'Amount', 'Note'],
    ];

    for (final s in spendings) {
      rows.add([
        s['date']?.toString() ?? '',
        s['type'],
        s['category'],
        s['amount'],
        s['note'],
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csvData);

    return file;
  }

  // ---------------------------------------------------------------------------
  //  PDF EXPORT
  // ---------------------------------------------------------------------------
  Future<File> exportToPdf({String? type}) async {
    final spendings = await _fetchSpendings(type: type);
    final dir = await _getExportDir();

    final now = DateTime.now();
    final typeLabel = type ?? 'all';
    final file = File(
      '${dir.path}/spendings_${typeLabel}_${now.millisecondsSinceEpoch}.pdf',
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Spending Report (${typeLabel.toUpperCase()})',
              style: pw.TextStyle(fontSize: 20),
            ),
          ),
          pw.Text(
            'Generated on: $now',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: const ['Date', 'Type', 'Category', 'Amount', 'Note'],
            data: spendings
                .map(
                  (s) => [
                    s['date']?.toString() ?? '',
                    s['type'],
                    s['category'],
                    s['amount'].toString(),
                    s['note'],
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// 🔗 Optional: export then share
  Future<void> exportAndShareCsv({String? type}) async {
    final file = await exportToCsv(type: type);
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> exportAndSharePdf({String? type}) async {
    final file = await exportToPdf(type: type);
    await Share.shareXFiles([XFile(file.path)]);
  }
}
