import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/util/extensions/string_extension.dart';

void main() {
  test("should return the string with the first letter in uppercase", () {
    expect("String", "string".capitalize());
  });

  test("should return the letter in uppercase", () {
    expect("S", "s".capitalize());
  });

  test("should return the empty space", () {
    expect(" ", " ".capitalize());
  });

  test("should return the empty string", () {
    expect("", "".capitalize());
  });
}
