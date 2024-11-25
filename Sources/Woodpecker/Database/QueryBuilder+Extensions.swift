import FluentKit
import Foundation

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
