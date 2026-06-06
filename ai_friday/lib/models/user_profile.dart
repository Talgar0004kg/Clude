class UserProfile {
  final String name;
  final String language;
  final String communicationStyle;
  final String preferredVoice;
  final double speechRate;
  final bool privateMode;
  final bool confirmBeforeSend;
  final bool previewBeforeAction;

  const UserProfile({
    this.name = '',
    this.language = 'auto',
    this.communicationStyle = 'friendly',
    this.preferredVoice = 'Fenrir',
    this.speechRate = 1.0,
    this.privateMode = false,
    this.confirmBeforeSend = false,
    this.previewBeforeAction = true,
  });

  UserProfile copyWith({
    String? name,
    String? language,
    String? communicationStyle,
    String? preferredVoice,
    double? speechRate,
    bool? privateMode,
    bool? confirmBeforeSend,
    bool? previewBeforeAction,
  }) {
    return UserProfile(
      name: name ?? this.name,
      language: language ?? this.language,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      preferredVoice: preferredVoice ?? this.preferredVoice,
      speechRate: speechRate ?? this.speechRate,
      privateMode: privateMode ?? this.privateMode,
      confirmBeforeSend: confirmBeforeSend ?? this.confirmBeforeSend,
      previewBeforeAction: previewBeforeAction ?? this.previewBeforeAction,
    );
  }
}
