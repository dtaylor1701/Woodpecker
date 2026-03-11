import FluentKit
import Foundation
import Testing
import Woodpecker

final class ModelDatabaseServiceTests {
  let service: ModelDatabaseService<Ingredient>
  let databaseManager: DatabaseManager

  var database: Database {
    get async {
      await databaseManager.database
    }
  }

  init() async throws {
    databaseManager = DatabaseManager(configuration: .memory)
    try await databaseManager.setUpForSyncedModelStore()
    await databaseManager.add(migrations: [
      Stored.IngredientCreateMigration(), Stored.ChildCreateMigration(),
      Stored.SiblingCreateMigration(), Stored.IngredientSiblingCreateMigration(),
    ])
    try await databaseManager.start()
    service = ModelDatabaseService<Ingredient>(databaseManager: databaseManager)
  }

  @Test func add() async throws {
    let existing = try await service.all()
    var toAdd = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toAdd)
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toAdd.children.append(child)
    toAdd.siblings.append(sibling)
    let saved = try await service.add(toAdd)
    #expect(saved.stored == true)
    #expect(saved.children.first?.stored == true)

    let updated = try await service.all()
    #expect(existing.count + 1 == updated.count)
    #expect(toAdd.name == saved.name)
    #expect(saved.stored)
    #expect(toAdd.children.count == saved.children.count)
    #expect(saved.children.count == 1)
    #expect(toAdd.children.first?.id.value == saved.children.first?.id.value)
    #expect(toAdd.siblings.count == saved.siblings.count)
    #expect(toAdd.siblings.first?.id.value == saved.siblings.first?.id.value)
  }

  @Test func update() async throws {
    var toUpdate = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toUpdate)
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toUpdate.children.append(child)
    toUpdate.siblings.append(sibling)
    toUpdate = try await service.add(toUpdate)
    let existing = try await service.all()
    let found = try await service.find(withId: toUpdate.id)
    toUpdate = try #require(found)
    toUpdate.name = "new name"
    var saved = try await service.update(toUpdate)
    let updated = try await service.all()

    #expect(existing.count == updated.count)
    #expect(toUpdate.name == saved.name)
    #expect(toUpdate.children.count == saved.children.count)
    #expect(toUpdate.children.first?.id.value == saved.children.first?.id.value)
    #expect(toUpdate.siblings.count == saved.siblings.count)
    #expect(toUpdate.siblings.first?.id.value == saved.siblings.first?.id.value)

    toUpdate.children.removeAll()
    toUpdate.siblings.removeAll()
    let firstNewChild = Child(name: "Child one", ingredient: toUpdate)
    let firstNewSibling = Sibling(name: "Sibling one")
    let secondNewChild = Child(name: "Child two", ingredient: toUpdate)
    let secondNewSibling = Sibling(name: "Sibling two")
    try await firstNewSibling.asStorageModel().save(on: database)
    try await secondNewSibling.asStorageModel().save(on: database)
    toUpdate.children.append(firstNewChild)
    toUpdate.siblings.append(firstNewSibling)
    toUpdate.children.append(secondNewChild)
    toUpdate.siblings.append(secondNewSibling)

    saved = try await service.update(toUpdate)

    #expect(toUpdate.children.count == saved.children.count)
    #expect(toUpdate.children.first?.id.value == saved.children.first?.id.value)
    #expect(toUpdate.siblings.count == saved.siblings.count)
    #expect(toUpdate.siblings.first?.id.value == saved.siblings.first?.id.value)
  }

  @Test func updateChild() async throws {
    var toUpdate = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toUpdate)
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toUpdate.children.append(child)
    toUpdate.siblings.append(sibling)
    toUpdate = try await service.add(toUpdate)
    var toUpdateChild = toUpdate.children[0]
    toUpdateChild.name = "Updated child"
    toUpdate.children[0] = toUpdateChild
    let updated = try await service.update(toUpdate)

    #expect("Updated child" == updated.children[0].name)
  }

  @Test func delete() async throws {
    var toDelete = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toDelete)
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toDelete.children.append(child)
    toDelete.siblings.append(sibling)
    toDelete = try await service.add(toDelete)
    let beforeCount = try await service.all().count
    try await service.delete(toDelete)
    let updated: [Ingredient] = try await service.all()

    #expect(
      !updated.contains {
        $0.id == toDelete.id
      })
    #expect(beforeCount - 1 == updated.count)
  }

  @Test func find() async throws {
    var toFind = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toFind)
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toFind.children.append(child)
    toFind.siblings.append(sibling)
    toFind = try await service.add(toFind)

    let found = try #require(try await service.find(withId: toFind.id))

    #expect(found.id.value == toFind.id.value)
    #expect(found.children.count == toFind.children.count)
    #expect(found.children.first?.id.value == toFind.children.first?.id.value)
    #expect(found.siblings.count == toFind.siblings.count)
    #expect(found.siblings.first?.id.value == toFind.siblings.first?.id.value)
  }

  @Test func clear() async throws {
    let service = service
    try await service.withContext { context in
      try await service.clear(withContext: context)
    }

    let serviceModels = try await service.all()

    #expect(serviceModels.count == 0)
  }

  @Test func populate() async throws {
    let remoteService = try await TestRemoteService<Ingredient>.forIngredients(withSiblings: false)
    let service = self.service
    var isStale = try await service.isStale()
    #expect(isStale == true)
    try await service.withContext { context in
      try await service.populate(with: remoteService, conflictResolutionStrategy: nil, context: context)
    }

    let serviceModels = try await service.all()
    let remoteModels = await remoteService.models

    let serviceIngredient = try #require(serviceModels.first)
    let remoteIngredient = try #require(remoteModels.first)

    #expect(serviceModels.count == remoteModels.count)
    #expect(serviceIngredient.name == remoteIngredient.name)
    #expect(serviceIngredient.stored)
    #expect(remoteIngredient.children.count == serviceIngredient.children.count)
    #expect(serviceIngredient.children.count == 1)
    #expect(remoteIngredient.children.first?.id.value == serviceIngredient.children.first?.id.value)
    isStale = try await service.isStale()
    #expect(isStale == false)
  }
}
