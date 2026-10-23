/// Custom URL scheme link that opens the app to join a space. The only place
/// to change once a web domain or an https redirect exists.
const kInvitationLinkBase = 'freshkeep://join';

/// The link to share for an invitation [token].
String invitationLink(String token) =>
    '$kInvitationLinkBase?token=${Uri.encodeQueryComponent(token)}';

/// The invitation token in [uri], if [uri] is a [kInvitationLinkBase] link.
/// Returns `null` for any other URI, and `''` when the token is missing.
String? parseInvitationToken(Uri uri) {
  final base = Uri.parse(kInvitationLinkBase);
  final isInvitation =
      uri.scheme.toLowerCase() == base.scheme &&
      uri.host.toLowerCase() == base.host;
  if (!isInvitation) return null;

  return (uri.queryParameters['token'] ?? '').trim();
}
