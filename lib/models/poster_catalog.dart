class PosterCatalogEntry {
  final String id;
  final String name;
  final String? referenceImagePath;

  const PosterCatalogEntry({
    required this.id,
    required this.name,
    this.referenceImagePath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (referenceImagePath != null) 'referenceImagePath': referenceImagePath,
      };
}

const posterCatalog = <PosterCatalogEntry>[
  PosterCatalogEntry(
    id: 'afis1',
    name: 'Afiș 1',
    referenceImagePath: 'postere/afis1.png',
  ),
  PosterCatalogEntry(
    id: 'afis2',
    name: 'Afiș 2',
    referenceImagePath: 'postere/afis2.png',
  ),
  PosterCatalogEntry(
    id: 'afis3',
    name: 'Afiș 3',
    referenceImagePath: 'postere/afis3.png',
  ),
  PosterCatalogEntry(
    id: 'afis4',
    name: 'Afiș 4',
    referenceImagePath: 'postere/afis4.png',
  ),
  PosterCatalogEntry(
    id: 'afis5',
    name: 'Afiș 5',
    referenceImagePath: 'postere/afis5.png',
  ),
  PosterCatalogEntry(
    id: 'afis6',
    name: 'Afiș 6',
    referenceImagePath: 'postere/afis6.png',
  ),
  PosterCatalogEntry(
    id: 'afis7',
    name: 'Afiș 7',
    referenceImagePath: 'postere/afis7.png',
  ),
  PosterCatalogEntry(
    id: 'afis8',
    name: 'Afiș 8',
    referenceImagePath: 'postere/afis8.png',
  ),
  PosterCatalogEntry(
    id: 'afis9',
    name: 'Afiș 9',
    referenceImagePath: 'postere/afis9.png',
  ),
  PosterCatalogEntry(
    id: 'afis10',
    name: 'Afiș 10',
    referenceImagePath: 'postere/afis10.png',
  ),
];

const defaultPosterId = 'afis1';