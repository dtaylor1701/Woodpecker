import Foundation

public struct DependencyGraph<SyncContext> {
  typealias Service = any SyncedServicing<SyncContext>

  struct Node {
    let service: Service
    var dependencies: [Node] = []

    var serviceID: UUID { service.serviceID }
    var dependencyServices: [Service] {
      dependencies.map(\.service)
    }

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
      let dependencyNode = nodeForServiceID[dependency.serviceID] ?? Node(dependency)
      serviceNode.dependencies.append(dependencyNode)
      nodeForServiceID[dependency.serviceID] = dependencyNode
    }
    nodeForServiceID[service.serviceID] = serviceNode
  }

  func merged(with graph: DependencyGraph) -> DependencyGraph<SyncContext> {
    var newGraph = self

    for node in nodeForServiceID.values {
      newGraph.add(node.service, with: node.dependencyServices)
    }

    for node in graph.nodeForServiceID.values {
      newGraph.add(node.service, with: node.dependencyServices)
    }

    return newGraph
  }

  func dependencySortedServices() -> [Service] {
    Self.topologicalSort(nodes: nodeForServiceID.values).map(\.service)
  }

  // MARK: - Implementations

  private static func topologicalSort(nodes: any Sequence<Node>) -> [Node] {
    var stack: [Node] = []
    var visited: Set<UUID> = []

    for node in nodes {
      depthFirstSearch(node, visited: &visited, stack: &stack)
    }

    return stack
  }

  private static func depthFirstSearch(_ node: Node, visited: inout Set<UUID>, stack: inout [Node])
  {
    guard !visited.contains(node.serviceID) else { return }

    visited.insert(node.serviceID)

    for dependency in node.dependencies where !visited.contains(dependency.serviceID) {
      depthFirstSearch(dependency, visited: &visited, stack: &stack)
    }

    stack.append(node)
  }
}
