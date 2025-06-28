import Foundation

public enum DependencyManagerError: Error {
  case graphForServiceNotFound
}

public actor DependencyManager<SyncContext> {
  public typealias Service = any SyncedServicing<SyncContext>

  private var graphs: [DependencyGraph<SyncContext>] = []
  private var graphForServiceID: [UUID: DependencyGraph<SyncContext>] = [:]

  public init() {}

  public func add(_ service: Service, dependencies: [Service] = []) {
    // The service is already represented in a graph.
    if graphForServiceID[service.serviceID] != nil {
      return
    }

    var graph = DependencyGraph<SyncContext>()
    graph.add(service, with: dependencies)

    if let existing = graphs.first(where: { !$0.serviceIDs.isDisjoint(with: graph.serviceIDs) }) {
      graph = existing.merged(with: graph)
    } else {
      graphs.append(graph)
    }

    for serviceIDs in graph.serviceIDs {
      graphForServiceID[serviceIDs] = graph
    }
  }

  public func dependencySortedServices(forService service: Service) throws -> [Service] {
    guard let graph = graphForServiceID[service.serviceID] else {
      throw DependencyManagerError.graphForServiceNotFound
    }

    return graph.dependencySortedServices()
  }
}
