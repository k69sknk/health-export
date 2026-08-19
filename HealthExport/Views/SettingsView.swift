import SwiftUI
#if DEBUG
import Inject
#endif

struct SettingsView: View {
    #if DEBUG
    @ObserveInjection private var inject
    #endif
    @EnvironmentObject private var store: PipelineSettingsStore
    @EnvironmentObject private var bridge: GatewayStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    modeSection
                    endpointSection
                    metricsSection
                    payloadSection
                    Button {
                        bridge.pushSettings()
                    } label: {
                        Label("Pousser les réglages vers la Watch", systemImage: "applewatch.and.arrow.forward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.chartreuse)

                    Button {
                        bridge.sendTestPayload()
                    } label: {
                        Label("Envoyer une course de test au webhook", systemImage: "paperplane")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Palette.celadon)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.clear)
            .navigationTitle("Réglages")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Palette.void, for: .navigationBar)
        }
        #if DEBUG
        .enableInjection()
        #endif
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Mode de transmission")
            Picker("Mode", selection: $store.settings.mode) {
                ForEach(TransmissionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(store.settings.mode.subtitle)
                .font(Typeface.body(13))
                .foregroundStyle(Palette.paperDim)

            if store.settings.mode == .live {
                HStack(spacing: 12) {
                    Picker("Protocole", selection: $store.settings.liveTransport) {
                        ForEach(LiveTransport.allCases) { transport in
                            Text(transport.title).tag(transport)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper("\(store.settings.intervalSeconds) s", value: $store.settings.intervalSeconds, in: 1...30, step: 1)
                        .foregroundStyle(Palette.paper)
                }
            }
        }
        .settingsCard()
    }

    private var endpointSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Serveur & authentification")

            TextField("https://api.votredomaine.com/webhook", text: $store.settings.endpoint)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .foregroundStyle(Palette.paper)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.void.opacity(0.5)))

            TextField("Utilisateur / coureur", text: $store.settings.userId)
                .textInputAutocapitalization(.never)
                .foregroundStyle(Palette.paper)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.void.opacity(0.5)))

            SecureField("Secret HMAC (optionnel)", text: $store.settings.hmacSecret)
                .foregroundStyle(Palette.paper)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.void.opacity(0.5)))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Headers personnalisés")
                        .font(Typeface.body(14, weight: .semibold))
                        .foregroundStyle(Palette.paper)
                    Spacer()
                    Button(action: store.addHeader) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Palette.chartreuse)
                    }
                }

                ForEach($store.settings.headers) { $header in
                    HStack(spacing: 10) {
                        TextField("Clé", text: $header.key)
                            .textInputAutocapitalization(.never)
                        TextField("Valeur", text: $header.value)
                            .textInputAutocapitalization(.never)
                    }
                    .font(Typeface.body(13))
                    .foregroundStyle(Palette.paper)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.void.opacity(0.35)))
                }
            }
        }
        .settingsCard()
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Métriques à envoyer")
            ForEach(StreamMetric.allCases) { metric in
                Toggle(isOn: binding(for: metric)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(metric.title)
                            .font(Typeface.body(15, weight: .semibold))
                            .foregroundStyle(Palette.paper)
                        Text(metric.detail)
                            .font(Typeface.body(12))
                            .foregroundStyle(Palette.paperDim)
                    }
                }
                .toggleStyle(.switch)
                .tint(Palette.chartreuse)
            }
        }
        .settingsCard()
    }

    private var payloadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Aperçu du payload")
            Text(samplePayload)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Palette.paperDim)
                .textSelection(.enabled)
        }
        .settingsCard()
    }

    private func binding(for metric: StreamMetric) -> Binding<Bool> {
        Binding(
            get: { store.settings.enabledMetrics.contains(metric) },
            set: { isOn in
                if isOn {
                    store.settings.enabledMetrics.insert(metric)
                } else {
                    store.settings.enabledMetrics.remove(metric)
                }
            }
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Typeface.body(12, weight: .semibold))
            .foregroundStyle(Palette.celadon)
            .tracking(1.4)
    }

    private var samplePayload: String {
        let live = LiveMetricsEnvelope(
            event: ConnectivityPacket.liveMetrics.rawValue,
            workoutId: "8E5C1B2A-3D90-4A56",
            timestamp: Date(),
            userId: store.settings.userId,
            data: LiveMetrics(
                heartRate: 154,
                speedMps: 3.42,
                paceSecPerKm: 292,
                distanceMeters: 3420.5,
                cadenceSpm: 172,
                elevationMeters: 18,
                altitude: 42.1,
                verticalOscillationCm: 7.4,
                groundContactTimeMs: 214,
                strideLengthMeters: 1.12,
                runningPowerWatts: 278,
                location: GeoPoint(latitude: 47.618, longitude: -0.521, altitude: 42.1, accuracy: 4.0, speedMps: 3.42, course: 87, timestamp: Date())
            )
        )
        guard
            let data = try? JSONCoding.encoder.encode(live),
            let text = String(data: data, encoding: .utf8)
        else {
            return "—"
        }
        return text
    }
}

private struct SettingsCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.bark.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Palette.paper.opacity(0.07), lineWidth: 1)
            )
    }
}

private extension View {
    func settingsCard() -> some View {
        modifier(SettingsCardModifier())
    }
}
