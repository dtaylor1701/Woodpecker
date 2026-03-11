import FluentKit
import Foundation
import Testing
@testable import Woodpecker

final class MergeSyncTest {
  let localService: ModelDatabaseService<Ingredient>
  let remoteService: TestRemoteService<Ingredient>
  let databaseManager: DatabaseManager
  let service:
    SyncedModelService<
      Ingredient, TestRemoteService<Ingredient>, ModelDatabaseService<Ingredient>,
      DatabaseSyncContext
    >

  init() async throws {
    databaseManager = DatabaseManager(configuration: .memory)
    try await databaseManager.setUpForSyncedModelStore()
    await databaseManager.add(migrations: [
      Stored.IngredientCreateMigration(), Stored.ChildCreateMigration(),
      Stored.SiblingCreateMigration(), Stored.IngredientSiblingCreateMigration(),
    ])
    try await databaseManager.start()

    localService = ModelDatabaseService<Ingredient>(databaseManager: databaseManager)
    remoteService = TestRemoteService<Ingredient>()

    service = SyncedModelService(
      remoteService: remoteService,
      localService: localService,
      syncStrategy: .merge(RemoteWinsStrategy())
    )
  }

  @Test func mergeSync() async throws {
    // 1. Setup local state
    let id = StorableID.new()
    let localIngredient = Ingredient(id: id, name: "local name", children: [], siblings: [])
    _ = try await localService.add(localIngredient)
    
    // 2. Setup remote state with same ID but different name
    let remoteIngredient = Ingredient(id: id, name: "remote name", children: [], siblings: [])
    try await remoteService.add(remoteIngredient)
    
    // 3. Mark local as stale to trigger sync
    try await localService.markStale()
    
    // 4. Sync (should merge and resolve using RemoteWinsStrategy)
    let models = try await service.all()
    
    #expect(models.count == 1)
    #expect(models.first?.name == "remote name")
    
    let savedLocal = try #require(try await localService.find(withId: id))
    #expect(savedLocal.name == "remote name")
  }
  
  @Test func localWinsMergeSync() async throws {
    // 1. Setup service with LocalWinsStrategy
    let localWinsService = SyncedModelService<
      Ingredient, TestRemoteService<Ingredient>, ModelDatabaseService<Ingredient>,
      DatabaseSyncContext
    >(
      remoteService: remoteService,
      localService: localService,
      syncStrategy: .merge(LocalWinsStrategy())
    )
    
    // 2. Setup local state
    let id = StorableID.new()
    let localIngredient = Ingredient(id: id, name: "local name", children: [], siblings: [])
    _ = try await localService.add(localIngredient)
    
    // 3. Setup remote state with same ID but different name
    let remoteIngredient = Ingredient(id: id, name: "remote name", children: [], siblings: [])
    try await remoteService.add(remoteIngredient)
    
    // 4. Mark local as stale to trigger sync
    try await localService.markStale()
    
    // 5. Sync (should merge and resolve using LocalWinsStrategy)
    let models = try await localWinsService.all()
    
    #expect(models.count == 1)
    #expect(models.first?.name == "local name")
    
    let savedLocal = try #require(try await localService.find(withId: id))
    #expect(savedLocal.name == "local name")
  }
}
