//
//  WorkoutRoutineSetEditor.swift
//  Iron
//
//  Created by Karim Abou Zeid on 21.03.20.
//  Copyright © 2020 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import WorkoutDataKit

struct WorkoutRoutineSetEditor: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    
    @State private var showKeyboard: KeyboardType = .none {
        didSet {
            if showKeyboard == .none {
                self.overwriteRepetitionsMin = nil
                self.overwriteRepetitionsMax = nil
            }
        }
    }
    private enum KeyboardType {
        case repetitionsMin
        case repetitionsMax
        case none
    }
    
    @State private var showMoreSheet = false

    @State private var showHelpAlert = false

    // A single set can target one rep count or a min–max range. Default is a single value; the range
    // toggle reveals the second dragger. Kept in sync with the selected set's data below.
    @State private var useRange = false
    
    @ObservedObject var workoutRoutineSet: WorkoutRoutineSet
    
    @ObservedObject private var refresher = Refresher()
    
    @Binding var overwriteRepetitionsMin: Int16? // should be set to nil by the parent view when the selected workoutRoutineSet changes
    @Binding var overwriteRepetitionsMax: Int16? // should be set to nil by the parent view when the selected workoutRoutineSet changes
    
    private var editorRepetitionsMin: Int16? {
        self.overwriteRepetitionsMin ?? self.workoutRoutineSet.minRepetitionsValue
    }
    private var editorRepetitionsMax: Int16? {
        self.overwriteRepetitionsMax ?? self.workoutRoutineSet.maxRepetitionsValue
    }
    
    private var validRepetitions: Bool {
        isValid(minReps: editorRepetitionsMin, maxReps: editorRepetitionsMax)
    }
    
    private func isValid(minReps: Int16?, maxReps: Int16?) -> Bool {
        if let minReps = minReps, let maxReps = maxReps {
            return minReps <= maxReps
        }
        return true
    }
    
    private var keyboardRepetitionsMin: Binding<Double?> {
        Binding(
            get: {
                self.editorRepetitionsMin.map { Double($0) }
            },
            set: { newValue in
                let newValue = newValue.map { Int16(max(min($0, Double(WorkoutSet.MAX_REPETITIONS)), 0)) }
                let maxValue = self.editorRepetitionsMax
                if self.isValid(minReps: newValue, maxReps: maxValue) {
                    self.workoutRoutineSet.minRepetitionsValue = newValue
                    self.workoutRoutineSet.maxRepetitionsValue = maxValue
                    self.overwriteRepetitionsMin = nil
                    self.overwriteRepetitionsMax = nil
                } else {
                    self.overwriteRepetitionsMin = newValue
                }
                self.refresher.refresh()
            }
        )
    }
    
    private var keyboardRepetitionsMax: Binding<Double?> {
        Binding(
            get: {
                self.editorRepetitionsMax.map { Double($0) }
            },
            set: { newValue in
                let newValue = newValue.map { Int16(max(min($0, Double(WorkoutSet.MAX_REPETITIONS)), 0)) }
                let minValue = self.editorRepetitionsMin
                if self.isValid(minReps: minValue, maxReps: newValue) {
                    self.workoutRoutineSet.minRepetitionsValue = minValue
                    self.workoutRoutineSet.maxRepetitionsValue = newValue
                    self.overwriteRepetitionsMin = nil
                    self.overwriteRepetitionsMax = nil
                } else {
                    self.overwriteRepetitionsMax = newValue
                }
                self.refresher.refresh()
            }
        )
    }
    
    private var draggerRepetitionsMin: Binding<Double?> {
        Binding(
            get: {
                self.editorRepetitionsMin.map { Double($0) }
            },
            set: { newValue in
                let newValue = newValue.map { Int16(max(min($0, Double(WorkoutSet.MAX_REPETITIONS)), 0)) }
                let maxValue = self.editorRepetitionsMax
                self.workoutRoutineSet.minRepetitionsValue = newValue
                self.workoutRoutineSet.maxRepetitionsValue = self.isValid(minReps: newValue, maxReps: maxValue) ? maxValue : newValue
                self.overwriteRepetitionsMin = nil
                self.overwriteRepetitionsMax = nil
                self.refresher.refresh()
            }
        )
    }
    
    private var draggerRepetitionsMax: Binding<Double?> {
        Binding(
            get: {
                self.editorRepetitionsMax.map { Double($0) }
            },
            set: { newValue in
                let newValue = newValue.map { Int16(max(min($0, Double(WorkoutSet.MAX_REPETITIONS)), 0)) }
                let minValue = self.editorRepetitionsMin
                self.workoutRoutineSet.maxRepetitionsValue = newValue
                self.workoutRoutineSet.minRepetitionsValue = self.isValid(minReps: minValue, maxReps: newValue) ? minValue : newValue
                self.overwriteRepetitionsMax = nil
                self.overwriteRepetitionsMin = nil
                self.refresher.refresh()
            }
        )
    }
    
    // Single-value mode: one dragger that keeps min and max equal, so the set targets a fixed rep count.
    private var editorRepetitionsSingle: Int16? {
        self.overwriteRepetitionsMin ?? self.workoutRoutineSet.minRepetitionsValue
    }
    private var repetitionsSingle: Binding<Double?> {
        Binding(
            get: {
                self.editorRepetitionsSingle.map { Double($0) }
            },
            set: { newValue in
                let value = newValue.map { Int16(max(min($0, Double(WorkoutSet.MAX_REPETITIONS)), 0)) }
                self.workoutRoutineSet.minRepetitionsValue = value
                self.workoutRoutineSet.maxRepetitionsValue = value
                self.overwriteRepetitionsMin = nil
                self.overwriteRepetitionsMax = nil
                self.refresher.refresh()
            }
        )
    }

    /// Sync the range toggle to the selected set: a set whose min and max differ is a range.
    private func syncRangeMode() {
        useRange = workoutRoutineSet.minRepetitionsValue != workoutRoutineSet.maxRepetitionsValue
    }

    private func setUseRange(_ newValue: Bool) {
        useRange = newValue
        if newValue {
            // Entering range: seed the max from the current single value so both draggers show.
            if workoutRoutineSet.maxRepetitionsValue == nil {
                workoutRoutineSet.maxRepetitionsValue = workoutRoutineSet.minRepetitionsValue
            }
        } else {
            // Single: collapse to the min value, the primary target.
            workoutRoutineSet.maxRepetitionsValue = workoutRoutineSet.minRepetitionsValue
        }
        overwriteRepetitionsMin = nil
        overwriteRepetitionsMax = nil
        refresher.refresh()
    }

    var showNext: Bool
    var onDone: () -> Void = {}

    private var repetitionsSingleDragger: some View {
        Dragger(
            value: repetitionsSingle,
            unit: "reps",
            minValue: 0,
            maxValue: Double(WorkoutSet.MAX_REPETITIONS),
            nilPosition: .belowMin,
            showCursor: showKeyboard == .repetitionsMin,
            onTextTapped: {
                if self.showKeyboard == .none {
                    withAnimation {
                        self.showKeyboard = .repetitionsMin
                    }
                } else {
                    self.showKeyboard = .repetitionsMin
                }
            }
        )
    }

    private var rangeToggleButton: some View {
        Button(action: {
            withAnimation { self.setUseRange(!self.useRange) }
        }) {
            HStack(spacing: 4) {
                Image(systemName: useRange ? "arrow.right.and.line.vertical.and.arrow.left" : "arrow.left.and.line.vertical.and.arrow.right")
                Text(useRange ? "Single" : "Range")
                    .fixedSize()
            }
            .padding(6)
        }
        .accessibilityLabel(useRange ? "Use a single rep target" : "Use a rep range")
    }

    private var repetitionsMinDragger: some View {
        Dragger(
            value: draggerRepetitionsMin,
            unit: "min reps",
            minValue: 0,
            maxValue: Double(WorkoutSet.MAX_REPETITIONS),
            nilPosition: .belowMin,
            showCursor: showKeyboard == .repetitionsMin,
            onTextTapped: {
                if self.showKeyboard == .none {
                    withAnimation {
                        self.showKeyboard = .repetitionsMin
                    }
                } else {
                    self.showKeyboard = .repetitionsMin
                }
            }
        )
        .foregroundColor(validRepetitions ? .primary : .red)
    }
    
    private var repetitionsMaxDragger: some View {
        Dragger(
            value: draggerRepetitionsMax,
            unit: "max reps",
            minValue: 0,
            maxValue: Double(WorkoutSet.MAX_REPETITIONS),
            nilPosition: .belowMin,
            showCursor: showKeyboard == .repetitionsMax,
            onTextTapped: {
                if self.showKeyboard == .none {
                    withAnimation {
                        self.showKeyboard = .repetitionsMax
                    }
                } else {
                    self.showKeyboard = .repetitionsMax
                }
            }
        )
        .foregroundColor(validRepetitions ? .primary : .red)
    }
    
    private var tagButton: some View {
        Button(action: {
            self.showMoreSheet = true
        }) {
            HStack(spacing: 0) {
                Image(systemName: "tag")
                    .padding(6)
            }
        }
    }
    
    private var doneButton: some View {
        Button(action: {
            self.onDone()
        }) {
            HStack {
                Spacer()
                Text(showNext ? "Next" : "Ok")
                    .fixedSize()
                    .foregroundColor(.white)
                    .padding(6)
                Spacer()
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .foregroundColor(.forgeAccent)
            )
        }
    }
    
    private var moreSheet: some View {
        var title = "Set"
        if let index = workoutRoutineSet.workoutRoutineExercise?.workoutRoutineSets?.index(of: workoutRoutineSet), index != NSNotFound {
            title += " \(index + 1)"
        }
        
        return NavigationStack {
            MoreView(workoutRoutineSet: workoutRoutineSet)
                .navigationBarTitle(Text(title), displayMode: .inline)
                .navigationBarItems(leading:
                    Button("Close") {
                        self.showMoreSheet = false
                    }
            )
        }
    }
    
    private var keyboard: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                NumericKeyboard(
                    value: self.showKeyboard == .repetitionsMin ? (self.useRange ? self.keyboardRepetitionsMin : self.repetitionsSingle) : self.keyboardRepetitionsMax,
                    alwaysShowDecimalSeparator: .constant(false),
                    minimumFractionDigits: .constant(0),
                    maximumFractionDigits: 0
                )
                VStack(spacing: 0) {
                    NumericKeyboard.imageActionKeyboardButton(label: Image(systemName: "keyboard.chevron.compact.down"), width: geometry.size.width / 4) {
                        withAnimation {
                            self.showKeyboard = .none
                        }
                    }
                    
                    NumericKeyboard.imageActionKeyboardButton(label: Image(systemName: "questionmark"), width: geometry.size.width / 4) {
                        self.showHelpAlert = true
                    }
                    
                    NumericKeyboard.imageActionKeyboardButton(label: Image(systemName: "tag"), width: geometry.size.width / 4) {
                        self.showMoreSheet = true
                    }
                    
                    Button(action: {
                        NumericKeyboard.playButtonSound()
                        // In range mode the min field advances to max; in single mode there is only one
                        // field, so it finishes like the max step does.
                        if self.showKeyboard == .repetitionsMin && self.useRange {
                            self.showKeyboard = .repetitionsMax
                        } else {
                            self.overwriteRepetitionsMin = nil
                            self.overwriteRepetitionsMax = nil
                            self.onDone()
                            self.showKeyboard = .repetitionsMin
                        }
                    }) {
                        Image(systemName: (self.showKeyboard == .repetitionsMin && self.useRange) ? "arrow.right" : self.showNext ? "arrow.right" : "checkmark")
                            .padding()
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .foregroundColor(Color.forgeAccent)
                            )
                            .frame(width: geometry.size.width / 4, height: geometry.size.height / 4)
                    }
                }
                .frame(width: geometry.size.width / 4)
            }
        }
        .frame(height: NumericKeyboard.HEIGHT)
        // Match the system keyboard's surface so the custom number pad reads as a keyboard and adapts
        // to light and dark, instead of showing the editor's background behind its transparent keys.
        .background(Color(uiColor: .systemGray5))
    }
    
    var body: some View {
        VStack { /// no spacing to the keyboard
            VStack(spacing: 24) {
                /**
                 NOTE: the draggers shouldn't be too low because
                 1. the thumb would be in an uncomfortable position
                 2. one easily triggers the reachability accessibilty on devices without a home button
                 */
                if useRange {
                    HStack(spacing: 16) {
                        repetitionsMinDragger
                        Divider().frame(height: 44)
                        repetitionsMaxDragger
                    }
                } else {
                    repetitionsSingleDragger
                }

                if showKeyboard == .none {
                    HStack(spacing: 16) {
                        rangeToggleButton
                        tagButton
                        doneButton
                    }
                    .padding(.bottom, 8) /// pushes the draggers up and makes the buttons look more centered
                }
            }.padding([.leading, .trailing])
            
            if showKeyboard != .none {
                keyboard
            }
        }
        .padding([.top, .bottom])
        .drawingGroup() /// fixes visual bug with show/hide animation of this view
        .gesture(DragGesture()
            .onEnded({ drag in
                let width = drag.predictedEndTranslation.width
                let height = drag.predictedEndTranslation.height
                
                if abs(height) > abs(width) {
                    if height > 200 {
                        withAnimation {
                            self.showKeyboard = .none
                        }
                    }
                } else {
                    if width > 200 && self.useRange {
                        withAnimation {
                            self.showKeyboard = .repetitionsMax
                        }
                    } else if width < 200 {
                        withAnimation {
                            self.showKeyboard = .repetitionsMin
                        }
                    }
                }
            })
        )
        .sheet(isPresented: $showMoreSheet) { self.moreSheet }
        .alert(isPresented: $showHelpAlert) { Alert(title: Text("You can also drag ☰ up and down to adjust the values.")) }
        .onAppear { syncRangeMode() }
        .onChange(of: workoutRoutineSet.objectID) { _, _ in syncRangeMode() }
    }
}

private struct MoreView: View {
    @ObservedObject var workoutRoutineSet: WorkoutRoutineSet
    
    @State private var workoutRoutineSetCommentInput: String? // cannot use ValueHolder here, since it would be recreated on changes
    private var workoutRoutineSetComment: Binding<String> {
        Binding(
            get: {
                self.workoutRoutineSetCommentInput ?? self.workoutRoutineSet.comment ?? ""
            },
            set: { newValue in
                self.workoutRoutineSetCommentInput = newValue
            }
        )
    }
    private func adjustAndSaveWorkoutRoutineSetCommentInput() {
        guard let newValue = workoutRoutineSetCommentInput?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        workoutRoutineSetCommentInput = newValue
        workoutRoutineSet.comment = newValue.isEmpty ? nil : newValue
        self.workoutRoutineSet.managedObjectContext?.saveOrCrash()
    }

    private func tagButton(tag: WorkoutSetTag) -> some View {
        Button(action: {
            if self.workoutRoutineSet.tagValue == tag {
                self.workoutRoutineSet.tagValue = nil
            } else {
                self.workoutRoutineSet.tagValue = tag
            }
            self.workoutRoutineSet.managedObjectContext?.saveOrCrash()
        }) {
            HStack {
                Image(systemName: "circle.fill")
                    .imageScale(.small)
                    .foregroundColor(tag.color)
                Text(tag.title.capitalized)
                Spacer()
                if self.workoutRoutineSet.tagValue == tag {
                    Image(systemName: "checkmark")
                        .foregroundColor(.secondary)
                }
            }.contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    var body: some View {
        List {
            Section(header: Text("Tag".uppercased())) {
                ForEach(WorkoutRoutineSet.supportedTags, id: \.self) { tag in
                    self.tagButton(tag: tag)
                }
            }
            
            Section(header: Text("Comment".uppercased())) {
                ClearableTextField(titleKey: "Comment", text: workoutRoutineSetComment, onCommit: { self.adjustAndSaveWorkoutRoutineSetCommentInput() })
            }
        }
        .listStyleCompat_InsetGroupedListStyle()
        .keyboardDoneToolbar()
    }
}

#if DEBUG
struct WorkoutRoutineSetEditor_Previews: PreviewProvider {
    static var overwriteRepetitionsMin: Int16? = nil
    static var overwriteRepetitionsMax: Int16? = nil
    
    static var tempRepetitionsMinBinding = Binding<Int16?>(
        get: {
            overwriteRepetitionsMin
        },
        set: { newValue in
            overwriteRepetitionsMin = newValue
        }
    )
    
    static var tempRepetitionsMaxBinding = Binding<Int16?>(
        get: {
            overwriteRepetitionsMax
        },
        set: { newValue in
            overwriteRepetitionsMax = newValue
        }
    )
    
    static var previews: some View {
        Group {
            WorkoutRoutineSetEditor(workoutRoutineSet: MockWorkoutData.metric.workoutRoutineSet, overwriteRepetitionsMin: tempRepetitionsMinBinding, overwriteRepetitionsMax: tempRepetitionsMaxBinding, showNext: false)
                .mockEnvironment(weightUnit: .metric)
                .previewLayout(.sizeThatFits)
            
            MoreView(workoutRoutineSet: MockWorkoutData.metric.workoutRoutineSet)
                .mockEnvironment(weightUnit: .metric)
                .previewLayout(.sizeThatFits)
                .listStyle(GroupedListStyle())
        }
    }
}
#endif
