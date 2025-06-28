import FluentKit
import Foundation
import Testing
import Woodpecker

struct TestAsyncContext: Sendable {}

actor TestService: SyncedServicing {
  let serviceID = UUID()

  var calledClear: Bool = false
  var calledPopulate: Bool = false

  typealias SyncContext = TestAsyncContext

  func sync() async throws {
    let context = TestAsyncContext()
    try await clear(withContext: context)
    try await populate(withContext: context)
  }

  func clear(withContext context: TestAsyncContext) async throws {
    calledClear = true
  }

  func populate(withContext context: TestAsyncContext) async throws {
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
}
