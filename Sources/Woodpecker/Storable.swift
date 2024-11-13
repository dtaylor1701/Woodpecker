import Foundation

/// A protocol for models that can be stored in a persistent store.
public protocol Storable {
  /// The type of the storage model that this model is stored in.
  associatedtype StorageModel

  /// Creates a new instance of the model from its storage model representation.
  static func create(fromStorageModel storageModel: StorageModel) throws -> Self
  /// Creates a new storage model representation of the model.
  static func createStorageModel(from model: Self) -> StorageModel

  /// True if the model is stored in a persistent store, false otherwise.
  var stored: Bool { get set }
}

extension Storable {
  func existingInStore() -> Self {
    var model = self
    model.stored = true
    return model
  }

  public func asStorageModel() -> StorageModel {
    Self.createStorageModel(from: self)
  }

  public static func createExisting(fromStorageModel storageModel: StorageModel) throws -> Self {
    try Self.create(fromStorageModel: storageModel).existingInStore()
  }
}

extension Array where Element: Storable {
  public func asStorageModels() -> [Element.StorageModel] {
    map { $0.asStorageModel() }
  }

  public static func createExisting(fromStorageModels storageModels: [Element.StorageModel]) throws
    -> [Element]
  {
    try storageModels.map { try Element.createExisting(fromStorageModel: $0) }
  }
}
