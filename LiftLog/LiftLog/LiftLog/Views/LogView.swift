import SwiftUI

/// Live session logger: shows the exercises already logged for the selected day,
/// plus an input area to build up one exercise's sets and "finish" it — which
/// commits it to GitHub and resets the input so you can move on to the next.
struct LogView: View {
    @EnvironmentObject var store: Store

    @State private var date = Date()
    @State private var name = ""
    @State private var sets: [WorkSet] = []

    @State private var isBodyweight = false
    @State private var weightText = ""
    @State private var repsText = ""

    @State private var showingPicker = false
    @FocusState private var focus: Field?
    private enum Field { case weight, reps }

    /// Exercises already saved for the selected day.
    private var todayExercises: [ExerciseEntry] {
        let key = Session.dateFormatter.string(from: date)
        return store.sessions.first { $0.dateString == key }?.exercises ?? []
    }

    private var lastEntry: ExerciseEntry? {
        name.isEmpty ? nil : store.lastEntry(for: name, before: date)
    }

    private var parsedWeight: Double? { Double(weightText.replacingOccurrences(of: ",", with: ".")) }
    private var parsedReps: Int? { Int(repsText) }
    private var canAddSet: Bool { parsedReps != nil && (isBodyweight || parsedWeight != nil) }
    private var canFinish: Bool { !name.isEmpty && !sets.isEmpty && !store.isBusy }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dateCard
                    if !todayExercises.isEmpty { todaySessionCard }
                    addExerciseHeader
                    exerciseCard
                    addSetCard
                    if !sets.isEmpty { setsCard }
                    finishButton
                    if !store.status.isEmpty {
                        Text(store.status).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Session")
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView(history: store.knownExercises) { picked in
                    // Switching exercise starts a fresh set list for the new movement.
                    if picked.caseInsensitiveCompare(name) != .orderedSame { sets = [] }
                    name = picked
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
            .refreshable { await store.load() }
        }
    }

    // MARK: - Today's session

    private var todaySessionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("TODAY'S SESSION").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(todayExercises.count) exercises · \(todaySetCount) sets")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(todayExercises) { ex in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name).font(.subheadline.weight(.semibold))
                        Text(ex.sets.map(\.token).joined(separator: "   "))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                    .onTapGesture { loadForEditing(ex) }
                }
            }
        }
    }

    private var todaySetCount: Int { todayExercises.reduce(0) { $0 + $1.sets.count } }

    // MARK: - Add exercise

    private var addExerciseHeader: some View {
        HStack {
            Text("ADD EXERCISE").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 4)
    }

    private var dateCard: some View {
        Card {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .font(.headline)
        }
    }

    private var exerciseCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    focus = nil
                    showingPicker = true
                } label: {
                    HStack {
                        Text(name.isEmpty ? "Choose exercise" : name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").foregroundStyle(.tint)
                    }
                }
                if let last = lastEntry {
                    Label {
                        Text("Last time: " + last.sets.map(\.token).joined(separator: "  "))
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var addSetCard: some View {
        Card {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    if !isBodyweight {
                        field(title: "Weight (kg)", text: $weightText,
                              keyboard: .decimalPad, focusValue: .weight)
                    }
                    field(title: "Reps", text: $repsText,
                          keyboard: .numberPad, focusValue: .reps)
                }

                Button { addSet() } label: {
                    Label("Add set", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!canAddSet)

                // Muted, secondary control — only relevant for the odd bodyweight lift.
                Button {
                    isBodyweight.toggle()
                    if isBodyweight { weightText = "" }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isBodyweight ? "checkmark.circle.fill" : "circle")
                        Text("Bodyweight exercise")
                    }
                    .font(.caption)
                    .foregroundStyle(isBodyweight ? Color.accentColor : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var setsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("CURRENT SETS").font(.caption).foregroundStyle(.secondary)
                ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                    HStack {
                        Text("\(idx + 1)")
                            .font(.caption.weight(.bold))
                            .frame(width: 24, height: 24)
                            .background(Color(.systemGray5), in: Circle())
                        Text(set.isBodyweight ? "Bodyweight" :
                                "\(WorkSet.formatWeight(set.weight ?? 0)) kg")
                        Spacer()
                        Text("× \(set.reps)").font(.body.weight(.semibold))
                        Button {
                            sets.removeAll { $0.id == set.id }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button {
                    if let last = sets.last { sets.append(WorkSet(weight: last.weight, reps: last.reps)) }
                } label: {
                    Label("Repeat last set", systemImage: "arrow.uturn.down").font(.footnote)
                }
            }
        }
    }

    private var finishButton: some View {
        Button {
            Task { await finishExercise() }
        } label: {
            HStack {
                if store.isBusy { ProgressView().tint(.white) }
                Text(finishTitle).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canFinish)
    }

    private var finishTitle: String {
        let alreadyLogged = todayExercises.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        return alreadyLogged ? "Update exercise" : "Finish exercise & add to session"
    }

    // MARK: - Helpers

    private func field(title: String, text: Binding<String>,
                       keyboard: UIKeyboardType, focusValue: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("0", text: text)
                .keyboardType(keyboard)
                .focused($focus, equals: focusValue)
                .font(.title3.weight(.medium))
                .padding(10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }

    private func addSet() {
        guard let reps = parsedReps else { return }
        sets.append(WorkSet(weight: isBodyweight ? nil : parsedWeight, reps: reps))
        repsText = ""
        focus = nil
    }

    /// Load an already-logged exercise back into the input area so its sets can be edited.
    private func loadForEditing(_ ex: ExerciseEntry) {
        name = ex.name
        sets = ex.sets
        isBodyweight = ex.sets.first?.isBodyweight ?? false
        weightText = ""; repsText = ""
    }

    private func finishExercise() async {
        let entry = ExerciseEntry(name: name.trimmingCharacters(in: .whitespaces), sets: sets)
        await store.commit(entry, on: date,
                           message: "Log \(entry.name) \(Session.dateFormatter.string(from: date))")
        if store.status.hasSuffix("✓") {
            // Reset the input for the next exercise; today's session card keeps the record.
            name = ""; sets = []; weightText = ""; repsText = ""; isBodyweight = false
            focus = nil
        }
    }
}

/// A rounded container used to group content into cards.
private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16))
    }
}
