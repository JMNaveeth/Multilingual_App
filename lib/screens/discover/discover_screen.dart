import 'package:flutter/material.dart';

class _D {
  static const bg = Color(0xFF0D0E1A);
  static const card = Color(0xFF1C1E31);
  static const cardBorder = Color(0xFF252842);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);
}

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  static const _games = [
    _MiniGame('Word Sprint', 'Type fast. Beat your friend.',
        Icons.spellcheck_rounded, _D.indigo),
    _MiniGame('Emoji Match', 'Memory game in 60s.',
        Icons.emoji_emotions_outlined, _D.violet),
    _MiniGame('Number Duel', 'Pick bigger number quickly.',
        Icons.numbers_rounded, _D.cyan),
    _MiniGame('Tic Tac Toe', 'Classic 1v1 quick game.', Icons.grid_3x3_rounded,
        _D.emerald),
  ];

  static const _friends = [
    _Friend('John', true),
    _Friend('Marie', false),
    _Friend('Satoshi', true),
    _Friend('Nadia', true),
  ];

  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(color: _D.textPrimary)),
        backgroundColor: _D.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Mini games with friends',
              'Quick 1v1 games you can play together'),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: _games.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.08,
            ),
            itemBuilder: (context, index) {
              final game = _games[index];
              return _gameCard(
                context: context,
                game: game,
              );
            },
          ),
          const SizedBox(height: 18),
          _sectionTitle('Friends online', 'Challenge a friend now'),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _friends.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final friend = _friends[index];
                return _friendCard(context, friend);
              },
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _D.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _D.cardBorder),
              gradient: LinearGradient(
                colors: [
                  _D.indigo.withOpacity(0.18),
                  _D.violet.withOpacity(0.14),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _D.indigo.withOpacity(0.2),
                  ),
                  child:
                      const Icon(Icons.groups_2_rounded, color: _D.indigoLight),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Party Room',
                          style: TextStyle(
                            color: _D.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          )),
                      SizedBox(height: 2),
                      Text('Invite up to 4 friends and play mini games',
                          style:
                              TextStyle(color: _D.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _D.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () =>
                      _showMessage(context, 'Party room coming soon'),
                  child: const Text('Create'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
              color: _D.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 3),
        Text(subtitle,
            style: const TextStyle(
              color: _D.textMuted,
              fontSize: 12,
            )),
      ],
    );
  }

  Widget _gameCard({required BuildContext context, required _MiniGame game}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _D.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _D.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: game.color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(game.icon, color: game.color),
          ),
          const SizedBox(height: 10),
          Text(game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _D.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              )),
          const SizedBox(height: 4),
          Text(
            game.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _D.textSecondary, fontSize: 11.5),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: game.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () =>
                  _showMessage(context, '${game.name} coming soon'),
              child: const Text('Play'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _friendCard(BuildContext context, _Friend friend) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _D.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _D.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _D.indigo.withOpacity(0.25),
                child: Text(friend.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                        color: _D.textPrimary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(friend.name,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: _D.textPrimary, fontSize: 13.5)),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: friend.isOnline ? _D.emerald : _D.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _D.amber,
                side: BorderSide(color: _D.amber.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: friend.isOnline
                  ? () =>
                      _showMessage(context, 'Challenge sent to ${friend.name}')
                  : null,
              child: const Text('Challenge', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniGame {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MiniGame(this.name, this.subtitle, this.icon, this.color);
}

class _Friend {
  final String name;
  final bool isOnline;

  const _Friend(this.name, this.isOnline);
}
