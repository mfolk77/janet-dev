import EventKit

let eventStore = EKEventStore()

// ✅ Ensure Calendar Access is Granted
eventStore.requestAccess(to: .event) { granted, error in
    if !granted || error != nil {
        print("❌ ERROR: Calendar access denied or an error occurred: \(error?.localizedDescription ?? "Unknown error")")
        return
    }

    let startOfDay = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
    let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
    let events = eventStore.events(matching: predicate)

    if events.isEmpty {
        print("✅ No events found for tomorrow.")
    } else {
        for event in events {
            let title = event.title ?? "Unnamed Event"
            let startDate = event.startDate ?? Date()
            print("📅 Event: \(title) at \(startDate)")
        }
    }
}
