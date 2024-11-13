import FluentKit
import Foundation

extension SiblingsProperty {
  public func attach(
    _ tos: [To],
    method: AttachMethod,
    on database: Database,
    _ edit: (Through) -> Void = { _ in }
  ) async throws {
    switch method {
    case .always:
      try await self.attach(tos, on: database, edit).get()
    case .ifNotExists:
      var toAttach: [To] = []
      for to in tos {
        if try await !self.isAttached(to: to, on: database) {
          toAttach.append(to)
        }
      }
      try await self.attach(toAttach, on: database)
    }
  }
}
