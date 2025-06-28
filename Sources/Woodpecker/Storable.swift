import Foundation

/// A protocol for models that can be stored in a persistent store.
public protocol Storable: Identifiable, Sendable {
  /// The type of the storage model that this model is stored in.
  associatedtype StorageModel: StorableStorageModel where StorageModel.AppModel == Self

  /// Creates a new instance of the model from its storage model representation.
  static func create(fromStorageModel storageModel: StorageModel) throws -> Self

  /// The storable ID of the model.
  var id: StorableID { get set }
}

extension Storable {
  /// If this model has been stored.
  public var stored: Bool {
    id.stored
  }

  /// The storage representation of this model.
  public func asStorageModel() -> StorageModel {
    .create(fromAppModel: self)
  }
}

extension Array where Element: Storable {
  /// The storage representation of this array of models.
  public func asStorageModels() -> [Element.StorageModel] {
    map { $0.asStorageModel() }
  }

  /// Create an instance of these model from their storage representation.
  public static func create(fromStorageModels storageModels: [Element.StorageModel]) throws
    -> [Element]
  {
    try storageModels.map { try .create(fromStorageModel: $0) }
  }
}
