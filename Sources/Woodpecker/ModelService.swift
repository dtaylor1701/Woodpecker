import Foundation

public protocol ModelServicing<Model>: Sendable {
  associatedtype Model: Storable

  /// Adds a new `model` to the service and returns it.
  func add(_ model: Model) async throws -> Model

  /// Updates an existing `model` in the service and returns it.
  func update(_ model: Model) async throws -> Model

  /// Deletes an existing `model` from the service and returns.
  func delete(_ model: Model) async throws

  /// Returns an array of all `models` in the service.
  func all() async throws -> [Model]

  /// Finds and returns a single `model` with the given ID.
  func find(withId id: StorableID) async throws -> Model?
}
