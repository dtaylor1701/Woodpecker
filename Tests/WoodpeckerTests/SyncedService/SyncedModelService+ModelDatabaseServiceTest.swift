import FluentKit
import Foundation
import Testing
import Woodpecker

final class SyncedModelService_ModelDatabaseServiceTests {
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

    remoteService = try await TestRemoteService<Ingredient>.forIngredients()
    service = .createWith(
      databaseManager: databaseManager, remoteService: remoteService,
      dependencyManager: dependencyManager)

    await dependencyManager.add(service, dependencies: [siblingService])
    await dependencyManager.add(siblingService)
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
}
