import SwiftUI

/// Log an exercise for a chosen date: pick/type a name, add sets, save + push.
struct LogView: View {
    @EnvironmentObject var store: Store

    @State private var date = Date()
    @State private var name = ""
    @State private var sets: [WorkSet] = []
    @State private var isBodyweight = false
    @State private var weight = 45.0
    @State private var reps = 8

    private var lastEntry: ExerciseEntry? {
        name.isEmpty ? nil : store.lastEntry(for: name, before: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Exercise") {
                    TextField("e.g. squat", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !store.knownExercises.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.knownExercises.prefix(20), id: \.self) { ex in
                                    Button(ex) { name = ex }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    if let last = lastEntry {
                        Text("Last time: " + last.sets.map(\.token).joined(separator: "  "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Add set") {
                    Toggle("Bodyweight", isOn: $isBodyweight)
                    if !isBodyweight {
                        Stepper(value: $weight, in: 0...500, step: 0.5) {
                            Text("Weight: \(WorkSet.formatWeight(weight)) kg")
                        }
                    }
                    Stepper(value: $reps, in: 1...50) { Text("Reps: \(reps)") }
                    Button {
                        sets.append(WorkSet(weight: isBodyweight ? nil : weight, reps: reps))
                    } label: {
                        Label("Add set", systemImage: "plus")
                    }
                }

                if !sets.isEmpty {
                    Section("Sets") {
                        ForEach(sets) { set in
                            Text(set.token)
                        }
                        .onDelete { sets.remove(atOffsets: $0) }
                        Button("Repeat last set") {
                            if let last = sets.last { sets.append(last) }
                        }
                        .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        if store.isBusy { ProgressView() }
                        else { Text("Save & push to GitHub") }
                    }
                    .disabled(name.isEmpty || sets.isEmpty || store.isBusy)
                }

                if !store.status.isEmpty {
                    Section { Text(store.status).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Log")
        }
    }

    private func save() async {
        let entry = ExerciseEntry(name: name.trimmingCharacters(in: .whitespaces), sets: sets)
        await store.commit(entry, on: date, message: "Log \(entry.name) \(Session.dateFormatter.string(from: date))")
        if store.status.hasSuffix("✓") {
            sets = []
            name = ""
        }
    }
}
