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
    var graph = graphForServiceID[service.serviceID] ?? DependencyGraph<SyncContext>()
    graph.add(service, with: dependencies)

    // Check if this graph now overlaps with any OTHER existing graphs.
    // If it was already in a graph, we need to remove it from the old one and merge.
    if let existingGraph = graphForServiceID[service.serviceID] {
      // It's already in a graph. Update that graph in place.
      // But what if it now depends on something in another graph?
      // Let's just find ALL graphs that contain any of the IDs in our new graph.
      let overlappingGraphs = graphs.filter { !$0.serviceIDs.isDisjoint(with: graph.serviceIDs) }
      
      var mergedGraph = graph
      for overlapping in overlappingGraphs {
        mergedGraph = mergedGraph.merged(with: overlapping)
      }
      
      // Remove all overlapping graphs from the list.
      graphs.removeAll { overlapping in overlappingGraphs.contains(where: { $0.serviceIDs == overlapping.serviceIDs }) }
      graphs.append(mergedGraph)
      graph = mergedGraph
    } else {
      // It's a new service. See if it overlaps with any existing graph.
      if let existing = graphs.first(where: { !$0.serviceIDs.isDisjoint(with: graph.serviceIDs) }) {
        let merged = existing.merged(with: graph)
        graphs.removeAll { $0.serviceIDs == existing.serviceIDs }
        graphs.append(merged)
        graph = merged
      } else {
        graphs.append(graph)
      }
    }

    // Update the mapping for all services in the resulting graph.
    for serviceID in graph.serviceIDs {
      graphForServiceID[serviceID] = graph
    }
  }

  public func dependencySortedServices(forService service: Service) throws -> [Service] {
    guard let graph = graphForServiceID[service.serviceID] else {
      throw DependencyManagerError.graphForServiceNotFound
    }

    return graph.dependencySortedServices()
  }
}
