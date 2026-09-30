/// Custom URL scheme link that opens the app to join a space. The only place
/// to change once a web domain or an https redirect exists.
const kInvitationLinkBase = 'freshkeep://join';

/// The link to share for an invitation [token].
String invitationLink(String token) =>
    '$kInvitationLinkBase?token=${Uri.encodeQueryComponent(token)}';
