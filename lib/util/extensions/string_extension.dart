extension StringExtension on String {
  String capitalize() {
    if (length > 1) {
      return substring(0, 1).toUpperCase() + substring(1).toLowerCase();
    }
    if (length == 1) {
      return toUpperCase();
    } else {
      return "";
    }
  }
}
