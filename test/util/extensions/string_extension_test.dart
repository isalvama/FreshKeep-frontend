import 'package:flutter_test/flutter_test.dart';
import 'package:fresh_keep_frontend/util/extensions/string_extension.dart';

void main() {
  test(
    "capitalize should return the string with the first letter in uppercase",
    () {
      expect("String", "string".capitalize());
    },
  );

  test("capitalize should return the letter in uppercase", () {
    expect("S", "s".capitalize());
  });

  test("capitalize should return the empty space", () {
    expect(" ", " ".capitalize());
  });

  test("capitalize should return the empty string", () {
    expect("", "".capitalize());
  });

  test(
    "toTitleCase should return the string with the first letter of each word in uppercase",
    () {
      expect("String Title", "string title".toTitleCase());
    },
  );

  test(
    "toTitleCase should return the string with the first letter in uppercase",
    () {
      expect("String", "string".toTitleCase());
    },
  );

  test("toTitleCase should return the letter in uppercase", () {
    expect("S", "s".capitalize());
  });

  test("toTitleCase should return the empty space", () {
    expect(" ", " ".capitalize());
  });

  test("toTitleCase should return the empty string", () {
    expect("", "".capitalize());
  });
}
