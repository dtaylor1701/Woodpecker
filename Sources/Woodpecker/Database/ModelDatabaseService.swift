import FluentKit
import Foundation

open class ModelDatabaseService<Model: Storable>: ModelStorageServicing
where Model.StorageModel: DatabaseModel, Model.StorageModel.AppModel == Model {
  public let databaseManager: DatabaseManager
  
  public var database: Database {
    get async {
      await databaseManager.database
    }
  }
  
  public init(databaseManager: DatabaseManager) {
    self.databaseManager = databaseManager
  }
  
  public func add(_ model: Model) async throws {
    let storageModel: Model.StorageModel = model.asStorageModel()
    try await storageModel.save(on: database)
    try await storageModel.addRelationships(from: model, on: database)
  }
  
  public func update(_ model: Model) async throws {
    let storageModel: Model.StorageModel = model.asStorageModel()
    try await storageModel.save(on: database)
    try await storageModel.updateRelationships(from: model, on: database)
  }
  
  public func delete(_ model: Model) async throws {
    let storageModel: Model.StorageModel = model.asStorageModel()
    try await storageModel.save(on: database) // Fluent assigns IDs to the properties upon saving. An elegant way around hitting the database here would be preferred.
    try await storageModel.deleteRelationships(on: database)
    try await storageModel.delete(on: database)
  }
  
  public func all() async throws -> [Model] {
    try await database.query(Model.StorageModel.self)
      .withRelationships()
      .allModels()
  }
  
  public func find(withId id: Model.ID) async throws -> Model? {
    try await database.query(Model.StorageModel.self).withRelationships().model(withId: id)
  }
}
