import Foundation

/// A protocol for resolving conflicts between local and remote models.
public protocol ConflictResolutionStrategy: Sendable {
  /// Resolves a conflict between a local and a remote version of a model.
  /// - Parameters:
  ///   - local: The local version of the model.
  ///   - remote: The remote version of the model.
  /// - Returns: The resolved version of the model.
  func resolve<Model: Storable>(local: Model, remote: Model) -> Model
}

/// A strategy that always prefers the remote version of a model in case of a conflict.
public struct RemoteWinsStrategy: ConflictResolutionStrategy {
  public init() {}
  public func resolve<Model: Storable>(local: Model, remote: Model) -> Model {
    return remote
  }
}

/// A strategy that always prefers the local version of a model in case of a conflict.
public struct LocalWinsStrategy: ConflictResolutionStrategy {
  public init() {}
  public func resolve<Model: Storable>(local: Model, remote: Model) -> Model {
    return local
  }
}
