# Woodpecker

Woodpecker is a lightweight and flexible Swift framework designed to bridge the gap between local persistence and remote data services. Built on top of Apple's modern concurrency (async/await) and leveraging Vapor's **Fluent** and **FluentSQLiteDriver**, it provides a structured way to handle model synchronization, dependency management, and local database operations.

## Features

- **Synced Model Services**: Seamlessly synchronize data between local storage and remote APIs.
- **Fluent Integration**: Built-in support for Vapor's Fluent ORM for powerful database modeling.
- **Dependency Graph**: Manage complex relationships and synchronization order between different data models.
- **Protocol-Oriented Design**: Extensible `Storable` and `ModelServicing` protocols to fit any architecture.
- **Modern Swift**: Fully utilizes `async/await` and `Sendable` for thread-safe data handling.

## Components

### Core Protocols
- `Storable`: The base protocol for any model that needs to be persisted. It maps application models to their underlying storage representations.
- `ModelServicing`: Defines the standard CRUD operations (Add, Update, Delete, Find, All) for interacting with models.
- `SyncedServicing`: Extends model services with synchronization capabilities (`sync`, `populate`, `clear`).

### Database Layer
- `DatabaseManager`: Manages the lifecycle and connection to the Fluent database (defaulting to SQLite).
- `ModelDatabaseService`: A concrete implementation of `LocalModelServicing` that uses Fluent to persist `Storable` models.
- `ModelRelationship`: Utilities for defining and handling relationships between database models.

### Synchronization Layer
- `SyncedModelService`: An actor-based service that orchestrates updates between a `RemoteService` and a `LocalService`.
- `DependencyManager`: Uses a `DependencyGraph` to ensure models are synchronized in the correct order, respecting foreign key constraints and business logic.

## Installation

### Swift Package Manager

Add Woodpecker to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/Woodpecker.git", from: "1.0.0")
]
```

Then, add it to your target's dependencies:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["Woodpecker"]
    )
]
```

## Usage

### 1. Define your Model
Conform your model to `Storable` and provide a corresponding `StorableStorageModel` (Fluent Model).

```swift
struct User: Storable {
    typealias StorageModel = UserDatabaseModel
    var id: StorableID
    var name: String
    
    static func create(fromStorageModel storageModel: UserDatabaseModel) throws -> User {
        User(id: .init(storageModel.id!), name: storageModel.name)
    }
}
```

### 2. Initialize Database
Setup the `DatabaseManager` with your Fluent models.

```swift
let dbManager = DatabaseManager()
try await dbManager.setup(models: [UserDatabaseModel.self])
```

### 3. Create a Synced Service
Combine a remote API service and a local database service.

```swift
let remoteService = UserRemoteService() // Conforms to ModelServicing
let localService = ModelDatabaseService<User>(database: dbManager.database)

let userService = SyncedModelService(
    remoteService: remoteService,
    localService: localService
)

// Automatically syncs before fetching
let users = try await userService.all()
```

## Dependencies

- [Fluent](https://github.com/vapor/fluent-kit): 1.4.9+
- [FluentSQLiteDriver](https://github.com/vapor/fluent-sqlite-driver): 4.0.0+
- **Platforms**: iOS 17.0+, macOS 13.0+
- **Swift**: 6.0+
