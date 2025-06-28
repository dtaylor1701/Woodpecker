extension DatabaseManager {
  public func setUpForSyncedModelStore() async throws {
    add(migration: SyncedModelStoreStateCreateMigration())
  }
}
