import EventKit

let eventStore = EKEventStore()
let startOfDay = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
let events = eventStore.events(matching: predicate)

for event in events {
    print("📅 Event: \(event.title) at \(event.startDate)")
}
