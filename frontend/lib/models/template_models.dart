/// Data models for the checklist template system.

class TemplateQuestion {
  TemplateQuestion({
    required this.id,
    required this.text,
    this.hasRemark = false,
    this.remarkHint,
  });

  final String id;
  String text;
  bool hasRemark;
  String? remarkHint;

  TemplateQuestion copy() => TemplateQuestion(
    id: id,
    text: text,
    hasRemark: hasRemark,
    remarkHint: remarkHint,
  );
}

class TemplateSection {
  TemplateSection({
    required this.id,
    required this.name,
    this.questions = const [],
    this.expanded = false,
  });

  final String id;
  String name;
  List<TemplateQuestion> questions;
  bool expanded;

  TemplateSection copy() => TemplateSection(
    id: id,
    name: name,
    expanded: expanded,
    questions: questions.map((q) => q.copy()).toList(),
  );
}

class DefectCategory {
  DefectCategory({
    required this.id,
    required this.name,
    this.group = 'General',
    this.keywords = const [],
  });

  final String id;
  String name;
  String group;
  List<String> keywords;

  DefectCategory copy() => DefectCategory(
      id: id,
      name: name,
      group: group,
      keywords: List<String>.from(keywords));

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      '_id': id, // always send _id so backend can read/preserve it
      'id': id, // also send as 'id' for compatibility
      'name': name,
      'group': group,
      'keywords': keywords,
    };
  }
}

class TemplateGroup {
  TemplateGroup({
    required this.id,
    required this.name,
    this.questions = const [],
    this.sections = const [],
    this.expanded = false,
  });

  final String id;
  String name;
  List<TemplateQuestion> questions;
  List<TemplateSection> sections;
  bool expanded;

  TemplateGroup copy() => TemplateGroup(
    id: id,
    name: name,
    expanded: expanded,
    questions: questions.map((q) => q.copy()).toList(),
    sections: sections.map((s) => s.copy()).toList(),
  );
}

class PhaseModel {
  String id;
  String name;
  String stage;
  List<TemplateGroup> groups;

  PhaseModel({
    required this.id,
    required this.name,
    required this.stage,
    this.groups = const [],
  });
}
