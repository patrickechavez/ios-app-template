//
//  DateField.swift
//  AppTemplate
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// Date picker wrapped in the same label-and-error frame as the text fields.
// Pass a range to limit the selectable dates.
struct DateField: View {

    @Binding var date: Date

    var label: String?
    var error: String?
    var isRequired: Bool = false
    var range: ClosedRange<Date>?
    var displayedComponents: DatePicker.Components = .date

    var body: some View {
        FieldContainer(label: label, isRequired: isRequired, error: error) {
            Group {
                if let range {
                    DatePicker("", selection: $date, in: range, displayedComponents: displayedComponents)
                } else {
                    DatePicker("", selection: $date, displayedComponents: displayedComponents)
                }
            }
            .labelsHidden()
            .accessibilityLabel(label.map(Text.init) ?? Text("Date", comment: "Accessibility label for a date field"))
        }
    }
}
