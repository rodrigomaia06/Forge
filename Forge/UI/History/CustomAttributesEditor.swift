//
//  CustomAttributesEditor.swift
//  Forge
//
//  A List section for user-defined key/value fields (location, mood, ...) on a workout or routine.
//  Read-only unless `isEditable`; adding and editing use a small sheet.
//

import SwiftUI

/// A field being added (nil originalKey) or edited (existing originalKey).
private struct AttributeField: Identifiable {
    let id = UUID()
    var originalKey: String?
    var key: String
    var value: String
}

struct CustomAttributesEditor: View {
    @Binding var attributes: [String: String]
    var isEditable: Bool

    @State private var editingField: AttributeField?

    private var sortedKeys: [String] { attributes.keys.sorted() }

    var body: some View {
        if !attributes.isEmpty || isEditable {
            Section(header: Text("Attributes"), footer: footer) {
                ForEach(sortedKeys, id: \.self) { key in
                    Button {
                        guard isEditable else { return }
                        editingField = AttributeField(originalKey: key, key: key, value: attributes[key] ?? "")
                    } label: {
                        HStack {
                            Text(key).foregroundColor(.forgeSecondaryLabel)
                            Spacer()
                            Text(attributes[key] ?? "").foregroundColor(.forgeLabel)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: isEditable ? deleteAttributes : nil)

                if isEditable {
                    Button {
                        editingField = AttributeField(originalKey: nil, key: "", value: "")
                    } label: {
                        Label("Add attribute", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editingField) { field in
                NavigationStack {
                    AttributeForm(field: field, onSave: save, onCancel: { editingField = nil })
                }
                .presentationDetents([.medium])
            }
        }
    }

    @ViewBuilder private var footer: some View {
        if isEditable {
            Text("Your own fields, like location or mood.")
        }
    }

    private func deleteAttributes(_ offsets: IndexSet) {
        for index in offsets { attributes.removeValue(forKey: sortedKeys[index]) }
    }

    private func save(_ field: AttributeField) {
        if let original = field.originalKey, original != field.key {
            attributes.removeValue(forKey: original)
        }
        let key = field.key.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            attributes[key] = value
        }
        editingField = nil
    }
}

private struct AttributeForm: View {
    @State var field: AttributeField
    var onSave: (AttributeField) -> Void
    var onCancel: () -> Void

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $field.key)
                TextField("Value", text: $field.value)
            }
        }
        .navigationBarTitle(field.originalKey == nil ? "Add attribute" : "Edit attribute", displayMode: .inline)
        .navigationBarItems(
            leading: Button("Cancel") { onCancel() },
            trailing: Button("Save") { onSave(field) }
                .disabled(field.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        )
    }
}
