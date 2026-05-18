class SportsBatsmanRow {
  final String name;
  final String dismissal;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final double strikeRate;

  const SportsBatsmanRow({
    required this.name,
    required this.dismissal,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.strikeRate = 0,
  });

  factory SportsBatsmanRow.fromJson(Map<String, dynamic> j) {
    return SportsBatsmanRow(
      name: j['name']?.toString() ?? '',
      dismissal: j['dismissal']?.toString() ?? '',
      runs: int.tryParse('${j['runs']}') ?? 0,
      balls: int.tryParse('${j['balls']}') ?? 0,
      fours: int.tryParse('${j['fours']}') ?? 0,
      sixes: int.tryParse('${j['sixes']}') ?? 0,
      strikeRate: double.tryParse('${j['strikeRate']}') ?? 0,
    );
  }
}

class SportsBowlerRow {
  final String name;
  final double overs;
  final int maidens;
  final int runs;
  final int wickets;
  final double economy;

  const SportsBowlerRow({
    required this.name,
    this.overs = 0,
    this.maidens = 0,
    this.runs = 0,
    this.wickets = 0,
    this.economy = 0,
  });

  factory SportsBowlerRow.fromJson(Map<String, dynamic> j) {
    return SportsBowlerRow(
      name: j['name']?.toString() ?? '',
      overs: double.tryParse('${j['overs']}') ?? 0,
      maidens: int.tryParse('${j['maidens']}') ?? 0,
      runs: int.tryParse('${j['runs']}') ?? 0,
      wickets: int.tryParse('${j['wickets']}') ?? 0,
      economy: double.tryParse('${j['economy']}') ?? 0,
    );
  }
}

class SportsInningScorecard {
  final String label;
  final String? extras;
  final String? totals;
  final List<SportsBatsmanRow> batting;
  final List<SportsBowlerRow> bowling;

  const SportsInningScorecard({
    required this.label,
    this.extras,
    this.totals,
    this.batting = const [],
    this.bowling = const [],
  });

  static String? _textField(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty || s == '[object Object]') return null;
      return s;
    }
    if (v is num) return v.toString();
    if (v is Map) {
      final parts = <String>[];
      v.forEach((k, val) {
        if (val == null) return;
        parts.add('$k: $val');
      });
      return parts.isEmpty ? null : parts.join(', ');
    }
    final s = v.toString().trim();
    return s.isEmpty || s == '[object Object]' ? null : s;
  }

  factory SportsInningScorecard.fromJson(Map<String, dynamic> j) {
    final batRaw = j['batting'];
    final bowlRaw = j['bowling'];
    return SportsInningScorecard(
      label: j['label']?.toString() ?? 'Innings',
      extras: _textField(j['extras']),
      totals: _textField(j['totals']),
      batting: batRaw is List
          ? batRaw
              .whereType<Map>()
              .map((e) => SportsBatsmanRow.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      bowling: bowlRaw is List
          ? bowlRaw
              .whereType<Map>()
              .map((e) => SportsBowlerRow.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class SportsTeam {
  final String name;
  final String shortName;
  final String? score;
  final String? overs;

  const SportsTeam({
    required this.name,
    required this.shortName,
    this.score,
    this.overs,
  });

  factory SportsTeam.fromJson(Map<String, dynamic> j) {
    return SportsTeam(
      name: j['name']?.toString() ?? '',
      shortName: j['shortName']?.toString() ?? '—',
      score: j['score']?.toString(),
      overs: j['overs']?.toString(),
    );
  }
}

enum SportsMatchStatus { live, upcoming, finished, unknown }

SportsMatchStatus sportsStatusFrom(String? s) {
  switch (s?.toLowerCase()) {
    case 'live':
      return SportsMatchStatus.live;
    case 'upcoming':
      return SportsMatchStatus.upcoming;
    case 'finished':
      return SportsMatchStatus.finished;
    default:
      return SportsMatchStatus.unknown;
  }
}

class SportsMatch {
  final String id;
  final List<SportsTeam> teams;
  final SportsMatchStatus status;
  final String statusLabel;
  final String? thumbnail;
  final DateTime? time;
  final String tournament;
  final String venue;
  final String? result;
  final List<SportsInningScorecard> scorecard;
  final String? tossWinner;
  final String? tossChoice;
  final String? matchWinner;

  const SportsMatch({
    required this.id,
    required this.teams,
    required this.status,
    required this.statusLabel,
    this.thumbnail,
    this.time,
    this.tournament = 'Cricket',
    this.venue = '',
    this.result,
    this.scorecard = const [],
    this.tossWinner,
    this.tossChoice,
    this.matchWinner,
  });

  factory SportsMatch.fromJson(Map<String, dynamic> j) {
    final teamsRaw = j['teams'];
    final teams = teamsRaw is List
        ? teamsRaw
            .whereType<Map>()
            .map((e) => SportsTeam.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <SportsTeam>[];
    DateTime? parsedTime;
    final t = j['time'];
    if (t != null) {
      parsedTime = DateTime.tryParse(t.toString());
    }
    final scRaw = j['scorecard'];
    final scorecard = scRaw is List
        ? scRaw
            .whereType<Map>()
            .map((e) => SportsInningScorecard.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <SportsInningScorecard>[];

    return SportsMatch(
      id: j['id']?.toString() ?? '',
      teams: teams,
      status: sportsStatusFrom(j['status']?.toString()),
      statusLabel: j['statusLabel']?.toString() ?? '',
      thumbnail: j['thumbnail']?.toString(),
      time: parsedTime,
      tournament: j['tournament']?.toString() ?? 'Cricket',
      venue: j['venue']?.toString() ?? '',
      result: j['result']?.toString(),
      scorecard: scorecard,
      tossWinner: j['tossWinner']?.toString(),
      tossChoice: j['tossChoice']?.toString(),
      matchWinner: j['matchWinner']?.toString(),
    );
  }
}

class SportsNewsItem {
  final String id;
  final String title;
  final String? thumbnail;
  final DateTime? time;
  final String source;
  final bool hasVideo;
  final String? youtubeVideoId;
  final String? youtubeUrl;

  const SportsNewsItem({
    required this.id,
    required this.title,
    this.thumbnail,
    this.time,
    this.source = 'Sports',
    this.hasVideo = false,
    this.youtubeVideoId,
    this.youtubeUrl,
  });

  factory SportsNewsItem.fromJson(Map<String, dynamic> j) {
    DateTime? parsed;
    final t = j['time'];
    if (t != null) parsed = DateTime.tryParse(t.toString());
    return SportsNewsItem(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      thumbnail: j['thumbnail']?.toString(),
      time: parsed,
      source: j['source']?.toString() ?? 'Sports',
      hasVideo: j['hasVideo'] == true,
      youtubeVideoId: j['youtubeVideoId']?.toString(),
      youtubeUrl: j['youtubeUrl']?.toString(),
    );
  }
}

class SportsHighlight {
  final String id;
  final String title;
  final String? thumbnail;
  final String? youtubeUrl;
  final String? youtubeVideoId;
  final DateTime? time;

  const SportsHighlight({
    required this.id,
    required this.title,
    this.thumbnail,
    this.youtubeUrl,
    this.youtubeVideoId,
    this.time,
  });

  factory SportsHighlight.fromJson(Map<String, dynamic> j) {
    DateTime? parsed;
    final t = j['time'];
    if (t != null) parsed = DateTime.tryParse(t.toString());
    return SportsHighlight(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      thumbnail: j['thumbnail']?.toString(),
      youtubeUrl: j['youtubeUrl']?.toString(),
      youtubeVideoId: j['youtubeVideoId']?.toString(),
      time: parsed,
    );
  }
}
