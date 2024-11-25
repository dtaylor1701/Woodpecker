import Foundation

public protocol ModelStorageServicing<Model> {
  associatedtype Model: Storable
  func add(_ model: Model) async throws
  func update(_ model: Model) async throws
  func delete(_ model: Model) async throws
  func all() async throws -> [Model]
  func find(withId id: Model.ID) async throws -> Model?
}
