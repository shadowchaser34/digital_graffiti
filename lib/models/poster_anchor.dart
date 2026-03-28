/// Represents a poster anchor that can host a shared canvas session.
class PosterAnchor {
  final String id;
  final String name;
  final String referenceImagePath;

  const PosterAnchor({
    required this.id,
    required this.name,
    required this.referenceImagePath,
  });
}

const List<PosterAnchor> posterCatalog = [
  PosterAnchor(
    id: 'afis1',
    name: 'Afiș 1',
    referenceImagePath: 'docs/project_definition/poze/afis1.png',
  ),
  PosterAnchor(
    id: 'afis2',
    name: 'Afiș 2',
    referenceImagePath: 'docs/project_definition/poze/afis2.png',
  ),
  PosterAnchor(
    id: 'afis3',
    name: 'Afiș 3',
    referenceImagePath: 'docs/project_definition/poze/afis3.png',
  ),
  PosterAnchor(
    id: 'afis4',
    name: 'Afiș 4',
    referenceImagePath: 'docs/project_definition/poze/afis4.png',
  ),
  PosterAnchor(
    id: 'afis5',
    name: 'Afiș 5',
    referenceImagePath: 'docs/project_definition/poze/afis5.png',
  ),
  PosterAnchor(
    id: 'afis6',
    name: 'Afiș 6',
    referenceImagePath: 'docs/project_definition/poze/afis6.png',
  ),
  PosterAnchor(
    id: 'afis7',
    name: 'Afiș 7',
    referenceImagePath: 'docs/project_definition/poze/afis7.png',
  ),
  PosterAnchor(
    id: 'afis8',
    name: 'Afiș 8',
    referenceImagePath: 'docs/project_definition/poze/afis8.png',
  ),
  PosterAnchor(
    id: 'afis9',
    name: 'Afiș 9',
    referenceImagePath: 'docs/project_definition/poze/afis9.png',
  ),
  PosterAnchor(
    id: 'afis10',
    name: 'Afiș 10',
    referenceImagePath: 'docs/project_definition/poze/afis10.png',
  ),
];

const PosterAnchor defaultPosterAnchor = PosterAnchor(
  id: 'afis1',
  name: 'Afiș 1',
  referenceImagePath: 'docs/project_definition/poze/afis1.png',
);