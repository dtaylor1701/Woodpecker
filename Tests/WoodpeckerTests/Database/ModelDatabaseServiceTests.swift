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
    await databaseManager.add(migrations: [
      Stored.IngredientCreateMigration(), Stored.ChildCreateMigration(),
      Stored.SiblingCreateMigration(), Stored.IngredientSiblingCreateMigration(),
    ])
    try await databaseManager.start()
    service = .init(databaseManager: databaseManager)
  }
  
  @Test func add() async throws {
    let existing = try await service.all()
    var toAdd = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toAdd)
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toAdd.children.append(child)
    toAdd.siblings.append(sibling)
    try await service.add(toAdd)
    let updated = try await service.all()
    let saved = try #require(updated.first { $0.id == toAdd.id })
    
    #expect(existing.count + 1 == updated.count)
    #expect(toAdd.name == saved.name)
    #expect(saved.stored)
    #expect(toAdd.children.count == saved.children.count)
    #expect(saved.children.count == 1)
    #expect(toAdd.children.first?.id == saved.children.first?.id)
    #expect(toAdd.siblings.count == saved.siblings.count)
    #expect(toAdd.siblings.first?.id == saved.siblings.first?.id)
  }
  
  @Test func update() async throws {
    var toUpdate = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toUpdate)
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toUpdate.children.append(child)
    toUpdate.siblings.append(sibling)
    try await service.add(toUpdate)
    let existing = try await service.all()
    toUpdate = try #require(existing.first { $0.id == toUpdate.id })
    toUpdate.name = "new name"
    try await service.update(toUpdate)
    var updated = try await service.all()
    var saved = try #require(updated.first { $0.id == toUpdate.id })
    
    #expect(existing.count == updated.count)
    #expect(toUpdate.name == saved.name)
    #expect(toUpdate.children.count == saved.children.count)
    #expect(toUpdate.children.first?.id == saved.children.first?.id)
    #expect(toUpdate.siblings.count == saved.siblings.count)
    #expect(toUpdate.siblings.first?.id == saved.siblings.first?.id)
    
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
    
    try await service.update(toUpdate)
    updated = try await service.all()
    saved = try #require(updated.first { $0.id == toUpdate.id })
    
    #expect(toUpdate.children.count == saved.children.count)
    #expect(toUpdate.children.first?.id == saved.children.first?.id)
    #expect(toUpdate.siblings.count == saved.siblings.count)
    #expect(toUpdate.siblings.first?.id == saved.siblings.first?.id)
  }
  
  @Test func updateChild() async throws {
    var toUpdate = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toUpdate)
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toUpdate.children.append(child)
    toUpdate.siblings.append(sibling)
    try await service.add(toUpdate)
    let existing = try await service.all()
    toUpdate = try #require(existing.first { $0.id == toUpdate.id })
    var toUpdateChild = toUpdate.children[0]
    toUpdateChild.name = "Updated child"
    toUpdate.children[0] = toUpdateChild
    try await service.update(toUpdate)
    let updated = try await service.all()
    let saved = try #require(updated.first { $0.id == toUpdate.id })
    
    #expect("Updated child" == saved.children[0].name)
  }
  
  @Test func delete() async throws {
    var toDelete = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toDelete)
    let sibling = Sibling(name: "Some sibling")
    try await sibling.asStorageModel().save(on: database)
    toDelete.children.append(child)
    toDelete.siblings.append(sibling)
    try await service.add(toDelete)
    let existing: [Ingredient] = try await service.all()
    toDelete = try #require(existing.first { $0.id == toDelete.id })
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
    try await sibling.asStorageModel().save(on: database)
    toFind.children.append(child)
    toFind.siblings.append(sibling)
    try await service.add(toFind)
    
    let found = try #require(try await service.find(withId: toFind.id))
    
    #expect(found.id == toFind.id)
    #expect(found.children.count == toFind.children.count)
    #expect(found.children.first?.id == toFind.children.first?.id)
    #expect(found.siblings.count == toFind.siblings.count)
    #expect(found.siblings.first?.id == toFind.siblings.first?.id)
  }
}
