//
//  CustomAttributesEditor.swift
//  Forge
//
//  A List section for user-defined key/value fields (location, mood, ...) on a workout or routine.
//  Editing happens inline: tapping a field brings up the keyboard, with no separate sheet.
//

import SwiftUI

struct CustomAttributesEditor: View {
    @Binding var attributes: [String: String]
    /// Controls adding a new attribute, renaming, and deleting. Gated behind edit mode on a finished
    /// workout or a routine.
    var isEditable: Bool
    /// When true, the value of an already-present attribute can be edited without the edit gate. Used on
    /// the live workout so routine-seeded fields (mood, location) can be filled in directly.
    var valuesEditable: Bool = false

    // A local, ordered editing model. Edits happen here and are written back to the dictionary when a
    // field loses focus or the view goes away, so a rename does not fight the dictionary's key identity.
    @State private var rows: [Row] = []
    @FocusState private var focus: FocusTarget?

    private struct Row: Identifiable, Equatable {
        let id = UUID()
        var key: String
        var value: String
    }

    private enum FocusTarget: Hashable {
        case key(UUID)
        case value(UUID)
    }

    var body: some View {
        if !attributes.isEmpty || isEditable {
            Section(header: Text("Attributes"), footer: footer) {
                ForEach($rows) { $row in
                    HStack {
                        if isEditable {
                            TextField("Name", text: $row.key)
                                .focused($focus, equals: .key(row.id))
                                .foregroundColor(.forgeSecondaryLabel)
                        } else {
                            Text(row.key)
                                .foregroundColor(.forgeSecondaryLabel)
                        }
                        Spacer()
                        if isEditable || valuesEditable {
                            TextField("Value", text: $row.value)
                                .focused($focus, equals: .value(row.id))
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.forgeLabel)
                        } else {
                            Text(row.value)
                                .foregroundColor(.forgeLabel)
                        }
                    }
                    // Tapping anywhere in the row brings up the keyboard on the value, the common edit.
                    .contentShape(Rectangle())
                    .onTapGesture { focus = .value(row.id) }
                }
                .onDelete(perform: isEditable ? deleteRows : nil)

                if isEditable {
                    Button {
                        let row = Row(key: "", value: "")
                        rows.append(row)
                        focus = .key(row.id)
                    } label: {
                        Label("Add attribute", systemImage: "plus")
                    }
                }
            }
            .onAppear { syncRowsFromAttributes() }
            // Commit when focus leaves a field (including keyboard dismissal) and when the view goes away.
            .onChange(of: focus) { _ in commit() }
            .onDisappear { commit() }
        }
    }

    @ViewBuilder private var footer: some View {
        if isEditable {
            Text("Your own fields, like location or mood.")
        }
    }

    private func syncRowsFromAttributes() {
        rows = attributes
            .sorted { $0.key < $1.key }
            .map { Row(key: $0.key, value: $0.value) }
    }

    private func deleteRows(_ offsets: IndexSet) {
        rows.remove(atOffsets: offsets)
        commit()
    }

    /// Writes the local rows back to the dictionary, dropping rows with an empty name. Rows stay in the
    /// local model while being filled in, so a new, unnamed row is not removed mid-edit.
    private func commit() {
        var result: [String: String] = [:]
        for row in rows {
            let key = row.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            result[key] = row.value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if result != attributes {
            attributes = result
        }
    }
}
