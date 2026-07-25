// Runnable check for the phone-to-watch wire format. Not part of any build target.
//
// The link itself cannot be exercised in a simulator: Apple does not deliver
// transferUserInfo to didReceiveUserInfo there, so the pure logic behind it (day
// keys, staleness, command encoding, redelivery dedupe) is checked here instead.
//
//   swiftc -o /tmp/watchcheck watch-bridge-check.swift WatchShared/WatchBridge.swift \
//     WatchShared/WatchStrings.swift Core/Extensions/Date+Extensions.swift && /tmp/watchcheck

import Foundation

func check(_ label: String, _ condition: Bool) {
    print(condition ? "ok   \(label)" : "FAIL \(label)")
    if !condition { exit(1) }
}

@main
struct WatchBridgeCheck {
    static func main() {
        // Day key format and stability
        let ref = Date(timeIntervalSince1970: 1_770_000_000)
        let key = WatchBridge.dayKey(for: ref)
        check("dayKey is yyyy-MM-dd", key.count == 10 && key.filter { $0 == "-" }.count == 2)
        check("dayKey stable for same day", key == WatchBridge.dayKey(for: ref.addingTimeInterval(60)))
        let nextDay = ref.addingTimeInterval(60 * 60 * 24)
        check("dayKey changes next day", key != WatchBridge.dayKey(for: nextDay))

        // Payload staleness
        let fresh = WatchPayload(dayKey: WatchBridge.dayKey(for: Date()), readinessScore: 72,
                                 readinessGrade: "B", dayType: "Maintain", actionHeadline: "Walk",
                                 actionDetail: "20 min", actionIcon: "figure.walk", actionDone: false,
                                 checkInAvailable: true, updatedAt: Date())
        check("fresh payload is not stale", !fresh.isStale())

        let old = WatchPayload(dayKey: WatchBridge.dayKey(for: Date()), readinessScore: 72,
                               readinessGrade: "B", dayType: "", actionHeadline: nil, actionDetail: nil,
                               actionIcon: nil, actionDone: false, checkInAvailable: false,
                               updatedAt: Date().addingTimeInterval(-WatchBridge.stalePayloadInterval - 1))
        check("aged payload is stale", old.isStale())

        let yesterday = WatchPayload(dayKey: WatchBridge.dayKey(for: Date().addingTimeInterval(-86_400)),
                                     readinessScore: 72, readinessGrade: "B", dayType: "",
                                     actionHeadline: nil, actionDetail: nil, actionIcon: nil,
                                     actionDone: false, checkInAvailable: false, updatedAt: Date())
        check("payload for another day is stale", yesterday.isStale())

        // Payload survives the wire
        let encoded = try! JSONEncoder().encode(fresh)
        check("payload round trips", try! JSONDecoder().decode(WatchPayload.self, from: encoded) == fresh)

        // Every command survives the wire and keeps its id and day
        let commands: [WatchCommand] = [
            .markActionDone(id: UUID(), dayKey: key),
            .checkIn(id: UUID(), dayKey: key, sleepQuality: 4, energyLevel: 3, soreness: 5),
            .journalTag(id: UUID(), dayKey: key, category: "caffeine", value: 1)
        ]
        for command in commands {
            let data = try! JSONEncoder().encode(command)
            let back = try! JSONDecoder().decode(WatchCommand.self, from: data)
            check("command round trips", back == command)
            check("command keeps id", back.id == command.id)
            check("command keeps day", back.dayKey == key)
        }

        // Dedupe ledger: a redelivered command is applied once
        let suite = UserDefaults(suiteName: "watchcheck.\(UUID().uuidString)")!
        let ledger = AppliedCommandLedger(defaults: suite)
        let once = UUID()
        check("first delivery is claimed", ledger.claim(once))
        check("redelivery is rejected", !ledger.claim(once))
        check("a different command still claims", ledger.claim(UUID()))

        // Ledger stays bounded and still rejects the newest ids
        for _ in 0..<(WatchBridge.appliedCommandIdsLimit + 50) { _ = ledger.claim(UUID()) }
        let stored = suite.stringArray(forKey: WatchBridge.appliedCommandIdsKey) ?? []
        check("ledger is capped", stored.count == WatchBridge.appliedCommandIdsLimit)
        let recent = UUID()
        _ = ledger.claim(recent)
        check("recent id still deduped after trim", !ledger.claim(recent))

        // Quick tags are the ones the phone can map back
        check("quick tags are unique", Set(WatchQuickTag.all.map(\.rawValue)).count == WatchQuickTag.all.count)
        check("quick tags log one unit", WatchQuickTag.all.allSatisfy { $0.value == 1 })

        print("\nall checks passed")
    }
}
