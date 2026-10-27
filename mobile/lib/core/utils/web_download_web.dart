// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
// ignore: deprecated_member_use
import 'dart:html' as html;

void downloadCsvWeb(String content, String filename) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
