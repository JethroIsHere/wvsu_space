// WVSU Space — `lib/features/vibe_rooms/utils.dart`
// Small models and helpers for Vibe Rooms: moods and crisis keyword lists.
class VibeMood {
  final String id;
  final String emoji;
  final String name;
  final String description;

  const VibeMood(
      {required this.id,
      required this.emoji,
      required this.name,
      required this.description});
}

const List<VibeMood> moods = [
  VibeMood(
      id: 'chill',
      emoji: '😌',
      name: 'Chill & Calm',
      description: 'Need to relax and unwind'),
  VibeMood(
      id: 'motivated',
      emoji: '💪',
      name: 'Motivated',
      description: 'Ready to be productive'),
  VibeMood(
      id: 'happy',
      emoji: '🎉',
      name: 'Happy & Excited',
      description: 'Want to celebrate'),
  VibeMood(
      id: 'support',
      emoji: '😔',
      name: 'Need Support',
      description: 'Looking for comfort'),
];

const List<String> crisisKeywords = [
  'suicide',
  'kill myself',
  'end it all',
  'not worth living',
  'self harm',
  'cutting',
  'overdose',
  'want to die'
];
