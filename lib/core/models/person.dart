// FROZEN: changes need approval from every team member
enum PartnerRole { her, him }

enum Stage { preconception, trimester1, trimester2, trimester3, delivered }

class Person {
  const Person({
    required this.id,
    required this.name,
    required this.role,
    this.stage = Stage.preconception,
  });

  final String id;
  final String name;
  final PartnerRole role;
  final Stage stage;
}
