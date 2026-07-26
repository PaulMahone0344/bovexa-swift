import Foundation

/// Rekenwerk achter de nu-lijn in de dagweergave: waar staat "nu" in het uurraster,
/// en op welk uur opent het raster.
enum DayNowIndicator {
    /// Standaard openingsuur als de getoonde dag niet vandaag is.
    static let defaultAnchorHour = 7

    /// Minuten sinds middernacht, of nil als `now` niet op `day` valt — dan is er
    /// geen nu-lijn te tekenen. Een lijn op een andere dag zou een tijd aanwijzen
    /// die daar niets betekent.
    static func minutesFromMidnight(now: Date, day: Date, calendar: Calendar = .current) -> Double? {
        guard calendar.isDate(now, inSameDayAs: day) else { return nil }
        let dayStart = calendar.startOfDay(for: day)
        return now.timeIntervalSince(dayStart) / 60
    }

    /// Uur waar het raster op opent. Vandaag: één uur vóór nu, zodat de nu-lijn
    /// meteen in beeld staat — anders opent een dag in de avond nog steeds op
    /// 07:00 en zie je de lijn pas na scrollen. Andere dagen: het vaste ochtenduur.
    static func anchorHour(now: Date, day: Date, calendar: Calendar = .current) -> Int {
        guard calendar.isDate(now, inSameDayAs: day) else { return defaultAnchorHour }
        return max(0, calendar.component(.hour, from: now) - 1)
    }
}
