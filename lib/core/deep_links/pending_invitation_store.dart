/// Holds the token of an invitation link opened while logged out, until the
/// user logs in. In memory only: it's lost if the app is killed.
class PendingInvitationStore {
  String? _token;

  /// Keeps [token]; the latest link wins.
  void save(String token) => _token = token;

  /// Returns the pending token, if any, and clears it.
  String? take() {
    final token = _token;
    _token = null;
    return token;
  }

  void clear() => _token = null;
}
