
// Fix the OllamaModel struct to make it Codable
struct OllamaModel: Codable {
    let name: String
    let modified_at: String
    let size: Int64
}
