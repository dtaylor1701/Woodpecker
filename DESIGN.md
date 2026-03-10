# Woodpecker Design Specification

Woodpecker is a high-performance, protocol-oriented persistence and synchronization framework for Swift, designed to bridge local storage (SQLite/Fluent) with remote data sources. It provides a type-safe, actor-based architecture for managing data lifecycles, complex relationships, and state consistency.

---

## 1. High-Level Architecture

Woodpecker follows a layered architecture that enforces a clean separation of concerns between domain models, persistence logic, and synchronization strategies.

### Layers:
- **Domain Layer (`Storable`)**: Defines the application-facing data models.
- **Persistence Layer (`DatabaseModel`)**: Implements the mapping between domain models and the underlying database schema using Fluent.
- **Service Layer (`ModelServicing`)**: Provides a unified CRUD interface for interacting with data.
- **Synchronization Layer (`SyncedServicing`)**: Orchestrates the flow of data between local and remote services, managing cache invalidation and dependency-ordered updates.

---

## 2. Core Design Philosophies

- **Protocol-Oriented**: Core behaviors are defined via protocols (`Storable`, `ModelServicing`, `SyncedServicing`), allowing for easy mocking and extensibility.
- **Actor-Based Concurrency**: Leverages Swift 6's structured concurrency and Actors (`DatabaseManager`, `ModelDatabaseService`, `SyncedModelService`) to ensure thread safety and eliminate data races.
- **Storage/App Model Separation**: Decouples the database schema from application logic. `Storable` types define how they convert to and from `StorageModel` types.
- **Dependency-Aware Sync**: Recognizes that data often has hierarchies (e.g., a "Post" must exist before its "Comments"). The `DependencyManager` ensures that local state is populated and cleared in the correct order to maintain referential integrity.

---

## 3. Technical Stack

- **Language**: Swift 6.0+ (utilizing `@Sendable`, `Task`, and `Actor`).
- **Persistence**: [FluentKit](https://github.com/vapor/fluent-kit) with [FluentSQLiteDriver](https://github.com/vapor/fluent-sqlite-driver).
- **Concurrency**: Swift NIO-based event loops (via Fluent) integrated with Swift Concurrency.
- **Platforms**: iOS 17+, macOS 13+.

---

## 4. Data Models & Persistence

### Storable & StorableID
All domain models must conform to the `Storable` protocol. This protocol requires an associated `StorageModel` and a `StorableID`. The `StorableID` acts as a type-safe wrapper for identifiers, tracking whether a model is already "stored" in the database.

### Database Architecture
- **DatabaseManager**: A central actor responsible for initializing the SQLite connection, managing migrations, and providing access to the Fluent `Database` instance.
- **ModelDatabaseService**: A generic persistence engine that handles CRUD operations. It uses Fluent's transaction API to ensure that model updates and their associated relationships are committed atomically.
- **Relationships**: Handled via `ModelRelationship` and extensions on Fluent's `QueryBuilder`, allowing for seamless loading of nested dependencies during fetching.

---

## 5. Synchronization Strategy

Woodpecker implements a **Stale-While-Revalidate** inspired sync strategy:

1.  **Staleness Tracking**: The `LocalModelServicing` layer tracks the "freshness" of the local data.
2.  **Ordered Synchronization**: When data is accessed via `all()` or `find()`, the `SyncedModelService` checks if the local store is stale.
3.  **Dependency Graph**: If a sync is required:
    - The `DependencyManager` calculates the correct order of operations.
    - Local data is **cleared** in reverse dependency order (to avoid foreign key violations).
    - Remote data is **fetched and populated** in forward dependency order.
4.  **Optimistic Updates**: CRUD operations attempt to update the remote service first. If the remote update succeeds but the local update fails, the local store is marked as stale to trigger a full re-sync on the next read.

---

## 6. Technical Specifications

### Concurrency Model
Woodpecker is designed for modern Swift. All services are actors, ensuring that database access and synchronization logic are serialized. Multi-threading is handled by Fluent’s underlying NIO `EventLoopGroup`, which is bridged to Swift’s `async/await` environment.

### Error Handling
- **Transaction Safety**: All persistence operations are wrapped in database transactions.
- **Sync Resilience**: Failures in the remote service are propagated to the caller, while failures in the local cache are handled gracefully by marking the cache as stale.

### State Management
State is decentralized across specialized services. The `ModelStoreState` (likely used in more complex UI scenarios) or the staleness flags in local services act as the primary drivers for data refreshing.

---

## 7. Testing Infrastructure

Woodpecker emphasizes a rigorous testing strategy across three levels:

- **Unit Tests**: Testing individual components like `DependencyManager` and `ModelRelationship` logic.
- **Database Tests**: Using in-memory SQLite instances (via `FluentSQLiteDriver`) to verify that migrations and CRUD operations behave correctly without disk I/O side effects.
- **Service Integration Tests**: Using `TestRemoteService` and `TestModel` to simulate network latency and failures, ensuring the `SyncedModelService` correctly handles synchronization edge cases.

---

## 8. Performance & Scalability

- **Batch Operations**: Designed to handle collections of models (`asStorageModels()`) to minimize database roundtrips.
- **In-Memory Caching**: Fluent's query builder and relationship eager-loading minimize N+1 query problems.
- **Selective Sync**: By using a dependency graph, Woodpecker can perform targeted synchronization of specific model sub-graphs rather than the entire database.
