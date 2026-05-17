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
