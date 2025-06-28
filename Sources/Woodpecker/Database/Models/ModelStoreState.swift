import FluentKit
import Foundation

public final class SyncedModelStoreState: Model, @unchecked Sendable {
  public static let schema = "synced_model_store_state"

  @ID(key: .id)
  public var id: UUID?

  @Field(key: "key")
  public var key: String

  @Field(key: "stale")
  public var stale: Bool

  public init() {}

  public init(id: UUID? = nil, key: String, stale: Bool = true) {
    self.key = key
    self.stale = stale
  }
}

public struct SyncedModelStoreStateCreateMigration: AsyncMigration {
  public func prepare(on database: any Database) async throws {
    try await database.schema("synced_model_store_state")
      .id()
      .field("key", .string, .required)
      .field("stale", .bool, .required)
      .unique(on: "key")
      .create()
  }

  public func revert(on database: any Database) async throws {
    try await database.schema("synced_model_store_state").delete()
  }
}
