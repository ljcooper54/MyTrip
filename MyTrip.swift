import SwiftUI

import MapKit

import CoreLocation



// ================================================================

// MARK: - Debug logging

// ================================================================

fileprivate var DebugEnabled = false



@inline(__always) func dlog(_ tag: String, _ msg: @autoclosure () -> String) {

    guard DebugEnabled else { return }

    let t = Thread.isMainThread ? "MAIN" : "BG"

    let ts = ISO8601DateFormatter().string(from: Date())

    print("[\(ts)] [\(t)] [\(tag)] \(msg())")

} // dlog



// ================================================================

// MARK: - App Entry

// ================================================================

@main

struct MyTripApp: App {

    var body: some Scene {

        dlog("APP", "MyTripApp started")

        return WindowGroup { ForecastShellView() }

    } // body

} // MyTripApp



// ================================================================

// MARK: - Models & Persistence

// ================================================================

struct Trip: Identifiable, Codable, Equatable {

    var id: UUID = UUID()

    var city: String

    var date: Date

    var latitude: Double? = nil

    var longitude: Double? = nil

} // Trip



enum RowStatus { case queued, loading, ready, failed } // RowStatus



struct ForecastRow: Identifiable, Equatable {

    let id = UUID()

    let tripId: UUID

    let date: Date

    let city: String

    var highC: Double? = nil

    var lowC: Double? = nil

    var rainPct: Int? = nil

    var status: RowStatus = .queued

} // ForecastRow



private let TRIPS_KEY = "trips.v8.coords.sorted"



func saveTrips(_ trips: [Trip]) {

    do {

        let data = try JSONEncoder().encode(trips)

        UserDefaults.standard.set(data, forKey: TRIPS_KEY)

        dlog("PERSIST", "Saved \(trips.count) trip(s)")

    } catch {

        dlog("PERSIST", "Save error: \(error.localizedDescription)")

    }

} // saveTrips



func loadTrips() -> [Trip] {

    if let data = UserDefaults.standard.data(forKey: TRIPS_KEY),

       let trips = try? JSONDecoder().decode([Trip].self, from: data) {

        dlog("PERSIST", "Loaded \(trips.count) trip(s)")

        return trips

    }

    dlog("PERSIST", "No saved trips; using defaults")

    return defaultTrips()

} // loadTrips



func sortTripsByDate(_ trips: inout [Trip]) {

    trips.sort { $0.date < $1.date }

    dlog("PERSIST", "Sorted \(trips.count) trip(s) by date (soonest first)")

} // sortTripsByDate



func defaultTrips() -> [Trip] {

    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

    func d(_ s: String) -> Date { df.date(from: s)! }

    return [

        Trip(city: "Tokyo, Japan",          date: d("2025-10-06")),

        Trip(city: "Tokyo, Japan",          date: d("2025-10-07")),

        Trip(city: "Shimizu, Japan",        date: d("2025-10-09")),

        Trip(city: "Shimizu, Japan",        date: d("2025-10-10")),

        Trip(city: "Osaka, Japan",          date: d("2025-10-11")),

        Trip(city: "Hiroshima, Japan",      date: d("2025-10-12")),

        Trip(city: "Hiroshima, Japan",      date: d("2025-10-13")),

        Trip(city: "Beppu, Japan",          date: d("2025-10-14")),

        Trip(city: "Kagoshima, Japan",      date: d("2025-10-15")),

        Trip(city: "Nagasaki, Japan",       date: d("2025-10-16")),

        Trip(city: "Taipei, Taiwan",        date: d("2025-10-18")),

        Trip(city: "Hong Kong, China",      date: d("2025-10-20")),

        Trip(city: "Hong Kong, China",      date: d("2025-10-21")),

        Trip(city: "Palo Alto, California", date: d("2025-10-21")),

        Trip(city: "Palo Alto, California", date: d("2025-10-22")),

        Trip(city: "Palo Alto, California", date: d("2025-10-23")),

        Trip(city: "Concord, Massachusetts",date: d("2025-10-24")),

    ]

} // defaultTrips



// ================================================================

// MARK: - Date/Format Helpers

// ================================================================

private enum DF {

    static let ymd: DateFormatter = { let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; return df }()

    static let med: DateFormatter = { let df = DateFormatter(); df.dateStyle = .medium; return df }()

} // DF



// ================================================================

// MARK: - Networking (coords-first)

// ================================================================

struct WeatherResponse: Codable {

    struct Daily: Codable {

        let temperature_2m_max: [Double]

        let temperature_2m_min: [Double]

        let precipitation_probability_max: [Int]?

    } // Daily

    let daily: Daily

} // WeatherResponse



struct GeoResponse: Codable {

    struct Result: Codable { let name: String; let latitude: Double; let longitude: Double; let country: String? } // Result

    let results: [Result]?

} // GeoResponse



func geocodeCity(_ city: String) async -> (lat: Double, lon: Double)? {

    let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city

    guard let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1") else { return nil }

    do {

        dlog("NET", "GEOCODE → \(city)")

        let (data, _) = try await URLSession.shared.data(from: url)

        if let g = try? JSONDecoder().decode(GeoResponse.self, from: data),

           let r = g.results?.first {

            dlog("NET", "GEOCODE OK lat=\(r.latitude) lon=\(r.longitude)")

            return (r.latitude, r.longitude)

        }

    } catch {

        dlog("NET", "GEOCODE ERR: \(error.localizedDescription)")

    }

    return nil

} // geocodeCity



func reverseGeocode(lat: Double, lon: Double) async -> String? {

    let geocoder = CLGeocoder()

    do {

        let marks = try await geocoder.reverseGeocodeLocation(.init(latitude: lat, longitude: lon))

        if let p = marks.first {

            let s = [p.locality, p.administrativeArea, p.country].compactMap{$0}.joined(separator: ", ")

            return s.isEmpty ? nil : s

        }

    } catch {

        dlog("MAP", "ReverseGeocode ERR: \(error.localizedDescription)")

    }

    return nil

} // reverseGeocode



/// Always returns Celsius. If coords exist, they are used and the city name is ignored.

/// Only if coords are nil do we geocode the city.

func fetchWeatherC(for trip: Trip) async -> (hiC: Double, loC: Double, rain: Int?)? {

    let ds = DF.ymd.string(from: trip.date)

    

    if let lat = trip.latitude, let lon = trip.longitude {

        // COORDS PATH

        guard let url = URL(string:

                                "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&start_date=\(ds)&end_date=\(ds)"

        ) else { return nil }

        do {

            dlog("NET", "WEATHER by COORDS → \(ds) lat=\(lat) lon=\(lon) (label '\(trip.city)')")

            let (data, _) = try await URLSession.shared.data(from: url)

            let w = try JSONDecoder().decode(WeatherResponse.self, from: data)

            guard let hi = w.daily.temperature_2m_max.first,

                  let lo = w.daily.temperature_2m_min.first else { return nil }

            let rain = w.daily.precipitation_probability_max?.first

            dlog("NET", "WEATHER OK hiC=\(hi) loC=\(lo) rain=\(rain.map(String.init) ?? "nil")")

            return (hi, lo, rain)

        } catch {

            dlog("NET", "WEATHER ERR (coords) \(error.localizedDescription)")

            return nil

        }

    }

    

    // CITY PATH (fallback)

    guard let (lat, lon) = await geocodeCity(trip.city) else {

        dlog("NET", "GEOCODE FAIL for '\(trip.city)' (no coords to use)")

        return nil

    }

    guard let url = URL(string:

                            "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&start_date=\(ds)&end_date=\(ds)"

    ) else { return nil }

    do {

        dlog("NET", "WEATHER by CITY → '\(trip.city)' \(ds) lat=\(lat) lon=\(lon)")

        let (data, _) = try await URLSession.shared.data(from: url)

        let w = try JSONDecoder().decode(WeatherResponse.self, from: data)

        guard let hi = w.daily.temperature_2m_max.first,

              let lo = w.daily.temperature_2m_min.first else { return nil }

        let rain = w.daily.precipitation_probability_max?.first

        dlog("NET", "WEATHER OK hiC=\(hi) loC=\(lo) rain=\(rain.map(String.init) ?? "nil")")

        return (hi, lo, rain)

    } catch {

        dlog("NET", "WEATHER ERR (city) \(error.localizedDescription)")

        return nil

    }

} // fetchWeatherC



// ================================================================

// MARK: - Temp Conversion

// ================================================================

private func cToF(_ c: Double) -> Double { (c * 9.0/5.0) + 32.0 } // cToF

private func formatTemp(celsius: Double, isF: Bool) -> String {

    let v = isF ? cToF(celsius) : celsius

    return String(Int(v.rounded())) + (isF ? "°F" : "°C")

} // formatTemp



// ================================================================

// MARK: - Button Style

// ================================================================

struct RoundedFilledButtonStyle: ButtonStyle {

    var color: Color

    func makeBody(configuration: Configuration) -> some View {

        configuration.label

            .font(.body.weight(.semibold))

            .foregroundStyle(.white)

            .padding(.horizontal, 14)

            .padding(.vertical, 10)

            .background(color.opacity(configuration.isPressed ? 0.85 : 1.0))

            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 2)

            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)

    } // makeBody

} // RoundedFilledButtonStyle



extension Color {

    static let btnPrimary = Color.blue

    static let btnSecondary = Color.purple

    static let btnNeutral = Color.gray.opacity(0.75)

    static let btnDestructive = Color.red

} // Color ext



// ================================================================

// MARK: - Map Picker Sheet (detents + bottom bar visible)

// ================================================================

struct MapPickerSheet: View {

    @Environment(\.dismiss) private var dismiss

    

    @State private var camera: MapCameraPosition

    @State private var coord: CLLocationCoordinate2D?

    

    let initial: CLLocationCoordinate2D?

    let onDone: (CLLocationCoordinate2D?) -> Void  // Done may pass nil

    

    init(initial: CLLocationCoordinate2D?, onDone: @escaping (CLLocationCoordinate2D?) -> Void) {

        self.initial = initial

        self.onDone = onDone

        if let initial {

            _camera = State(initialValue: .region(MKCoordinateRegion(

                center: initial,

                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)

            )))

            _coord = State(initialValue: initial)

        } else {

            _camera = State(initialValue: .automatic)

            _coord = State(initialValue: nil)

        }

    } // init

    

    var body: some View {

        ZStack(alignment: .bottom) {

            VStack(spacing: 12) {

                Text("Pick a Location")

                    .font(.title3.weight(.semibold))

                    .frame(maxWidth: .infinity, alignment: .leading)

                

                MapReader { proxy in

                    Map(position: $camera, interactionModes: [.all]) {

                        if let c = coord {

                            Annotation("Selected", coordinate: c) {

                                ZStack {

                                    Circle().fill(.red).frame(width: 16, height: 16)

                                    Circle().stroke(.white, lineWidth: 2).frame(width: 16, height: 16)

                                }

                            }

                        }

                    }

                    .mapStyle(.standard)

                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    .simultaneousGesture(

                        DragGesture(minimumDistance: 0).onEnded { value in

                            let drag = hypot(value.translation.width, value.translation.height)

                            guard drag < 4 else { return } // treat as tap, not pan/zoom

                            if let c = proxy.convert(value.location, from: .local) { coord = c }

                        }

                    )

                } // MapReader

                .frame(maxWidth: .infinity)

                .frame(maxHeight: .infinity, alignment: .top)

                

                if let c = coord {

                    Text(String(format: "Lat: %.5f  Lon: %.5f", c.latitude, c.longitude))

                        .font(.footnote.monospaced())

                        .foregroundStyle(.secondary)

                        .frame(maxWidth: .infinity, alignment: .leading)

                } else {

                    Text("Tap the map to drop a pin. You can pan and zoom normally.")

                        .font(.footnote)

                        .foregroundStyle(.secondary)

                        .frame(maxWidth: .infinity, alignment: .leading)

                }

                

                Spacer().frame(height: 70) // room for bottom bar

            } // VStack

            .padding(.horizontal)

            .padding(.top)

            .frame(minHeight: 540) // keeps bar visible in .medium

            

            // Bottom bar

            HStack(spacing: 16) {

                Button("Cancel") { onDone(nil); dismiss() }

                    .buttonStyle(RoundedFilledButtonStyle(color: .btnNeutral))

                

                Spacer()

                

                Button("Done") { onDone(coord); dismiss() }

                    .buttonStyle(RoundedFilledButtonStyle(color: .btnPrimary))

                    .disabled(coord == nil)

                    .opacity(coord == nil ? 0.5 : 1.0)

            } // HStack

            .padding(.horizontal)

            .padding(.vertical, 10)

            .frame(maxWidth: .infinity)

            .background(.regularMaterial)

            .overlay(Divider(), alignment: .top)

        } // ZStack

    } // body

} // MapPickerSheet



// ================================================================

// MARK: - Date Picker Sheet (large-only + bottom bar)

// ================================================================

struct DatePickerSheet: View {

    @Environment(\.dismiss) private var dismiss

    @Binding var date: Date

    let onDone: (Date) -> Void

    

    @State private var tempDate: Date

    

    init(date: Binding<Date>, onDone: @escaping (Date) -> Void) {

        self._date = date

        self.onDone = onDone

        _tempDate = State(initialValue: date.wrappedValue)

    } // init

    

    var body: some View {

        VStack(spacing: 0) {

            ScrollView {

                VStack(alignment: .leading, spacing: 16) {

                    Text("Select Date")

                        .font(.title3.weight(.semibold))

                        .frame(maxWidth: .infinity, alignment: .leading)

                    

                    DatePicker("", selection: $tempDate, displayedComponents: .date)

                        .datePickerStyle(.graphical)

                        .labelsHidden()

                        .frame(maxHeight: 340)

                } // VStack

                .padding(.horizontal)

                .padding(.top)

                .padding(.bottom, 90) // space for bottom bar

            } // ScrollView

        } // VStack

        .safeAreaInset(edge: .bottom) {

            HStack(spacing: 16) {

                Button("Cancel") { dismiss() }

                    .buttonStyle(RoundedFilledButtonStyle(color: .btnNeutral))

                Spacer()

                Button("Done") {

                    date = tempDate

                    onDone(tempDate)

                    dismiss()

                }

                .buttonStyle(RoundedFilledButtonStyle(color: .btnPrimary))

            } // HStack

            .padding(.horizontal)

            .padding(.vertical, 10)

            .background(.regularMaterial)

            .overlay(Divider(), alignment: .top)

        } // safeAreaInset

    } // body

} // DatePickerSheet



// ================================================================

// MARK: - Edit/Create Sheet

// ================================================================

struct EditTripSheet: View {

    @Environment(\.dismiss) private var dismiss

    @Environment(\.colorScheme) private var scheme

    

    // Inputs

    let initialTrip: Trip?

    let onSave: (Trip) -> Void

    let onDelete: (UUID) -> Void

    

    // Mode capture (prevents SwiftUI reinit surprises)

    private let isEditing: Bool

    

    // State

    @State private var city: String

    @State private var date: Date

    @State private var latitude: Double?

    @State private var longitude: Double?

    @State private var isFahrenheit = true

    

    // Modal sheets

    @State private var showMap = false

    @State private var mapDetent: PresentationDetent = .large

    @State private var showDatePicker = false

    

    // Preview

    @State private var previewLoading = false

    @State private var preview: (hiC: Double, loC: Double, rain: String)?

    @State private var previewError: String?

    

    init(initialTrip: Trip? = nil, onSave: @escaping (Trip) -> Void, onDelete: @escaping (UUID) -> Void) {

        self.initialTrip = initialTrip

        self.onSave = onSave

        self.onDelete = onDelete

        self.isEditing = (initialTrip != nil)

        

        let t = initialTrip ?? Trip(city: "", date: Date(), latitude: nil, longitude: nil)

        _city = State(initialValue: t.city)

        _date = State(initialValue: t.date)

        _latitude = State(initialValue: t.latitude)

        _longitude = State(initialValue: t.longitude)

    } // init

    

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 16) {

                

                Text(isEditing ? "Edit Trip" : "Create Trip")

                    .font(.title2.weight(.semibold))

                

                // ---------- Destination ----------

                sectionCard {

                    HStack(spacing: 10) {

                        Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)

                        TextField("City (auto-fills when you pick on map)", text: $city)

                            .textInputAutocapitalization(.words)

                            .disableAutocorrection(true)

                    } // HStack

                    

                    HStack(spacing: 10) {

                        Image(systemName: "calendar").foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {

                            Text("Date: \(DF.med.string(from: date))")

                            Button("Change Date") { showDatePicker = true }

                                .buttonStyle(RoundedFilledButtonStyle(color: .btnSecondary))

                        } // VStack

                        Spacer()

                    } // HStack

                    

                    HStack(spacing: 10) {

                        Image(systemName: "location.viewfinder").foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {

                            if let lat = latitude, let lon = longitude {

                                Text(String(format: "Lat %.5f  Lon %.5f", lat, lon))

                                    .font(.footnote.monospaced()).foregroundStyle(.secondary)

                            } else {

                                Text("No location selected")

                                    .font(.footnote).foregroundStyle(.secondary)

                            }

                            HStack(spacing: 8) {

                                Button("Map") { showMap = true }

                                    .buttonStyle(RoundedFilledButtonStyle(color: .btnSecondary))

                                if latitude != nil || longitude != nil {

                                    Button("Clear") { latitude = nil; longitude = nil }

                                        .buttonStyle(RoundedFilledButtonStyle(color: .btnNeutral))

                                }

                            } // HStack

                        } // VStack

                        Spacer()

                    } // HStack

                } // sectionCard

                

                // ---------- Units (preview only) ----------

                sectionCard {

                    Toggle(isOn: $isFahrenheit) { Text("Preview in Fahrenheit") }

                } // sectionCard

                

                // ---------- Preview ----------

                sectionCard {

                    if previewLoading {

                        HStack { ProgressView(); Text("Fetching preview…") } // HStack

                    } else if let p = preview {

                        VStack(alignment: .leading, spacing: 6) {

                            Text(city.isEmpty ? "Selected location" : city).font(.headline)

                            Text(DF.med.string(from: date)).foregroundStyle(.secondary)

                            HStack(spacing: 12) {

                                Text("High: \(formatTemp(celsius: p.hiC, isF: isFahrenheit))")

                                Text("Low: \(formatTemp(celsius: p.loC, isF: isFahrenheit))")

                                Text("Rain: \(p.rain)")

                            } // HStack

                        } // VStack

                    } else if let e = previewError {

                        Text(e).foregroundStyle(.red)

                    } else {

                        Text("Tap Preview to fetch weather for the City or Map location.")

                            .foregroundStyle(.secondary)

                    }

                    HStack {

                        Spacer()

                        Button("Preview") { Task { await runPreviewSmart() } }

                            .buttonStyle(RoundedFilledButtonStyle(color: .btnPrimary))

                    } // HStack

                } // sectionCard

                

                // ---------- Actions ----------

                HStack(spacing: 16) {

                    if isEditing, let t = initialTrip {

                        Button("Delete") {

                            onDelete(t.id)

                            dismiss()

                        }

                        .buttonStyle(RoundedFilledButtonStyle(color: .btnDestructive))

                    } // if

                    

                    Button("Cancel") { dismiss() }

                        .buttonStyle(RoundedFilledButtonStyle(color: .btnNeutral))

                    Spacer()

                    Button("Done") {

                        var t = initialTrip ?? Trip(city: "", date: Date())

                        t.city = city.trimmingCharacters(in: .whitespacesAndNewlines)

                        t.date = date

                        t.latitude = latitude

                        t.longitude = longitude

                        dlog("EDIT", "Saving trip id=\(t.id) city='\(t.city)' date=\(DF.ymd.string(from: t.date)) lat=\(t.latitude?.description ?? "nil") lon=\(t.longitude?.description ?? "nil")")

                        onSave(t)

                        dismiss()

                    }

                    .buttonStyle(RoundedFilledButtonStyle(color: .btnPrimary))

                    .disabled(!canSave)

                } // HStack

                .padding(.top, 4)

            } // VStack

            .padding()

        } // ScrollView

        // Date picker

        .sheet(isPresented: $showDatePicker) {

            DatePickerSheet(date: $date) { newDate in

                dlog("EDIT", "Picked date \(DF.ymd.string(from: newDate))")

            } // DatePickerSheet

            .presentationDetents([.large])

            .presentationDragIndicator(.visible)

        } // .sheet

        // Map picker — ALWAYS keep coords; city label is cosmetic

        .sheet(isPresented: $showMap) {

            let initialCoord = (latitude != nil && longitude != nil)

            ? CLLocationCoordinate2D(latitude: latitude!, longitude: longitude!)

            : nil

            MapPickerSheet(initial: initialCoord) { c in

                guard let c else {

                    dlog("EDIT", "Map Cancel (no coord change)")

                    return

                }

                latitude = c.latitude

                longitude = c.longitude

                dlog("EDIT", String(format: "Map Done lat=%.6f lon=%.6f (saved)", c.latitude, c.longitude))

                Task {

                    if let name = await reverseGeocode(lat: c.latitude, lon: c.longitude) {

                        await MainActor.run {

                            city = name

                            dlog("EDIT", "ReverseGeocode → '\(name)' (label only; coords take precedence)")

                        }

                    } else {

                        dlog("EDIT", "ReverseGeocode failed (label stays as-is); coords still saved")

                    }

                }

            } // MapPickerSheet

            .presentationDetents([.medium, .large], selection: $mapDetent)

            .presentationDragIndicator(.visible)

        } // .sheet

    } // body

    

    // MARK: logic & styling

    private var canSave: Bool {

        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        || (latitude != nil && longitude != nil)

    } // canSave

    

    /// Coords-first: if lat/lon exist, preview by coords; else geocode city.

    private func runPreviewSmart() async {

        previewError = nil

        preview = nil

        previewLoading = true

        defer { previewLoading = false }

        

        if let lat = latitude, let lon = longitude {

            dlog("PREVIEW", String(format: "Using COORDS lat=%.6f lon=%.6f (city label '%@' ignored)", lat, lon, city))

            if let w = await fetchWeatherC(for: Trip(id: UUID(), city: city, date: date, latitude: lat, longitude: lon)) {

                preview = (w.hiC, w.loC, w.rain.map { "\($0)%" } ?? "—")

                return

            } else {

                previewError = "Could not fetch weather for that location."

                return

            }

        }

        

        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCity.isEmpty else {

            previewError = "Enter a city or pick a location on the map first."

            return

        }

        dlog("PREVIEW", "No coords; geocoding city '\(trimmedCity)'")

        var tempTrip = Trip(city: trimmedCity, date: date)

        if let w = await fetchWeatherC(for: tempTrip) {

            preview = (w.hiC, w.loC, w.rain.map { "\($0)%" } ?? "—")

        } else {

            previewError = "Could not fetch weather for “\(trimmedCity)”."

        }

    } // runPreviewSmart

    

    @ViewBuilder private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {

        let fill: AnyShapeStyle = (scheme == .dark ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.ultraThinMaterial))

        VStack(alignment: .leading, spacing: 12) { content() }

            .padding(16)

            .background(fill)

            .clipShape(RoundedRectangle(cornerRadius: 14))

            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(uiColor: .separator), lineWidth: 1))

    } // sectionCard

} // EditTripSheet



// ================================================================

// MARK: - Grid (6 columns: Date, City, High, Low, Rain, Edit)

// ================================================================

struct IncrementalForecastGrid: View {

    @Binding var trips: [Trip]

    @Binding var isFahrenheit: Bool

    

    var onEdit: (Trip) -> Void

    var onAdd: () -> Void

    

    @State private var rows: [ForecastRow] = []

    @State private var fetchTasks: [UUID: Task<Void, Never>] = [:]

    

    // 6 columns (last is Edit actions)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0, alignment: .center), count: 6)

    private static let zebraA = Color.clear

    private static let zebraB = Color.secondary.opacity(0.06)

    

    var body: some View {

        ScrollView {

            VStack(spacing: 8) {

                // Centered title over the columns

                Text("MyTrip Forecast")

                    .font(.title.weight(.bold))

                    .frame(maxWidth: .infinity)

                    .multilineTextAlignment(.center)

                    .padding(.top, 4)

                

                LazyVGrid(columns: columns, spacing: 0) {

                    // Header

                    headerCell("Date")

                    headerCell("City")

                    headerCell("High (\(isFahrenheit ? "°F" : "°C"))")

                    headerCell("Low (\(isFahrenheit ? "°F" : "°C"))")

                    headerCell("Rain")

                    headerCell("Edit")

                    

                    // Rows

                    ForEach(rows) { row in

                        let zebra = zebraColor(for: row)

                        bodyCell(DF.med.string(from: row.date), zebra)

                        

                        // Visual marker 📍 when coords are present

                        let hasCoords = trips.first(where: { $0.id == row.tripId })?.latitude != nil

                        bodyCell(hasCoords ? "\(row.city)  📍" : row.city, zebra)

                        

                        bodyCell(row.highC.map { formatTemp(celsius: $0, isF: isFahrenheit) } ?? "—", zebra)

                        bodyCell(row.lowC.map { formatTemp(celsius: $0, isF: isFahrenheit) } ?? "—", zebra)

                        bodyCell(row.rainPct.map { "\($0)%" } ?? "—", zebra)

                        

                        editCell(zebra) {

                            if let t = tripFor(row) { onEdit(t) }

                        }

                    } // ForEach

                    

                    // Add-new row: "+" button in the Edit column

                    addNewRow { onAdd() }

                } // LazyVGrid

                .padding(.horizontal, 8)

                .overlay(Rectangle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))

            } // VStack

        } // ScrollView

        .frame(minHeight: 320)

        .task { await initialSetupAndLoad() }

        .onChange(of: trips) { _, _ in Task { await initialSetupAndLoad(rebuildRows: true) } }

        // No refetch on unit toggle; UI recomputes temps.

    } // body

    

    // MARK: Cells

    private func headerCell(_ text: String) -> some View {

        Text(text)

            .font(.headline)

            .frame(maxWidth: .infinity, minHeight: 36)

            .multilineTextAlignment(.center)

            .background(Color.secondary.opacity(0.12))

            .overlay(Rectangle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))

    } // headerCell

    

    private func bodyCell(_ text: String, _ bg: Color) -> some View {

        ZStack {

            if text == "—" { Text(text).foregroundStyle(.secondary) }

            else { Text(text) }

        }

        .font(.system(size: 14, weight: .medium, design: .rounded))

        .frame(maxWidth: .infinity, minHeight: 36)

        .multilineTextAlignment(.center)

        .background(bg)

        .overlay(Rectangle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))

    } // bodyCell

    

    private func editCell(_ bg: Color, action: @escaping () -> Void) -> some View {

        Button {

            action()

        } label: {

            Image(systemName: "pencil")

                .font(.system(size: 16, weight: .semibold))

                .frame(maxWidth: .infinity, minHeight: 36)

        }

        .buttonStyle(.plain)

        .background(bg)

        .overlay(Rectangle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))

        .contentShape(Rectangle())

    } // editCell

    

    private func addNewRow(_ action: @escaping () -> Void) -> some View {

        Group {

            bodyCell("", Self.zebraA) // Date

            bodyCell("", Self.zebraA) // City

            bodyCell("", Self.zebraA) // High

            bodyCell("", Self.zebraA) // Low

            bodyCell("", Self.zebraA) // Rain

            Button {

                action()

            } label: {

                Text("+")

                    .font(.system(size: 20, weight: .bold))

                    .frame(maxWidth: .infinity, minHeight: 36)

            }

            .buttonStyle(.plain)

            .background(Self.zebraA)

            .overlay(Rectangle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))

        } // Group

    } // addNewRow

    

    private func zebraColor(for row: ForecastRow) -> Color {

        guard let idx = rows.firstIndex(where: {$0.id == row.id}) else { return Self.zebraA }

        return idx.isMultiple(of: 2) ? Self.zebraA : Self.zebraB

    } // zebraColor

    

    private func tripFor(_ row: ForecastRow) -> Trip? {

        visibleTrips().first(where: { $0.id == row.tripId })

    } // tripFor

    

    // MARK: Future-only filter

    private func visibleTrips() -> [Trip] {

        let today = Calendar.current.startOfDay(for: Date())

        return trips.filter { Calendar.current.startOfDay(for: $0.date) >= today }

    } // visibleTrips

    

    // MARK: Loading

    private func initialSetupAndLoad(rebuildRows: Bool = false) async {

        dlog("GRID", "initialSetupAndLoad started")

        fetchTasks.values.forEach { $0.cancel() }

        fetchTasks.removeAll()

        

        let vTrips = visibleTrips()

        

        if rebuildRows || rows.count != vTrips.count || !rows.map(\.tripId).elementsEqual(vTrips.map(\.id)) {

            await MainActor.run {

                rows = vTrips.map { t in

                    ForecastRow(tripId: t.id, date: t.date, city: t.city, status: .queued)

                }

            }

        }

        await reloadAll()

    } // initialSetupAndLoad

    

    private func reloadAll() async {

        dlog("GRID", "reloadAll started")

        fetchTasks.values.forEach { $0.cancel() }

        fetchTasks.removeAll()

        

        let vTrips = visibleTrips()

        

        for (idx, trip) in vTrips.enumerated() {

            await MainActor.run {

                guard idx < rows.count else { return }

                rows[idx].status = .loading

                rows[idx].highC = nil

                rows[idx].lowC = nil

                rows[idx].rainPct = nil

            }

            

            let task = Task.detached(priority: .medium) {

                let res = await fetchWeatherC(for: trip)

                await MainActor.run {

                    guard idx < rows.count else { return }

                    if let r = res {

                        rows[idx].highC = r.hiC

                        rows[idx].lowC  = r.loC

                        rows[idx].rainPct = r.rain

                        rows[idx].status = .ready

                    } else {

                        rows[idx].status = .failed

                    }

                }

            }

            fetchTasks[trip.id] = task

        }

    } // reloadAll

} // IncrementalForecastGrid



// ================================================================

// MARK: - Shell (Edit sheet via item:, bottom + to add)

// ================================================================

struct ForecastShellView: View {

    @State private var trips: [Trip] = {

        var t = loadTrips()

        sortTripsByDate(&t) // ensure sorted on first load too

        return t

    }()

    

    @AppStorage("isFahrenheit") private var isFahrenheit: Bool = false

    

    @State private var showNewEditor = false

    @State private var editing: Trip? = nil

    

    var body: some View {

        NavigationStack {

            IncrementalForecastGrid(

                trips: $trips,

                isFahrenheit: $isFahrenheit,

                onEdit: { t in editing = t },

                onAdd: { showNewEditor = true }

            )

            .navigationTitle("MyTrip3 (C) H2so4 Consulting LLC 2025")

            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .topBarTrailing) {

                    HStack(spacing: 6) {

                        Text("F / C")

                            .font(.subheadline.weight(.semibold))

                            .foregroundStyle(.secondary)

                        Toggle("", isOn: $isFahrenheit)

                            .labelsHidden()

                            .toggleStyle(.switch)

                    }

                } // ToolbarItem

                // NOTE: No top-right "+" (adding is via bottom "+" row)

            } // toolbar

        } // NavigationStack

        

        // EDIT SHEET (Delete visible) — sort AFTER edit

        .sheet(item: $editing) { trip in

            EditTripSheet(

                initialTrip: trip,

                onSave: { updated in

                    if let idx = trips.firstIndex(where: { $0.id == updated.id }) {

                        trips[idx] = updated

                    }

                    sortTripsByDate(&trips)

                    saveTrips(trips)

                },

                onDelete: { id in

                    if let idx = trips.firstIndex(where: { $0.id == id }) {

                        trips.remove(at: idx)

                        saveTrips(trips)

                    }

                }

            )

            .presentationDetents([.large, .medium])

            .presentationDragIndicator(.visible)

        } // .sheet(item:)

        

        // NEW SHEET (triggered by "+" in bottom add row) — sort AFTER add

        .sheet(isPresented: $showNewEditor) {

            EditTripSheet(

                initialTrip: nil,

                onSave: { created in

                    trips.append(created)

                    sortTripsByDate(&trips)

                    saveTrips(trips)

                },

                onDelete: { _ in /* not shown in new mode */ }

            )

            .presentationDetents([.large, .medium])

            .presentationDragIndicator(.visible)

        } // .sheet(isPresented:)

        

        .onChange(of: trips) { _, new in

            saveTrips(new)

        } // .onChange

    } // body

} // ForecastShellView

