import FluentKit

public protocol SyncModelServiceContext {}

public class SyncModelDatabaseServiceContext: SyncModelServiceContext {}

public struct DatabaseSyncContext: Sendable {
  let database: Database
}

extension ModelDatabaseService: LocalModelServicing {
  public func withContext(_ perform: @escaping @Sendable (DatabaseSyncContext) async throws -> Void)
    async throws
  {
    try await database.transaction { database in
      try await perform(DatabaseSyncContext(database: database))
    }
  }

  public func clear(
    withContext context: DatabaseSyncContext
  )
    async throws
  {
    let localModels = try await Self.all(on: context.database)
    for model in localModels {
      try await Self.delete(model, on: context.database)
    }
  }

  public func populate(
    with remoteService: any ModelServicing<Model>,
    conflictResolutionStrategy: (any ConflictResolutionStrategy)?,
    context: DatabaseSyncContext
  ) async throws {
    let remoteModels = try await remoteService.all()
    if let strategy = conflictResolutionStrategy {
      let localModels = try await Self.all(on: context.database)
      let localByID = Dictionary(grouping: localModels, by: { $0.id.value }).compactMapValues { $0.first }
      let remoteIDs = Set(remoteModels.map { $0.id.value })
      
      for remoteModel in remoteModels {
        if let localModel = localByID[remoteModel.id.value] {
          var resolved = strategy.resolve(local: localModel, remote: remoteModel)
          // Ensure the resolved model is marked as stored so the database update succeeds.
          resolved.id = resolved.id.asStored()
          _ = try await Self.update(resolved, on: context.database)
        } else {
          _ = try await Self.add(remoteModel, on: context.database)
        }
      }
      
      // Delete local models not in remote.
      for localModel in localModels where !remoteIDs.contains(localModel.id.value) {
        try await Self.delete(localModel, on: context.database)
      }
    } else {
      // Original full-replace-style populate (assuming clear was called).
      for model in remoteModels {
        _ = try await Self.add(model, on: context.database)
      }
    }
    try await updateState(stale: false, database: context.database)
  }

  /// Indicate whether or not the local service is out of date and needs to be updated.
  public func isStale() async throws -> Bool {
    try await storeState(on: database).stale
  }

  /// Indicate that the local service is out of date and needs to be updated.
  public func markStale() async throws {
    try await updateState(stale: true, database: database)
  }

  // MARK: - Utilities

  private func updateState(stale: Bool, database: Database) async throws {
    let storeState = try await storeState(on: database)
    storeState.stale = stale
    try await storeState.save(on: database)
  }

  private func storeState(on database: Database) async throws -> SyncedModelStoreState {
    let key = Model.StorageModel.schema
    return try await database.query(SyncedModelStoreState.self).filter(\.$key == key)
      .first() ?? SyncedModelStoreState(key: key)
  }
}
