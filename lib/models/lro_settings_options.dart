/// Display-order options for the 16-digit LRO Recording Number.
enum LroNumberOrder {
  /// County No. + Payment Date + Unique No.
  countyDateUnique,
  /// Unique No. + Payment Date + County No.
  uniqueDateCounty,
  /// Payment Date + County No. + Unique No.
  dateCountyUnique,
}