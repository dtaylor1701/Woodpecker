import FluentKit

public protocol ModelServicing<Model> {
  associatedtype Model: Storable where Model.StorageModel: DatabaseModel & EagerLoadable
  func add(_ model: Model) async throws
  func update(_ model: Model) async throws
  func delete(_ model: Model) async throws
  func all() async throws -> [Model]
  func find(withId id: Model.StorageModel.IDValue) async throws -> Model?
}

open class ModelService<Model: Storable>: ModelServicing
where Model.StorageModel: DatabaseModel & EagerLoadable {
  public let databaseManager: DatabaseManager

  public var database: Database {
    databaseManager.database
  }

  public init(databaseManager: DatabaseManager) {
    self.databaseManager = databaseManager
  }

  public func add(_ model: Model) async throws {
    try await model.asStorageModel().save(on: database)
  }

  public func update(_ model: Model) async throws {
    try await model.asStorageModel().save(on: database)
  }

  public func delete(_ model: Model) async throws {
    try await model.asStorageModel().delete(on: database)
  }

  public func all() async throws -> [Model] {
    try await database.query(Model.StorageModel.self)
      .fullyLoaded()
      .allModels()
  }

  public func find(withId id: Model.StorageModel.IDValue) async throws -> Model? {
    try await database.query(Model.StorageModel.self).model(withId: id)
  }
}
