import FluentSQLiteDriver
import Foundation

/// The Database Manager is responsible for managing the local database.
public actor DatabaseManager {
  private let configuration: SQLiteConfiguration
  private var eventLoopGroup: EventLoopGroup?
  private var threadPool: NIOThreadPool?
  private var databases: Databases?
  private var logger: Logger = Logger(label: "database.logger")
  private var migrations = Migrations()
  private var migrator: Migrator {
    guard let databases = databases, let eventLoop = eventLoopGroup?.next() else {
      fatalError("DatabaseManager not setup. Call `start` before using.")
    }

    return Migrator(
      databases: databases,
      migrations: migrations,
      logger: logger,
      on: eventLoop)
  }

  public var database: Database {
    guard let eventLoop = eventLoopGroup?.next() else {
      fatalError("DatabaseManager not setup. Call `start` before using.")
    }

    guard let database = databases?.database(logger: logger, on: eventLoop) else {
      fatalError("Database does not exist.")
    }

    return database
  }

  public init(configuration: SQLiteConfiguration = .defaultConfiguration()) {
    self.configuration = configuration
    #if DEBUG
      logger.logLevel = .trace
    #endif
  }

  deinit {
    do {
      databases?.shutdown()
      try threadPool?.syncShutdownGracefully()
      try eventLoopGroup?.syncShutdownGracefully()
    } catch {
      logger.log(level: .error, "\(error.localizedDescription)")
    }
  }

  /// Starts the database manager and all of its dependencies. Must be called before use.
  public func start() async throws {
    // Priority passed explicitly to prevent thread sanitizer warning.
    // EventLoopGroup's init uses a dispatch queue with the default priority.
    await Task(priority: .medium) {
      let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
      self.eventLoopGroup = eventLoopGroup
      let threadPool = NIOThreadPool(numberOfThreads: 2)
      threadPool.start()
      self.threadPool = threadPool
      let databases = Databases(threadPool: threadPool, on: eventLoopGroup)
      databases.use(.sqlite(configuration), as: .sqlite)
      databases.default(to: .sqlite)
      self.databases = databases
    }.value
    try await migrator.setupIfNeeded().get()
    try await migrator.prepareBatch().get()
  }

  /// Add migrations to be run on the database when `start` is called.
  public func add(migrations: [any Migration]) {
    self.migrations.add(migrations)
  }

  /// Add a migration to be run on the database when `start` is called.
  public func add(migration: any Migration) {
    self.migrations.add(migration)
  }
}

extension SQLiteConfiguration {
  public static func defaultConfiguration() -> SQLiteConfiguration {
    SQLiteConfiguration(
      storage: .file(path: URL.documentsDirectory.appendingPathComponent("database").absoluteString)
    )
  }
}
