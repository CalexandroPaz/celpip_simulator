/// Representa las cuatro secciones del examen CELPIP-General.
enum Section {
  listening,
  reading,
  writing,
  speaking;

  String get displayName {
    return switch (this) {
      Section.listening => 'Listening',
      Section.reading => 'Reading',
      Section.writing => 'Writing',
      Section.speaking => 'Speaking',
    };
  }
}
