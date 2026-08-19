import SwiftUI

struct CatalogView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tout ce qui sort de la montre")
                            .font(Typeface.display(30))
                            .foregroundStyle(Palette.paper)
                        Text("Les champs que la passerelle peut exporter pendant et après la course.")
                            .font(Typeface.body(15))
                            .foregroundStyle(Palette.paperDim)
                    }

                    ForEach(ExportCatalog.grouped, id: \.0) { group, fields in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.uppercased())
                                .font(Typeface.body(12, weight: .semibold))
                                .foregroundStyle(Palette.celadon)
                                .tracking(1.4)

                            ForEach(fields) { field in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(field.live ? Palette.chartreuse : Palette.rust)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 7)
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(field.title)
                                                .font(Typeface.body(15, weight: .semibold))
                                                .foregroundStyle(Palette.paper)
                                            Spacer()
                                            Text(field.live ? "live" : "fin")
                                                .font(Typeface.body(11, weight: .bold))
                                                .foregroundStyle(Palette.void)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Capsule().fill(field.live ? Palette.chartreuse : Palette.rust))
                                        }
                                        Text("\(field.source) · `\(field.key)`")
                                            .font(Typeface.body(12))
                                            .foregroundStyle(Palette.paperDim)
                                        if !field.notes.isEmpty {
                                            Text(field.notes)
                                                .font(Typeface.body(12))
                                                .foregroundStyle(Palette.paperDim.opacity(0.8))
                                        }
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Palette.bark.opacity(0.38))
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.clear)
            .navigationTitle("Exports")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Palette.void, for: .navigationBar)
        }
    }
}
