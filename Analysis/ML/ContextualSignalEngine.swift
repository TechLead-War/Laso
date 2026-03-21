import Foundation
import CoreLocation
@preconcurrency import WeatherKit

// MARK: - Weather Context

/// Daily weather summary for a single date, used as ML contextual signal.
struct WeatherContext: Codable, Sendable {
    let date: Date
    let temperatureHigh: Double         // Celsius
    let temperatureLow: Double          // Celsius
    let humidity: Double                // 0-1
    let barometricPressure: Double      // hPa
    let uvIndex: Int                    // 0-11+
    let precipitation: Double           // mm
    let windSpeed: Double               // m/s
    let condition: WeatherCondition     // categorical

    enum WeatherCondition: String, Codable, Sendable {
        case clear, partlyCloudy, cloudy, rain, snow, storm, fog, windy
    }
}

// MARK: - Enriched Circadian Context

/// Extended temporal and behavioral context features for a single day.
struct EnrichedCircadianContext: Codable {
    // Existing (from ContextFeatures)
    let weekdaySin: Double
    let weekdayCos: Double
    let monthSin: Double
    let monthCos: Double
    let isWeekend: Double

    // Time-of-year features
    let dayOfYearSin: Double            // Cyclical encoding, period = 365
    let dayOfYearCos: Double
    let daylightHours: Double           // Approximate from latitude + date
    let seasonIndex: Double             // 0=winter, 0.25=spring, 0.5=summer, 0.75=fall

    // Sleep timing derived features
    let bedtimeDeviation: Double?       // Hours from personal mean bedtime
    let sleepMidpoint: Double?          // Clock time of sleep midpoint (hours, 0-24)
    let socialJetLag: Double?           // |weekday_midpoint - weekend_midpoint| in hours

    // Activity timing
    let morningActivityRatio: Double?   // % of daily steps before noon
    let eveningActivityRatio: Double?   // % of daily steps after 6 PM

    /// All feature values as an ordered array for ML input.
    var asArray: [Double] {
        let values: [Double?] = [
            weekdaySin, weekdayCos, monthSin, monthCos, isWeekend,
            dayOfYearSin, dayOfYearCos, daylightHours, seasonIndex,
            bedtimeDeviation, sleepMidpoint, socialJetLag,
            morningActivityRatio, eveningActivityRatio
        ]
        return values.map { $0 ?? 0.0 }
    }

    /// Feature key names in the same order as `asArray`.
    static let featureKeys: [String] = [
        "weekday_sin", "weekday_cos", "month_sin", "month_cos", "is_weekend",
        "day_of_year_sin", "day_of_year_cos", "daylight_hours", "season_index",
        "bedtime_deviation", "sleep_midpoint", "social_jet_lag",
        "morning_activity_ratio", "evening_activity_ratio"
    ]
}

// MARK: - Cycle Context

/// Menstrual cycle context for ML feature enrichment.
struct CycleContext: Codable {
    let cycleDay: Int?                  // Day within current cycle (1-35)
    let cycleDaySin: Double?            // Cyclical encoding, period = estimated cycle length
    let cycleDayCos: Double?
    let estimatedPhase: CyclePhase?
    let phaseOneHot: [Double]           // 4-element one-hot encoding
    let daysUntilNextPeriod: Int?       // Predicted days until next menstruation

    enum CyclePhase: String, Codable {
        case menstrual      // Days 1-5 (adjusts to actual cycle length)
        case follicular     // Days 6-13
        case ovulatory      // Days 14-16
        case luteal         // Days 17-28+
    }

    /// All feature values as an ordered array for ML input.
    var asArray: [Double] {
        let base: [Double] = [
            Double(cycleDay ?? 0),
            cycleDaySin ?? 0.0,
            cycleDayCos ?? 0.0,
            Double(daysUntilNextPeriod ?? 0)
        ]
        return base + phaseOneHot
    }

    /// Feature key names in the same order as `asArray`.
    static let featureKeys: [String] = [
        "cycle_day", "cycle_day_sin", "cycle_day_cos", "days_until_next_period",
        "phase_menstrual", "phase_follicular", "phase_ovulatory", "phase_luteal"
    ]

    /// Context indicating no cycle tracking data is available.
    static let unavailable = CycleContext(
        cycleDay: nil,
        cycleDaySin: nil,
        cycleDayCos: nil,
        estimatedPhase: nil,
        phaseOneHot: [0, 0, 0, 0],
        daysUntilNextPeriod: nil
    )
}

// MARK: - Enriched Context (Unified)

/// Unified contextual signal vector combining circadian, weather, and cycle context.
/// The `pressureChangeDelta` is populated by the batch context builder when consecutive-day
/// weather data is available; single-date builds leave it at zero.
struct EnrichedContext: Codable {
    let date: Date
    let circadian: EnrichedCircadianContext
    let weather: WeatherContext?
    let cycle: CycleContext?
    /// Barometric pressure change from the previous day (hPa). Zero when unavailable.
    var pressureChangeDelta: Double = 0.0

    /// Flatten all contextual features into a single array for ML input.
    /// Returns `(values, keys)` where keys describe each feature by name.
    func toFeatureArray() -> (values: [Double], keys: [String]) {
        var values: [Double] = []
        var keys: [String] = []

        // Circadian features (always available)
        values.append(contentsOf: circadian.asArray)
        keys.append(contentsOf: EnrichedCircadianContext.featureKeys)

        // Weather features (fallback to 0 when unavailable)
        values.append(contentsOf: weatherFeatureValues())
        keys.append(contentsOf: Self.weatherFeatureKeys)

        // Cycle features (fallback to 0 when unavailable)
        let cycleValues = (cycle ?? .unavailable).asArray
        values.append(contentsOf: cycleValues)
        keys.append(contentsOf: CycleContext.featureKeys)

        return (values, keys)
    }

    // MARK: - Weather Feature Extraction

    static let weatherFeatureKeys: [String] = [
        "temp_high_c", "temp_low_c", "humidity", "pressure_hpa",
        "pressure_change_hpa", "uv_category", "is_precipitation",
        "wind_speed_ms", "condition_clear", "condition_cloudy", "condition_rain_snow"
    ]

    private func weatherFeatureValues() -> [Double] {
        guard let w = weather else {
            return Array(repeating: 0.0, count: Self.weatherFeatureKeys.count)
        }

        let uvCategory: Double
        switch w.uvIndex {
        case 0...2: uvCategory = 0.0    // low
        case 3...5: uvCategory = 0.33   // moderate
        case 6...7: uvCategory = 0.66   // high
        default:    uvCategory = 1.0    // extreme
        }

        let isPrecipitation: Double = w.precipitation > 0.5 ? 1.0 : 0.0

        let conditionClear: Double = (w.condition == .clear) ? 1.0 : 0.0
        let conditionCloudy: Double = (w.condition == .partlyCloudy || w.condition == .cloudy || w.condition == .fog) ? 1.0 : 0.0
        let conditionRainSnow: Double = (w.condition == .rain || w.condition == .snow || w.condition == .storm) ? 1.0 : 0.0

        return [
            w.temperatureHigh,
            w.temperatureLow,
            w.humidity,
            w.barometricPressure,
            pressureChangeDelta,
            uvCategory,
            isPrecipitation,
            w.windSpeed,
            conditionClear,
            conditionCloudy,
            conditionRainSnow
        ]
    }
}

// MARK: - Weather Signal Provider

/// Fetches and caches daily weather data from WeatherKit.
/// Falls back gracefully when WeatherKit is unavailable or permission is denied.
final class WeatherSignalProvider: Sendable {

    /// Thread-safe cache backed by an actor.
    private let cache = CacheStorage()

    private actor CacheStorage {
        private var store: [String: WeatherContext] = [:]

        func get(_ key: String) -> WeatherContext? { store[key] }
        func set(_ key: String, _ value: WeatherContext) { store[key] = value }
        func getAll() -> [String: WeatherContext] { store }
    }

    // MARK: - Public API

    /// Fetch daily weather for a specific date and location.
    /// Returns `nil` if WeatherKit is unavailable or the request fails.
    func fetchWeather(for date: Date, location: CLLocation) async -> WeatherContext? {
        let key = Self.cacheKey(for: date)
        if let cached = await cache.get(key) {
            return cached
        }

        guard let context = await requestWeatherKit(date: date, location: location) else {
            return nil
        }

        await cache.set(key, context)
        return context
    }

    /// Fetch weather for a date range (batch). Skips dates already cached.
    func fetchWeather(
        for dates: [Date],
        location: CLLocation
    ) async -> [Date: WeatherContext] {
        var results: [Date: WeatherContext] = [:]
        let calendar = Calendar.current

        for date in dates {
            let day = calendar.startOfDay(for: date)
            let key = Self.cacheKey(for: day)
            if let cached = await cache.get(key) {
                results[day] = cached
                continue
            }
            if let context = await requestWeatherKit(date: day, location: location) {
                await cache.set(key, context)
                results[day] = context
            }
        }

        return results
    }

    /// All currently cached weather data.
    func cachedWeather() async -> [Date: WeatherContext] {
        let all = await cache.getAll()
        let formatter = Self.dateFormatter()
        var result: [Date: WeatherContext] = [:]
        for (key, value) in all {
            if let date = formatter.date(from: key) {
                result[date] = value
            }
        }
        return result
    }

    // MARK: - WeatherKit Integration

    private func requestWeatherKit(date: Date, location: CLLocation) async -> WeatherContext? {
        let service = WeatherService.shared

        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                return nil
            }

            let weather = try await service.weather(
                for: location,
                including: .daily(startDate: startOfDay, endDate: endOfDay)
            )

            guard let dayWeather = weather.forecast.first else { return nil }

            let condition = mapCondition(dayWeather.condition)

            return WeatherContext(
                date: startOfDay,
                temperatureHigh: dayWeather.highTemperature.converted(to: .celsius).value,
                temperatureLow: dayWeather.lowTemperature.converted(to: .celsius).value,
                humidity: 0.5, // DayWeather doesn't expose humidity; use hourly data if available
                barometricPressure: 1013.25, // DayWeather lacks pressure; populated via hourly if needed
                uvIndex: dayWeather.uvIndex.value,
                precipitation: dayWeather.precipitationAmount.converted(to: .millimeters).value,
                windSpeed: dayWeather.wind.speed.converted(to: .metersPerSecond).value,
                condition: condition
            )
        } catch {
            // WeatherKit unavailable, permission denied, or network error
            return nil
        }
    }

    private func mapCondition(_ condition: WeatherKit.WeatherCondition) -> WeatherContext.WeatherCondition {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return .clear
        case .partlyCloudy:
            return .partlyCloudy
        case .cloudy, .mostlyCloudy:
            return .cloudy
        case .rain, .drizzle, .heavyRain, .freezingRain, .freezingDrizzle:
            return .rain
        case .snow, .heavySnow, .flurries, .sleet, .blizzard, .wintryMix,
             .blowingSnow:
            return .snow
        case .strongStorms, .thunderstorms, .isolatedThunderstorms,
             .scatteredThunderstorms, .tropicalStorm, .hurricane:
            return .storm
        case .foggy, .haze, .smoky:
            return .fog
        case .windy, .breezy, .blowingDust:
            return .windy
        default:
            return .cloudy
        }
    }

    // MARK: - Helpers

    private static func cacheKey(for date: Date) -> String {
        dateFormatter().string(from: date)
    }

    private static func dateFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }
}

// MARK: - Contextual Signal Engine

/// Builds enriched contextual feature vectors from weather, circadian, sleep timing,
/// activity timing, and menstrual cycle data. These features explain variance in health
/// metrics that cannot be captured by the metric time series alone.
enum ContextualSignalEngine {

    // MARK: - Single-Date Context Builder

    /// Build enriched context for a specific date.
    ///
    /// - Parameters:
    ///   - date: The target date.
    ///   - sleepTimingSeries: Recent sleep episodes with bedtime and wake time.
    ///   - hourlyStepData: Per-date array of 24 hourly step counts (index 0 = midnight-1 AM).
    ///   - weatherData: Pre-fetched weather for this date (nil if unavailable).
    ///   - cycleData: Current cycle day and estimated cycle length (nil if not tracking).
    ///   - latitude: User's latitude for daylight estimation (nil uses 40 N default).
    static func buildContext(
        date: Date,
        sleepTimingSeries: [(date: Date, bedtime: Date, wakeTime: Date)]?,
        hourlyStepData: [Date: [Double]]?,
        weatherData: WeatherContext?,
        cycleData: (currentDay: Int, cycleLength: Int)?,
        latitude: Double?
    ) -> EnrichedContext {
        let calendar = Calendar.current
        let circadian = buildCircadianContext(
            date: date,
            sleepTimingSeries: sleepTimingSeries,
            hourlyStepData: hourlyStepData,
            latitude: latitude,
            calendar: calendar
        )

        let cycle: CycleContext?
        if let cycleData {
            cycle = buildCycleContext(
                cycleDay: cycleData.currentDay,
                cycleLength: cycleData.cycleLength
            )
        } else {
            cycle = nil
        }

        return EnrichedContext(
            date: date,
            circadian: circadian,
            weather: weatherData,
            cycle: cycle,
            pressureChangeDelta: 0.0
        )
    }

    // MARK: - Batch Context Builder

    /// Build enriched contexts for a date range. Computes pressure deltas across
    /// consecutive days and populates social jet lag from aggregated sleep timing.
    ///
    /// - Parameters:
    ///   - dateRange: Array of dates (need not be sorted).
    ///   - sleepTimingSeries: All available sleep episodes.
    ///   - hourlyStepData: Hourly step counts keyed by date.
    ///   - weatherHistory: Pre-fetched weather keyed by date.
    ///   - cycleHistory: Menstrual cycle start dates with lengths.
    ///   - latitude: User's latitude for daylight estimation.
    static func buildContexts(
        dateRange: [Date],
        sleepTimingSeries: [(date: Date, bedtime: Date, wakeTime: Date)]?,
        hourlyStepData: [Date: [Double]]?,
        weatherHistory: [Date: WeatherContext]?,
        cycleHistory: [(startDate: Date, length: Int)]?,
        latitude: Double?
    ) -> [Date: EnrichedContext] {
        let calendar = Calendar.current
        let sortedDates = dateRange.sorted()

        // Pre-compute social jet lag from all sleep data
        let globalSocialJetLag = computeSocialJetLag(
            sleepTimingSeries: sleepTimingSeries,
            calendar: calendar
        )

        // Pre-compute per-date cycle day
        let cycleDayMap = buildCycleDayMap(
            dateRange: sortedDates,
            cycleHistory: cycleHistory,
            calendar: calendar
        )

        // Build pressure change map (hPa delta from yesterday)
        let pressureChangeMap = buildPressureChangeMap(
            dateRange: sortedDates,
            weatherHistory: weatherHistory,
            calendar: calendar
        )

        var results: [Date: EnrichedContext] = [:]
        results.reserveCapacity(sortedDates.count)

        for date in sortedDates {
            let day = calendar.startOfDay(for: date)

            // Circadian
            var circadian = buildCircadianContext(
                date: day,
                sleepTimingSeries: sleepTimingSeries,
                hourlyStepData: hourlyStepData,
                latitude: latitude,
                calendar: calendar
            )

            // Override social jet lag with global computation (more accurate with more data)
            if circadian.socialJetLag == nil, let sjl = globalSocialJetLag {
                circadian = EnrichedCircadianContext(
                    weekdaySin: circadian.weekdaySin,
                    weekdayCos: circadian.weekdayCos,
                    monthSin: circadian.monthSin,
                    monthCos: circadian.monthCos,
                    isWeekend: circadian.isWeekend,
                    dayOfYearSin: circadian.dayOfYearSin,
                    dayOfYearCos: circadian.dayOfYearCos,
                    daylightHours: circadian.daylightHours,
                    seasonIndex: circadian.seasonIndex,
                    bedtimeDeviation: circadian.bedtimeDeviation,
                    sleepMidpoint: circadian.sleepMidpoint,
                    socialJetLag: sjl,
                    morningActivityRatio: circadian.morningActivityRatio,
                    eveningActivityRatio: circadian.eveningActivityRatio
                )
            }

            // Cycle
            let cycle: CycleContext?
            if let (cycleDay, cycleLength) = cycleDayMap[day] {
                cycle = buildCycleContext(cycleDay: cycleDay, cycleLength: cycleLength)
            } else {
                cycle = nil
            }

            let pressureDelta = pressureChangeMap[day] ?? 0.0

            results[day] = EnrichedContext(
                date: day,
                circadian: circadian,
                weather: weatherHistory?[day],
                cycle: cycle,
                pressureChangeDelta: pressureDelta
            )
        }

        return results
    }

    // MARK: - Daylight Hours Calculation

    /// Approximate daylight hours using the sunrise equation.
    ///
    /// Uses: `hours = 24 - (24/pi) * acos((sin(0.8333*pi/180) + sin(lat)*sin(decl)) / (cos(lat)*cos(decl)))`
    /// where declination = -23.45 * cos(2*pi/365 * (dayOfYear + 10))
    ///
    /// - Parameters:
    ///   - latitude: Latitude in degrees (-90 to 90).
    ///   - dayOfYear: Day of the year (1-366).
    /// - Returns: Estimated daylight hours (0-24). Clamped for polar edge cases.
    static func estimateDaylightHours(latitude: Double, dayOfYear: Int) -> Double {
        let latRad = latitude * .pi / 180.0

        // Solar declination angle
        let declinationDeg = -23.45 * cos(2.0 * .pi / 365.0 * Double(dayOfYear + 10))
        let declRad = declinationDeg * .pi / 180.0

        // Hour angle calculation
        let cosLat = cos(latRad)
        let cosDec = cos(declRad)

        guard cosLat * cosDec != 0 else {
            // Exactly at poles. 24h or 0h depending on hemisphere/season
            return latitude >= 0
                ? (declinationDeg > 0 ? 24.0 : 0.0)
                : (declinationDeg < 0 ? 24.0 : 0.0)
        }

        let numerator = sin(0.8333 * .pi / 180.0) + sin(latRad) * sin(declRad)
        let denominator = cosLat * cosDec

        let cosHourAngle = numerator / denominator

        // Clamp for polar day / polar night
        if cosHourAngle < -1.0 { return 24.0 }  // Midnight sun
        if cosHourAngle > 1.0 { return 0.0 }    // Polar night

        let hourAngle = acos(cosHourAngle)
        let daylightHours = 24.0 - (24.0 / .pi) * hourAngle

        return max(0, min(24, daylightHours))
    }

    /// Determine season index from month and hemisphere.
    ///
    /// Northern hemisphere: 0=winter(Dec-Feb), 0.25=spring(Mar-May), 0.5=summer(Jun-Aug), 0.75=fall(Sep-Nov)
    /// Southern hemisphere: seasons are inverted.
    static func seasonIndex(month: Int, isNorthernHemisphere: Bool) -> Double {
        let nhIndex: Double
        switch month {
        case 12, 1, 2: nhIndex = 0.0       // Winter
        case 3, 4, 5:  nhIndex = 0.25      // Spring
        case 6, 7, 8:  nhIndex = 0.5       // Summer
        case 9, 10, 11: nhIndex = 0.75     // Fall
        default: nhIndex = 0.0
        }

        if isNorthernHemisphere {
            return nhIndex
        } else {
            // Southern hemisphere: shift by 0.5 (6 months)
            let shifted = nhIndex + 0.5
            return shifted >= 1.0 ? shifted - 1.0 : shifted
        }
    }

    // MARK: - Circadian Context Builder

    private static func buildCircadianContext(
        date: Date,
        sleepTimingSeries: [(date: Date, bedtime: Date, wakeTime: Date)]?,
        hourlyStepData: [Date: [Double]]?,
        latitude: Double?,
        calendar: Calendar
    ) -> EnrichedCircadianContext {
        // Base cyclical encodings
        let weekday = Double(calendar.component(.weekday, from: date))   // 1=Sun, 7=Sat
        let month = Double(calendar.component(.month, from: date))       // 1-12
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)

        let weekdayAngle = 2.0 * .pi * (weekday - 1.0) / 7.0
        let monthAngle = 2.0 * .pi * (month - 1.0) / 12.0
        let dayOfYearAngle = 2.0 * .pi * (dayOfYear - 1.0) / 365.0

        let dayOfWeek = calendar.component(.weekday, from: date)
        let isWeekend = (dayOfWeek == 1 || dayOfWeek == 7) ? 1.0 : 0.0

        // Daylight hours
        let lat = latitude ?? 40.0 // Default to mid-northern latitude
        let doy = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let daylightHours = estimateDaylightHours(latitude: lat, dayOfYear: doy)

        // Season
        let monthInt = calendar.component(.month, from: date)
        let isNorthern = lat >= 0
        let season = seasonIndex(month: monthInt, isNorthernHemisphere: isNorthern)

        // Sleep timing features
        let day = calendar.startOfDay(for: date)
        let (bedtimeDeviation, sleepMidpoint, socialJetLag) = computeSleepTimingFeatures(
            for: day,
            sleepTimingSeries: sleepTimingSeries,
            calendar: calendar
        )

        // Activity timing features
        let (morningRatio, eveningRatio) = computeActivityTimingFeatures(
            for: day,
            hourlyStepData: hourlyStepData
        )

        return EnrichedCircadianContext(
            weekdaySin: sin(weekdayAngle),
            weekdayCos: cos(weekdayAngle),
            monthSin: sin(monthAngle),
            monthCos: cos(monthAngle),
            isWeekend: isWeekend,
            dayOfYearSin: sin(dayOfYearAngle),
            dayOfYearCos: cos(dayOfYearAngle),
            daylightHours: daylightHours,
            seasonIndex: season,
            bedtimeDeviation: bedtimeDeviation,
            sleepMidpoint: sleepMidpoint,
            socialJetLag: socialJetLag,
            morningActivityRatio: morningRatio,
            eveningActivityRatio: eveningRatio
        )
    }

    // MARK: - Sleep Timing Features

    /// Compute bedtime deviation, sleep midpoint, and social jet lag for a given date.
    private static func computeSleepTimingFeatures(
        for date: Date,
        sleepTimingSeries: [(date: Date, bedtime: Date, wakeTime: Date)]?,
        calendar: Calendar
    ) -> (bedtimeDeviation: Double?, sleepMidpoint: Double?, socialJetLag: Double?) {
        guard let series = sleepTimingSeries, !series.isEmpty else {
            return (nil, nil, nil)
        }

        // Find sleep entry for this date (match on calendar day)
        let todaySleep = series.first { calendar.isDate($0.date, inSameDayAs: date) }

        // Compute mean bedtime from all entries for deviation calculation
        let bedtimeHours = series.map { bedtimeToHours($0.bedtime, calendar: calendar) }
        let meanBedtime = circularMean(hours: bedtimeHours)

        // Today's values
        let midpoint: Double?
        let deviation: Double?

        if let sleep = todaySleep {
            let bed = bedtimeToHours(sleep.bedtime, calendar: calendar)
            let wake = wakeTimeToHours(sleep.wakeTime, calendar: calendar)
            midpoint = sleepMidpointHours(bedtime: bed, wakeTime: wake)
            deviation = circularDifference(bed, meanBedtime)
        } else {
            midpoint = nil
            deviation = nil
        }

        // Social jet lag: requires at least 2 weekday and 2 weekend sleep entries
        let socialJetLag = computeSocialJetLag(sleepTimingSeries: series, calendar: calendar)

        return (deviation, midpoint, socialJetLag)
    }

    /// Compute social jet lag from the entire sleep timing series.
    /// Requires at least 2 weekday and 2 weekend sleep data points.
    private static func computeSocialJetLag(
        sleepTimingSeries: [(date: Date, bedtime: Date, wakeTime: Date)]?,
        calendar: Calendar
    ) -> Double? {
        guard let series = sleepTimingSeries, series.count >= 4 else { return nil }

        var weekdayMidpoints: [Double] = []
        var weekendMidpoints: [Double] = []

        for entry in series {
            let dow = calendar.component(.weekday, from: entry.date)
            let bed = bedtimeToHours(entry.bedtime, calendar: calendar)
            let wake = wakeTimeToHours(entry.wakeTime, calendar: calendar)
            let mid = sleepMidpointHours(bedtime: bed, wakeTime: wake)

            if dow == 1 || dow == 7 {
                weekendMidpoints.append(mid)
            } else {
                weekdayMidpoints.append(mid)
            }
        }

        guard weekdayMidpoints.count >= 2, weekendMidpoints.count >= 2 else {
            return nil
        }

        let weekdayMean = circularMean(hours: weekdayMidpoints)
        let weekendMean = circularMean(hours: weekendMidpoints)
        return abs(circularDifference(weekdayMean, weekendMean))
    }

    /// Convert a bedtime Date to hours (0-30). Bedtimes after 6 PM are kept as-is (18-24);
    /// bedtimes before 6 AM are treated as next-day (24-30) to handle midnight wrap-around.
    private static func bedtimeToHours(_ bedtime: Date, calendar: Calendar) -> Double {
        let hour = Double(calendar.component(.hour, from: bedtime))
        let minute = Double(calendar.component(.minute, from: bedtime))
        let totalHours = hour + minute / 60.0
        // If bedtime is in the early morning (0-6), treat as late-night (24-30)
        return totalHours < 6.0 ? totalHours + 24.0 : totalHours
    }

    /// Convert a wake time Date to hours (0-36). Wake times in early morning (0-18)
    /// are shifted to (24-42) when they represent "morning after" late bedtimes.
    private static func wakeTimeToHours(_ wakeTime: Date, calendar: Calendar) -> Double {
        let hour = Double(calendar.component(.hour, from: wakeTime))
        let minute = Double(calendar.component(.minute, from: wakeTime))
        let totalHours = hour + minute / 60.0
        // Wake times are typically in 4-12 range; shift to 28-36 for midnight-crossing math
        return totalHours < 18.0 ? totalHours + 24.0 : totalHours
    }

    /// Compute sleep midpoint: (bedtime + wakeTime) / 2, handling wrap-around via extended-hour encoding.
    /// Result is normalized back to 0-24 range.
    private static func sleepMidpointHours(bedtime: Double, wakeTime: Double) -> Double {
        let mid = (bedtime + wakeTime) / 2.0
        // Normalize to 0-24
        var normalized = mid.truncatingRemainder(dividingBy: 24.0)
        if normalized < 0 { normalized += 24.0 }
        return normalized
    }

    /// Circular mean for hours (0-24 clock). Uses angular averaging to handle midnight wrap-around.
    private static func circularMean(hours: [Double]) -> Double {
        guard !hours.isEmpty else { return 0 }
        let angles = hours.map { $0 * .pi / 12.0 } // Convert hours to radians (24h -> 2*pi)
        let sinSum = angles.reduce(0.0) { $0 + sin($1) }
        let cosSum = angles.reduce(0.0) { $0 + cos($1) }
        let meanAngle = atan2(sinSum / Double(hours.count), cosSum / Double(hours.count))
        var meanHours = meanAngle * 12.0 / .pi
        if meanHours < 0 { meanHours += 24.0 }
        return meanHours
    }

    /// Signed circular difference between two times in hours. Handles wrap-around.
    private static func circularDifference(_ a: Double, _ b: Double) -> Double {
        // Normalize both to 0-24
        var na = a.truncatingRemainder(dividingBy: 24.0)
        if na < 0 { na += 24.0 }
        var nb = b.truncatingRemainder(dividingBy: 24.0)
        if nb < 0 { nb += 24.0 }
        var diff = na - nb
        if diff > 12.0 { diff -= 24.0 }
        if diff < -12.0 { diff += 24.0 }
        return diff
    }

    // MARK: - Activity Timing Features

    /// Compute morning (before noon) and evening (after 6 PM) activity ratios from hourly step data.
    private static func computeActivityTimingFeatures(
        for date: Date,
        hourlyStepData: [Date: [Double]]?
    ) -> (morningRatio: Double?, eveningRatio: Double?) {
        guard let steps = hourlyStepData?[date], steps.count == 24 else {
            return (nil, nil)
        }

        let totalSteps = steps.reduce(0, +)
        guard totalSteps > 0 else { return (0, 0) }

        let morningSteps = steps[0..<12].reduce(0, +)     // midnight to noon
        let eveningSteps = steps[18..<24].reduce(0, +)     // 6 PM to midnight

        return (morningSteps / totalSteps, eveningSteps / totalSteps)
    }

    // MARK: - Cycle Context Builder

    /// Build menstrual cycle context for a specific cycle day and cycle length.
    private static func buildCycleContext(cycleDay: Int, cycleLength: Int) -> CycleContext {
        let safeLength = max(21, min(45, cycleLength))
        let safeDay = max(1, min(cycleDay, safeLength + 7)) // Allow some overflow for late cycles

        // Cyclical encoding with period = actual cycle length
        let angle = 2.0 * .pi * Double(safeDay - 1) / Double(safeLength)

        // Phase estimation adapted to actual cycle length
        let phase = estimatePhase(cycleDay: safeDay, cycleLength: safeLength)

        // One-hot encoding: [menstrual, follicular, ovulatory, luteal]
        let oneHot: [Double]
        switch phase {
        case .menstrual:  oneHot = [1, 0, 0, 0]
        case .follicular: oneHot = [0, 1, 0, 0]
        case .ovulatory:  oneHot = [0, 0, 1, 0]
        case .luteal:     oneHot = [0, 0, 0, 1]
        }

        // Days until next period
        let daysUntilNext = max(0, safeLength - safeDay + 1)

        return CycleContext(
            cycleDay: safeDay,
            cycleDaySin: sin(angle),
            cycleDayCos: cos(angle),
            estimatedPhase: phase,
            phaseOneHot: oneHot,
            daysUntilNextPeriod: daysUntilNext
        )
    }

    /// Estimate menstrual cycle phase, adapting standard 28-day model to actual cycle length.
    ///
    /// The luteal phase is relatively fixed at ~14 days before the next period.
    /// Ovulation is estimated at cycleLength - 14 (plus/minus 1 day).
    /// Menstrual phase is fixed at days 1-5.
    /// Follicular fills the gap between menstrual and ovulatory.
    private static func estimatePhase(cycleDay: Int, cycleLength: Int) -> CycleContext.CyclePhase {
        let menstrualEnd = 5
        let ovulationCenter = max(menstrualEnd + 3, cycleLength - 14)
        let ovulationStart = max(menstrualEnd + 1, ovulationCenter - 1)
        let ovulationEnd = min(cycleLength, ovulationCenter + 1)

        if cycleDay <= menstrualEnd {
            return .menstrual
        } else if cycleDay < ovulationStart {
            return .follicular
        } else if cycleDay <= ovulationEnd {
            return .ovulatory
        } else {
            return .luteal
        }
    }

    // MARK: - Batch Helpers

    /// Build a map from date -> (cycleDay, cycleLength) for a range of dates.
    private static func buildCycleDayMap(
        dateRange: [Date],
        cycleHistory: [(startDate: Date, length: Int)]?,
        calendar: Calendar
    ) -> [Date: (Int, Int)] {
        guard let cycles = cycleHistory, !cycles.isEmpty else { return [:] }

        let sortedCycles = cycles.sorted { $0.startDate < $1.startDate }
        var result: [Date: (Int, Int)] = [:]

        for date in dateRange {
            let day = calendar.startOfDay(for: date)

            // Find the most recent cycle start on or before this date
            guard let cycleIndex = sortedCycles.lastIndex(where: {
                calendar.startOfDay(for: $0.startDate) <= day
            }) else { continue }

            let cycle = sortedCycles[cycleIndex]
            let cycleStart = calendar.startOfDay(for: cycle.startDate)
            let dayInCycle = (calendar.dateComponents([.day], from: cycleStart, to: day).day ?? 0) + 1

            // Only include if within a reasonable window of the cycle length
            if dayInCycle >= 1 && dayInCycle <= cycle.length + 7 {
                result[day] = (dayInCycle, cycle.length)
            }
        }

        return result
    }

    /// Build pressure change map (hPa delta from previous day) for consecutive dates.
    private static func buildPressureChangeMap(
        dateRange: [Date],
        weatherHistory: [Date: WeatherContext]?,
        calendar: Calendar
    ) -> [Date: Double] {
        guard let weather = weatherHistory, weather.count >= 2 else { return [:] }

        var result: [Date: Double] = [:]
        let sorted = dateRange.sorted()

        for i in 1..<sorted.count {
            let today = calendar.startOfDay(for: sorted[i])
            let yesterday = calendar.startOfDay(for: sorted[i - 1])

            if let todayWeather = weather[today], let yesterdayWeather = weather[yesterday] {
                result[today] = todayWeather.barometricPressure - yesterdayWeather.barometricPressure
            }
        }

        return result
    }
}

// MARK: - Weather Impact Analyzer

/// Discovers how weather features correlate with specific health metrics for THIS user.
/// Requires at least `minimumDays` of paired weather + health data.
enum WeatherImpactAnalyzer {

    struct WeatherImpact {
        let weatherFeature: String          // "temperature", "pressure_change", "humidity"
        let healthMetric: HealthMetric
        let correlation: Double             // Pearson r
        let impactDescription: String       // "Your HRV drops ~12% on days above 30C"
        let sampleCount: Int
    }

    /// Weather features to test against health metrics.
    private static let weatherFeatureExtractors: [(name: String, extract: (WeatherContext) -> Double)] = [
        ("temperature", { ($0.temperatureHigh + $0.temperatureLow) / 2.0 }),
        ("temperature_high", { $0.temperatureHigh }),
        ("humidity", { $0.humidity }),
        ("precipitation", { $0.precipitation }),
        ("uv_index", { Double($0.uvIndex) }),
        ("wind_speed", { $0.windSpeed }),
        ("barometric_pressure", { $0.barometricPressure })
    ]

    /// Health metrics most likely to be weather-sensitive.
    private static let sensitiveMetrics: [HealthMetric] = [
        .heartRate, .restingHeartRate, .heartRateVariability,
        .sleepDuration, .sleepDeep, .sleepREM,
        .steps, .activeCalories, .exerciseMinutes,
        .vo2Max, .bloodOxygen, .respiratoryRate
    ]

    /// Analyze correlations between weather features and health metrics.
    ///
    /// - Parameters:
    ///   - weatherHistory: Daily weather data keyed by date.
    ///   - timeSeries: Health metric time series.
    ///   - minimumDays: Minimum overlapping days required (default 30).
    /// - Returns: Statistically meaningful weather-health impacts sorted by absolute correlation.
    static func analyzeWeatherImpact(
        weatherHistory: [Date: WeatherContext],
        timeSeries: [HealthMetric: MetricTimeSeries],
        minimumDays: Int = 30
    ) -> [WeatherImpact] {
        guard weatherHistory.count >= minimumDays else { return [] }

        let calendar = Calendar.current

        // Build date-indexed health metric values
        var metricByDate: [HealthMetric: [Date: Double]] = [:]
        for metric in sensitiveMetrics {
            guard let series = timeSeries[metric] else { continue }
            var dateMap: [Date: Double] = [:]
            for sample in series.sortedSamples {
                let day = calendar.startOfDay(for: sample.date)
                dateMap[day] = sample.value
            }
            if dateMap.count >= minimumDays {
                metricByDate[metric] = dateMap
            }
        }

        // Pre-compute pressure change series
        let sortedWeatherDates = weatherHistory.keys.sorted()
        var pressureChanges: [Date: Double] = [:]
        for i in 1..<sortedWeatherDates.count {
            let today = sortedWeatherDates[i]
            let yesterday = sortedWeatherDates[i - 1]
            if let tw = weatherHistory[today], let yw = weatherHistory[yesterday] {
                pressureChanges[today] = tw.barometricPressure - yw.barometricPressure
            }
        }

        var impacts: [WeatherImpact] = []

        // Test all weather feature x health metric combinations
        let allExtractors = weatherFeatureExtractors + [
            ("pressure_change", { (_: WeatherContext) -> Double in 0.0 }) // Handled specially
        ]

        for (featureName, extractor) in allExtractors {
            for (metric, dateMap) in metricByDate {
                var weatherValues: [Double] = []
                var healthValues: [Double] = []

                for date in sortedWeatherDates {
                    guard let healthValue = dateMap[date] else { continue }

                    let weatherValue: Double
                    if featureName == "pressure_change" {
                        guard let pc = pressureChanges[date] else { continue }
                        weatherValue = pc
                    } else {
                        guard let w = weatherHistory[date] else { continue }
                        weatherValue = extractor(w)
                    }

                    weatherValues.append(weatherValue)
                    healthValues.append(healthValue)
                }

                guard weatherValues.count >= minimumDays else { continue }

                let r = pearsonCorrelation(weatherValues, healthValues)

                // Only report meaningful correlations (|r| >= 0.15 with sufficient sample)
                guard abs(r) >= 0.15 else { continue }

                // t-test for significance: t = r * sqrt(n-2) / sqrt(1-r^2)
                let n = Double(weatherValues.count)
                let tStat = abs(r) * sqrt(n - 2) / sqrt(max(1e-10, 1 - r * r))
                // Approximate p < 0.05 threshold for large n: t > 1.96
                guard tStat > 1.96 else { continue }

                let description = generateImpactDescription(
                    featureName: featureName,
                    metric: metric,
                    correlation: r,
                    weatherValues: weatherValues,
                    healthValues: healthValues
                )

                impacts.append(WeatherImpact(
                    weatherFeature: featureName,
                    healthMetric: metric,
                    correlation: r,
                    impactDescription: description,
                    sampleCount: weatherValues.count
                ))
            }
        }

        return impacts.sorted { abs($0.correlation) > abs($1.correlation) }
    }

    // MARK: - Pearson Correlation

    private static func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(min(x.count, y.count))
        guard n > 2 else { return 0 }

        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0, sumY2 = 0.0
        for i in 0..<Int(n) {
            sumX += x[i]
            sumY += y[i]
            sumXY += x[i] * y[i]
            sumX2 += x[i] * x[i]
            sumY2 += y[i] * y[i]
        }

        let numerator = n * sumXY - sumX * sumY
        let denominatorA = n * sumX2 - sumX * sumX
        let denominatorB = n * sumY2 - sumY * sumY
        let denominator = sqrt(max(0, denominatorA) * max(0, denominatorB))

        guard denominator > 1e-10 else { return 0 }
        return max(-1, min(1, numerator / denominator))
    }

    // MARK: - Impact Description Generation

    private static func generateImpactDescription(
        featureName: String,
        metric: HealthMetric,
        correlation: Double,
        weatherValues: [Double],
        healthValues: [Double]
    ) -> String {
        let direction = correlation > 0 ? "increases" : "decreases"
        let metricName = metric.displayName

        // Compute quantile-based impact magnitude
        let sortedWeather = weatherValues.sorted()
        let n = sortedWeather.count
        guard n >= 4 else {
            return "Your \(metricName) \(direction) with \(featureName)."
        }

        let topQuartileThreshold = sortedWeather[n * 3 / 4]
        let bottomQuartileThreshold = sortedWeather[n / 4]

        var topQuartileHealth: [Double] = []
        var bottomQuartileHealth: [Double] = []

        for i in 0..<n {
            if weatherValues[i] >= topQuartileThreshold {
                topQuartileHealth.append(healthValues[i])
            }
            if weatherValues[i] <= bottomQuartileThreshold {
                bottomQuartileHealth.append(healthValues[i])
            }
        }

        guard !topQuartileHealth.isEmpty, !bottomQuartileHealth.isEmpty else {
            return "Your \(metricName) \(direction) with \(featureName)."
        }

        let topMean = topQuartileHealth.reduce(0, +) / Double(topQuartileHealth.count)
        let bottomMean = bottomQuartileHealth.reduce(0, +) / Double(bottomQuartileHealth.count)
        let percentDiff = bottomMean != 0
            ? abs((topMean - bottomMean) / bottomMean) * 100
            : abs(topMean - bottomMean)

        let featureLabel: String
        switch featureName {
        case "temperature", "temperature_high":
            featureLabel = "temperature"
        case "pressure_change":
            featureLabel = "barometric pressure change"
        case "humidity":
            featureLabel = "humidity"
        case "precipitation":
            featureLabel = "precipitation"
        case "uv_index":
            featureLabel = "UV exposure"
        case "wind_speed":
            featureLabel = "wind"
        case "barometric_pressure":
            featureLabel = "barometric pressure"
        default:
            featureLabel = featureName
        }

        return String(
            format: "Your %@ %@ ~%.0f%% on high-%@ days vs low-%@ days.",
            metricName,
            direction,
            percentDiff,
            featureLabel,
            featureLabel
        )
    }
}
