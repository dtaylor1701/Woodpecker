import FluentKit
import Foundation

public protocol DatabaseModel: FluentKit.Model, StorableStorageModel
where AppModel: Storable, AppModel.StorageModel == Self, Self.IDValue == UUID {
  static var relationships: [any ModelRelationship<AppModel>] { get }
  static func withRelationships(in query: QueryBuilder<Self>) -> QueryBuilder<Self>

  func addRelationships(from model: AppModel, on database: Database) async throws
  func updateRelationships(from model: AppModel, on database: Database) async throws
  func deleteRelationships(from model: AppModel, on database: Database) async throws
  func withRelationships(from model: AppModel, on database: Database) async throws
}

extension DatabaseModel {
  public static var relationships: [any ModelRelationship<AppModel>] { [] }

  public func addRelationships(from model: AppModel, on database: Database) async throws {
    for relationship in Self.relationships {
      try await relationship.addRelationship(with: model, storageModel: self, on: database)
    }
  }

  public func updateRelationships(from model: AppModel, on database: Database) async throws {
    for relationship in Self.relationships {
      try await relationship.updateRelationship(with: model, storageModel: self, on: database)
    }
  }

  public func deleteRelationships(from model: AppModel, on database: Database) async throws {
    for relationship in Self.relationships {
      try await relationship.deleteRelationship(with: model, storageModel: self, on: database)
    }
  }

  public func withRelationships(from model: AppModel, on database: Database) async throws {
    for relationship in Self.relationships {
      try await relationship.fetch(with: model, storageModel: self, on: database)
    }
  }

  public static func withRelationships(in query: QueryBuilder<Self>) -> QueryBuilder<Self> {
    var query = query
    for relationship in relationships {
      query = relationship.updatedQuery(query)
    }
    return query
  }

  public func updateStorableID(_ storableID: StorableID) {
    id = storableID.value
    _$idExists = storableID.stored
  }
}

extension Collection where Element: DatabaseModel {
  public func save(on database: Database) async throws {
    for item in self {
      try await item.save(on: database)
    }
  }
}

extension QueryBuilder where Model: DatabaseModel {
  public func withRelationships() -> QueryBuilder<Model> {
    var query = self
    for relationship in Model.relationships {
      query = relationship.updatedQuery(query)
    }
    return query
  }
}
