class UserProfile {
  UserProfile({
    required String name,
    required this.goal,
    required this.experience,
  }) : name = name.trim() {
    if (this.name.length > 50 ||
        !goals.contains(goal) ||
        !experienceLevels.contains(experience)) {
      throw const FormatException(
        'Choose a valid goal, experience level and a name up to 50 characters.',
      );
    }
  }

  static const goals = [
    'Build strength',
    'Build muscle',
    'Stay consistent',
    'General fitness',
  ];
  static const experienceLevels = ['Beginner', 'Intermediate', 'Advanced'];
  final String name;
  final String goal;
  final String experience;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    if (json['name'] is! String ||
        json['goal'] is! String ||
        json['experience'] is! String) {
      throw const FormatException('Invalid saved profile.');
    }
    return UserProfile(
      name: json['name'] as String,
      goal: json['goal'] as String,
      experience: json['experience'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'goal': goal,
    'experience': experience,
  };
}
