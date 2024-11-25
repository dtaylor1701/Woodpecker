import FluentKit
import Foundation

public protocol DatabaseModel: FluentKit.Model
where AppModel: Storable, AppModel.StorageModel == Self, AppModel.ID == Self.IDValue {
  associatedtype AppModel: Storable
  static func withRelationships(in query: QueryBuilder<Self>) -> QueryBuilder<Self>
  func relationships() -> [any ModelRelationship<AppModel>]
  func addRelationships(from model: AppModel, on database: Database) async throws
  func updateRelationships(from model: AppModel, on database: Database) async throws
  func deleteRelationships(on database: Database) async throws
}

extension DatabaseModel {
  public func asExisting(_ existing: Bool) -> Self {
    _$idExists = existing
    return self
  }
  
  public func addRelationships(from model: AppModel, on database: Database) async throws {
    for relationship in relationships() {
      try await relationship.addRelationship(with: model, on: database)
    }
  }
  
  public func updateRelationships(from model: AppModel, on database: Database) async throws {
    for relationship in relationships() {
      try await relationship.updateRelationship(with: model, on: database)
    }
  }
  
  public func deleteRelationships(on database: Database) async throws {
    for relationship in relationships() {
      try await relationship.deleteRelationship(on: database)
    }
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
    return Model.withRelationships(in: self)
  }
}
