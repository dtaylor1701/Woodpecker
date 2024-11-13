import FluentKit
import Foundation
import Woodpecker

struct Ingredient: Codable, Identifiable {
  let id: UUID
  var stored: Bool = false

  var name: String

  init(id: UUID = UUID(), name: String) {
    self.id = id
    self.name = name
  }
}

enum Stored {
  final class Ingredient: Model, @unchecked Sendable {
    static let schema: String = "ingredients"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    init() {}

    init(id: UUID, name: String) {
      self.id = id
      self.name = name
    }
  }

  struct IngredientCreateMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
      try await database.schema("ingredients")
        .id()
        .field("name", .string, .required)
        .create()
    }

    func revert(on database: Database) async throws {
      try await database.schema("ingredients").delete()
    }
  }

}

extension Stored.Ingredient: Woodpecker.EagerLoadable {
  static func fullyLoaded(in query: FluentKit.QueryBuilder<Stored.Ingredient>)
    -> FluentKit.QueryBuilder<Stored.Ingredient>
  {
    return query
  }
}

extension Ingredient: Storable {
  static func createStorageModel(from model: Ingredient) -> Stored.Ingredient {
    Stored.Ingredient(
      id: model.id,
      name: model.name
    )
    .asExisting(model.stored)
  }

  static func create(fromStorageModel storageModel: Stored.Ingredient) throws -> Ingredient {
    try Ingredient(
      id: storageModel.requireID(),
      name: storageModel.name)
  }
}
