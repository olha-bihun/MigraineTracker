import SwiftUI

struct MonthCalendarView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedDate: Date
    let timeZone: TimeZone
    let records: [String: DaySnapshot]
    @State private var month = Date()

    private var calendar: Calendar { MonthGrid.calendar(timeZone: timeZone) }
    private var todayKey: String { DayEntry.key(for: Date()) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { moveMonth(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.text("Попередній місяць"))
                Spacer(minLength: 4)
            Text(MonthGrid.label(month, template: "MMMM yyyy", timeZone: timeZone))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                Button { moveMonth(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.text("Наступний місяць"))
                .disabled(DayEntry.key(for: month, timeZone: timeZone).prefix(7) >= todayKey.prefix(7))
            }
            if dynamicTypeSize.isAccessibilitySize {
                DisclosureGroup(L10n.text("Обрати дату")) {
                    ForEach(MonthGrid.days(in: month, calendar: calendar).compactMap { $0 }, id: \.self) { day in
                        dayButton(day)
                    }
                }
            } else {
                ScrollView(.horizontal) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 2), count: 7), spacing: 4) {
                ForEach(0..<7) { index in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7])
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                ForEach(Array(MonthGrid.days(in: month, calendar: calendar).enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear.frame(height: 52).accessibilityHidden(true)
                    }
                }
            }
                    .frame(minWidth: 320)
                }
            }
            HStack(alignment: .center, spacing: 10) {
                Label { Text(L10n.text("Без аури")) } icon: { Text("🤕") }
                Label { Text(L10n.text("З аурою")) } icon: { Text("😵‍💫") }
                Label { Text(L10n.text("Тригери")) } icon: { Text("🎯") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)

        }
        .buttonStyle(.plain)
        .onAppear { month = selectedDate }
        .onChange(of: selectedDate) { _, value in month = value }
    }

    private func moveMonth(_ delta: Int) {
        guard let start = calendar.dateInterval(of: .month, for: month)?.start,
              let next = calendar.date(byAdding: .month, value: delta, to: start) else { return }
        month = next
    }

    private func dayButton(_ day: Date) -> some View {
        let key = DayEntry.key(for: day, timeZone: timeZone)
        let selected = key == DayEntry.key(for: selectedDate, timeZone: timeZone)
        let today = key == todayKey
        let record = records[key]
        let migraine = record?.hasMigraine == true
        let triggers = !(record?.triggerIDs.isEmpty ?? true)
        return Button { selectedDate = day } label: {
            VStack(spacing: 3) {
                Text(dynamicTypeSize.isAccessibilitySize ? MonthGrid.label(day, template: "EEEE d MMMM", timeZone: timeZone) : "\(calendar.component(.day, from: day))")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 3) {
                    if migraine { Text(record?.migraineEmoji ?? "❔") }
                    if triggers { Text("🎯") }
                }
                .font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(migraine ? DiaryStyle.dustyLavender.opacity(0.28) : (selected ? DiaryStyle.lavender.opacity(0.2) : Color.clear), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke((today || selected) ? DiaryStyle.lavender : Color.clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .disabled(key > todayKey)
        .opacity(key > todayKey ? 0.35 : 1)
        .accessibilityLabel(MonthGrid.label(day, template: "d MMMM yyyy", timeZone: timeZone))
        .accessibilityValue([today ? L10n.text("Сьогодні") : "", selected ? L10n.text("Обрано") : "", migraine ? L10n.text("Була мігрень") : "", triggers ? L10n.text("Є тригери") : ""].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
