function coarseCoordinate(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? Math.round(number * 100) / 100 : null;
}

function publicTreasure(treasure, { distanceKm = null } = {}) {
  const handovers = Array.isArray(treasure.handovers) ? treasure.handovers : [];
  return {
    id: treasure.id,
    userId: treasure.userId,
    ownerUserId: treasure.userId,
    title: treasure.title,
    description: treasure.description,
    location: treasure.location,
    latitude: coarseCoordinate(treasure.latitude),
    longitude: coarseCoordinate(treasure.longitude),
    approximateLocation: true,
    category: treasure.category,
    condition: treasure.condition,
    visibility: treasure.visibility,
    shareRadiusKm: treasure.shareRadiusKm,
    isFree: treasure.isFree,
    price: treasure.price,
    photoUrl: treasure.photoUrl,
    photoUrls: Array.isArray(treasure.photoUrls) ? treasure.photoUrls : [],
    pickupSlots: Array.isArray(treasure.pickupSlots) ? treasure.pickupSlots : [],
    status: treasure.status,
    views: treasure.views,
    rating: treasure.rating,
    ratingCount: treasure.ratingCount,
    reservedCount: handovers.filter(h => h.status === 'pending' || h.status === 'reserved').length,
    availableHandovers: handovers.filter(h => h.status === 'pending').length,
    claimedCount: handovers.filter(h => h.status === 'confirmed' || h.status === 'completed').length,
    distanceKm,
    createdAt: treasure.createdAt,
    expiresAt: treasure.expiresAt,
  };
}

module.exports = { publicTreasure };
