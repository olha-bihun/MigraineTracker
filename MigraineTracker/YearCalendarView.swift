import SwiftUI

struct YearCalendarView: View {
    let timeZone: TimeZone
    let records: [String: DaySnapshot]
    let selectedDate: Date
    let selectMonth: (Date) -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var year = Calendar.current.component(.year, from: Date())
    private var calendar: Calendar { MonthGrid.calendar(timeZone: timeZone) }
    private var currentYear: Int { calendar.component(.year, from: Date()) }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { year -= 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel(L10n.text("Попередній рік"))
                Spacer()
                Text(String(year)).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Spacer()
                Button { year += 1 } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .disabled(year >= currentYear).accessibilityLabel(L10n.text("Наступний рік"))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: textSize.isAccessibilitySize ? 1 : 3), spacing: 12) {
                ForEach(1...12, id: \.self) { number in
                    if let month = calendar.date(from: DateComponents(year: year, month: number, day: 1)) {
                        monthButton(month)
                    }
                }
            }
            HStack {
                Label { Text(L10n.text("Без аури")) } icon: { Text("🤕") }
                Label { Text(L10n.text("З аурою")) } icon: { Text("😵‍💫") }
                Label { Text(L10n.text("Тригери")) } icon: { Text("🎯") }
            }.font(.caption).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .onAppear { year = calendar.component(.year, from: selectedDate) }
    }

    private func monthButton(_ month: Date) -> some View {
        let days = MonthGrid.days(in: month, calendar: calendar)
        let key = DayEntry.key(for: month, timeZone: timeZone)
        return Button { selectMonth(month) } label: {
            VStack(spacing: 6) {
                Text(MonthGrid.label(month, template: "MMM", timeZone: timeZone))
                    .font(.caption.weight(.semibold)).foregroundStyle(.primary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let day {
                            let record = records[DayEntry.key(for: day, timeZone: timeZone)]
                            VStack(spacing: 0) {
                                Text(String(calendar.component(.day, from: day)))
                                    .font(.system(size: textSize.isAccessibilitySize ? 16 : 8, design: .rounded))
                                HStack(spacing: 1) {
                                    if record?.hasMigraine == true { Text(record?.migraineEmoji ?? "❔") }
                                    if !(record?.triggerIDs.isEmpty ?? true) { Text("🎯") }
                                }.font(.system(size: 5)).frame(height: 5)
                            }
                            .frame(maxWidth: .infinity)
                            .background(record?.hasMigraine == true ? DiaryStyle.dustyLavender.opacity(0.28) : Color.clear, in: RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(record == nil ? Color.secondary : DiaryStyle.lavender)
                        } else { Color.clear.frame(height: 14) }
                    }
                }.frame(minHeight: textSize.isAccessibilitySize ? 150 : 84, alignment: .top)
            }
            .padding(8)
            .background(DiaryStyle.lavender.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(key > DayEntry.key(for: Date()))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MonthGrid.label(month, template: "MMMM yyyy", timeZone: timeZone))
        .accessibilityHint(L10n.text("Відкрити місяць і записи"))
    }
}
