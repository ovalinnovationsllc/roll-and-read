import 'dart:html' as html;

// Web-specific storage implementation using localStorage
Future<void> setString(String key, String value) async {
  html.window.localStorage[key] = value;
}

Future<String?> getString(String key) async {
  return html.window.localStorage[key];
}

Future<void> remove(String key) async {
  html.window.localStorage.remove(key);
}