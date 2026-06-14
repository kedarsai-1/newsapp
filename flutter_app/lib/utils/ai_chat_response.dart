class AiChatRelatedArticle {
  final String id;
  final String title;
  final String? summary;
  final String? sourceName;

  const AiChatRelatedArticle({
    required this.id,
    required this.title,
    this.summary,
    this.sourceName,
  });

  factory AiChatRelatedArticle.fromJson(Map<String, dynamic> json) {
    return AiChatRelatedArticle(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      summary: json['summary']?.toString(),
      sourceName: json['sourceName']?.toString(),
    );
  }
}

class AiChatResponse {
  final String answer;
  final bool aiGenerated;
  final List<AiChatRelatedArticle> relatedArticles;
  final Map<String, dynamic>? weather;
  final int sourcesUsed;

  const AiChatResponse({
    required this.answer,
    this.aiGenerated = false,
    this.relatedArticles = const [],
    this.weather,
    this.sourcesUsed = 0,
  });

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    final relatedRaw = json['relatedArticles'];
    final related = <AiChatRelatedArticle>[];
    if (relatedRaw is List) {
      for (final item in relatedRaw) {
        if (item is Map) {
          related.add(
            AiChatRelatedArticle.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return AiChatResponse(
      answer: (json['answer'] ?? json['message'] ?? '').toString(),
      aiGenerated: json['aiGenerated'] == true,
      relatedArticles: related,
      weather: json['weather'] is Map
          ? Map<String, dynamic>.from(json['weather'] as Map)
          : null,
      sourcesUsed: json['sourcesUsed'] is num
          ? (json['sourcesUsed'] as num).toInt()
          : int.tryParse(json['sourcesUsed']?.toString() ?? '') ?? 0,
    );
  }
}
