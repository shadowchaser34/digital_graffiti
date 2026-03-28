enum BrushType {
  pen,
  marker,
  calligraphy,
  neon,
}

extension BrushTypeX on BrushType {
  String get id {
    switch (this) {
      case BrushType.pen:
        return 'pen';
      case BrushType.marker:
        return 'marker';
      case BrushType.calligraphy:
        return 'calligraphy';
      case BrushType.neon:
        return 'neon';
    }
  }

  String get label {
    switch (this) {
      case BrushType.pen:
        return 'Pen';
      case BrushType.marker:
        return 'Marker';
      case BrushType.calligraphy:
        return 'Calligraphy';
      case BrushType.neon:
        return 'Neon';
    }
  }
}

BrushType brushTypeFromId(String? id) {
  switch (id) {
    case 'marker':
      return BrushType.marker;
    case 'calligraphy':
      return BrushType.calligraphy;
    case 'neon':
      return BrushType.neon;
    case 'pen':
    default:
      return BrushType.pen;
  }
}