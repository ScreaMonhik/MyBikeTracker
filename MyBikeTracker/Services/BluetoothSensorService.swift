import CoreBluetooth
import Foundation

struct DiscoveredSensor: Identifiable, Hashable {
    enum Kind: String {
        case heartRate
        case cadence
        case both
    }

    let id: UUID
    let name: String
    let kind: Kind
}

@MainActor
final class BluetoothSensorService: NSObject, ObservableObject {
    @Published var isPoweredOn = false
    @Published var isScanning = false
    @Published var discovered: [DiscoveredSensor] = []
    @Published var heartRateName: String?
    @Published var cadenceName: String?
    @Published var heartRate: Int?
    @Published var cadenceRPM: Double?
    @Published var wheelSpeedKmh: Double?

    @Published var wheelCircumferenceMm: Double = UserDefaults.standard.object(forKey: PreferenceKey.wheelCircumferenceMm) as? Double ?? 2105 {
        didSet {
            UserDefaults.standard.set(wheelCircumferenceMm, forKey: PreferenceKey.wheelCircumferenceMm)
        }
    }

    private var central: CBCentralManager?
    private var knownPeripherals: [UUID: CBPeripheral] = [:]
    private var heartRatePeripheral: CBPeripheral?
    private var cadencePeripheral: CBPeripheral?

    private var lastWheelRevs: UInt32?
    private var lastWheelTime: UInt16?
    private var lastCrankRevs: UInt16?
    private var lastCrankTime: UInt16?

    private static let heartRateService = CBUUID(string: "180D")
    private static let heartRateMeasurement = CBUUID(string: "2A37")
    private static let cscService = CBUUID(string: "1816")
    private static let cscMeasurement = CBUUID(string: "2A5B")

    override init() {
        super.init()
    }

    func prepareIfNeeded() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func prepareKnownSensorsIfNeeded() {
        let defaults = UserDefaults.standard
        let hasKnown = defaults.string(forKey: PreferenceKey.lastHeartRateSensorId) != nil
            || defaults.string(forKey: PreferenceKey.lastCadenceSensorId) != nil
        guard hasKnown else { return }
        prepareIfNeeded()
    }

    var hasLiveMetrics: Bool {
        heartRate != nil || cadenceRPM != nil || wheelSpeedKmh != nil
    }

    func startScan() {
        prepareIfNeeded()
        guard let central, central.state == .poweredOn else { return }
        discovered = []
        isScanning = true
        central.scanForPeripherals(
            withServices: [Self.heartRateService, Self.cscService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        central?.stopScan()
        isScanning = false
    }

    func connect(_ sensor: DiscoveredSensor) {
        guard let peripheral = knownPeripherals[sensor.id] else { return }
        stopScan()
        central?.connect(peripheral, options: nil)
    }

    func disconnectHeartRate() {
        if let peripheral = heartRatePeripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        heartRatePeripheral = nil
        heartRateName = nil
        heartRate = nil
        UserDefaults.standard.removeObject(forKey: PreferenceKey.lastHeartRateSensorId)
    }

    func disconnectCadence() {
        if let peripheral = cadencePeripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        cadencePeripheral = nil
        cadenceName = nil
        cadenceRPM = nil
        wheelSpeedKmh = nil
        lastWheelRevs = nil
        lastWheelTime = nil
        lastCrankRevs = nil
        lastCrankTime = nil
        UserDefaults.standard.removeObject(forKey: PreferenceKey.lastCadenceSensorId)
    }

    func reconnectKnownSensors() {
        guard let central, central.state == .poweredOn else { return }
        var identifiers: [UUID] = []
        if let raw = UserDefaults.standard.string(forKey: PreferenceKey.lastHeartRateSensorId),
           let id = UUID(uuidString: raw) {
            identifiers.append(id)
        }
        if let raw = UserDefaults.standard.string(forKey: PreferenceKey.lastCadenceSensorId),
           let id = UUID(uuidString: raw) {
            identifiers.append(id)
        }
        guard !identifiers.isEmpty else { return }
        for peripheral in central.retrievePeripherals(withIdentifiers: identifiers) {
            knownPeripherals[peripheral.identifier] = peripheral
            central.connect(peripheral, options: nil)
        }
    }

    private func kind(for advertisement: [String: Any]) -> DiscoveredSensor.Kind? {
        let services = (advertisement[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let hasHR = services.contains(Self.heartRateService)
        let hasCSC = services.contains(Self.cscService)
        if hasHR && hasCSC { return .both }
        if hasHR { return .heartRate }
        if hasCSC { return .cadence }
        return nil
    }

    private func parseHeartRate(_ data: Data) {
        guard let first = data.first else { return }
        let flags = Int(first)
        let value: Int
        if flags & 0x01 == 0 {
            value = data.count > 1 ? Int(data[1]) : 0
        } else if data.count >= 3 {
            value = Int(UInt16(data[1]) | UInt16(data[2]) << 8)
        } else {
            return
        }
        heartRate = value
    }

    private func parseCSC(_ data: Data) {
        guard let first = data.first else { return }
        var offset = 1
        let hasWheel = first & 0x01 != 0
        let hasCrank = first & 0x02 != 0

        if hasWheel, data.count >= offset + 6 {
            let revs = readUInt32(data, offset: offset)
            let time = readUInt16(data, offset: offset + 4)
            offset += 6
            if let lastRevs = lastWheelRevs, let lastTime = lastWheelTime {
                let dRevs = revs &- lastRevs
                let dTime = time &- lastTime
                if dTime > 0 {
                    let seconds = Double(dTime) / 1024.0
                    let meters = Double(dRevs) * (wheelCircumferenceMm / 1000.0)
                    wheelSpeedKmh = (meters / seconds) * 3.6
                }
            }
            lastWheelRevs = revs
            lastWheelTime = time
        }

        if hasCrank, data.count >= offset + 4 {
            let revs = readUInt16(data, offset: offset)
            let time = readUInt16(data, offset: offset + 2)
            if let lastRevs = lastCrankRevs, let lastTime = lastCrankTime {
                let dRevs = revs &- lastRevs
                let dTime = time &- lastTime
                if dTime > 0 {
                    let seconds = Double(dTime) / 1024.0
                    cadenceRPM = Double(dRevs) / seconds * 60.0
                }
            }
            lastCrankRevs = revs
            lastCrankTime = time
        }
    }

    private func readUInt16(_ data: Data, offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}

extension BluetoothSensorService: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            isPoweredOn = central.state == .poweredOn
            if central.state == .poweredOn {
                reconnectKnownSensors()
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            knownPeripherals[peripheral.identifier] = peripheral
            let name = peripheral.name
                ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
                ?? "Sensor"
            let kind = kind(for: advertisementData) ?? .both
            let sensor = DiscoveredSensor(id: peripheral.identifier, name: name, kind: kind)
            if !discovered.contains(where: { $0.id == sensor.id }) {
                discovered.append(sensor)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([Self.heartRateService, Self.cscService])
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            if peripheral.identifier == heartRatePeripheral?.identifier {
                heartRatePeripheral = nil
                heartRateName = nil
                heartRate = nil
            }
            if peripheral.identifier == cadencePeripheral?.identifier {
                cadencePeripheral = nil
                cadenceName = nil
                cadenceRPM = nil
                wheelSpeedKmh = nil
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            if service.uuid == Self.heartRateService {
                peripheral.discoverCharacteristics([Self.heartRateMeasurement], for: service)
            } else if service.uuid == Self.cscService {
                peripheral.discoverCharacteristics([Self.cscMeasurement], for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == Self.heartRateMeasurement || characteristic.uuid == Self.cscMeasurement {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        Task { @MainActor in
            let name = peripheral.name ?? "Sensor"
            if service.uuid == Self.heartRateService {
                heartRatePeripheral = peripheral
                heartRateName = name
                UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: PreferenceKey.lastHeartRateSensorId)
            }
            if service.uuid == Self.cscService {
                cadencePeripheral = peripheral
                cadenceName = name
                UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: PreferenceKey.lastCadenceSensorId)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        Task { @MainActor in
            if characteristic.uuid == Self.heartRateMeasurement {
                parseHeartRate(data)
            } else if characteristic.uuid == Self.cscMeasurement {
                parseCSC(data)
            }
        }
    }
}
