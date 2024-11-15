import FluentKit
import Foundation
import Testing
import Woodpecker

final class ModelServiceTests {
  let service: ModelService<Ingredient>
  let databaseManager: DatabaseManager

  init() async throws {
    databaseManager = DatabaseManager(configuration: .memory)
    await databaseManager.add(migration: Stored.IngredientCreateMigration())
    try await databaseManager.start()
    service = .init(databaseManager: databaseManager)
  }

  @Test func add() async throws {
    let existing = try await service.all()
    let toAdd = Ingredient(name: "chips")
    try await service.add(toAdd)
    let updated = try await service.all()
    let saved = try #require(updated.first { $0.id == toAdd.id })

    #expect(existing.count + 1 == updated.count)
    #expect(toAdd.name == saved.name)
    #expect(saved.stored)
  }

  @Test func update() async throws {
    var toUpdate = Ingredient(name: "chips")
    try await service.add(toUpdate)
    let existing = try await service.all()
    toUpdate = try #require(existing.first { $0.id == toUpdate.id })
    toUpdate.name = "new name"
    try await service.update(toUpdate)
    let updated = try await service.all()
    let saved = try #require(updated.first { $0.id == toUpdate.id })

    #expect(existing.count == updated.count)
    #expect(toUpdate.name == saved.name)
  }

  @Test func delete() async throws {
    let toDelete = Ingredient(name: "chips")
    try await service.add(toDelete)
    let existing = try await service.all()
    try await service.delete(toDelete)
    let updated = try await service.all()

    #expect(
      !updated.contains {
        $0.id == toDelete.id
      })
    #expect(existing.count - 1 == updated.count)
  }

  @Test func find() async throws {
    let toFind = Ingredient(name: "chips")
    try await service.add(toFind)

    let found = try #require(try await service.find(withId: toFind.id))

    #expect(found.id == toFind.id)
  }
}
