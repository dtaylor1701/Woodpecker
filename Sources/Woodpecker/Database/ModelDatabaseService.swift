import FluentKit
import Foundation

public actor ModelDatabaseService<Model: Storable>: ModelServicing, Sendable
where Model.StorageModel: DatabaseModel, Model.StorageModel.AppModel == Model {
  public let databaseManager: DatabaseManager

  public var database: Database {
    get async {
      await databaseManager.database
    }
  }

  public init(databaseManager: DatabaseManager, dependencies: [ModelDatabaseService] = []) {
    self.databaseManager = databaseManager
  }

  // MARK: - CRUD API

  public func add(_ model: Model) async throws -> Model {
    try await database.transaction { database in
      try await Self.add(model, on: database)
    }
  }

  public func update(_ model: Model) async throws -> Model {
    try await database.transaction { database in
      try await Self.update(model, on: database)
    }
  }

  public func delete(_ model: Model) async throws {
    try await database.transaction { database in
      try await Self.delete(model, on: database)
    }
  }

  // MARK: - CRUD Implementations

  static public func add(_ model: Model, on database: Database) async throws -> Model {
    let storageModel: Model.StorageModel = model.asStorageModel()
    try await storageModel.save(on: database)
    try await storageModel.addRelationships(from: model, on: database)
    // try await storageModel.withRelationships(from: model, on: database)
    return try Model.create(fromStorageModel: storageModel)
  }

  static public func update(_ model: Model, on database: Database) async throws -> Model {
    let storageModel: Model.StorageModel = model.asStorageModel()
    try await storageModel.save(on: database)
    try await storageModel.updateRelationships(from: model, on: database)
    try await storageModel.withRelationships(from: model, on: database)
    return try Model.create(fromStorageModel: storageModel)
  }

  static public func delete(_ model: Model, on database: Database) async throws {
    let storageModel: Model.StorageModel = model.asStorageModel()
    try await storageModel.save(on: database)  // Fluent assigns IDs to the properties upon saving. An elegant way around hitting the database here would be preferred.
    try await storageModel.deleteRelationships(from: model, on: database)
    try await storageModel.delete(on: database)
  }

  // MARK: - Access API

  public func all() async throws -> [Model] {
    try await Self.all(on: database)
  }

  public func find(withId id: StorableID) async throws -> Model? {
    try await Self.find(withId: id, on: database)
  }

  // MARK: - Access Implementations

  static public func all(on database: Database) async throws -> [Model] {
    try await database.query(Model.StorageModel.self)
      .withRelationships()
      .allModels()
  }

  static public func find(withId id: StorableID, on database: Database) async throws -> Model? {
    try await database.query(Model.StorageModel.self).withRelationships().model(withId: id.value)
  }
}
