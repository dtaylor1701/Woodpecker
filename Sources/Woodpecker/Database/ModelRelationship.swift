import FluentKit
import Foundation

public protocol ModelRelationship<Model> where Model: Storable {
  associatedtype Model
  func addRelationship(with model: Model, on database: Database) async throws
  func updateRelationship(with model: Model, on database: Database) async throws
  func deleteRelationship(on database: Database) async throws
}

public struct SiblingRelationship<Model: Storable, Child: Storable, Through: FluentKit.Model>:
  ModelRelationship
where Model.StorageModel: DatabaseModel, Child.StorageModel: DatabaseModel {
  
  public let modelPath: KeyPath<Model, [Child]>
  public let storageProperty: SiblingsProperty<Model.StorageModel, Child.StorageModel, Through>
  
  public init(
    modelPath: KeyPath<Model, [Child]>,
    storageProperty: SiblingsProperty<Model.StorageModel, Child.StorageModel, Through>
  ) {
    self.modelPath = modelPath
    self.storageProperty = storageProperty
  }
  
  public func addRelationship(with model: Model, on database: Database) async throws {
    let toSave: [Child.StorageModel] = model[keyPath: modelPath].asStorageModels()
    try await storageProperty.attach(toSave, method: .ifNotExists, on: database)
  }
  
  public func updateRelationship(with model: Model, on database: Database) async throws {
    let existing = try await storageProperty.query(on: database).all()
    let updated = model[keyPath: modelPath].asStorageModels()
    
    let delta = try Delta(existing: existing, updated: updated)
    
    try await storageProperty.detach(delta.deleted, on: database)
    try await storageProperty.attach(delta.added, method: .ifNotExists, on: database)
  }
  
  public func deleteRelationship(on database: Database) async throws {
    let existing = try await storageProperty.query(on: database).all()
    try await storageProperty.detach(existing, on: database)
  }
}

public struct ChildRelationship<Model: Storable, Child: Storable>: ModelRelationship
where Model.StorageModel: DatabaseModel, Child.StorageModel: DatabaseModel {
  public let modelPath: KeyPath<Model, [Child]>
  public let storageProperty: ChildrenProperty<Model.StorageModel, Child.StorageModel>
  
  public init(
    modelPath: KeyPath<Model, [Child]>,
    storageProperty: ChildrenProperty<Model.StorageModel, Child.StorageModel>
  ) {
    self.modelPath = modelPath
    self.storageProperty = storageProperty
  }
  
  public func addRelationship(with model: Model, on database: Database) async throws {
    let toSave: [Child.StorageModel] = model[keyPath: modelPath].asStorageModels()
    try await storageProperty.create(toSave, on: database)
  }
  
  public func updateRelationship(with model: Model, on database: Database) async throws {
    let existing = try await storageProperty.query(on: database).all()
    let updated = model[keyPath: modelPath].asStorageModels()
    
    let delta = try Delta(existing: existing, updated: updated)
    
    try await delta.deleted.delete(on: database)
    try await storageProperty.create(delta.added, on: database)
    try await delta.remaining.save(on: database)
  }
  
  public func deleteRelationship(on database: Database) async throws {
    let existing = try await storageProperty.query(on: database).all()
    try await existing.delete(on: database)
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
    
    deleted = try existing.filter {
      try deletedIDs.contains($0.requireID())
    }
    added = try updated.filter {
      try newIDs.contains($0.requireID())
    }
    remaining = try updated.filter {
      try updatedIDs.contains($0.requireID())
    }
  }
}
