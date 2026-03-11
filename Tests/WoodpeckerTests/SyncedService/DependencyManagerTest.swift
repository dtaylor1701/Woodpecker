import FluentKit
import Foundation
import Testing
@testable import Woodpecker

struct TestAsyncContext: Sendable {}

actor TestService: SyncedServicing {
  let serviceID = UUID()

  var calledClear: Bool = false
  var calledPopulate: Bool = false

  typealias SyncContext = TestAsyncContext

  func sync() async throws {
    let context = TestAsyncContext()
    try await clear(withContext: context)
    try await populate(withContext: context, strategy: .fullReplace)
  }

  func clear(withContext context: TestAsyncContext) async throws {
    calledClear = true
  }

  func populate(withContext context: TestAsyncContext, strategy: SyncStrategy) async throws {
    calledPopulate = true
  }
}

final class DependencyManagerTest {
  @Test func addDependency() async throws {
    let manager = DependencyManager<TestAsyncContext>()

    let firstService = TestService()
    let secondService = TestService()

    await manager.add(firstService, dependencies: [secondService])
    await manager.add(secondService)

    let firstServiceDependencies = try await manager.dependencySortedServices(
      forService: firstService)
    #expect(
      firstServiceDependencies.map(\.serviceID) == [
        secondService.serviceID, firstService.serviceID,
      ])

    let secondServiceDependencies = try await manager.dependencySortedServices(
      forService: secondService)
    #expect(
      secondServiceDependencies.map(\.serviceID) == [
        secondService.serviceID, firstService.serviceID,
      ])
  }

  @Test func addDisjointService() async throws {
    let manager = DependencyManager<TestAsyncContext>()

    let firstService = TestService()
    let secondService = TestService()
    let disjointService = TestService()

    await manager.add(firstService, dependencies: [secondService])
    await manager.add(secondService)
    await manager.add(disjointService)

    let disjointServiceDependencies = try await manager.dependencySortedServices(
      forService: disjointService)
    #expect(disjointServiceDependencies.map(\.serviceID) == [disjointService.serviceID])
  }

  @Test func deepDependency() async throws {
    let manager = DependencyManager<TestAsyncContext>()

    let a = TestService()
    let b = TestService()
    let c = TestService()

    // Add A -> B first.
    await manager.add(a, dependencies: [b])
    // Then add B -> C.
    await manager.add(b, dependencies: [c])
    // Ensure both are registered.
    await manager.add(c)

    let aDependencies = try await manager.dependencySortedServices(forService: a)
    let aIDs = aDependencies.map(\.serviceID)
    
    // Expected: [C, B, A] because A -> B and B -> C.
    // If it fails, it might be [B, A, C] or similar.
    #expect(aIDs == [c.serviceID, b.serviceID, a.serviceID])
  }
}
