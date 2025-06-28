import FluentKit
import Foundation
import Woodpecker

struct Ingredient: Codable, Identifiable {
  var id: StorableID

  var name: String
  var children: [Child]
  var siblings: [Sibling]

  init(id: ID = .new(), name: String, children: [Child], siblings: [Sibling]) {
    self.id = id
    self.name = name
    self.children = children
    self.siblings = siblings
  }
}

struct Child: Codable, Identifiable {
  var id: StorableID
  let ingredientID: StorableID

  var name: String

  init(id: StorableID = .new(), name: String, ingredientID: StorableID) {
    self.id = id
    self.name = name
    self.ingredientID = ingredientID
  }

  init(id: StorableID = .new(), name: String, ingredient: Ingredient) {
    self.init(id: id, name: name, ingredientID: ingredient.id)
  }
}

struct Sibling: Codable, Identifiable {
  var id: StorableID

  var name: String

  init(id: StorableID = .new(), name: String) {
    self.id = id
    self.name = name
  }
}

enum Stored {
  final class Ingredient: DatabaseModel, @unchecked Sendable {
    typealias AppModel = WoodpeckerTests.Ingredient

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

    init(id: StorableID, name: String) {
      self.name = name
      updateStorableID(id)
    }

    public static let relationships:
      [any Woodpecker.ModelRelationship<WoodpeckerTests.Ingredient>] =
        [
          ChildRelationship<
            WoodpeckerTests.Ingredient, WoodpeckerTests.Child
          >(
            modelPath: \.children, relationshipPropertyPath: \.$children),
          SiblingRelationship<
            WoodpeckerTests.Ingredient, WoodpeckerTests.Sibling, Stored.IngredientSibling
          >(modelPath: \.siblings, relationshipPropertyPath: \.$siblings),
        ]

    static func create(fromAppModel appModel: WoodpeckerTests.Ingredient) -> Self {
      Self(id: appModel.id, name: appModel.name)
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
    typealias AppModel = WoodpeckerTests.Child

    static let schema: String = "children"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Parent(key: "ingredient_id")
    var ingredient: Ingredient

    init() {}

    init(id: StorableID, name: String, ingredientID: Ingredient.IDValue) {
      self.name = name
      self.$ingredient.id = ingredientID
      updateStorableID(id)
    }

    static func create(fromAppModel appModel: WoodpeckerTests.Child) -> Self {
      Self(id: appModel.id, name: appModel.name, ingredientID: appModel.ingredientID.value)
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
    typealias AppModel = WoodpeckerTests.Sibling

    static let schema: String = "siblings"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    init() {}

    init(id: StorableID, name: String) {
      self.name = name
      updateStorableID(id)
    }

    static func create(fromAppModel appModel: WoodpeckerTests.Sibling) -> Self {
      Self(id: appModel.id, name: appModel.name)
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
  static func create(fromStorageModel storageModel: Stored.Ingredient) throws -> Ingredient {
    try Ingredient(
      id: .from(storageModel: storageModel),
      name: storageModel.name,
      children: [Child].create(fromStorageModels: storageModel.children),
      siblings: [Sibling].create(fromStorageModels: storageModel.siblings))
  }
}

extension Child: Storable {
  static func create(fromStorageModel storageModel: Stored.Child) throws -> Child {
    try Child(
      id: .from(storageModel: storageModel),
      name: storageModel.name,
      ingredientID: .stored(storageModel.$ingredient.id))
  }
}

extension Sibling: Storable {
  static func create(fromStorageModel storageModel: Stored.Sibling) throws -> Sibling {
    try Sibling(id: .from(storageModel: storageModel), name: storageModel.name)
  }
}
