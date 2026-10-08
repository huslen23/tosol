const districts = [
  'Хан-Уул',
  'Сүхбаатар',
  'Баянзүрх',
  'Баянгол',
  'Сонгинохайрхан',
  'Чингэлтэй',
  'Налайх',
  'Багануур',
  'Багахангай',
];
const propertyTypes = {
  'apartment': 'Орон сууц',
  'house': 'Хаус',
  'office': 'Оффис',
  'land': 'Газар',
};

String money(num value) {
  final text = value.toStringAsFixed(0);
  return '${text.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ₮';
}

class PropertyPhoto {
  final int id;
  final String url;
  const PropertyPhoto(this.id, this.url);
  factory PropertyPhoto.fromJson(Map<String, dynamic> data) =>
      PropertyPhoto(data['id'] as int, data['image'] as String);
}

class Property {
  final int id;
  final String title,
      description,
      location,
      district,
      listingType,
      propertyType,
      phone;
  final double price, area;
  final int rooms, floor, totalFloors;
  final bool isFavorite, isOwner;
  final String? image;
  final List<PropertyPhoto> photos;
  final Map<String, dynamic>? owner;
  final int? complexId;
  final String complexName;
  final double? latitude, longitude;
  const Property({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.district,
    required this.listingType,
    required this.propertyType,
    required this.phone,
    required this.price,
    required this.area,
    required this.rooms,
    required this.floor,
    required this.totalFloors,
    required this.isFavorite,
    required this.isOwner,
    this.image,
    required this.photos,
    this.owner,
    this.complexId,
    this.complexName = '',
    this.latitude,
    this.longitude,
  });
  factory Property.fromJson(Map<String, dynamic> d) => Property(
    id: d['id'] as int,
    title: d['title'] as String,
    description: d['description'] as String? ?? '',
    location: d['location'] as String? ?? '',
    district: d['district'] as String? ?? '',
    listingType: d['listing_type'] as String? ?? 'sale',
    propertyType: d['property_type'] as String? ?? 'apartment',
    phone: d['contact_phone'] as String? ?? '',
    price: double.parse('${d['price']}'),
    area: double.parse('${d['area'] ?? 1}'),
    rooms: d['rooms'] as int? ?? 1,
    floor: d['floor'] as int? ?? 1,
    totalFloors: d['total_floors'] as int? ?? 1,
    isFavorite: d['is_favorite'] == true,
    isOwner: d['is_owner'] == true,
    image: d['image'] as String?,
    photos: (d['images'] as List? ?? [])
        .map((e) => PropertyPhoto.fromJson(e as Map<String, dynamic>))
        .toList(),
    owner: d['owner'] as Map<String, dynamic>?,
    complexId: d['complex'] as int?,
    complexName: d['complex_name'] as String? ?? '',
    latitude: (d['latitude'] as num?)?.toDouble(),
    longitude: (d['longitude'] as num?)?.toDouble(),
  );
  List<String> get imageUrls => [?image, ...photos.map((p) => p.url)];
  String get priceLabel =>
      '${money(price)}${listingType == 'rent' ? ' / сар' : ''}';
  String get typeLabel => listingType == 'rent' ? 'Түрээслэх' : 'Худалдах';
}

class PropertyResults {
  final List<Property> items;
  final int count;
  final bool hasNext;
  const PropertyResults(this.items, this.count, this.hasNext);
}
