extension SyncedModelService where LocalService == ModelDatabaseService<Model> {
  public static func createWith(
    databaseManager: DatabaseManager, remoteService: RemoteService,
    dependencyManager: DependencyManager<SyncContext>? = nil
  ) -> some SyncedModelService {
    SyncedModelService(
      remoteService: remoteService,
      localService: ModelDatabaseService(databaseManager: databaseManager),
      dependencyManager: dependencyManager)
  }
}
