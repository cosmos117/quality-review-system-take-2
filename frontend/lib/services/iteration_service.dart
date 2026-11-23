/// Helpers for reading question data out of checklist iteration snapshots.
class IterationService {
  /// Find answer for a specific question in a specific iteration
  /// Returns the full question data including answer, remark, images, etc.
  Map<String, dynamic>? findQuestionInIteration(
    Map<String, dynamic> iteration,
    String questionId,
  ) {
    try {
      final groups = iteration['groups'] as List<dynamic>? ?? [];

      for (final group in groups) {
        if (group is! Map<String, dynamic>) continue;

        // Check direct questions
        final questions = group['questions'] as List<dynamic>? ?? [];
        for (final q in questions) {
          if (q is! Map<String, dynamic>) continue;
          if (q['_id'].toString() == questionId) {
            return q;
          }
        }

        // Check questions in sections
        final sections = group['sections'] as List<dynamic>? ?? [];
        for (final section in sections) {
          if (section is! Map<String, dynamic>) continue;
          final sectionQuestions = section['questions'] as List<dynamic>? ?? [];
          for (final q in sectionQuestions) {
            if (q is! Map<String, dynamic>) continue;
            if (q['_id'].toString() == questionId) {
              return q;
            }
          }
        }
      }
    } catch (_) {
      // Malformed iteration data: treat as not found.
    }
    return null;
  }

  /// Extract executor and reviewer answers from a question iteration data
  /// Returns: { executorAnswer: ..., executorRemark: ..., executorImages: ..., reviewerAnswer: ..., etc. }
  Map<String, dynamic> extractAnswersFromQuestion(
    Map<String, dynamic> questionData,
  ) {
    return {
      'executorAnswer': questionData['executorAnswer'],
      'executorRemark': questionData['executorRemark'] ?? '',
      'executorImages': questionData['executorImages'] ?? [],
      'reviewerAnswer': questionData['reviewerAnswer'],
      'reviewerRemark': questionData['reviewerRemark'] ?? '',
      'reviewerImages': questionData['reviewerImages'] ?? [],
      'categoryId': questionData['categoryId'] ?? '',
      'severity': questionData['severity'] ?? '',
      'answeredAt': questionData['answeredAt'],
      'answeredBy': questionData['answeredBy'],
    };
  }
}
