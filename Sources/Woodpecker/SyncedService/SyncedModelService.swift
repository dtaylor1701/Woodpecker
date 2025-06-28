import Foundation

public protocol SyncedServicing<SyncContext>: Sendable {
  associatedtype SyncContext: Sendable

  var serviceID: UUID { get }

  func sync() async throws

  func clear(withContext context: SyncContext) async throws

  func populate(withContext context: SyncContext) async throws
}

public actor SyncedModelService<
  Model: Storable,
  RemoteService: ModelServicing,
  LocalService: LocalModelServicing,
  SyncContext: Sendable
>:
  ModelServicing, SyncedServicing
where
  RemoteService.Model == Model, LocalService.Model == Model,
  LocalService.SyncContext == SyncContext
{
  public typealias Dependency = SyncedServicing<SyncContext>
  public let remoteService: RemoteService
  public let localService: LocalService
  public let serviceID = UUID()
  public let dependencyManager: DependencyManager<SyncContext>

  public init(
    remoteService: RemoteService,
    localService: LocalService,
    dependencyManager: DependencyManager<SyncContext> = DependencyManager<SyncContext>()
  ) {
    self.remoteService = remoteService
    self.localService = localService
    self.dependencyManager = dependencyManager
  }

  /// MARK: - CRUD

  @discardableResult
  public func add(_ model: Model) async throws -> Model {
    let result = try await attemptRemoteUpdate {
      try await remoteService.add(model)
    }

    try await attemptLocalUpdate {
      try await localService.add(model)
    }

    return result
  }

  @discardableResult
  public func update(_ model: Model) async throws -> Model {
    let result = try await attemptRemoteUpdate {
      try await remoteService.update(model)
    }

    try await attemptLocalUpdate {
      try await localService.update(model)
    }

    return result
  }

  public func delete(_ model: Model) async throws {
    try await attemptRemoteUpdate {
      try await remoteService.delete(model)
    }

    try await attemptLocalUpdate {
      try await localService.delete(model)
    }
  }

  // MARK: - Accessing

  public func all() async throws -> [Model] {
    try await sync()
    return try await localService.all()
  }

  public func find(withId id: StorableID) async throws -> Model? {
    try await sync()
    return try await localService.find(withId: id)
  }

  // MARK: - Managing State

  public func sync() async throws {
    guard try await localService.isStale() else { return }

    let dependencySortedServices = try await dependencyManager.dependencySortedServices(
      forService: self)
    try await localService.withContext { context in
      for service in dependencySortedServices.reversed() {
        try await service.clear(withContext: context)
      }

      for service in dependencySortedServices {
        try await service.populate(withContext: context)
      }
    }
  }

  public func clear(withContext context: SyncContext) async throws {
    try await localService.clear(withContext: context)
  }

  public func populate(withContext context: SyncContext) async throws {
    try await localService.populate(
      with: remoteService, context: context)
  }

  // MARK: - Utilities

  private func attemptLocalUpdate(_ operation: () async throws -> Void) async throws {
    do {
      try await operation()
    } catch {
      logger.warning("Local update failed with error: \(error)")
      try await localService.markStale()
    }
  }

  private func attemptRemoteUpdate<T: Sendable>(_ operation: () async throws -> T) async throws -> T
  {
    do {
      return try await operation()
    } catch {
      /// Potentially retry later and optimistically update the local service.
      throw error
    }
  }
}
