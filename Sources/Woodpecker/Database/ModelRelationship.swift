import FluentKit
import Foundation

public protocol ModelRelationship<Model>: Sendable
where Model: Storable, Model.StorageModel: DatabaseModel {
  associatedtype Model
  func addRelationship(with model: Model, storageModel: Model.StorageModel, on database: Database)
    async throws
  func updateRelationship(
    with model: Model, storageModel: Model.StorageModel, on database: Database) async throws
  func deleteRelationship(
    with model: Model, storageModel: Model.StorageModel, on database: Database) async throws
  func fetch(with model: Model, storageModel: Model.StorageModel, on database: Database)
    async throws
  func updatedQuery(_ query: QueryBuilder<Model.StorageModel>) -> QueryBuilder<Model.StorageModel>
}

public struct SiblingRelationship<Model: Storable, Sibling: Storable, Through: FluentKit.Model>:
  ModelRelationship
where Model.StorageModel: DatabaseModel, Sibling.StorageModel: DatabaseModel {
  public typealias RelationshipProperty = SiblingsProperty<
    Model.StorageModel, Sibling.StorageModel, Through
  >

  public let modelPath: KeyPath<Model, [Sibling]>
  public let relationshipPropertyPath: KeyPath<Model.StorageModel, RelationshipProperty>

  public init(
    modelPath: KeyPath<Model, [Sibling]>,
    relationshipPropertyPath: KeyPath<Model.StorageModel, RelationshipProperty>
  ) {
    self.modelPath = modelPath
    self.relationshipPropertyPath = relationshipPropertyPath
  }

  public func addRelationship(
    with model: Model, storageModel: Model.StorageModel, on database: Database
  ) async throws {
    let toSave: [Sibling.StorageModel] = model[keyPath: modelPath].asStorageModels()
    try await storageModel[keyPath: relationshipPropertyPath].attach(
      toSave, method: .ifNotExists, on: database)
    storageModel[keyPath: relationshipPropertyPath].value = toSave
  }

  public func updateRelationship(
    with model: Model, storageModel: Model.StorageModel, on database: Database
  ) async throws {
    let relationshipProperty = storageModel[keyPath: relationshipPropertyPath]
    let existing = try await relationshipProperty.query(on: database).all()
    let updated = model[keyPath: modelPath].asStorageModels()

    let delta = try Delta(existing: existing, updated: updated)

    try await relationshipProperty.detach(delta.deleted, on: database)
    try await relationshipProperty.attach(delta.added, method: .ifNotExists, on: database)
    storageModel[keyPath: relationshipPropertyPath].value = delta.added + delta.remaining
  }

  public func deleteRelationship(
    with model: Model, storageModel: Model.StorageModel, on database: Database
  ) async throws {
    let relationshipProperty = storageModel[keyPath: relationshipPropertyPath]
    try await relationshipProperty.detachAll(on: database)
  }

  public func fetch(with model: Model, storageModel: Model.StorageModel, on database: any Database)
    async throws
  {
    _ = try await storageModel[keyPath: relationshipPropertyPath].get(on: database)
  }

  public func updatedQuery(_ query: QueryBuilder<Model.StorageModel>) -> QueryBuilder<
    Model.StorageModel
  > {
    query.with(relationshipPropertyPath)
  }
}

public struct ChildRelationship<Model: Storable, Child: Storable>: ModelRelationship
where Model.StorageModel: DatabaseModel, Child.StorageModel: DatabaseModel {
  public typealias RelationshipProperty = ChildrenProperty<Model.StorageModel, Child.StorageModel>

  public let modelPath: KeyPath<Model, [Child]>
  public let relationshipPropertyPath: KeyPath<Model.StorageModel, RelationshipProperty>

  public init(
    modelPath: KeyPath<Model, [Child]>,
    relationshipPropertyPath: KeyPath<Model.StorageModel, RelationshipProperty>
  ) {
    self.modelPath = modelPath
    self.relationshipPropertyPath = relationshipPropertyPath
  }

  public func addRelationship(
    with model: Model, storageModel: Model.StorageModel, on database: Database
  ) async throws {
    let toSave: [Child.StorageModel] = model[keyPath: modelPath].asStorageModels()
    try await storageModel[keyPath: relationshipPropertyPath].create(toSave, on: database)
    storageModel[keyPath: relationshipPropertyPath].value = toSave
  }

  public func updateRelationship(
    with model: Model, storageModel: Model.StorageModel, on database: Database
  ) async throws {
    let storageProperty = storageModel[keyPath: relationshipPropertyPath]
    let existing = try await storageProperty.query(on: database).all()
    let updated = model[keyPath: modelPath].asStorageModels()

    let delta = try Delta(existing: existing, updated: updated)

    try await delta.deleted.delete(on: database)
    try await storageProperty.create(delta.added, on: database)
    try await delta.remaining.save(on: database)
    storageModel[keyPath: relationshipPropertyPath].value = delta.added + delta.remaining
  }

  public func deleteRelationship(
    with model: Model, storageModel: Model.StorageModel, on database: Database
  ) async throws {
    let existing = try await storageModel[keyPath: relationshipPropertyPath].query(on: database)
      .all()
    try await existing.delete(on: database)
    storageModel[keyPath: relationshipPropertyPath].value = []
  }

  public func fetch(with model: Model, storageModel: Model.StorageModel, on database: any Database)
    async throws
  {
    let values = try await storageModel[keyPath: relationshipPropertyPath].get(on: database)
    storageModel[keyPath: relationshipPropertyPath].value = values
  }

  public func updatedQuery(_ query: QueryBuilder<Model.StorageModel>) -> QueryBuilder<
    Model.StorageModel
  > {
    query.with(relationshipPropertyPath)
  }
}

struct Delta<T: DatabaseModel> {
  let deleted: [T]
  let added: [T]
  let remaining: [T]

  init(existing: [T], updated: [T]) throws {
    let existingIDs = try Set(existing.map { try $0.requireID() })
    let updatedIDs = try Set(updated.map { try $0.requireID() })
    let newIDs = updatedIDs.subtracting(existingIDs)
    let deletedIDs = existingIDs.subtracting(updatedIDs)
    let remainingIDs = updatedIDs.intersection(existingIDs)

    deleted = try existing.filter {
      try deletedIDs.contains($0.requireID())
    }
    added = try updated.filter {
      try newIDs.contains($0.requireID())
    }
    remaining = try updated.filter {
      try remainingIDs.contains($0.requireID())
    }
  }
}
