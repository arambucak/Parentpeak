enum ChatProviderIssue { authorization, quota, network, unavailable }

class ChatProviderException implements Exception {
  const ChatProviderException(this.issue);
  final ChatProviderIssue issue;
  @override
  String toString() => 'Chat provider unavailable (${issue.name})';
}
