class PosterCatalogEntry {
  final String id;
  final String name;

  const PosterCatalogEntry({required this.id, required this.name});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
      };
}

const posterCatalog = <PosterCatalogEntry>[
  PosterCatalogEntry(id: 'poster-1', name: 'Poster 1'),
  PosterCatalogEntry(id: 'poster-2', name: 'Poster 2'),
  PosterCatalogEntry(id: 'poster-3', name: 'Poster 3'),
];

const defaultPosterId = 'poster-1';