import FluentKit
import Foundation

public typealias DatabaseModel = FluentKit.Model

extension DatabaseModel {
  public func asExisting(_ existing: Bool) -> Self {
    _$idExists = existing
    return self
  }
}

extension Collection where Element: DatabaseModel {
  public func save(on database: Database) async throws {
    for item in self {
      try await item.save(on: database)
    }
  }
}

public protocol EagerLoadable: DatabaseModel {
  static func fullyLoaded(in query: QueryBuilder<Self>) -> QueryBuilder<Self>
}

extension QueryBuilder where Model: EagerLoadable {
  public func fullyLoaded() -> QueryBuilder<Model> {
    return Model.fullyLoaded(in: self)
  }
}

extension QueryBuilder {
  public func find(withId id: Model.IDValue) async throws -> Model? {
    try await filter(\._$id == id)
      .first()
  }

  public func model<AppModel: Storable>(withId id: Model.IDValue) async throws -> AppModel?
  where AppModel.StorageModel == Model {
    guard let result: Model = try await find(withId: id) else { return nil }

    return try AppModel.createExisting(fromStorageModel: result)
  }

  public func allModels<AppModel: Storable>() async throws -> [AppModel]
  where AppModel.StorageModel == Model {
    try await all().map { try AppModel.createExisting(fromStorageModel: $0) }
  }
}
