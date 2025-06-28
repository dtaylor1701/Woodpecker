extension StorableID {
  public static func from(storageModel: any DatabaseModel) throws -> Self {
    if storageModel._$idExists {
      return try Self.stored(storageModel.requireID())
    } else {
      return try Self.new(withValue: storageModel.requireID())
    }
  }
}
