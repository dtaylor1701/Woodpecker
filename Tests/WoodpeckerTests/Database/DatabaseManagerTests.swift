import FluentKit
import Foundation
import Testing
import Woodpecker
import FluentSQLiteDriver

final class TestModel: Model, @unchecked Sendable {
    static let schema = "test_models"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    init() { }

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}

struct TestModelMigration: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(TestModel.schema)
            .id()
            .field("name", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(TestModel.schema).delete()
    }
}

final class DatabaseManagerTests {
    let databaseManager: DatabaseManager

    var database: Database {
        get async {
            await databaseManager.database
        }
    }

    init() async throws {
        databaseManager = DatabaseManager(configuration: .memory)
        await databaseManager.add(migration: TestModelMigration())
        try await databaseManager.start()
    }

    @Test func revert() async throws {
        // 1. Arrange
        let model = TestModel(name: "test")
        try await model.save(on: database)
        let countBefore = try await TestModel.query(on: database).count()
        #expect(countBefore == 1)

        // 2. Act
        try await databaseManager.revert()

        // 3. Assert
        await #expect(throws: SQLiteError.self) {
            _ = try await TestModel.query(on: self.database).count()
        }
    }

    @Test func reset() async throws {
        // 1. Arrange
        let model = TestModel(name: "test")
        try await model.save(on: database)
        let countBefore = try await TestModel.query(on: database).count()
        #expect(countBefore == 1)

        // 2. Act
        try await databaseManager.reset()

        // 3. Assert
        let countAfter = try await TestModel.query(on: database).count()
        #expect(countAfter == 0)
    }
}
