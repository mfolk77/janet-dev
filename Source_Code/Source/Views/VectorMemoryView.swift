import SwiftUI
import SQLite

struct VectorMemoryView: View {
    @ObservedObject private var sqliteMemory = SQLiteMemoryService.shared
    @State private var searchText: String = ""
    @State private var selectedSource: String = "All"
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: VectorMemoryItem?
    @State private var isAddingMemory = false
    @State private var newMemoryContent = ""
    @State private var newMemorySource = "manual"
    @State private var newMemoryTags = ""
    
    private let sources = ["All", "chat", "user", "assistant", "notion", "manual"]
    
    var filteredMemories: [VectorMemoryItem] {
        var filtered = sqliteMemory.memoryItems
        
        // Filter by source
        if selectedSource != "All" {
            filtered = filtered.filter { $0.source == selectedSource }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.content.lowercased().contains(searchText.lowercased()) ||
                $0.tags.joined(separator: " ").lowercased().contains(searchText.lowercased())
            }
        }
        
        return filtered
    }
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Vector Memory")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    isAddingMemory = true
                }) {
                    Label("Add Memory", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    sqliteMemory.loadMemoryItems()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            // Search and filter
            HStack {
                TextField("Search memories...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Picker("Source", selection: $selectedSource) {
                    ForEach(sources, id: \.self) { source in
                        Text(source).tag(source)
                    }
                }
                .frame(width: 150)
            }
            .padding(.horizontal)
            
            // Memory list
            List {
                ForEach(filteredMemories) { item in
                    VectorMemoryItemView(item: item)
                        .contextMenu {
                            Button(action: {
                                itemToDelete = item
                                showingDeleteConfirmation = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(PlainListStyle())
            
            // Stats
            HStack {
                Text("Total: \(sqliteMemory.memoryItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Filtered: \(filteredMemories.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert("Delete Memory", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    sqliteMemory.deleteMemoryItem(withID: item.id)
                }
            }
        } message: {
            Text("Are you sure you want to delete this memory? This action cannot be undone.")
        }
        .sheet(isPresented: $isAddingMemory) {
            AddMemoryView(isPresented: $isAddingMemory)
        }
    }
}

struct VectorMemoryItemView: View {
    let item: VectorMemoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.content)
                .font(.body)
                .lineLimit(3)
            
            HStack {
                Label(item.source, systemImage: sourceIcon(for: item.source))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatDate(item.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !item.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func sourceIcon(for source: String) -> String {
        switch source {
        case "user":
            return "person"
        case "assistant":
            return "brain"
        case "notion":
            return "doc.text"
        case "manual":
            return "hand.tap"
        default:
            return "bubble.left"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AddMemoryView: View {
    @Binding var isPresented: Bool
    @State private var content: String = ""
    @State private var source: String = "manual"
    @State private var tags: String = ""
    
    private let sources = ["manual", "user", "assistant", "notion"]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add New Memory")
                .font(.title2)
                .fontWeight(.bold)
            
            TextEditor(text: $content)
                .frame(height: 150)
                .border(Color.gray.opacity(0.2))
                .padding(.horizontal)
            
            HStack {
                Text("Source:")
                
                Picker("Source", selection: $source) {
                    ForEach(sources, id: \.self) { source in
                        Text(source).tag(source)
                    }
                }
                .frame(width: 150)
            }
            .padding(.horizontal)
            
            HStack {
                Text("Tags:")
                
                TextField("Enter tags separated by commas", text: $tags)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Add Memory") {
                    addMemory()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 350)
        .padding()
    }
    
    private func addMemory() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty {
            let tagArray = tags.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            EnhancedMemoryManager.shared.addMemoryItem(
                content: trimmedContent,
                source: source,
                tags: tagArray
            )
        }
    }
}

struct VectorMemoryView_Previews: PreviewProvider {
    static var previews: some View {
        VectorMemoryView()
    }
} 