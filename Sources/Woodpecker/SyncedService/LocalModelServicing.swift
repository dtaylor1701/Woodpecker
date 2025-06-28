public protocol LocalModelServicing<Model>: ModelServicing, Sendable {
  associatedtype SyncContext: Sendable

  /// Indicate whether or not the local service is out of date and needs to be updated.
  func isStale() async throws -> Bool

  /// Indicate that the local service is out of date and needs to be updated.
  func markStale() async throws

  func withContext(_ perform: @escaping @Sendable (SyncContext) async throws -> Void) async throws

  func clear(
    withContext context: SyncContext) async throws

  func populate(
    with remoteService: any ModelServicing<Model>,
    context: SyncContext) async throws
}
