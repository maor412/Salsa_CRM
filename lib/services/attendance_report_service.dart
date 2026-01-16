import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import 'firestore_service.dart';

/// שירות ליצירת דוחות נוכחות PDF
class AttendanceReportService {
  final FirestoreService _firestoreService = FirestoreService();

  /// יצירת דוח נוכחות PDF
  Future<Uint8List> generateAttendanceReport() async {
    WidgetsFlutterBinding.ensureInitialized();
    // טעינת נתונים
    final students = await _firestoreService.getActiveStudents().first;
    final sessionsDescending = await _getLastNSessions(10);
    // הפוך את הסדר מהחדש לישן -> מהישן לחדש
    final sessions = sessionsDescending.reversed.toList();

    // טעינת מפת נוכחות לכל תלמיד ושיעור
    final Map<String, Map<String, bool>> attendanceMap = {};
    for (final student in students) {
      attendanceMap[student.id] = {};
      for (final session in sessions) {
        final attended = await _wasStudentPresent(student.id, session.id);
        attendanceMap[student.id]![session.id] = attended;
      }
    }

    // יצירת PDF
    final pdf = pw.Document();

    // טעינת פונט עברית (אופציונלי - אם הפונט קיים)
    pw.Font? hebrewFont;
    pw.Font? hebrewFontBold;
    try {
      final fontData = await rootBundle.load('assets/fonts/Rubik.ttf');
      hebrewFont = pw.Font.ttf(fontData);
      hebrewFontBold = pw.Font.ttf(fontData);
    } catch (e) {
      print('Could not load custom font, using default: $e');
      // נמשיך עם הפונט הדיפולטיבי
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // כותרת
              _buildHeader(hebrewFontBold),
              pw.SizedBox(height: 20),

              // טבלת נוכחות
              _buildAttendanceTable(
                students: students,
                sessions: sessions,
                attendanceMap: attendanceMap,
                font: hebrewFont,
                fontBold: hebrewFontBold,
              ),

              pw.Spacer(),

              // פוטר
              _buildFooter(hebrewFont),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// בניית כותרת הדוח
  pw.Widget _buildHeader(pw.Font? fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#673AB7'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'דוח נוכחות',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    font: fontBold,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'קבוצת אסתי - סלסה',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    font: fontBold,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'תאריך: ${_formatDate(DateTime.now())}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    font: fontBold,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// בניית טבלת נוכחות
  pw.Widget _buildAttendanceTable({
    required List<StudentModel> students,
    required List<AttendanceSession> sessions,
    required Map<String, Map<String, bool>> attendanceMap,
    pw.Font? font,
    pw.Font? fontBold,
  }) {
    // עמודות הטבלה (בסדר RTL - סיכום, תאריכים מהחדש לישן, שם)
    final headers = [
      'סה"כ',
      ...sessions.map((session) => _formatDateShort(session.date)).toList().reversed,
      'שם תלמיד',
    ];

    // שורות הטבלה
    final List<List<String>> rows = [];

    for (final student in students) {
      final row = <String>[];

      // נוכחות בכל שיעור
      int presentCount = 0;
      final attendanceMarks = <String>[];
      for (final session in sessions) {
        final attended = attendanceMap[student.id]?[session.id] ?? false;
        if (attended) presentCount++;
        attendanceMarks.add(attended ? 'V' : 'X');
      }

      // בניית השורה בסדר RTL (סיכום, נוכחות מהחדש לישן, שם)
      row.add('$presentCount/${sessions.length}'); // סיכום
      row.addAll(attendanceMarks.reversed); // שיעורים מהחדש לישן
      row.add(student.name); // שם

      rows.add(row);
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#E0E0E0'),
        width: 1,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5), // סיכום
        ...Map.fromEntries(
          List.generate(
            sessions.length,
            (i) => MapEntry(i + 1, const pw.FlexColumnWidth(1)),
          ),
        ),
        sessions.length + 1: const pw.FlexColumnWidth(3), // שם התלמיד
      },
      children: [
        // שורת כותרת
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#9575CD'),
          ),
          children: headers.asMap().entries.map((entry) {
            final index = entry.key;
            final header = entry.value;
            final isLastColumn = index == headers.length - 1; // עמודת שם התלמיד

            return pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: isLastColumn ? pw.Alignment.centerRight : pw.Alignment.center,
              child: pw.Text(
                header,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                  font: fontBold,
                  fontWeight: pw.FontWeight.bold,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
            );
          }).toList(),
        ),

        // שורות תלמידים
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isEven = index % 2 == 0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven
                  ? PdfColors.white
                  : PdfColor.fromHex('#F5F5F5'),
            ),
            children: row.asMap().entries.map((cellEntry) {
              final cellIndex = cellEntry.key;
              final cell = cellEntry.value;
              final isLastColumn = cellIndex == row.length - 1; // עמודת שם התלמיד
              final isFirstColumn = cellIndex == 0; // עמודת סיכום

              // צבע לסמלי נוכחות (עמודות באמצע)
              PdfColor? textColor;
              if (!isFirstColumn && !isLastColumn) {
                textColor = cell == 'V'
                    ? PdfColor.fromHex('#4CAF50')
                    : PdfColor.fromHex('#F44336');
              }

              return pw.Container(
                padding: const pw.EdgeInsets.all(8),
                alignment: isLastColumn
                    ? pw.Alignment.centerRight
                    : pw.Alignment.center,
                child: pw.Text(
                  cell,
                  style: pw.TextStyle(
                    fontSize: 10,
                    font: isLastColumn ? fontBold : font,
                    fontWeight: isLastColumn
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color: textColor ?? PdfColors.black,
                  ),
                  textDirection: isLastColumn ? pw.TextDirection.rtl : null,
                ),
              );
            }).toList(),
          );
        }).toList(),
      ],
    );
  }

  /// בניית פוטר
  pw.Widget _buildFooter(pw.Font? font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.grey300,
            width: 1,
          ),
        ),
      ),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'מערכת ניהול קבוצת סלסה - קבוצת אסתי',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
                font: font,
              ),
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              'עמוד 1 מתוך 1',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
                font: font,
              ),
              textDirection: pw.TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }

  /// שליפת N שיעורים אחרונים
  Future<List<AttendanceSession>> _getLastNSessions(int count) async {
    try {
      return await _firestoreService.getRecentAttendanceSessions(limit: count).first;
    } catch (e) {
      print('Error fetching sessions: $e');
      return [];
    }
  }

  /// קבלת רשומות נוכחות לשיעור מסוים
  Future<List<AttendanceRecord>> _getAttendanceRecords(String sessionId) async {
    try {
      return await _firestoreService.getAttendanceRecordsBySession(sessionId);
    } catch (e) {
      print('Error fetching attendance records: $e');
      return [];
    }
  }

  /// בדיקה האם תלמיד היה נוכח בשיעור
  Future<bool> _wasStudentPresent(String studentId, String sessionId) async {
    try {
      final records = await _getAttendanceRecords(sessionId);
      final studentRecord = records.firstWhere(
        (record) => record.studentId == studentId,
        orElse: () => AttendanceRecord(
          id: '',
          sessionId: sessionId,
          studentId: studentId,
          studentName: '',
          attended: false,
          createdAt: DateTime.now(),
        ),
      );
      return studentRecord.attended;
    } catch (e) {
      return false;
    }
  }

  /// פורמט תאריך מלא
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
           '${date.month.toString().padLeft(2, '0')}/'
           '${date.year}';
  }

  /// פורמט תאריך קצר (יום/חודש)
  String _formatDateShort(DateTime date) {
    return '${date.day}/${date.month}';
  }

  /// הצגת/שמירת ה-PDF
  Future<void> showPdfPreview() async {
    try {
      final pdfBytes = await generateAttendanceReport();

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'attendance_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      print('Error showing PDF: $e');
      rethrow;
    }
  }
}






