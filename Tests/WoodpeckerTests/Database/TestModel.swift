import FluentKit
import Foundation
import Woodpecker

struct Ingredient: Codable, Identifiable {
  let id: UUID
  var stored: Bool = false

  var name: String
  var children: [Child]
  var siblings: [Sibling]

  init(id: UUID = UUID(), name: String, children: [Child], siblings: [Sibling]) {
    self.id = id
    self.name = name
    self.children = children
    self.siblings = siblings
  }
}

struct Child: Codable, Identifiable {
  let id: UUID
  var stored: Bool = false
  let ingredientID: UUID

  var name: String

  init(id: UUID = UUID(), name: String, ingredientID: UUID) {
    self.id = id
    self.name = name
    self.ingredientID = ingredientID
  }

  init(id: UUID = UUID(), name: String, ingredient: Ingredient) {
    self.init(id: id, name: name, ingredientID: ingredient.id)
  }
}

struct Sibling: Codable, Identifiable {
  let id: UUID
  var stored: Bool = false

  var name: String

  init(id: UUID = UUID(), name: String) {
    self.id = id
    self.name = name
  }
}

enum Stored {
  final class Ingredient: DatabaseModel, @unchecked Sendable {
    static let schema: String = "ingredients"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Children(for: \.$ingredient)
    var children: [Child]

    @Siblings(through: IngredientSibling.self, from: \.$ingredient, to: \.$sibling)
    var siblings: [Sibling]

    init() {}

    init(id: UUID, name: String) {
      self.id = id
      self.name = name
    }

    func relationships() -> [any Woodpecker.ModelRelationship<WoodpeckerTests.Ingredient>] {
      [
        ChildRelationship<
          WoodpeckerTests.Ingredient, WoodpeckerTests.Child
        >(
          modelPath: \.children, storageProperty: $children),
        SiblingRelationship<
          WoodpeckerTests.Ingredient, WoodpeckerTests.Sibling, Stored.IngredientSibling
        >(modelPath: \.siblings, storageProperty: $siblings),
      ]
    }

    static func withRelationships(in query: FluentKit.QueryBuilder<Stored.Ingredient>)
      -> FluentKit.QueryBuilder<Stored.Ingredient>
    {
      query.with(\.$children).with(\.$siblings)
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

  final class Child: DatabaseModel, @unchecked Sendable {
    static let schema: String = "children"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Parent(key: "ingredient_id")
    var ingredient: Ingredient

    init() {}

    init(id: UUID, name: String, ingredientID: Ingredient.IDValue) {
      self.id = id
      self.name = name
      self.$ingredient.id = ingredientID
    }

    static func withRelationships(in query: FluentKit.QueryBuilder<Stored.Child>)
      -> FluentKit.QueryBuilder<Child>
    {
      return query
    }

    func relationships() -> [any ModelRelationship<WoodpeckerTests.Child>] {
      []
    }
  }

  struct ChildCreateMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
      try await database.schema("children")
        .id()
        .field("ingredient_id", .uuid, .required, .references("ingredients", "id"))
        .field("name", .string, .required)
        .create()
    }

    func revert(on database: Database) async throws {
      try await database.schema("children").delete()
    }
  }

  final class Sibling: DatabaseModel, @unchecked Sendable {
    static func withRelationships(in query: FluentKit.QueryBuilder<Stored.Sibling>)
      -> FluentKit.QueryBuilder<Stored.Sibling>
    {
      return query
    }

    func relationships() -> [any ModelRelationship<WoodpeckerTests.Sibling>] {
      []
    }

    static let schema: String = "siblings"

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

  struct SiblingCreateMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
      try await database.schema("siblings")
        .id()
        .field("name", .string, .required)
        .create()
    }

    func revert(on database: Database) async throws {
      try await database.schema("siblings").delete()
    }
  }

  final class IngredientSibling: Model, @unchecked Sendable {
    static let schema: String = "ingredient+sibling"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "ingredient_id")
    var ingredient: Ingredient

    @Parent(key: "sibling_id")
    var sibling: Sibling
  }

  struct IngredientSiblingCreateMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
      try await database.schema("ingredient+sibling")
        .id()
        .field("ingredient_id", .uuid, .required, .references("ingredients", "id"))
        .field("sibling_id", .uuid, .required, .references("siblings", "id"))
        .create()
    }

    func revert(on database: Database) async throws {
      try await database.schema("ingredient+sibling").delete()
    }
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
      name: storageModel.name,
      children: storageModel.children.map { try Child.createExisting(fromStorageModel: $0) },
      siblings: storageModel.siblings.map { try Sibling.createExisting(fromStorageModel: $0) })
  }
}

extension Child: Storable {
  static func create(fromStorageModel storageModel: Stored.Child) throws -> Child {
    try Child(
      id: storageModel.requireID(), name: storageModel.name,
      ingredientID: storageModel.$ingredient.id)
  }

  static func createStorageModel(from model: Child) -> Stored.Child {
    Stored.Child(id: model.id, name: model.name, ingredientID: model.ingredientID).asExisting(
      model.stored)
  }
}

extension Sibling: Storable {
  static func create(fromStorageModel storageModel: Stored.Sibling) throws -> Sibling {
    try Sibling(id: storageModel.requireID(), name: storageModel.name)

  }

  static func createStorageModel(from model: Sibling) -> Stored.Sibling {
    Stored.Sibling(id: model.id, name: model.name).asExisting(model.stored)
  }
}
