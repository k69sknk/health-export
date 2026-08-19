import SwiftUI
import MapKit

struct LiveMapView: View {
    let run: ActiveRun

    @State private var camera: MapCameraPosition = .automatic

    private var coordinates: [CLLocationCoordinate2D] {
        run.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Plan de course", systemImage: "map")
                    .font(Typeface.body(15, weight: .semibold))
                    .foregroundStyle(Palette.paper)
                Spacer()
                Text("\(run.points.count) points")
                    .font(Typeface.numeric(13, weight: .medium))
                    .foregroundStyle(Palette.paperDim)
            }

            Map(position: $camera) {
                if coordinates.count > 1 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(Palette.chartreuse, lineWidth: 4)
                }
                if let first = coordinates.first {
                    Marker("Départ", systemImage: "flag.fill", coordinate: first)
                        .tint(Palette.celadon)
                }
                if let last = coordinates.last, coordinates.count > 1 {
                    Marker("Position", systemImage: "figure.run", coordinate: last)
                        .tint(Palette.chartreuse)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.paper.opacity(0.08), lineWidth: 1)
            )
            .onChange(of: run.points.count) { _, _ in
                fitCamera()
            }
            .onAppear {
                fitCamera()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.bark.opacity(0.62))
        )
    }

    private func fitCamera() {
        guard !coordinates.isEmpty else { return }
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        if rect.isNull || rect.size.width == 0 || rect.size.height == 0 {
            if let last = coordinates.last {
                camera = .region(MKCoordinateRegion(
                    center: last,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
            return
        }
        let padded = rect.insetBy(dx: -rect.size.width * 0.25, dy: -rect.size.height * 0.25)
        withAnimation(.easeInOut(duration: 0.4)) {
            camera = .rect(padded)
        }
    }
}
