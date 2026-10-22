func alternateInputSource(ids: [String], current: String) -> String? {
    guard ids.count == 2, ids.contains(current) else { return nil }
    return ids.first { $0 != current }
}
