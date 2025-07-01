import FluentKit
import Foundation
import Testing
import Woodpecker

final class SyncedModelServiceTests {
  let localService: ModelDatabaseService<Ingredient>
  let remoteService: TestRemoteService<Ingredient>
  let databaseManager: DatabaseManager
  let service:
    SyncedModelService<
      Ingredient, TestRemoteService<Ingredient>, ModelDatabaseService<Ingredient>,
      DatabaseSyncContext
    >
  let siblingService:
    SyncedModelService<
      Sibling, TestRemoteService<Sibling>, ModelDatabaseService<Sibling>, DatabaseSyncContext
    >

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

    let dependencyManager = DependencyManager<DatabaseSyncContext>()
    let siblingLocalService = ModelDatabaseService<Sibling>(databaseManager: databaseManager)
    siblingService = try await SyncedModelService(
      remoteService: TestRemoteService<Sibling>.forSiblings(), localService: siblingLocalService,
      dependencyManager: dependencyManager)

    localService = ModelDatabaseService<Ingredient>(databaseManager: databaseManager)
    remoteService = try await TestRemoteService<Ingredient>.forIngredients()

    service = SyncedModelService(
      remoteService: remoteService, localService: localService, dependencyManager: dependencyManager
    )
    await dependencyManager.add(service, dependencies: [siblingService])
    await dependencyManager.add(siblingService)
  }

  @Test func all() async throws {
    let remoteModels = await remoteService.models
    let models = try await service.all()

    #expect(Set(models.map(\.id.value)) == Set(remoteModels.map(\.id.value)))

    let localModels = try await localService.all()
    #expect(Set(localModels.map(\.id.value)) == Set(remoteModels.map(\.id.value)))
  }

  @Test func add() async throws {
    let existing = try await service.all()
    var toAdd = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some new child", ingredient: toAdd)
    let sibling: Sibling = Sibling(name: "Some new sibling")
    try await siblingService.add(sibling)
    let siblingToAdd = try #require(try await siblingService.find(withId: sibling.id))
    toAdd.children.append(child)
    toAdd.siblings.append(siblingToAdd)
    try await service.add(toAdd)
    #expect(await remoteService.models.contains { $0.id.value == toAdd.id.value })
    let updated = try await service.all()
    let saved: Ingredient = try #require(try await service.find(withId: toAdd.id))

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
    try await siblingService.add(sibling)
    toUpdate.children.append(child)
    toUpdate.siblings.append(sibling)
    toUpdate = try await service.add(toUpdate)
    toUpdate.name = "new name"
    try await service.update(toUpdate)
    var saved = try #require(try await service.find(withId: toUpdate.id))

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
    try await siblingService.add(firstNewSibling)
    try await siblingService.add(secondNewSibling)
    toUpdate.children.append(firstNewChild)
    toUpdate.siblings.append(firstNewSibling)
    toUpdate.children.append(secondNewChild)
    toUpdate.siblings.append(secondNewSibling)

    try await service.update(toUpdate)
    saved = try #require(try await service.find(withId: toUpdate.id))

    #expect(toUpdate.children.count == saved.children.count)
    #expect(toUpdate.children.first?.id.value == saved.children.first?.id.value)
    #expect(toUpdate.siblings.count == saved.siblings.count)
    #expect(toUpdate.siblings.first?.id.value == saved.siblings.first?.id.value)
  }

  @Test func updateChild() async throws {
    var toUpdate = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toUpdate)
    let sibling = Sibling(name: "Some sibling")
    try await siblingService.add(sibling)
    toUpdate.children.append(child)
    toUpdate.siblings.append(sibling)
    toUpdate = try await service.add(toUpdate)
    var toUpdateChild = toUpdate.children[0]
    toUpdateChild.name = "Updated child"
    toUpdate.children[0] = toUpdateChild
    try await service.update(toUpdate)
    let saved = try #require(try await service.find(withId: toUpdate.id))

    #expect("Updated child" == saved.children[0].name)
  }

  @Test func delete() async throws {
    var toDelete = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toDelete)
    let sibling = Sibling(name: "Some sibling")
    try await siblingService.add(sibling)
    toDelete.children.append(child)
    toDelete.siblings.append(sibling)
    try await service.add(toDelete)
    let existing: [Ingredient] = try await service.all()
    toDelete = try #require(try await service.find(withId: toDelete.id))
    try await service.delete(toDelete)
    let updated: [Ingredient] = try await service.all()

    #expect(
      !updated.contains {
        $0.id == toDelete.id
      })
    #expect(existing.count - 1 == updated.count)
  }

  @Test func find() async throws {
    var toFind = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toFind)
    let sibling = Sibling(name: "Some sibling")
    try await siblingService.add(sibling)
    toFind.children.append(child)
    toFind.siblings.append(sibling)
    try await service.add(toFind)

    let found = try #require(try await service.find(withId: toFind.id))

    #expect(found.id.value == toFind.id.value)
    #expect(found.children.count == toFind.children.count)
    #expect(found.children.first?.id.value == toFind.children.first?.id.value)
    #expect(found.siblings.count == toFind.siblings.count)
    #expect(found.siblings.first?.id.value == toFind.siblings.first?.id.value)
  }

  @Test func sync() async throws {
    try await service.sync()
    try await service.sync()

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
    #expect(remoteIngredient.siblings.count != 0)
    #expect(remoteIngredient.siblings.count == serviceIngredient.siblings.count)
    #expect(remoteIngredient.siblings.first?.id.value == serviceIngredient.siblings.first?.id.value)
  }

  @Test func withoutDependencyManager() async throws {
    let siblingLocalService = ModelDatabaseService<Sibling>(databaseManager: databaseManager)
    let aloneSiblingService = try await SyncedModelService(
      remoteService: TestRemoteService<Sibling>.forSiblings(), localService: siblingLocalService)

    let siblings = try await aloneSiblingService.all()
    #expect(siblings.count > 0)
  }
}
