import FluentKit
import Foundation
import Testing
import Woodpecker

final class ModelRelationshipTest {
  let databaseManager: DatabaseManager

  var database: Database {
    get async {
      await databaseManager.database
    }
  }

  init() async throws {
    databaseManager = DatabaseManager(configuration: .memory)
    await databaseManager.add(migrations: [
      Stored.IngredientCreateMigration(), Stored.ChildCreateMigration(),
      Stored.SiblingCreateMigration(), Stored.IngredientSiblingCreateMigration(),
    ])
    try await databaseManager.start()
  }

  // Add

  @Test
  func addChildRelationship() async throws {
    var toAdd = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toAdd)
    toAdd.children = [child]

    let storageModel = toAdd.asStorageModel()
    try await storageModel.save(on: database)

    let childRelationship = ChildRelationship(
      modelPath: \Ingredient.children, relationshipPropertyPath: \Stored.Ingredient.$children)
    try await childRelationship.addRelationship(
      with: toAdd, storageModel: storageModel, on: database)

    #expect(storageModel.$children.value != nil)
  }

  @Test
  func addSiblingRelationship() async throws {
    var toAdd = Ingredient(name: "chips", children: [], siblings: [])
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toAdd.siblings = [sibling]

    let storageModel = toAdd.asStorageModel()
    try await storageModel.save(on: database)

    let siblingRelationship = SiblingRelationship(
      modelPath: \Ingredient.siblings, relationshipPropertyPath: \Stored.Ingredient.$siblings)
    try await siblingRelationship.addRelationship(
      with: toAdd, storageModel: storageModel, on: database)

    #expect(storageModel.$siblings.value != nil)
  }

  @Test
  func addAllRelationships() async throws {
    var toAdd = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toAdd)
    toAdd.children = [child]
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toAdd.siblings = [sibling]

    let storageModel = toAdd.asStorageModel()
    try await storageModel.save(on: database)
    try await storageModel.addRelationships(from: toAdd, on: database)

    #expect(storageModel.$children.value != nil)
    #expect(storageModel.$siblings.value != nil)
  }

  // Delete

  @Test
  func deleteChildRelationship() async throws {
    var toAdd = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toAdd)
    toAdd.children = [child]

    let storageModel = toAdd.asStorageModel()
    try await storageModel.save(on: database)

    let childRelationship = ChildRelationship(
      modelPath: \Ingredient.children, relationshipPropertyPath: \Stored.Ingredient.$children)
    try await childRelationship.addRelationship(
      with: toAdd, storageModel: storageModel, on: database)

    #expect(try await Stored.Child.query(on: database).count() == 1)

    try await childRelationship.deleteRelationship(
      with: toAdd, storageModel: storageModel, on: database)

    #expect(try await Stored.Child.query(on: database).count() == 0)
  }

  @Test
  func deleteSiblingRelationship() async throws {
    var toAdd = Ingredient(name: "chips", children: [], siblings: [])
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toAdd.siblings = [sibling]

    let storageModel = toAdd.asStorageModel()
    try await storageModel.save(on: database)

    let siblingRelationship = SiblingRelationship(
      modelPath: \Ingredient.siblings, relationshipPropertyPath: \Stored.Ingredient.$siblings)
    try await siblingRelationship.addRelationship(
      with: toAdd, storageModel: storageModel, on: database)

    #expect(try await Stored.IngredientSibling.query(on: database).count() == 1)

    try await siblingRelationship.deleteRelationship(
      with: toAdd, storageModel: storageModel, on: database)

    #expect(try await Stored.IngredientSibling.query(on: database).count() == 0)
  }

  // Update

  @Test
  func updateChildRelationship() async throws {
    var ingredient = Ingredient(name: "chips", children: [], siblings: [])
    let child1 = Child(name: "Child 1", ingredient: ingredient)
    let child2 = Child(name: "Child 2", ingredient: ingredient)
    ingredient.children = [child1, child2]

    let storageModel = ingredient.asStorageModel()
    try await storageModel.save(on: database)

    let childRelationship = ChildRelationship(
      modelPath: \Ingredient.children, relationshipPropertyPath: \Stored.Ingredient.$children)
    try await childRelationship.addRelationship(
      with: ingredient, storageModel: storageModel, on: database)

    let savedChildren = try await Stored.Child.query(on: database).sort(\.$name).all()
    #expect(savedChildren.count == 2)
    let savedChild1ID = try savedChildren[0].requireID()
    var updatedChild2 = try Child.create(fromStorageModel: savedChildren[1])
    updatedChild2.name = "Child 2 updated"

    let child3 = Child(name: "Child 3", ingredient: ingredient)
    ingredient.children = [updatedChild2, child3]

    try await childRelationship.updateRelationship(
      with: ingredient, storageModel: storageModel, on: database)

    let finalChildren = try await Stored.Child.query(on: database).sort(\.$name).all()
    #expect(finalChildren.count == 2)
    #expect(finalChildren[0].name == "Child 2 updated")
    #expect(finalChildren[1].name == "Child 3")
    #expect(try await Stored.Child.find(savedChild1ID, on: database) == nil)
  }

  @Test
  func updateSiblingRelationship() async throws {
    var ingredient = Ingredient(name: "chips", children: [], siblings: [])
    let sibling1 = Sibling(name: "Sibling 1")
    try await sibling1.asStorageModel().save(on: database)
    let sibling2 = Sibling(name: "Sibling 2")
    try await sibling2.asStorageModel().save(on: database)

    ingredient.siblings = [sibling1, sibling2]

    let storageModel = ingredient.asStorageModel()
    try await storageModel.save(on: database)

    let siblingRelationship = SiblingRelationship(
      modelPath: \Ingredient.siblings, relationshipPropertyPath: \Stored.Ingredient.$siblings)
    try await siblingRelationship.addRelationship(
      with: ingredient, storageModel: storageModel, on: database)

    #expect(try await storageModel.$siblings.get(on: database).count == 2)

    let sibling3 = Sibling(name: "Sibling 3")
    try await sibling3.asStorageModel().save(on: database)
    ingredient.siblings = [sibling2, sibling3]

    try await siblingRelationship.updateRelationship(
      with: ingredient, storageModel: storageModel, on: database)

    let attachedSiblings = try await storageModel.$siblings.get(on: database).sorted(by: {
      $0.name < $1.name
    })
    #expect(attachedSiblings.count == 2)
    #expect(attachedSiblings[0].name == "Sibling 2")
    #expect(attachedSiblings[1].name == "Sibling 3")
  }
}
