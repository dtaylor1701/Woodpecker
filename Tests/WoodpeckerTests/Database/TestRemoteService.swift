import Foundation
import Woodpecker

let siblingID = StorableID.new()

struct TestError: Error {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}

actor TestRemoteService<Model: Storable>: ModelServicing {
  var models: [Model] = []

  var added: [Model] = []
  var updated: [Model] = []
  var deleted: [Model] = []

  @discardableResult
  func add(_ model: Model) async throws -> Model {
    models.append(model)
    added.append(model)
    return model
  }

  func update(_ model: Model) async throws -> Model {
    guard
      let index = models.firstIndex(where: {
        $0.id.value == model.id.value
      })
    else {
      throw TestError("Could not find \(Model.self) to update.")
    }

    updated.append(model)
    models[index] = model
    return model
  }

  func delete(_ model: Model) async throws {
    guard
      let index = models.firstIndex(where: {
        $0.id.value == model.id.value
      })
    else {
      throw TestError("Could not find \(Model.self) to remove.")
    }

    deleted.append(model)
    models.remove(at: index)
  }

  func all() async throws -> [Model] {
    models
  }

  func find(withId id: Woodpecker.StorableID) async throws -> Model? {
    models.first {
      $0.id.value == id.value
    }
  }

  func setModels(_ models: [Model]) {
    self.models = models
  }
}

extension TestRemoteService {
  static func forSiblings() async throws -> TestRemoteService<Sibling> {
    let service = TestRemoteService<Sibling>()
    let sibling = Sibling(id: siblingID, name: "Some sibling")
    await service.setModels([sibling])
    return service
  }

  static func forIngredients(withSiblings: Bool = true) async throws -> TestRemoteService<
    Ingredient
  > {
    let service = TestRemoteService<Ingredient>()
    var toAdd = Ingredient(name: "chips", children: [], siblings: [])
    let child = Child(name: "Some child", ingredient: toAdd)
    if withSiblings {
      let sibling = Sibling(id: siblingID, name: "Some sibling")
      toAdd.siblings.append(sibling)
    }
    toAdd.children.append(child)
    await service.setModels([toAdd])

    return service
  }
}
