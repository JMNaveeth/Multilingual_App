import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class _G {
  static const bg = Color(0xFF080A14);
  static const card = Color(0xFF181B2E);
  static const cardBorder = Color(0xFF242742);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);
  static const indigo = Color(0xFF6366F1);
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const emerald = Color(0xFF10B981);
  
  static var amber;
}

class WordSprintGameScreen extends StatefulWidget {
  const WordSprintGameScreen({super.key});

  @override
  State<WordSprintGameScreen> createState() => _WordSprintGameScreenState();
}

class _WordSprintGameScreenState extends State<WordSprintGameScreen> {
  static const _wordPool = [
    'hello',
    'friend',
    'message',
    'game',
    'typing',
    'winner',
    'online',
    'quick',
    'chat',
    'speed',
    'focus',
    'react',
  ];

  final _ctrl = TextEditingController();
  final _rng = math.Random();
  Timer? _timer;
  int _seconds = 60;
  int _score = 0;
  String _target = _wordPool.first;

  @override
  void initState() {
    super.initState();
    _target = _wordPool[_rng.nextInt(_wordPool.length)];
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _seconds--;
      });
      if (_seconds <= 0) {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_seconds <= 0) return;
    if (_ctrl.text.trim().toLowerCase() == _target) {
      setState(() {
        _score++;
        _target = _wordPool[_rng.nextInt(_wordPool.length)];
      });
    }
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _G.bg,
      appBar: AppBar(
        title: const Text('Word Sprint'),
        backgroundColor: _G.bg,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statRow(score: _score, seconds: _seconds, color: _G.indigo),
            const SizedBox(height: 18),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Type this word',
                      style: TextStyle(color: _G.textSecondary)),
                  const SizedBox(height: 8),
                  Text(_target,
                      style: const TextStyle(
                          color: _G.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              enabled: _seconds > 0,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(color: _G.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type and press Enter',
                hintStyle: const TextStyle(color: _G.textMuted),
                filled: true,
                fillColor: _G.card,
                enabledBorder: _border(),
                focusedBorder: _border(_G.indigo),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _seconds > 0 ? _submit : null,
                style: ElevatedButton.styleFrom(backgroundColor: _G.indigo),
                child: const Text('Submit'),
              ),
            ),
            const SizedBox(height: 12),
            if (_seconds <= 0)
              _card(
                child: Text('Time up! Final score: $_score',
                    style:
                        const TextStyle(color: _G.textPrimary, fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}

class EmojiMatchGameScreen extends StatefulWidget {
  const EmojiMatchGameScreen({super.key});

  @override
  State<EmojiMatchGameScreen> createState() => _EmojiMatchGameScreenState();
}

class _EmojiMatchGameScreenState extends State<EmojiMatchGameScreen> {
  final _rng = math.Random();
  late List<String> _deck;
  late List<bool> _revealed;
  late List<bool> _matched;
  int _first = -1;
  int _second = -1;
  int _moves = 0;
  bool _busy = false;

  static const _symbols = ['😀', '😍', '🤖', '🎯', '🚀', '🍀', '🔥', '🎮'];

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _deck = [..._symbols, ..._symbols]..shuffle(_rng);
    _revealed = List.filled(16, false);
    _matched = List.filled(16, false);
    _first = -1;
    _second = -1;
    _moves = 0;
    _busy = false;
    setState(() {});
  }

  Future<void> _tap(int i) async {
    if (_busy || _matched[i] || _revealed[i]) return;
    setState(() {
      _revealed[i] = true;
      if (_first == -1) {
        _first = i;
      } else {
        _second = i;
      }
    });

    if (_first != -1 && _second != -1) {
      _moves++;
      if (_deck[_first] == _deck[_second]) {
        setState(() {
          _matched[_first] = true;
          _matched[_second] = true;
          _first = -1;
          _second = -1;
        });
      } else {
        _busy = true;
        await Future.delayed(const Duration(milliseconds: 550));
        if (!mounted) return;
        setState(() {
          _revealed[_first] = false;
          _revealed[_second] = false;
          _first = -1;
          _second = -1;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _matched.every((e) => e);
    return Scaffold(
      backgroundColor: _G.bg,
      appBar: AppBar(title: const Text('Emoji Match'), backgroundColor: _G.bg),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _statRow(
                score: done ? 16 : _matched.where((e) => e).length,
                seconds: _moves,
                color: _G.violet,
                scoreLabel: 'Matched',
                timeLabel: 'Moves'),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: 16,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (_, i) {
                  final open = _revealed[i] || _matched[i];
                  return InkWell(
                    onTap: () => _tap(i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: open ? _G.violet.withOpacity(0.18) : _G.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _G.cardBorder),
                      ),
                      child: Center(
                        child: Text(
                          open ? _deck[i] : '?',
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(backgroundColor: _G.violet),
                child: Text(done ? 'Play Again' : 'Reset'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class NumberDuelGameScreen extends StatefulWidget {
  const NumberDuelGameScreen({super.key});

  @override
  State<NumberDuelGameScreen> createState() => _NumberDuelGameScreenState();
}

class _NumberDuelGameScreenState extends State<NumberDuelGameScreen> {
  final _rng = math.Random();
  int _left = 0;
  int _right = 0;
  int _round = 1;
  int _score = 0;
  static const _totalRounds = 10;

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  void _nextRound() {
    int a = _rng.nextInt(100);
    int b = _rng.nextInt(100);
    while (a == b) {
      b = _rng.nextInt(100);
    }
    setState(() {
      _left = a;
      _right = b;
    });
  }

  void _pick(bool leftPicked) {
    if (_round > _totalRounds) return;
    final picked = leftPicked ? _left : _right;
    final best = math.max(_left, _right);
    setState(() {
      if (picked == best) _score++;
      _round++;
    });
    if (_round <= _totalRounds) _nextRound();
  }

  @override
  Widget build(BuildContext context) {
    final finished = _round > _totalRounds;
    return Scaffold(
      backgroundColor: _G.bg,
      appBar: AppBar(title: const Text('Number Duel'), backgroundColor: _G.bg),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _statRow(
                score: _score,
                seconds: finished ? _totalRounds : _round,
                color: _G.cyan,
                timeLabel: 'Round'),
            const SizedBox(height: 18),
            if (!finished)
              Row(
                children: [
                  Expanded(child: _numberButton(_left, () => _pick(true))),
                  const SizedBox(width: 10),
                  Expanded(child: _numberButton(_right, () => _pick(false))),
                ],
              )
            else
              _card(
                child: Column(
                  children: [
                    const Text('Game finished',
                        style: TextStyle(color: _G.textSecondary)),
                    const SizedBox(height: 8),
                    Text('Score: $_score / $_totalRounds',
                        style: const TextStyle(
                            color: _G.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _round = 1;
                    _score = 0;
                  });
                  _nextRound();
                },
                style: ElevatedButton.styleFrom(backgroundColor: _G.cyan),
                child: const Text('Restart'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberButton(int value, VoidCallback onTap) {
    return SizedBox(
      height: 120,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _G.card,
          foregroundColor: _G.textPrimary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _G.cardBorder)),
        ),
        child: Text('$value',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class TicTacToeGameScreen extends StatefulWidget {
  const TicTacToeGameScreen({super.key});

  @override
  State<TicTacToeGameScreen> createState() => _TicTacToeGameScreenState();
}

class _TicTacToeGameScreenState extends State<TicTacToeGameScreen> {
  final List<String> _board = List.filled(9, '');
  bool _playerTurn = true;
  String _result = '';

  void _tap(int i) {
    if (!_playerTurn || _board[i].isNotEmpty || _result.isNotEmpty) return;
    setState(() {
      _board[i] = 'X';
      _playerTurn = false;
    });
    _check();
    if (_result.isEmpty) {
      Future.delayed(const Duration(milliseconds: 250), _aiMove);
    }
  }

  void _aiMove() {
    if (_result.isNotEmpty) return;
    final empties = <int>[];
    for (var i = 0; i < 9; i++) {
      if (_board[i].isEmpty) empties.add(i);
    }
    if (empties.isEmpty) {
      _check();
      return;
    }
    empties.shuffle();
    setState(() {
      _board[empties.first] = 'O';
      _playerTurn = true;
    });
    _check();
  }

  void _check() {
    const lines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (final line in lines) {
      final a = _board[line[0]];
      final b = _board[line[1]];
      final c = _board[line[2]];
      if (a.isNotEmpty && a == b && b == c) {
        setState(() {
          _result = a == 'X' ? 'You win!' : 'AI wins!';
        });
        return;
      }
    }
    if (_board.every((e) => e.isNotEmpty)) {
      setState(() {
        _result = 'Draw';
      });
    }
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < 9; i++) {
        _board[i] = '';
      }
      _playerTurn = true;
      _result = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _G.bg,
      appBar: AppBar(title: const Text('Tic Tac Toe'), backgroundColor: _G.bg),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _card(
              child: Row(
                children: [
                  const Text('Status:',
                      style: TextStyle(color: _G.textSecondary)),
                  const SizedBox(width: 8),
                  Text(
                    _result.isNotEmpty
                        ? _result
                        : (_playerTurn ? 'Your turn' : 'AI thinking...'),
                    style: const TextStyle(
                        color: _G.textPrimary, fontWeight: FontWeight.w700),
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: 9,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (_, i) => InkWell(
                  onTap: () => _tap(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _G.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _G.cardBorder),
                    ),
                    child: Center(
                      child: Text(
                        _board[i],
                        style: TextStyle(
                          color: _board[i] == 'X' ? _G.emerald : _G.amber,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(backgroundColor: _G.emerald),
                child: const Text('Restart'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _statRow({
  required int score,
  required int seconds,
  required Color color,
  String scoreLabel = 'Score',
  String timeLabel = 'Time',
}) {
  return Row(
    children: [
      Expanded(
        child: _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(scoreLabel, style: const TextStyle(color: _G.textSecondary)),
              const SizedBox(height: 4),
              Text('$score',
                  style: TextStyle(
                      color: color, fontSize: 24, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(timeLabel, style: const TextStyle(color: _G.textSecondary)),
              const SizedBox(height: 4),
              Text('$seconds',
                  style: const TextStyle(
                      color: _G.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _card({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _G.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _G.cardBorder),
    ),
    child: child,
  );
}

OutlineInputBorder _border([Color color = _G.cardBorder]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
}
