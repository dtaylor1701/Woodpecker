public protocol StorableStorageModel {
  associatedtype AppModel: Storable where AppModel.StorageModel == Self

  /// Creates a new instance of the storage model from its app model representation.
  static func create(fromAppModel appModel: AppModel) -> Self
}
