import Foundation

public struct DependencyGraph<SyncContext> {
  typealias Service = any SyncedServicing<SyncContext>

  struct Node {
    let service: Service
    var dependencyIDs: Set<UUID> = []

    var serviceID: UUID { service.serviceID }

    init(_ service: Service) {
      self.service = service
    }
  }

  private var nodeForServiceID: [UUID: Node] = [:]

  var serviceIDs: Set<UUID> {
    Set(nodeForServiceID.keys)
  }

  init() {}

  mutating func add(_ service: Service, with dependencies: [Service] = []) {
    var serviceNode = nodeForServiceID[service.serviceID] ?? Node(service)
    for dependency in dependencies {
      serviceNode.dependencyIDs.insert(dependency.serviceID)
      if nodeForServiceID[dependency.serviceID] == nil {
        nodeForServiceID[dependency.serviceID] = Node(dependency)
      }
    }
    nodeForServiceID[service.serviceID] = serviceNode
  }

  func merged(with graph: DependencyGraph) -> DependencyGraph<SyncContext> {
    var newGraph = self

    for node in nodeForServiceID.values {
      newGraph.add(node.service, with: node.dependencyIDs.compactMap { nodeForServiceID[$0]?.service })
    }

    for node in graph.nodeForServiceID.values {
      newGraph.add(node.service, with: node.dependencyIDs.compactMap { graph.nodeForServiceID[$0]?.service })
    }

    return newGraph
  }

  func dependencySortedServices() -> [Service] {
    topologicalSort().map { nodeForServiceID[$0]!.service }
  }

  // MARK: - Implementations

  private func topologicalSort() -> [UUID] {
    var stack: [UUID] = []
    var visited: Set<UUID> = []
    var visiting: Set<UUID> = []

    for serviceID in nodeForServiceID.keys {
      depthFirstSearch(serviceID, visited: &visited, visiting: &visiting, stack: &stack)
    }

    return stack
  }

  private func depthFirstSearch(_ serviceID: UUID, visited: inout Set<UUID>, visiting: inout Set<UUID>, stack: inout [UUID])
  {
    if visiting.contains(serviceID) {
      // Circular dependency!
      return
    }
    if visited.contains(serviceID) {
      return
    }

    visiting.insert(serviceID)

    if let node = nodeForServiceID[serviceID] {
      for dependencyID in node.dependencyIDs {
        depthFirstSearch(dependencyID, visited: &visited, visiting: &visiting, stack: &stack)
      }
    }

    visiting.remove(serviceID)
    visited.insert(serviceID)
    stack.append(serviceID)
  }
}
