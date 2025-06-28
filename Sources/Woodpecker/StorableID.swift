import Foundation

/// An identifier for a model that can be stored.
public struct StorableID: Hashable, Sendable, Codable {
  /// The underlying identifier value.
  public let value: UUID

  /// The stored state of the model associated with this identifier.
  public private(set) var stored: Bool

  private init(value: UUID, stored: Bool) {
    self.value = value
    self.stored = stored
  }

  /// Create an ID from its underlying value and indicate that it is already stored.
  public func asStored() -> StorableID {
    return StorableID.stored(value)
  }

  /// Create a new ID for a model which is not yet stored.
  public static func new(withValue value: UUID = UUID()) -> StorableID {
    StorableID(value: value, stored: false)
  }

  /// Create a new ID with the value of the identifier for an existing model.
  public static func stored(_ value: UUID) -> StorableID {
    StorableID(value: value, stored: true)
  }
}
